settings =
  # delay after filling in cells
  FILL_DELAY: 50
  # delay between strategies
  STRAT_DELAY: 100
  # number of times to run the solve loop before dying
  max_solve_iter: 10

## ---------------------------------------------------------------------------
## General Helpers -----------------------------------------------------------

helpers =

 ## Basic helper functions.

  eq: (xs, ys) ->
    return false if xs.length != ys.length
    for i in xs.length
      return false if xs[i] != ys[i]
    return true

  # returns the set which contains all elements of x which are not elements of y.
  set_subtract: (xs, ys) ->
    result = []
    for x in xs
      result.push x unless x in ys
    return result

  # count the number of elements of an array which are greater than 0. this
  # will be used for a grid to see how many elements have been filled into
  # particular rows/cols/boxes (empty values are stored as 0's).
  num_pos: (xs) ->
    i = 0
    for x in xs
      i += 1 if x > 0
    return i

  ## Coordinate manipulation.

  # cartesian coordinates -> box coordinates
  # x,y -> [b_x, b_y, s_x, s_y]
  # two parameters are expected, but if only one parameter is passed, then the
  # first argument is treated as an array of the two parameters.
  cart_to_box: (x,y) ->
    unless y?
      y = x[1]
      x = x[0]

    b_x = Math.floor x / 3 # which big column
    b_y = Math.floor y / 3 # which big row
    s_x = Math.floor x % 3 # which small column within b_x
    s_y = Math.floor y % 3 # which small row within b_y

    return [b_x, b_y, s_x, s_y]

  # box coordinates -> cartesian coordinates
  # b_x,b_y,s_x,s_y -> [x, y]
  box_to_cart: (b_x, b_y, s_x, s_y) ->
    x = 3*b_x + s_x
    y = 3*b_y + s_y

    return [x, y]

## ---------------------------------------------------------------------------
## Helpers for interactions with the DOM -------------------------------------

