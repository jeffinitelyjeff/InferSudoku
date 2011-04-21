# Sudoku.coffee is a sudoku solver created by Jeff Ruberg for a project in
# COMP352 - Topics in Artificial Intelligence at Wesleyan University. The solver
# uses human-level inference to solve a sudoku puzzle like a human, particularly
# I, would. To this effect it uses a variety of strategies--some of which act
# purely to fill in cells if possible, some of which act purely to refine
# information about possible cell values, and some of which lie somewhere in
# between. The goal of the project was to create a solver which imitated the
# processes I would use to solve a sudoku, and, ideally, to replicate the order
# of actions that I would take.
#
# It will be helpful to define some terminology that will be used abundantly
# throughout the code and documentation.
#
# - **grid** The Sudoku board.
# - **cell** The smallest division of the grid; there are 81 cells, arranged in
#            rows of 9 by 9.
# - **value** A number in the range [1,9], and represents an item that can be
#             used to fill in a cell.
# - **possible value** A *possible value* for a particular cell is a value which
#                      can be placed in the cell without contradicting other
#                      information we know about the grid at the time. Note:
#                      this definition is very subjective, and very dependent on
#                      "what we know at the time"; in the end, only one value is
#                      really "possible" for each cell. We will try to avoid
#                      using the term "possible value" without specifying the
#                      context of "possible."
# - **naively possible value** A value which is possible in a particular cell
#                              when considering only the other values which are
#                              currently filled in on the grid.
# - **informed possible value** A value which is possible in a particular cell
#                               when considering the other values currently
#                               filled in and all relevant information about
#                               cell possibilites which we are storing.
# - **row** A row of the Sudoku grid.
# - **col** A column of the Sudoku grid.
# - **box** One of the nine 3x3 subsections of the grid.
# - **group** A row, col, or box.
# - **valid** A group is *valid* if it contains one of each of the values 1-9
# - **solved** A Sudoku grid is *solved* if all 9 rows, all 9 cols, and all 9
#              boxes are valid.
# - **strategy** A method/algorithm for filling in cell values or gathering
#                information about possible cell values or restrictions with the
#                goal of bringing the grid closer to a solved state.
# - **declarative strategy** A strategy which aims to fill in values into cells
#                            without attempting to update stored information
#                            about cells' possibilities.
# - **knowledge refinement strategy** A strategy which aims to update stored
#                                     information about cells' possibilites and
#                                     not fill in cell values.
# - **hybrid strategy** A strategy which aims to fill in values into cells and
#                       may update stored information about cells'
#                       possibilities.
# - **cartesian coordinates** A system of describing cell positions in the form
#                             (c, r) where c is a col number and r is a row
#                             number.
# - **box coordinates** A system of describing cell positions in the form (bx,
#                       by, sx, sy) where (bx, by) are the cartesian coordinates
#                       of the box which the cell belongs to (note that boxes
#                       are in the range [0-2]x[0-2]) and (sx, sy) are the
#                       certesian coordinates of the cell within the box (also
#                       in the range [0-2]x[0-2])
# - **base index** An index into the sudoku grid internal representation, which
#                  is stored as a 81-element array.
# - **obvious value** A cell value is *obvious* if the value is not yet filled
#                     in, but it is in a group which has all other values filled
#                     in.


#### Settings

settings =

  # Delay after filling in cells.
  FILL_DELAY: 50

  # Delay after finishing a strategy.
  STRAT_DELAY: 100

  # Maximum number of iterations to try for solve loop.
  max_solve_iter: 10

#### Basic Helper Functions

helpers =

  # Count the number of elements of an array which
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

  display_pos: (x,y) ->
    fn = ->
      $("#pos-label").html("(#{x},#{y})")
    $(@sel(x,y)).hover(fn)

  # a low-level function to get the value of the input HTML element at the
  # specified position in the Sudoku grid.
  get_input_val: (x, y) ->
    $(@sel(x,y) + " .num").val()

  # set_input_val(x,y,v) is a low-level function to set the value of the input
  # HTML element at the specified position in the Sudoku grid.
  set_input_val: (x, y, v) ->
    $(@sel(x,y) + " .num").val(v)

  # informs the display of a new display.
  announce_strategy: (s) ->
    $("#strat").html(s)


## ----------------------------------------------------------------------------
## Low-level Utility Functions ------------------------------------------------

## Logging.

