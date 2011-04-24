root = exports ? this

## Import Statements ##

FILL_DELAY = root.FILL_DELAY
STRAT_DELAY = root.STRAT_DELAY
max_solve_iter = root.max_solve_iter

util = root.util
dom = root.dom
log = dom.log

## Solver Class ##

class Solver
  constructor: (@grid, why) ->

    # A Solver is constructed once every time the solve button is hit, so all
    # the relevant parameters are set to their defaults here.

    # Restrictions are indexed first by cell index and then by value
    # restricted. So `@restrictions[0]` is the array of restricted values for
    # cell 0, and `@restrictions[10][5]` is a 1 if cell 10 is restricted from
    # being value 5 or is a 0 if cell 10 is not restricted from being value 5.
    @restrictions = []
    make_empty_restriction = -> [0,0,0,0,0,0,0,0,0,0]
    @restrictions = (make_empty_restriction() for i in [0...81])

    # Clusters are indexed first by type of group (row = 0, col = 1, box = 2),
    # then by index of that group (0-8), then by value (1-9), then by positions
    # (0-8), with a 0 indicating not in the cluster and 1 indicating in the
    # cluster. For example, if `@clusters[1][3][2]` were `[1,1,1,0,0,0,0,0,0]`,
    # then the 4th row would need to have value 2 in the first 3 spots.
    @clusters = []
    make_empty_cluster = -> [0,0,0,0,0,0,0,0,0]
    make_empty_cluster_vals = -> (make_empty_cluster() for i in [1..9])
    make_empty_cluster_groups = -> (make_empty_cluster_vals() for i in [0..8])
    @clusters = (make_empty_cluster_groups() for i in [0..2])

    # Counts the iterations thrrough the loop, may be phased out in favor of
    # just stopping once have exhausted strategies. FIXME phase this out.
    @solve_iter = 0

    # Count the number of occurrences of each value.
    @occurrences = [0,0,0,0,0,0,0,0,0,0]
    for v in [1..9]
      for i in [0...81]
        @occurrences[v] += 1 if @grid.get(i) == v

    # A collection keeping track of previous success/failures of strategies.
    @prev_results = []

    # Variable to track whether the last strategy was a success or not... FIXME
    # should be phased out, is redundant with @prev_strategies
    @updated = true


  ### Variable Access ###
  # Some of the data structures used by Solver are relatively complicated and
  # structured strangely. These methods provide better interfaces for
  # interacting with (ie, getting/setting/adding to) these variables.

  # Get the list of names of previously performed strategies.
  prev_strats: ->
    strats = (@prev_results[i].strat for i in [0...@prev_results.length])

  # Adds a restriction of value v to cell with base index i. Returns whether the
  # restriction was useful information (ie, if the restriction wasn't already in
  # the database of restrictions)
  add_restriction: (i, v) ->
    # we should only be adding restrictions to cells which aren't set yet.
    throw "Error" if @grid.get(i) != 0

    prev = @restrictions[i][v]
    @restrictions[i][v] = 1
    return prev == 0

  # Gets a representation of the cell restriction for the cell with base index
  # i. If the cell has a lot of restrictions, then returns a list of values
  # which the cell must be; if the cell has only a few restrictions, then
  # returns a list of values which the cell can't be. The returned object will
  # have a "type" field specifying if it's returning the list of cells possible
  # ("must"), the list of cells not possible ("cant"), or no information because
  # no info has yet been storetd for the cell ("none"), and a "vals" array with
  # the list of values either possible or impossle.
  get_restrictions: (i) ->
    r = @restrictions[i]
    n = util.num_pos r

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


  ### Setting ###

  # wrapper for @grid.set which will update the knowledge base.
  set: (i, v, callback) ->
    @grid.set i,v

    @occurrences[v] += 1

    [x,y] = util.base_to_cart i
    [b_x,b_y,s_x,s_y] = util.base_to_box i

    fun =  ( =>
      @fill_obvious_row(y, =>
      @fill_obvious_col(x, =>
      @fill_obvious_box(b_x, b_y, callback) ) ) )

    setTimeout(fun, FILL_DELAY)

  # wrapper for @grid.set_c which will update the knowledge base if it needs to.
  set_c: (x,y,v, callback) ->
    @set(util.cart_to_base(x,y), v, callback)

  # wrapper for @grid.set_b which will update the knowldege base if it needs to.
  set_b: (b_x, b_y, s_x, s_y, callback) ->
    @set(util.cart_to_base util.box_to_cart(b_x, b_y, s_x, s_y)..., v, callback)

  # if the specified row only has one value missing, then will fill in that value.
  fill_obvious_row: (y, callback) ->
    vals = @grid.get_row_vals y

    if util.num_pos(vals) == 8
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
    vals = @grid.get_col_vals x

    if util.num_pos(vals) == 8
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

    vals = @grid.get_box_vals b

    if util.num_pos(vals) == 8
      # get the one missing value
      v = 1
      v += 1 until v not in vals

      # get the list of indices in the box.
      box_idxs = []
      for j in [0..2]
        for k in [0..2]
          box_idxs.push util.box_to_base(b_x, b_y, k, j)

      # get the position missing it.
      i = 0
      i += 1 until @grid.get(box_idxs[i]) == 0

      log "Setting (#{util.base_to_cart(box_idxs[i])}) to #{v} because it's" +
      " box-obvious"
      @set(box_idxs[i], v, callback)
    else
      callback()


  ### Basic Logic ###

  # get an array of all naively impossible values to fill into the cell at base
  # index i in the grid. the impossible values are simply the values filled in
  # to cells that share a row, col, or box with this cell. if the cell already
  # has a value, then will return all other values; this seems a little
  # unnecessary, but turns out to make other things cleaner.
  naive_impossible_values: (i) ->
    if @grid.get(i) > 0
      return _.without([1..9], @grid.get(i))
    else
      @grid.get_row_vals_of(i).
        concat(@grid.get_col_vals_of(i)).
          concat(@grid.get_box_vals_of(i))

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
        i = util.box_to_base x,y,a,b
        ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # gets a list of positions in a specified row where v can be filled in based
  # on naive_impossible_values. the row is specified as a y-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_row: (v, y) ->
    ps = []
    for x in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # gets a list of positions in a specified col where v can be filled in based
  # on naive_impossible_values. the row is specified as an x-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_col: (v, x) ->
    ps = []
    for y in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

    return ps

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

  # If the base indices are all in the same row, then returns that row;
  # otherwise returns false.
  same_row: (idxs) ->
    first_row = util.base_to_cart(idxs[0])[1]
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the rows doesn't match the first.
      return false if util.base_to_cart(idx)[1] != first_row

    # return true if they all match the first.
    return first_row

  # If the base indices are all in the same column, then returns that col;
  # otherwise returns false.
  same_col: (idxs) ->
    first_col = util.base_to_cart(idxs[0])[0]
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the cols doesn't match the first.
      return false if util.base_to_cart(idx)[0] != first_col

    # return true if they all match the first
    return first_col

  # If the base indices are all in the same box, then returns that box;
  # otherwise returns false.
  same_box: (idxs) ->
    first_box = util.base_to_box(idx[0])
    idxs = _.rest(idxs)

    for idx in idxs
      # return false if one of the boxes doesn't match the first.
      box = util.base_to_box(idx)
      return false if box[0] != first_box[0] or box[1] != first_box[1]

    # return true if they all match the first
    return first_box[0]+first_box[0]*3


  ### Strategies ###

  #### Grid Scan ####
  # Considers each value that occurs 5 or more times, in order of currently most
  # present on the grid to currently least present (pre-computed, so adding new
  # values will not affect the order values are iterated through; this is
  # roughly similar to what a real person would do, as they would basically look
  # over the grid once, then start looking through values, keeping a mental list
  # of what values they'd already tried and not returning back to them). For
  # each value v, consider the boxes b where v has not yet been filled in.

  # Get the list of values in order of their occurrences, and start the main
  # value loop.
  GridScan: ->
    @updated = false

    vals = @vals_by_occurrences_above_4()

    if vals.length > 0
      @GridScanValLoop(vals, 0)
    else
      @prev_results[@prev_results.length-1].success = @updated
      setTimeout(( => @solve_loop()), STRAT_DELAY)

  # For a specified value, get the boxes where that value has not yet been
  # filled in. If there such boxes, then begin a box loop in the first of the
  # boxes; if there are no such boxes, then either go to the next value or
  # finish the strategy.
  GridScanValLoop: (vs, vi) ->
    log "GridScan examining value #{vs[vi]}"

    v = vs[vi]

    boxes = []
    # get the boxes which don't contain v, which are the only ones we're
    # considering for the strategy
    for b in [0..8]
      boxes.push(b) if v not in @grid.get_box_vals(b)

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
        setTimeout(( => @solve_loop()), STRAT_DELAY)

  # For a specified value and box, see where the value is possible in the
  # box. If the value is only possible in one position, then fill it in. Move
  # on to the next box if there are more boxes; move on to the next value if
  # there are no more boxes and there are more values; move on to the next
  # strategy if there are n omroe boxes or values.
  GridScanBoxLoop: (vs, vi, bs, bi) ->
    log "GridScan examining value #{vs[vi]} in box #{bs[bi]}"

    v = vs[vi]
    b = bs[bi]

    ps = @naive_possible_positions_in_box v, b

    next_box =   => @GridScanBoxLoop(vs, vi, bs, bi+1)
    next_val =   => @GridScanValLoop(vs, vi+1)
    next_strat = => @solve_loop()

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
      delay = STRAT_DELAY

    if ps.length == 1
      log "Setting (#{util.base_to_cart ps[0]}) to #{v} by GridScan"
      @set(ps[0], v, =>
        @updated = true
        delay += FILL_DELAY
        setTimeout(callback, delay))
    else
      if callback == next_strat
        @prev_results[@prev_results.length-1].success = @updated
      setTimeout(callback, delay)

  # A heuristic for whether Grid Scan should be run.
  should_gridscan: ->
    # For now, will only run gridscan if the last operation was gridscan and it
    # worked. This reflects how I use it mainly in the beginning of a puzzle.
    return true if @prev_results.length == 0

    last_result = @prev_results[@prev_results.length-1]
    last_result.strat == "GridScan" and last_result.success


  #### Smart Grid Scan ####
  # Consider each value, in order of currently most present on the grid to least
  # present (as above, with the order pre-computed). For each value v, consider
  # each box b where v has not yet been filled in. Let p be the set of positions
  # where v can be placed within b. If p is a single position, then fill in v at
  # this position (note that this is extremely similar to GridScan in this
  # case). If all the positions in p are in a single row or col, then add a
  # restriction of v to all other cells in the row or col but outside of
  # b.
  #
  # NOTE: This is mostly a knowledge refinement strategy, and the goal is to
  # only add a couple restrictions here and there, which would then be picked up
  # by ExhaustionSearch, but we will also fill in some values which Grid Scan
  # would not pick up (since we will consider something more strict than naively
  # impossible values).
  #
  # FIXME actually consider something mroe strict than naively impossible
  # vaules, and also completely restructure this: should only store restrictions
  # if a set of restrictions already exists, and something like Exhaustion
  # Search should instead create them initially.

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
      boxes.push(b) if v not in @grid.get_box_vals(b)

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
        setTimeout(( => @solve_loop()), STRAT_DELAY)

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
      delay = STRAT_DELAY

    switch ps.length
      when 1
        log "Setting (#{util.base_to_cart ps[0]}) to #{v} by SmartGridScan"
        @set(ps[0], v, =>
          @updated = true
          delay += FILL_DELAY)
      when 2,3
        just_updated = false
        if @same_row(ps)
          y = @same_row(ps)
          for x in [0..8]
            i = util.cart_to_base(x,y)
            unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
              just_updated = @add_restriction(i,v)
        else if @same_col(ps)
          x = @same_col(ps)
          for y in [0..8]
            i = util.cart_to_base(x,y)
            unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
              just_updated = @add_restriction(i,v)
        log "Refining knowldege base using SmartGridScan" if just_updated
        @updated ||= just_updated

    setTimeout(callback, delay)

  # Heuristic for whether Smart Grid Scan should be performed.
  should_smartgridscan: ->
    # Should do a smart gridscan if the last attempt at gridscan failed. this
    # should work because gridscan is always run first, so there should always
    # be previous strategies with gridscan among them.
    last_gridscan = -1
    _.each(@prev_results, (result, i) ->
      last_gridscan = i if result.strat == "GridScan" )
    return not @prev_results[last_gridscan].success


  #### Think Inside the Box ####
  # For each box b and for each value v which has not yet been filled in within
  # b, see where v could possibly be placed within b (consulting th evalues in
  # corresponding rows/cols and any cant/must arrays filled in within b); if v
  # can only be placed in one position in b, then fill it in.

  # Get a list of boxes and begin the main loop through the box list.
  ThinkInsideTheBox: ->
    @updated = false

    boxes = [0..8]

    @ThinkInsideBoxLoop(boxes, 0)

  # Get the list of values which have not yet been filled in within the current
  # box, and begin a loop through those values.
  ThinkInsideBoxLoop: (bs, bi) ->
    filled = @grid.get_box_vals bs[bi]
    vals = _.without([1..9], filled...)

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
        setTimeout(( => @solve_loop()), STRAT_DELAY)

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
      delay = STRAT_DELAY

    if ps.length == 1
      log "Setting (#{util.base_to_cart ps[0]}) to #{v} by ThinkInsideTheBox"
      @set(ps[0], v, =>
        @updated = true
        delay += FILL_DELAY
        setTimeout(callback, delay))
    else
      if callback == next_strat
        @prev_results[@prev_results.length-1].success = @updated
      setTimeout(callback, delay)

  # Heuristic for whether Think Inside the Box should be peformed.
  should_thinkinsidethebox: ->
    # do ThinkInsideTheBox unless the last attempt at ThinkInsideTheBox failed.
    last_thinkinside = -1
    _.each(@prev_results, (result, i) ->
      last_thinkinside = i if result.strat == "ThinkInsideTheBox" )
    return last_thinkinside == -1 or @prev_results[last_thinkinside].success



  ### Solve Loop ###

  # Choose a strategy, using the heuristic each strategy provides.
  # FIXME should provide a weighting system based on previous success/failure of
  # attempts at strategies.
  choose_strategy: ->
    if @should_gridscan()
      @prev_results.push {strat: "GridScan"}
      dom.announce_strategy "GridScan"
      log "Trying GridScan"
      return @GridScan()

    if @should_thinkinsidethebox()
      @prev_results.push {strat: "ThinkInsideTheBox"}
      dom.announce_strategy "ThinkInside<br />TheBox"
      log "Trying ThinkInsideTheBox"
      return @ThinkInsideTheBox()

    if @should_smartgridscan()
      @prev_results.push {strat: "SmartGridSCan"}
      dom.announce_strategy "SmartGridScan"
      log "Trying ThinkInsideTheBox"
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
    done = @grid.is_solved() or @solve_iter > max_solve_iter

    if done
      @solve_loop_done()
    else
      # fill obvious cells and then choose a strategy once complete
      @choose_strategy()


  solve_loop_done: ->
    log if @grid.is_solved() then "Grid solved! :)" else "Grid not solved :("

    dom.solve_done_animate()

  solve: ->
    @solve_loop()


## Wrap Up ##
# Export the Solver class to the window for access in the main file.
root.Solver = Solver