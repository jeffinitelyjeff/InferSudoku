settings =
  # delay after filling in cells
  fdel: 50
  # delay between strategies
  sdel: 100

## ---------------------------------------------------------------------------
## General Helpers -----------------------------------------------------------

helpers =

 ## Basic helper functions.

  init: (a, len, fn_value) ->
    a[i] = fn_value() for i in a[1..len]

  eq: (xs, ys) ->
    return false if xs.length != ys.length

    for i in xs.length
      return false if xs[i] != ys[i]

    return true

  set_subtract: (xs, ys) ->
    result = []
    for x in xs
      result.push x unless x in ys
    return result

  # count the number of elements of an array which are greater than 0. this
  # will be used for a grid to see how many elements have been filled into
  # particular rows/cols/groups (empty values are stored as 0's).
  num_pos: (xs) ->
    i = 0
    for x in xs
      i += 1 if x > 0
    return i

  ## Coordinate manipulation.

  # cartesian coordinates -> group coordinates
  # x,y -> [b_x, b_y, s_x, s_y]
  # two parameters are expected, but if only one parameter is passed, then the
  # first argument is treated as an array of the two parameters.
  cart_to_group: (x,y) ->
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
  group_to_cart: (b_x, b_y, s_x, s_y) ->
    x = 3*b_x + s_x
    y = 3*b_y + s_y

    return [x, y]

## ---------------------------------------------------------------------------
## Helpers for interactions with the DOM -------------------------------------