log = (s) ->
  t = $('#stderr')
  t.val(t.val() + s + '\n')
  t.scrollTop(9999999)
  return s






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

  # return whether base idx i is in row r.
  idx_in_row: (i, r) ->
    @base_to_cart(i)[1] == r

  # return whether base idx i is in col r.
  idx_in_col: (i, c) ->
    @base_to_cart(i)[0] == c

  # return whether base idx i is in box b.
  idx_in_box: (i, b) ->
    [b_x, b_y] = @base_to_box i
    return 3*b_y + b_x == b






## ---------------------------------------------------------------------------
## Solver Class --------------------------------------------------------------

class Solver
  constructor: (@grid) ->

    # A Solver is constructed once every time the solve button is hit, so all
    # the relevant parameters are set to their defaults here.

    # Restrictions are indexed first by cell index and then by value
    # restricted. So @restrictions[0] is the array of restricted values for cell
    # 0, and @restrictions[10][5] is a 1 if cell 10 is restricted from being value
    # 5 or is a 0 if cell 10 is not restricted from being value 5.
    @restrictions = []
    make_empty_restriction = -> [0,0,0,0,0,0,0,0,0,0]
    @restrictions = (make_empty_restriction() for i in [0...81])

    # Clusters are indexed first by type of group (row = 0, col = 1, box = 2),
    # then by index of that group (0-8), then by value (1-9), then by positions
    # (0-8), with a 0 indicating not in the cluster and 1 indicating in the
    # cluster. For example, if @clusters[1][3][2] were [1,1,1,0,0,0,0,0,0], then
    # the 4th row would need to have value 2 in the first 3 spots.
    @clusters = []
    make_empty_cluster = -> [0,0,0,0,0,0,0,0,0]
    make_empty_cluster_vals = -> (make_empty_cluster() for i in [1..9])
    make_empty_cluster_groups = -> (make_empty_cluster_vals() for i in [0..8])
    @clusters = (make_empty_cluster_groups() for i in [0..2])

    @solve_iter = 0

    # count the number of occurrences of each value.
    @occurrences = [0,0,0,0,0,0,0,0,0,0]
    for v in [1..9]
      for i in [0...81]
        @occurrences[v] += 1 if @grid.get(i) == v

    @prev_results = []
    @updated = true

  prev_strats: ->
    strats = (@prev_results[i].strat for i in [0...@prev_results.length])

  # get an array of all naively impossible values to fill into the cell at base
  # index i in the grid. the impossible values are simply the values filled in
  # to cells that share a row, col, or box with this cell. if the cell already
  # has a value, then will return all other values; this seems a little
  # unnecessary, but turns out to make other things cleaner.
  naive_impossible_values: (i) ->
    if @grid.get(i) > 0
      return _.without([1..9], @grid.get(i))
    else
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

    return ps

  # gets a list of positions in a specified col where v can be filled in based
  # on naive_impossible_values. the row is specified as an x-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_col: (v, x) ->
    ps = []
    for y in [0..8]
      i = @cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # wrapper for @grid.set which will update the knowledge base.
  set: (i, v, callback) ->
    @grid.set i,v

    @occurrences[v] += 1

    [x,y] = @grid.base_to_cart i
    [b_x,b_y,s_x,s_y] = @grid.base_to_box i

    fun =  ( =>
      @fill_obvious_row(y, =>
      @fill_obvious_col(x, =>
      @fill_obvious_box(b_x, b_y, callback) ) ) )

    setTimeout(fun, settings.FILL_DELAY)

  # if the specified row only has one value missing, then will fill in that value.
  fill_obvious_row: (y, callback) ->
    vals = @grid.get_row y

    if helpers.num_pos(vals) == 8
      # get the one missing value
      v = 1
      v += 1 until v not in vals

      # get the position missing it.
      x = 0
      x += 1 until @grid.get_c(x,y) == 0

      log "Setting (#{x},#{y}) to #{v} because it's row-obvious"
      @set_c(x,y,v, callback)
    else
      callback()

  # if the specified col only has one value missing, then will fill in that
  # value.
  fill_obvious_col: (x, callback) ->
    vals = @grid.get_col x

    if helpers.num_pos(vals) == 8
      # get the one missing value
      v = 1
      v += 1 until v not in vals

      # get the position missing it.
      y = 0
      y += 1 until @grid.get_c(x,y) == 0

      log "Setting (#{x},#{y}) to #{v} becasue it's col-obvious"
      @set_c(x,y,v, callback)
    else
      callback()

  # if the specified box only has one value missing, then will fill in that
  # value.
  fill_obvious_box: (b_x, b_y, callback) ->
    if b_y?
      b = 3*b_y + b_x
    else
      b = b_x
      b_x = Math.floor(b_x % 3)
      b_y = Math.floor(b_y / 3)

    vals = @grid.get_box b

    if helpers.num_pos(vals) == 8
      # get the one missing value
      v = 1
      v += 1 until v not in vals

      # get the list of indices in the box.
      box_idxs = []
      for j in [0..2]
        for k in [0..2]
          box_idxs.push @grid.box_to_base(b_x, b_y, k, j)

      # get the position missing it.
      i = 0
      i += 1 until @grid.get(box_idxs[i]) == 0

      log "Setting (#{@grid.base_to_cart(box_idxs[i])}) to #{v} because it's" +
      " box-obvious"
      @set(box_idxs[i], v, callback)
    else
      callback()

  # wrapper for @grid.set_c which will update the knowledge base if it needs to.
  set_c: (x,y,v, callback) ->
    @set(@grid.cart_to_base(x,y), v, callback)

  # wrapper for @grid.set_b which will update the knowldege base if it needs to.
  set_b: (b_x, b_y, s_x, s_y, callback) ->
    @set(@grid.cart_to_base helpers.box_to_cart(b_x, b_y, s_x, s_y), v, callback)

  # adds a restriction of value v to cell with base index i. returns whether the
  # restriction was useful information (ie, if the restriction wasn't already in
  # the database of restrictions)
  add_restriction: (i, v) ->
    # we should only be adding restrictions to cells which aren't set yet.
    throw "Error" if @grid.get(i) != 0

    prev = @restrictions[i][v]
    @restrictions[i][v] = 1
    return prev == 0


  # gets a representation of the cell restriction for the cell with base index
  # i. if the cell has a lot of restrictions, then returns a list of values
  # which the cell must be; if the cell has only a few restrictions, then
  # returns a list of values which the cell can't be. the returned object will
  # have a "type" field specifying if it's returning the list of cells possible
  # ("must"), the list of cells not possible ("cant"), or no information because
  # no info has yet been storetd for the cell ("none"), and a "vals" array with
  # the list of values either possible or impossle.
  get_restrictions: (i) ->
    r = @restrictions[i]
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

  # returns an array of values in order of the number of their occurrences,
  # in order of most prevalent to least prevalent. only includes values which
  # occur 5 or more times.
  vals_by_occurrences_above_4: ->
    ord = []
    for o in [9..5]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord

  vals_by_occurrences: ->
    ord = []
    for o in [9..1]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord

  # if the base indices are all in the same row, then returns that row;
  # otherwise returns false.
  same_row: (idxs) ->
    first_row = @grid.base_to_cart(idxs[0])[1]
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the rows doesn't match the first.
      return false if @grid.base_to_cart(idx)[1] != first_row

    # return true if they all match the first.
    return first_row

  # if the base indices are all in the same column, then returns that col;
  # otherwise returns false.
  same_col: (idxs) ->
    first_col = @grid.base_to_cart(idxs[0])[0]
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the cols doesn't match the first.
      return false if @grid.base_to_cart(idx)[0] != first_col

    # return true if they all match the first
    return first_col

  # if the base indices are all in the same box, then returns that box;
  # otherwise returns false.
  same_box: (idxs) ->
    first_box = @grid.base_to_box(idx[0])
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the boxes doesn't match the first.
      box = @grid.base_to_box(idx)
      return false if box[0] != first_box[0] or box[1] != first_box[1]

    # return true if they all match the first
    return first_box[0]+first_box[0]*3

  # STRATEGIES -----------------------------------------------------------------

  # GridScan -------------------------------------------------------------------
  # ----------------------------------------------------------------------------
  # --- Consider each value that occurs 5 or more times, in order of currently -
  # --- most present on the grid to least present. For each value v, consider --
  # --- the boxes b where v has not yet been filled in. ------------------------
  # ----------------------------------------------------------------------------

  # Get the list of values in order of their occurrences, and start the main
  # value loop.
  GridScan: ->
    log "Trying GridScan"

    @updated = false

    vals = @vals_by_occurrences_above_4()

    if vals.length > 0
      @GridScanValLoop(vals, 0)
    else
      @prev_results[@prev_results.length-1].success = @updated
      setTimeout(( => @solve_loop()), settings.STRAT_DELAY)

  # For a specified value, get the boxes where that value has not yet been
  # filled in. If there such boxes, then begin a box loop in the first of the
  # boxes; if there are no such boxes, then either go to the next value or
  # finish the strategy.
  GridScanValLoop: (vs, vi) ->
    v = vs[vi]

    boxes = []
    # get the boxes which don't contain v, which are the only ones we're
    # considering for the strategy
    for b in [0..8]
      boxes.push(b) if v not in @grid.get_box(b)

    if boxes.length > 0
      # if there are possible boxes, then start iterating on them.
      @GridScanBoxLoop(vs, vi, boxes, 0)
    else
      if vi < vs.length - 1
        # if there are no possible boxes and there are more values, move to the
        # next value.
        @GridScanValLoop(vs, vi+1)
      else
        # if there are no possible boxes and there are no more values, then move
        # to the next strategy
        @prev_results[@prev_results.length-1].success = @updated
        setTimeout(( => @solve_loop()), settings.STRAT_DELAY)

  # For a specified value and box, see where the value is possible in the
  # box. If the value is only possible in one position, then fill it in. Move
  # on to the next box if there are more boxes; move on to the next value if
  # there are no more boxes and there are more values; move on to the next
  # strategy if there are n omroe boxes or values.
  GridScanBoxLoop: (vs, vi, bs, bi) ->
    v = vs[vi]
    b = bs[bi]

    ps = @naive_possible_positions_in_box v, b

    next_box = ( => @GridScanBoxLoop(vs, vi, bs, bi+1) )
    next_val = ( => @GridScanValLoop(vs, vi+1) )
    next_strat = ( => @solve_loop() )

    if bi < bs.length - 1
      # go to the next box if there are more boxes.
      callback = next_box
      delay = 0
    else if vi < vs.length - 1
      # go to the next value if there are no more boxes, but more values.
      callback = next_val
      delay = 0
    else
      # go to the next strategy if there are no more values or boxes.
      callback = next_strat
      delay = settings.STRAT_DELAY

    if ps.length == 1
      log "Setting (#{@grid.base_to_cart ps[0]}) to #{v} by GridScan"
      @set(ps[0], v, =>
        @updated = true
        delay += settings.FILL_DELAY
        setTimeout(callback, delay))
    else
      if callback == next_strat
        @prev_results[@prev_results.length-1].success = @updated
      setTimeout(callback, delay)

  should_gridscan: ->
    # for now, will only run gridscan if the last operation was gridscan and it
    # worked. this reflects how I use it mainly in the beginning of a puzzle.
    return true if @prev_results.length == 0

    last_result = @prev_results[@prev_results.length-1]
    last_result.strat == "GridScan" and last_result.success

  # SmartGridScan --------------------------------------------------------------
  # ----------------------------------------------------------------------------
  # --- Consider each value, in order of currently most present on the grid to -
  # --- least present. For each value v, consider each box b where v has not ---
  # --- yet been filled in. Let p be the set of positions where v can be -------
  # --- placed within b. If p is a single position, then fill in v at this -----
  # --- position (note that this is extremely similar to GridScan in this ------
  # --- case). If all the positions in p are in a single row or col, then add --
  # --- a restriction of v to all other cells in the row or col but outside of -
  # --- b. NOTE: This is entirely a knowledge refinement strategy (except in ---
  # --- the case where it is exactly GridScan), because adding a restriction ---
  # --- won't affect anything until ExhaustionSearch is run. -------------------
  # ----------------------------------------------------------------------------

  # Get the list of values in order of their occurrences, and start the main
  # value loop.
  SmartGridScan: ->
    log "Trying SmartGridScan"

    @updated = false

    vals = @vals_by_occurrences()

    @SmartGridValLoop(vals, 0)

  # For a specified value, get the boxes where that value has not yet been
  # filled in. If there are such boxes, then begin a box loop in the frsit of
  # the boxes; if there are no such boxes, then either go to the next value or
  # finish the strategy.
  SmartGridValLoop: (vs, vi) ->
    v = vs[vi]

    boxes = []
    # get the boxes which don't contain v, which are the only ones we're
    # considering for this startegy.
    for b in [0..8]
      boxes.push(b) if v not in @grid.get_box(b)

    if boxes.length > 0
      # if there are possible boxes, then start iterating on them.
      @SmartGridBoxLoop(vs, vi, boxes, 0)
    else
      if vi < vs.length - 1
        # if there are no possible boxes and there are more values, move to the
        # next value.
        @SmartGridValLoop(vs, vi+1)
      else
        # if there are no possible boxes and there are no more values, then move
        # to the next strategy.
        @prev_results[@prev_results.length-1].success = @updated
        setTimeout(( => @solve_loop()), settings.STRAT_DELAY)

  # For a specified value and box, see where the values is possible in the
  # box. If the value is only possible in one position, then fill it in (like
  # normal GridScan). If it's possible in two or three positions, and those
  # positions happen to be in the same rows or cols, then will add restrictions
  # to all the other cells in the same row/col outside the box. Move on to the
  # next box if there are more boxes; move on to the next value if there are no
  # more boxes and there are more values; move on to the next strategy if there
  # are no more boxes or values.
  SmartGridBoxLoop: (vs, vi, bs, bi) ->
    v = vs[vi]
    b = bs[bi]

    ps = @naive_possible_positions_in_box v, b

    next_box = ( => @SmartGridBoxLoop(vs, vi, bs, bi+1) )
    next_val = ( => @SmartGridValLoop(vs, vi+1) )
    next_strat = ( => @solve_loop() )

    if bi < bs.length - 1
      # go to the next box if there are more boxes.
      callback = next_box
      delay = 0
    else if vi < vs.length - 1
      # go to the next value if there are no more boxes, but more values.
      callback = next_val
      delay = 0
    else
      # go to the next strategy if there are no more values or boxes.
      callback = next_strat
      delay = settings.STRAT_DELAY

    switch ps.length
      when 1
        log "Setting (#{@grid.base_to_cart ps[0]}) to #{v} by SmartGridScan"
        @set(ps[0], v, =>
          @updated = true
          delay += settings.FILL_DELAY)
      when 2,3
        if @same_row(ps)
          log "Refining knowledge base using SmartGridScan"
          @updated = true

          y = @same_row(ps)
          for x in [0..8]
            i = @grid.cart_to_base(x,y)
            @add_restriction(i,v) unless @grid.idx_in_box(i,b) or @grid.get(i)!=0
        else if @same_col(ps)
          log "Refining knowledge base using SmartGridScan"
          @updated = true

          x = @same_col(ps)
          for y in [0..8]
            i = @grid.cart_to_base(x,y)
            @add_restriction(i,v) unless @grid.idx_in_box(i,b) or @grid.get(i)!=0

    setTimeout(callback, delay)

  should_smartgridscan: ->
    # Should do a smart gridscan if the last attempt at gridscan failed. this
    # should work because gridscan is always run first, so there should always
    # be previous strategies with gridscan among them.
    last_gridscan = -1
    _.each(@prev_results, (result, i) ->
      last_gridscan = i if result.strat == "GridScan" )
    return not @prev_results[last_gridscan].success



  # ThinkInsideTheBox ----------------------------------------------------------
  # ----------------------------------------------------------------------------
  # --- For each box b and for each value v which has not yet been filled in ---
  # --- within b, see where v could possibly be placed within b (consulting ----
  # --- the values in corresponding rows/cols and any cant/must arrays filled --
  # --- in within b); if v can only be placed in one position in b, then -------
  # --- fill it in. ------------------------------------------------------------
  # ----------------------------------------------------------------------------

  # Get a list of boxes and begin the main loop through the box list.
  ThinkInsideTheBox: ->
    log "Trying ThinkInsideTheBox"

    @updated = false

    boxes = [0..8]

    @ThinkInsideBoxLoop(boxes, 0)

  # Get the list of values which have not yet been filled in within the current
  # box, and begin a loop through those values.
  ThinkInsideBoxLoop: (bs, bi) ->
    filled = @grid.get_box bs[bi]
    log "filled: " + filled
    vals = _.without([1..9], filled...)
    log "vals: " + vals

    if vals.length > 0
      # if there are unfilled values, then start iterating on them
      @ThinkInsideValLoop(bs, bi, vals, 0)
    else
      if bi < bs.length - 1
        # if there are no unfilled values and there are more boxes to consider,
        # then move on to the next box.
        @ThinkInsideBoxLoop(bs, bi+1)
      else
        # if there are no unfilled values and there are no more boxes to
        # consider, then go to the next strategy.
        @prev_results[@prev_results.length-1].success = @updated
        setTimeout(( => @solve_loop()), settings.STRAT_DELAY)

  # See where the current value can be placed within the current box. If the
  # value is only possible in one position, then fill it in. Move on to the next
  # value if there are more values; move on to the next box if thre are no more
  # values and there are more boxes; move on to the next strategy if there are
  # no more values or boxes.
  ThinkInsideValLoop: (bs, bi, vs, vi) ->
    v = vs[vi]
    b = bs[bi]

    ps = @naive_possible_positions_in_box v, b

    next_val = ( => @ThinkInsideValLoop(bs, bi, vs, vi+1) )
    next_box = ( => @ThinkInsideBoxLoop(bs, bi+1) )
    next_strat = ( => @solve_loop() )

    if vi < vs.length - 1
      # go to the next value if there are more values.
      callback = next_val
      delay = 0
    else if bi < bs.length - 1
      # go to the next box if there are no more values, but more boxes.
      callback = next_box
      delay = 0
    else
      # go to the next strategy if there are no more boxes or values.
      callback = next_strat
      delay = settings.STRAT_DELAY

    if ps.length == 1
      log "Setting (#{@grid.base_to_cart ps[0]}) to #{v} by ThinkInsideTheBox"
      @set(ps[0], v, =>
        @updated = true
        delay += settings.FILL_DELAY
        setTimeout(callback, delay))
    else
      if callback == next_strat
        @prev_results[@prev_results.length-1].success = @updated
      setTimeout(callback, delay)

  should_thinkinsidethebox: ->
    # do ThinkInsideTheBox unless the last attempt at ThinkInsideTheBox failed.
    last_thinkinside = -1
    _.each(@prev_results, (result, i) ->
      last_thinkinside = i if result.strat == "ThinkInsideTheBox" )
    return last_thinkinside == -1 or @prev_results[last_thinkinside].success



  # SOLVE LOOP ---------------------------------------------------------------

  choose_strategy: ->
    if @should_gridscan()
      @prev_results.push {strat: "GridScan"}
      domhelpers.announce_strategy "GridScan"
      return @GridScan()

    if @should_thinkinsidethebox()
      @prev_results.push {strat: "ThinkInsideTheBox"}
      domhelpers.announce_strategy "ThinkInside<br />TheBox"
      return @ThinkInsideTheBox()

    if @should_smartgridscan()
      @prev_results.push {strat: "SmartGridSCan"}
      domhelpers.announce_strategy "SmartGridScan"
      return @SmartGridScan()

    # FIXME

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
      @choose_strategy()


  solve_loop_done: ->
    log if @grid.is_valid() then "Grid solved! :)" else "Grid not solved :("

    $("#strat").animate(`{opacity: 0.0, top: '+=75px'}`, 500, 'easeOutQuad', ->
      $("#solve-b").animate(`{opacity: 1.0, top: '-=50px'}`, 500, 'easeInQuad', ->
      $("#solve-b, #input-b, input.num").attr('disabled', false)))

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
  $("#strat").fadeTo(0, 0)
  log 'init webapp'

  $(document).mousemove( (e) ->
    $("#pos-label").css('left', e.pageX + 5)
    $("#pos-label").css('top', e.pageY + 5)
  )

  display_pos = (e) ->
    $("#pos-label").css('display', 'inline')
  hide_pos = (e) ->
    $("#pos-label").css('display', 'none')

  $("#grid").hover(display_pos, hide_pos)

  $("#stdin").val(easy)

  $("#puzzle-select").change( -> $("#stdin").val(eval($("#puzzle-select").val())))

  for j in [0..8]
    for i in [0..8]
      domhelpers.color_adjacent(i,j)
      domhelpers.display_pos(i,j)


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
    $("#solve-b, #input-b, input.num").attr('disabled', true)
    $("#solve-b").animate(`{opacity: 0.0, top: '+=50px'}`, 250, 'easeOutQuad', ->
      $("#strat").animate(`{opacity: 1.0, top: '-75px'}`, 250, 'easeInQuad', ->

        log "Creating a grid object"
        g = new Grid()

        log "Creating a solver object"
        s = new Solver(g)

        log "Solving..."
        s.solve()
      ))

