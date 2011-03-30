$(document).ready ->

  ## ---------------------------------------------------------------------------
  ## General Helper Functions --------------------------------------------------

  init = (a, len, fn_value) ->
    a[i] = fn_value() for i in a[1..len]

  eq = (xs, ys) ->
    return false if xs.length != ys.length
    for i in [0...xs.length]
      return false if xs[i] != ys[i]
    return true

  ## ----------------------------------------------------------------------------
  ## Low-level Utility Functions ------------------------------------------------

  ## Logging.

  log = (s) ->
    t = $('#stderr')
    t.val(t.val() + s + '\n')
    t.scrollTop(9999999)
    return s

  log 'init webapp'

  ## Coordinate manipulation.

  # cartesian coordinates -> group coordinates
  # x,y -> [b_x, b_y, s_x, s_y]
  # two parameters are expected, but if only one parameter is passed, then the
  # first argument is treated as an array of the two parameters.
  cart_to_group = (x,y) ->
    unless y?
      y = x[1]
      x = x[0]

    b_x = Math.floor x / 3 # which big column
    b_y = Math.floor y / 3 # which big row
    s_x = Math.floor x % 3 # which small column within b_x
    s_y = Math.floor y % 3 # which small row within b_y

    return [b_x, b_y, s_x, s_y]

  # group coordinates -> cartesian coordinates
  # b_x,b_y,s_x,s_y -> [x, y]
  group_to_cart = (b_x, b_y, s_x, s_y) ->
    x = 3*b_x + s_x
    y = 3*b_y + s_y

    return [x, y]

  ## Interaction with Sudoku grid HTML input elements.

  # a low-level function to get the JQuery selector for the HTML table cell at
  # the specified cartesian coordinates in the Sudoku grid.
  sel = (x, y) ->
    [b_x, b_y, s_x, s_y] = cart_to_group x,y
    return ".gr#{b_y} .gc#{b_x} .r#{s_y} .c#{s_x}"

  # a low-level function to get the value of the input HTML element at the
  # specified position in the Sudoku grid.
  get_input_val = (x, y) ->
    $(sel(x,y) + " .num").val()

  # set_input_val(x,y,v) is a low-level function to set the value of the input
  # HTML element at the specified position in the Sudoku grid.
  set_input_val = (x, y, v) ->
    $(sel(x,y) + " .num").val(v)


  ## ---------------------------------------------------------------------------
  ## Grid Class ----------------------------------------------------------------

  class Grid
    constructor: ->
      # cell values
      @base_array = @collect_input()

      # which values each cell can be; this info will ordinarily be stored if
      # there are only a couple possible values, or if the algorithm is
      # desperate (and then it only makes sense to store this if there are up to
      # 4 elements; if there are 5 possibilities, then it's easier (and more
      # human-like) to store that 4 possibilities are ruled out.
      @cell_must_arrays = []
      init(@cell_must_arrays, 81, -> 0)

      # which values each cell cannot be; this info will ordinarily only be
      # stored if the algorithm is desperate, as it does not immediately help
      # find values to fill in. it only makes sense to store this if there are
      # up to 4 elements; if there are 5 possibilites ruled out, then it's
      # easier (and more human-like) to store the 4 possibilites instead of the
      # 5 ruled out ones.
      @cell_cant_arrays = []
      init(@cell_cant_arrays, 81, -> 0)

      @desperate = false


    # UTILITY METHODS ----------------------------------------------------------
    # --------------------------------------------------------------------------

    # collect the values of the input elements and return them in a 1D array.
    collect_input: ->
      a = []
      for j in [0..8]
        for i in [0..8]
          v = get_input_val i, j
          a.push if v is '' then 0 else parseInt v
      return a

    # cartesian coordinates -> base index
    # x,y -> i
    cart_to_base: (x,y) ->
      unless y?
        y = x[1]
        x = x[0]

      9*y + x

    # base index -> cartesian coordinates
    # i -> [x,y]
    base_to_cart: (i) ->
      x = Math.floor i % 9
      y = Math.floor i / 9
      return [x,y]

    # count the number of elements of an array which are greater than 0. this
    # will be used for a grid to see how man elements in a row/col/group are
    # filled in.x
    count_filled: (xs) ->
      i = 0
      for x in xs
        i += 1 if x > 0
      return i

    # access an element using base indices.
    get_b: (i) ->
      @base_array[i]

    # access an element using cartesian coordinates.
    get_c: (x,y) ->
      @get_b @cart_to_base(x,y)

    # access an element using group coordinates
    get_g: (b_x, b_y, s_x, s_y) ->
      @get_b @cart_to_base group_to_cart(b_x, b_y, s_x, s_y)

    set_b: (i, v) ->
      # store in internal representation
      @base_array[i] = v

      # change displayed value in HTML
      [x,y] = @base_to_cart i
      if v is 0
        set_input_val(x,y,'')
      else
        set_input_val(x,y,v)

      # TODO update stored info

    set_c: (x,y,v) ->
      @set_b(@cart_to_base(x,y), v)

    set_g: (b_x, b_y, s_x, s_y) ->
      @set_b(@cart_to_base group_to_cart(b_x, b_y, s_x, s_y), v)

    # returns an array of all the values in a particular group, either specified
    # as a pair of coordinates or as an index (so the 6th group is the group
    # with b_x=0, b_y=2).
    get_group: (x, y) ->
      unless y?
        y = Math.floor x / 3
        x = Math.floor x % 3

      a = []
      for i in [0..2]
        for j in [0..2]
          a.push @get_g(x, y, i, j)

      return a

    # returns the array of all values in the group which this cell (specified in
    # cartesian coordinates if two parameters are passed, in a base index if
    # only one paramater is passed) occupies.
    get_group_of: (x, y) ->
      if y?
        cart = [x,y]
      else
        cart = @base_to_cart x

      [b_x, b_y, s_x, s_y] = cart_to_group cart
      @get_group b_x, b_y

    # gets the arroy of values from particular row
    get_col: (x) ->
      (@get_c(x,i) for i in [0..8])

    # returns the array of all values in the col which this cell (specified in
    # cartesian coordinates if two parameters are passed, or specified in a base
    # index if only one paramater is passed) occupies.
    get_col_of: (x, y) ->
      if y?
        @get_col x
      else
        @get_col @base_to_cart(x)[0]

    # get the array of values from particular col
    get_row: (y) ->
      (@get_c(i,y) for i in [0..8])

    # returns the array of all values in the row which this cell occupies
    # (specified in cartesian coordinatse if two parameters are passed, or
    # specified in a base index if only one parameter is passed).
    get_row_of: (x, y) ->
      if y?
        @get_row y
      else
        @get_row @base_to_cart(x)[1]

    # determines if an array of numbers has one of each of the numbers 1..9
    # without any repeats. will be called on rows, columns, and groups.
    is_valid: (xs) ->
      hits = []

      for x in xs
        if hits[x]? then hits[x] += 1 else hits[x] = 1

      for hit in hits[1...9]
        return false if hit isnt 1

      return true

    # determine if the entire grid is valid according to the three satisfaction
    # rules:
    #   - each row is unique
    #   - each col is unique
    #   - each group is unique
    grid_is_valid: ->
      for i in [0..8]
        return false unless @is_valid @get_col i
        return false unless @is_valid @get_row i
        return false unless @is_valid @get_group i
      return true

    # determines if it is possible to put value v at index i of the grid.
    is_possible: (v, i) ->
      v not in @get_row_of(i) and
      v not in @get_col_of(i) and
      v not in @get_group_of(i)

    # returns the values the cell must be if that info is currently stored;
    # otherwise returns null.
    cell_must: (i) ->
      if @cell_must_arrays[i] == 0 then null else @cell_must_arrays[i]

    # returns the values the cell cant be if that info is currently stored;
    # otherwise returns null.
    cell_cant: (i) ->
      if @cell_cant_arrays[i] == 0 then null else @cell_cant_arrays[i]


    # STRATEGIES ---------------------------------------------------------------
    # --------------------------------------------------------------------------

    # Returns true if the grid has been updated (or, if @desperate, then if any
    # knowledge has been updated)
    cellByCell: ->
      log "performing Cell By Cell"
      updated = false

      # for each cell index
      for i in [0...81]
        can = []

        # only proceed if the cell is unknown, and if desperate or if there is
        # enough info to make this strategy seem reasonable.
        if @base_array[i] == 0 and (@desperate or
                                    @count_filled(@get_group_of(i)) >= 4 or
                                    @count_filled(@get_col_of(i)) >= 4 or
                                    @count_filled(@get_row_of(i)) >= 4)

          # store which values are possible for the cell
          for v in [1..9]
            can.push v if @is_possible v, i

          # set the cell's value if only one value is possible
          if can.length == 1
            log "Setting (#{@base_to_cart(i)[0]}, #{@base_to_cart(i)[1]}) by CellByCell"
            @set_b(i, can[0])
            updated = true

          # store the cell-must-be-one-of-these-values info if there are 2 or 3
          # possible values, or if there are 4 and you're desperate
          if can.length == 2 or can.length == 3 or
             (@desperate and can.length == 4)
            # only store it and mark as updated if the info wasn't previously
            # there.
            unless @cell_must(i)? and eq(@cell_must(i), can)
              @cell_must_arrays[i] = can
              updated = if @desperate then true else false

          # if we're desperate and we don't have info about what value this cell
          # must be already (possibly filled in just above), then there are
          # several possibilites and only a couple ruled out, so we'll instead
          # store the ruled out possibilites.
          if @desperate and not @cell_must(i)?
            cant = []
            for v in [1..9]
              cant.push v unless @is_possible v, i

            unless @cell_cant(i)? and eq(@cell_cant(i), cant)
              @cell_cant_arrays[i] = cant
              updated = if @desperate then true else false

      # this will be set to true if any info was updated on any cells.
      return updated


    # SOLVE LOOP ---------------------------------------------------------------
    # --------------------------------------------------------------------------

    solve: ->
      iter = 0
      grid_changed = true

      until @grid_is_valid() or not grid_changed
        iter += 1

        grid_changed = @cellByCell()
        @desperate = not grid_changed

      log if @grid_is_valid() then "Grid solved! :)" else "Grid not solved :("

      log "Must: " + @cell_must_arrays
      log "Cant: " + @cell_cant_arrays





  sample = '''
           .1.97...6
           ...1..4..
           329..87.5
           1.2...9..
           .9.....7.
           ..4...2.8
           9.75..834
           ..8..3...
           5...47.2.
           '''

  $("#stdin").val(sample)

  $("#input-b").click ->
    text = $("#stdin").val()

    rows = text.split("\n")
    r = 0

    for row in rows

      cols = row.split('')
      c = 0

      for v in cols
        if v is '.' then set_input_val(c,r,'') else set_input_val(c,r,v)
        c += 1

      r += 1

    log 'injecting input into the grid'


  $("#solve-b").click ->
    grid = new Grid()
    grid.solve()