domhelpers =

  ## JQuery selectors.

  sel_row: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_group x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{i} .r#{s_y} .c#{j}, " unless i == b_x and j == s_x
    return s

  sel_col: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_group x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{i} .gc#{b_x} .r#{j} .c#{s_x}, " unless i == b_y and j == s_y
    return s

  sel_group: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_group x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{b_x} .r#{j} .c#{i}, " unless i == s_x and j == s_y
    return s

  sel: (x, y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_group x,y
    return ".gr#{b_y} .gc#{b_x} .r#{s_y} .c#{s_x}"

  color_adjacent: (x,y) ->
    fn1 = ->
      $(@sel_group(x,y)).addClass("adjacent2")
      $(@sel_col(x,y)).addClass("adjacent")
      $(@sel_row(x,y)).addClass("adjacent")
    fn2 = ->
      $(@sel_group(x,y)).removeClass("adjacent2")
      $(@sel_col(x,y)).removeClass("adjacent")
      $(@sel_row(x,y)).removeClass("adjacent")
    $(@sel(x,y)).hover(fn1, fn2)

  # a low-level function to get the value of the input HTML element at the
  # specified position in the Sudoku grid.
  get_input_val: (x, y) ->
    $(@sel(x,y) + " .num").val()

  # set_input_val(x,y,v) is a low-level function to set the value of the input
  # HTML element at the specified position in the Sudoku grid.
  set_input_val: (x, y, v) ->
    $(@sel(x,y) + " .num").val(v)


## ----------------------------------------------------------------------------
## Low-level Utility Functions ------------------------------------------------

## Logging.

log = (s) ->
  t = $('#stderr')
  t.val(t.val() + s + '\n')
  t.scrollTop(9999999)
  return s

log 'init webapp'






## ---------------------------------------------------------------------------
## Grid Class ----------------------------------------------------------------

class Grid
  constructor: ->
    # cell values
    @base_array = @collect_input()

  # UTILITY METHODS ----------------------------------------------------------
  # --------------------------------------------------------------------------

  # collect the values of the input elements and return them in a 1D array.
  collect_input: ->
    a = []
    for j in [0..8]
      for i in [0..8]
        v = domhelpers.get_input_val i, j
        a.push if v is '' then 0 else parseInt(v)
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

  # access an element using base indices.
  get_b: (i) ->
    @base_array[i]

  # access an element using cartesian coordinates.
  get_c: (x,y) ->
    @get_b @cart_to_base(x,y)

  # access an element using group coordinates
  get_g: (b_x, b_y, s_x, s_y) ->
    @get_b @cart_to_base helpers.group_to_cart(b_x, b_y, s_x, s_y)

  set_b: (i, v) ->
    # store in internal representation
    @base_array[i] = v

    # change displayed value in HTML
    [x,y] = @base_to_cart i
    if v is 0
      domhelpers.set_input_val(x,y,'')
    else
      domhelpers.set_input_val(x,y,v)
      $(domhelpers.sel(x,y)).addClass('new')
      $(domhelpers.sel(x,y))
        .addClass('highlight', 500).delay(500).removeClass('highlight', 2000)

    # TODO update stored info

  set_c: (x,y,v) ->
    @set_b(@cart_to_base(x,y), v)

  set_g: (b_x, b_y, s_x, s_y) ->
    @set_b(@cart_to_base helpers.group_to_cart(b_x, b_y, s_x, s_y), v)

  # returns an array of all the values in a particular group, either specified
  # as a pair of coordinates or as an index (so the 6th group is the group
  # with b_x=0, b_y=2).
  get_group: (x, y) ->
    unless y?
      y = Math.floor x / 3
      x = Math.floor x % 3

    a = []
    for j in [0..2]
      for i in [0..2]
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

    [b_x, b_y, s_x, s_y] = helperscart_to_group cart
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
  valid_array: (xs) ->
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
  is_valid: ->
    for i in [0..8]
      return false unless @valid_array @get_col i
      return false unless @valid_array @get_row i
      return false unless @valid_array @get_group i
    return true

## ---------------------------------------------------------------------------
## Solver Class --------------------------------------------------------------

class Solver
  constructor: (@grid) ->
    # which values each cell can be; this info will ordinarily be stored if
    # there are only a couple possible values, or if the algorithm is
    # desperate (and then it only makes sense to store this if there are up to
    # 4 elements; if there are 5 possibilities, then it's easier (and more
    # human-like) to store that 4 possibilities are ruled out.
    @cell_must_arrays = []
    helpers.init(@cell_must_arrays, 81, -> 0)

    # which values each cell cannot be; this info will ordinarily only be
    # stored if the algorithm is desperate, as it does not immediately help
    # find values to fill in. it only makes sense to store this if there are
    # up to 4 elements; if there are 5 possibilites ruled out, then it's
    # easier (and more human-like) to store the 4 possibilites instead of the
    # 5 ruled out ones.
    @cell_cant_arrays = []
    helpers.init(@cell_cant_arrays, 81, -> 0)

    @solve_iter = 0
    @updated = true # this initial value turns out to matter
    @desperate = false

  # returns the values the cell must be if that info is currently stored;
  # otherwise returns null.
  cell_must: (i) ->
    if @cell_must_arrays[i] == 0 then null else @cell_must_arrays[i]

  # sets a list of values that a cell must be. returns whether the setting was
  # necessary, ie if an identical array was already present.
  set_cell_must: (i, a) ->
    if @cell_must(i)? and helpers.eq(@cell_must(i), a)
      retun false
    else
      @cell_must_arrays[i] = a
      return true

  # returns the values the cell cant be if that info is currently stored;
  # otherwise returns null.
  cell_cant: (i) ->
    if @cell_cant_arrays[i] == 0 then null else @cell_cant_arrays[i]

  # sets a list of values that a cell cant be. returns whether the setting was
  # necessary, ie if an identical array was already present.
  set_cell_cant: (i, a) ->
    if @cell_cant(i)? and helpers.eq(@cell_cant(i), a)
      return false
    else
      @cell_cant_arrays[i] = a
      return true

  # determines if it is possible to put value v at index i of the grid.
  cell_is_possible: (v, i) ->
    v not in @grid.get_row_of(i) and
    v not in @grid.get_col_of(i) and
    v not in @grid.get_group_of(i)

  # STRATEGIES ---------------------------------------------------------------

  cell_by_cell_loop: (i) ->
    can = []

    [x,y] = @grid.base_to_cart i

    next_step = @cell_by_cell_loop.bind(@, i+1)
    done = @solve_loop.bind(@)
    immediately_iterate = ->
      if i == 80 then setTimeout(done, sdel) else next_step()

    # only proceed if the cell is unknown, and if desperate or if there is
    # enough info to make this strategy seem reasonable.
    if @grid.get_b(i) == 0 and (@desperate or
                                helpers.num_pos(@grid.get_group_of(i)) >= 4 or
                                helpers.num_pos(@grid.get_col_of(i)) >= 4 or
                                helpers.num_pos(@grid.get_row_of(i)) >= 4)
      # store which values are possible for this cell.
      for v in [1..9]
        can.push v if @cell_is_possible v, i

      switch can.length
        when 1
          # set the cell's value if only one value is possible.
          desp_string = if @desperate then 'desperate ' else ''
          log "Setting (#{x}, #{y}) to #{can[0]} by #{desp_string}Cell By Cell"

          @grid.set_b(i, can[0])
          @updated = true

          if i == 80 then setTimeout(done, sdel) else setTimeout(next_step, fdel)

        when 2,3
          # store the cell-must-be-one-of-these-values info if there are 2 or
          # 3 possible values.
          @updated = @desperate and @set_cell_must(i, can)

          immediately_iterate()

        when 4
          # store the cell-must-be-one-of-these-values info if we're desperate
          # and there are 4 possible values.
          if @desperate
            @updated = @set_cell_must(i, can)

          immediately_iterate()

        else
          # if this cell can be more than 4 things and we're desperate, then
          # store info about what cells aren't possible.
          if @desperate
            cant = helpers.set_subtract([1..9], can)

            @updated = @set_cell_cant(i, cant)

          immediately_iterate()
    else
      immediately_iterate()

  cell_by_cell: ->
    log (if @desperate then "desperately " else "") + "performing Cell By Cell"

    @updated = false

    @cell_by_cell_loop(0)

  # SOLVE LOOP ---------------------------------------------------------------

  solve_loop : ->
    @solve_iter += 1
    log "iteration #{@solve_iter}" + if @desperate then ", desperate" else ""

    if not @updated
      # give up if we were desperate and didn't get anywhere.
      if @desperate
        @solve_loop_done()
      # if we weren't desperate, then set to desperate and try again.
      else
        @desperate = true

    # finish if the grid is complete or we've done too much effort
    if @grid.is_valid() or @solve_iter > 100
      log 'breaking out?'
      @solve_loop_done()
    else
      # this will set @updated, and call solve_loop recursively.
      @cell_by_cell()

  solve_loop_done: ->
    log if @grid.is_valid() then "Grid solved! :)" else "Grid not solved :("

    log "Must: " + @cell_must_arrays
    log "Cant: " + @cell_cant_arrays

  solve: ->
    @solve_loop()


easy = '''
3784.9...
2....14.9
1.9.5.3..
71....25.
....7....
.92....84
..4.2.8.3
5.71....2
...9.6547
'''

hard = '''
4...8.3..
.7..63..5
.......46
.6.357...
.8.....3.
...648.2.
14.......
7..93..6.
..2.7...8
'''

evil = '''
..1...39.
.....1.8.
76..4..2.
....98...
3...2...8
...57....
.1..3..54
.2.9.....
.83...6..
'''

$("#stdin").val(easy)

for j in [0..8]
  for i in [0..8]
    domhelpers.color_adjacent(i,j)


inject = ->
  text = $("#stdin").val()

  rows = text.split("\n")
  r = 0

  for row in rows

    cols = row.split('')
    c = 0

    for v in cols
      if v is '.'
        domhelpers.set_input_val(c,r,'')
      else
        domhelpers.set_input_val(c,r,v)
      c += 1

    r += 1

  log 'injecting input into the grid'

$("#input-b").click inject
inject()


$("#solve-b").click ->
  g = new Grid()
  s = new Solver(g)
  s.solve()
