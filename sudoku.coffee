$(document).ready ->

  ## ---------------------------------------------------------------------------
  ## General Helper Functions --------------------------------------------------

  init = (a, len, fn_value) ->
    a[i] = fn_value() for i in a[1..len]

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
  cart_to_group = (x,y) ->
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
      log "grid: " + @base_array

      # which values each cell CANNOT be, along with a parallel array tracking
      # how many such values each cell has.
      @cant_array = []
      init(@cant_array, 81, -> [])
      @cant_length = []
      init(@cant_length, 81, 0)

      # which values each cell MUST be, along with a parallel array tracking how
      # many such values each cell has.
      @must_array = []
      init(@must_array, 81, -> [])
      @must_length = []
      init(@must_length, 81, 0)

    # collect the values of the input elements and return them in a 1D array.
    collect_input: ->
      a = []
      for i in [0..8]
        for j in [0..8]
          v = get_input_val i,j
          a.push if v is '' then 0 else v
      return a

    # cartesian coordinates -> base index
    # x,y -> i
    cart_to_base: (x,y) ->
      9*y + x

    # base index -> cartesian coordinates
    # i -> [x,y]
    base_to_cart: (i) ->
      x = Math.floor i % 9
      y = Math.floor i / 9
      return [x,y]

    # access an element using base indices.
    get_b: (i) ->
      @base_array[i]

    # access an element using cartesian coordinates.
    get_c: (x,y) ->
      @get_b @cart_to_base(x,y)

    # access an element using group coordinates
    get_g: (b_x, b_y, s_x, s_y) ->
      get_b @cart_to_base group_to_cart(b_x, b_y, s_x, s_y)

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

    # gets the arroy of values from particular row
    get_col: (x) ->
      (@get_c(x,i) for i in [0..8])

    # get the array of values from particular col
    get_row: (y) ->
      log "getting row " + y
      a = (@get_c(i,y) for i in [0..8])
      log a


    # determines if an array of numbers has one of each of the numbers 1..9
    # without any repeats. will be called on rows, columns, and groups.
    is_valid: (xs) ->
      hits = []
      for x in xs
        hits[x] += 1

      for hit in hits[1..9]
        return false unless hit is 1

      return true

    # determine if the entire grid is valid according to the three satisfaction
    # rules:
    #   - each row is unique
    #   - each col is unique
    #   - each group is unique
    grid_is_valid: ->
      log "checking if grid is valid"
      for i in [0..8]
        log "checking col " + i
        return false unless @is_valid @get_col i
        log "checking row " + i
        return false unless @is_vaild @get_row i
        log "checking group " + i
        return false unless @is_valid @get_group i
      return true

    solve: ->
      if @grid_is_valid() then log 'solved :)' else log 'not solved :('


  sample = '''
           ..58..9..
           ........8
           .2..17.3.
           ....64..9
           37..5..46
           9..38....
           .1.64..9.
           8........
           ..7..16..
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