domhelpers =

  ## JQuery selectors.

  sel_row: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{i} .r#{s_y} .c#{j}, " unless i == b_x and j == s_x
    return s

  sel_col: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{i} .gc#{b_x} .r#{j} .c#{s_x}, " unless i == b_y and j == s_y
    return s

  sel_box: (x,y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{b_x} .r#{j} .c#{i}, " unless i == s_x and j == s_y
    return s

  sel: (x, y) ->
    [b_x, b_y, s_x, s_y] = helpers.cart_to_box x,y
    return ".gr#{b_y} .gc#{b_x} .r#{s_y} .c#{s_x}"

  color_adjacent: (x,y) ->
    fn1 = =>
      $(@sel_box(x,y)).addClass("adj-box")
      $(@sel_col(x,y)).addClass("adj-col")
      $(@sel_row(x,y)).addClass("adj-row")
    fn2 = =>
      $(@sel_box(x,y)).removeClass("adj-box")
      $(@sel_col(x,y)).removeClass("adj-col")
      $(@sel_row(x,y)).removeClass("adj-row")
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

  box_to_base: (b_x, b_y, s_x, s_y) ->
    @cart_to_base helpers.box_to_cart(b_x, b_y, s_x, s_y)

  base_to_box: (i) ->
    helpers.cart_to_box(@base_to_cart i)

  # access an element using base indices.
  get: (i) ->
    @base_array[i]

  # access an element using cartesian coordinates.
  get_c: (x,y) ->
    @get @cart_to_base(x,y)

  # access an element using box coordinates
  get_b: (b_x, b_y, s_x, s_y) ->
    @get @cart_to_base helpers.box_to_cart(b_x, b_y, s_x, s_y)

  # set a cell specified with a base index i to a value v.
  set: (i, v) ->
    # store in internal representation
    @base_array[i] = v

    # change displayed value in HTML
    [x,y] = @base_to_cart i
    if v is 0
      domhelpers.set_input_val(x,y,'')
    else
      domhelpers.set_input_val(x,y,v)
      $(domhelpers.sel(x,y)).addClass('new')
      $(domhelpers.sel(x,y)).
        addClass('highlight', 500).delay(500).removeClass('highlight', 2000)

  # set a cell specified by cartesian coordinates (x,y) to a value v.
  set_c: (x,y,v) ->
    @set(@cart_to_base(x,y), v)

  # set a cell specified by box coordinates (b_x,b_y,s_x,s_y) to a value v.
  set_b: (b_x, b_y, s_x, s_y) ->
    @set(@cart_to_base helpers.box_to_cart(b_x, b_y, s_x, s_y), v)

  # returns an array of all the values in a particular box, either specified
  # as a pair of coordinates or as an index (so the 6th box is the box
  # with b_x=0, b_y=2).
  get_box: (x, y) ->
    unless y?
      y = Math.floor x / 3
      x = Math.floor x % 3

    a = []
    for j in [0..2]
      for i in [0..2]
        a.push @get_b(x, y, i, j)

    return a

  # returns the array of all values in the box which this cell (specified in
  # cartesian coordinates if two parameters are passed, in a base index if
  # only one paramater is passed) occupies.
  get_box_of: (x, y) ->
    if y?
      cart = [x,y]
    else
      cart = @base_to_cart x

    [b_x, b_y, s_x, s_y] = helpers.cart_to_box cart
    @get_box b_x, b_y

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
  # without any repeats. will be called on rows, columns, and boxes.
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
  #   - each box is unique
  is_valid: ->
    for i in [0..8]
      return false unless @valid_array @get_col i
      return false unless @valid_array @get_row i
      return false unless @valid_array @get_box i
    return true

## ---------------------------------------------------------------------------
## Solver Class --------------------------------------------------------------

class Solver
  constructor: (@grid) ->
    # Cell restrictions will contain info gathered about what value a cell can
    # or cannot be. Each cell restriction will be an object, with a 'type' field
    # either set to "cant" or "must" to specify which kind of restriction info
    # it is storing and with a 'vals' field that is an array of values which the
    # cell either can or cannot be (again, depending on the value of the 'type'
    # field).
    @cell_restrictions = []
    make_restriction = -> [0,0,0,0,0,0,0,0,0,0]
    @cell_restrictions = (make_restriction() for i in [0...81])

    @solve_iter = 0

    @prev_strategies = []

    # count the number of occurrences of each value.
    @occurrences = [0,0,0,0,0,0,0,0,0,0]
    for v in [1..9]
      for i in [0...81]
        @occurrences[v] += 1 if @grid.get(i) == v

    # call the solver's set function for all the pre-filled in values, to create
    # the basic knowledge representation.
    for i in [0...81]
      v = @grid.get i
      if v > 0
        @record i,v



  # get an array of all naively impossible values to fill into the cell at base
  # index i in the grid. the impossible values are simply the values filled in
  # to cells that share a row, col, or box with this cell. will return -1 if the
  # cell already has a value.
  naive_impossible_values: (i) ->
    v = @grid.get i
    if v > 0
      return helpers.set_subtract([1..9], [v])

    @grid.get_row_of(i).
      concat(@grid.get_col_of(i)).
        concat(@grid.get_box_of(i))

  # gets a list of positions in a specified box where v can be filled in based
  # on naive_impossible_values. the box is specified either as (x,y) in
  # [0..2]x[0..2] or with a single index in [0..8]. positions are returned as
  # base indices of the grid.
  naive_possible_positions_in_box: (v, x, y) ->
    unless y?
      y = Math.floor x / 3
      x = Math.floor x % 3

    ps = []
    for b in [0..2]
      for a in [0..2]
        i = @grid.box_to_base x,y,a,b
        ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # gets a list of positions in a specified row where v can be filled in based
  # on naive_impossible_values. the row is specified as a y-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_row: (v, y) ->
    ps = []
    for x in [0..8]
      i = @cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

  # gets a list of positions in a specified col where v can be filled in based
  # on naive_impossible_values. the row is specified as an x-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_col: (v, x) ->
    ps = []
    for y in [0..8]
      i = @cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

  # wrapper for @grid.set which will update the knowledge base. also optionally
  # takes a callback and a delay and then calls the callback after delay.
  set: (i, v, callback, delay) ->
    @grid.set i,v

    @occurrences[v] += 1

    if true
      @record i,v

    if callback?
      if delay? or delay > 0
        setTimeout(callback, delay)
      else
        callback()

  # updates the neighbors (cells in the same row/col/box) that the value v has
  # been "used up" by going in cell i. this probably shouldn't be called all the
  # time, since calling it all the time dosen't really reflect how a human would
  # think of things.
  record: (i,v) ->
    [x,y] = @grid.base_to_cart i
    [b_x, b_y, s_x, s_y] = @grid.base_to_box i

    # get the indices of the cells in the same row, col, and box.
    row_idxs = (@grid.cart_to_base(x,j) for j in [0..8])
    col_idxs = (@grid.cart_to_base(j,y) for j in [0..8])
    box_idxs = []
    for j in [0..2]
      for k in [0..2]
        box_idxs.push @grid.box_to_base(b_x, b_y, j, k)

    # combine all the indices into one array.
    idxs = row_idxs.concat(col_idxs).concat(box_idxs)

    # add restrictions to all unset cells in the same row, col, and box.
    for idx in idxs
      @add_restriction(idx, v) if @grid.get(idx) == 0

  # wrapper for @grid.set_c which will update the knowledge base if it needs to.
  set_c: (x,y,v, callback, delay) ->
    @set(@cart_to_base(x,y), v, callback, delay)

  # wrapper for @grid.set_b which will update the knowldege base if it needs to.
  set_b: (b_x, b_y, s_x, s_y, callback, delay) ->
    @set(@cart_to_base helpers.box_to_cart(b_x, b_y, s_x, s_y), v, callback, delay)

  # adds a restriction of value v to cell with base index i. if this restriction
  # made it so a cell only has one possible value, then the value will be
  # set. returns whether a value was set.
  add_restriction: (i, v) ->
    # we should only be adding restrictions to cells which aren't set yet.
    throw "Error" if @grid.get(i) != 0

    @cell_restrictions[i][v] = 1

    # FIXME: I don't think we should blindly be setting a value whenever a
    # restriction makes it obvious to the computer, becasue this may very well
    # not be obvious to a human solving the sudoku.
    # if helpers.num_pos(@cell_restrictions[i]) == 8
    #   j = 1
    #   until @cell_restrictions[i][j] == 0
    #     j += 1
    #   # now i is the only non-restricted value, so we can fill it in
    #   log "Setting (#{@grid.base_to_cart i}) to #{j} by adding restrictions"
    #   @set i, j
    #   return true


  # gets a representation of the cell restriction for the cell with base index
  # i. if the cell has a lot of restrictions, then returns a list of values
  # which the cell must be; if the cell has only a few restrictions, then
  # returns a list of values which the cell can't be. the returned object will
  # have a "type" field specifying if it's returning the list of cells possible
  # ("must"), the list of cells not possible ("cant"), or no information because
  # no info has yet been storetd for the cell ("none"), and a "vals" array with
  # the list of values either possible or impossle.
  get_restrictions: (i) ->
    r = @cell_restrictions[i]
    n = helpers.num_pos r

    if n == 0
      return { type: "none" }
    else if 1 <= n <= 4
      cants = []
      for j in [1..9]
        cants.push(j) if r[j] == 1
      return { type: "cant", vals: cants }
    else # this will mean n >= 5
      musts = []
      for j in [1..9]
        musts.push(j) if r[j] == 0
      return { type: "must", vals: musts }

  # returns an array of values in order of the number of their occurrences, with
  # in order of most prevalent to least prevalent.
  vals_by_occurrences: ->
    ord = []
    for o in [9..1]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord


  # STRATEGIES ---------------------------------------------------------------

  ###
  cell_by_cell_loop: (i) ->
    can = []

    [x,y] = @grid.base_to_cart i

    next_step = @cell_by_cell_loop.bind(@, i+1)
    done = @solve_loop.bind(@)
    immediately_iterate = ->
      if i == 80 then setTimeout(done, settings.STRAT_DELAY) else next_step()

    # only proceed if the cell is unknown, and if desperate or if there is
    # enough info to make this strategy seem reasonable.
    if @grid.get(i) == 0 and (@desperate or
                                helpers.num_pos(@grid.get_box_of(i)) >= 4 or
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

          if i == 80
            setTimeout(done, settings.STRAT_DELAY)
          else
            setTimeout(next_step, settings.FILL_DELAY)

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
  ###

  # GridScan -------------------------------------------------------------------

  GridScan: ->
    vals = @vals_by_occurrences()

    @GridScanValLoop(vals, 0)

  GridScanValLoop: (vs, vi) ->
    v = vs[vi]

    boxes = []
    # get the boxes which don't contain v, which are the only ones we're
    # considering for the strategy
    for b in [0..8]
      boxes.push(b) if v not in @grid.get_box(b)


    if boxes.length == 0
      # if there are no possible boxes and there are more values, move to the
      # next value.
      if vi < vs.length - 1
        @GridScanValLoop(vs, vi+1)
      # if there are no possible boxes and there are no more values, then stop
      # iterating.
      else
        @solve_loop()
    # if there are possible boxes, then start iterating on them.
    else
      @GridScanBoxLoop(vs, vi, boxes, 0)


  GridScanBoxLoop: (vs, vi, bs, bi) ->
    v = vs[vi]
    b = bs[bi]

    ps = @naive_possible_positions_in_box v, b

    next_box = ( => @GridScanBoxLoop(vs, vi, bs, bi+1) )
    next_val = ( => @GridScanValLoop(vs, vi+1) )
    done = ( => @solve_loop() )

    # if there are more boxes, go to the next box.
    if bi < bs.length - 1
      callback = next_box
      delay = settings.FILL_DELAY
    # if there are more values but no more boxes, go to the next value.
    else if vi < vs.length - 1 and bi == bs.length - 1
      callback = next_val
      delay = settings.FILL_DELAY
    # if there are no more values and no more boxes, go to the next strat.
    else
      callback = done
      delay = settings.STRAT_DELAY

    # if there is only one possible location, then fill it in and wait the
    # appropriate time to call the next method.
    if ps.length == 1
      log "Setting (#{@grid.base_to_cart ps[0]}) to #{v} by GridScan"
      @set ps[0], v
      setTimeout(callback, delay)
    else
      # if we haven't filled in anything, then call the callback immediately,
      # unless the callback is to go to the next strategy, in which case we
      # should still delay.
      if callback == done then setTimeout(callback, delay) else callback()

  should_gridscan: ->
    # FIXME: GridScan should be run more in the beginning, and less in the
    # end. Need a good heuristic to represent the "beginning" and the "end".

    # for now, will only run gridscan FIRST. that is, once another technique is
    # tried, will never run gridscan again. this clearly isn't ideal, I feel
    # there are times I might use gridscan in real life even after doing somes
    # other strategies.
    @prev_strategies.length == 0 or (@prev_strategies.length == 1 and
                                     @prev_strategies[0] == "GridScan")


  # SOLVE LOOP ---------------------------------------------------------------

  # Finds and fills in any cells which are in a row, col, or box which is only
  # missing one value (and thus the missing value is obvious).
  fill_obvious_cells: (callback) ->
    for y in [0..8]
      vals = @grid.get_row y

      if helpers.num_pos(vals) == 8
        # get the one missing value.
        v = 1
        v += 1 until v not in vals

        # get the position missing it.
        x = 0
        x += 1 until @grid.get_c(x,y) == 0

        log "Filling in #{v} at (#{[x,y]}) becaause it's obvious"
        @set_c x,y,v

        # continue trying to fill obvious cells.
        return setTimeout(@fill_obvious_cells, settings.FILL_DELAY)

    for x in [0..8]
      vals = @grid.get_col x

      if helpers.num_pos(vals) == 8
        # get the one missing value.
        v = 1
        v += 1 until v not in vals

        # get the position missing it.
        y = 0
        y += 1 until @grid.get_c(x,y) == 0

        log "Filling in #{v} at (#{[x,y]}) because it's obvious"
        @set x,y,v

        # continue trying to fill obvious cells.
        return setTimeout(@fill_obvious_cells, settings.FILL_DELAY)

    for b in [0..8]
      vals = @grid.get_box b

      if helpers.num_pos(vals) == 8
        # get the one missing value
        v = 1
        v += 1 until v not in vals

        box_idxs = []
        for j in [0..2]
          for k in [0..2]
            box_idxs.push @grid.box_to_base(b%3, b/3, k, j)

        # get the position missing it.
        i = 0
        i += 1 until @grid.get(box_idxs[i]) == 0

        log "Filling in #{v} at (#{@grid.base_to_cart i}) because it's obvious"
        @set i, v

        # continue trying to fill obvious cells.
        return setTimeout(@fill_obvious_cells, settings.FILL_DELAY)

    # if we didn't find any obvious cells, then call the callback
    return callback()









  choose_strategy: ->
    if @should_gridscan()
      return @GridScan()

    # FIXME these should be filled in once they're implemented.

    # if @should_thinkinsidethebox()
    #   return @ThinkInsideTheBox()

    # if @should_smartgridscan()
    #   return @SmartGridScan()

    # if @should_thinkoutsidethebox()
    #   return @ThinkOutsideTheBox()

    # if @should_exhaustionsearch()
    #   return @ExhaustionSearch()

    # if @should_desperationsearch()
    #   return @DesperationSearch()

  solve_loop: ->
    @solve_iter += 1
    log "iteration #{@solve_iter}"

    # done if the grid is complete or we've done too many iterations
    done = @grid.is_valid() or @solve_iter > settings.max_solve_iter

    if done
      @solve_loop_done()
    else
      # fill obvious cells and then choose a strategy once complete
      @fill_obvious_cells(( => @choose_strategy()))


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

$(document).ready ->
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
    log "Creating a grid object"
    g = new Grid()

    log "Creating a solver object"
    s = new Solver(g)

    log "Solving..."
    s.solve()
