root = exports ? this

## Import Statements

FILL_DELAY = root.FILL_DELAY
STRAT_DELAY = root.STRAT_DELAY
max_solve_iter = root.max_solve_iter

util = root.util
dom = root.dom
log = dom.log
debug = dom.debug

## Solver Class ##

class Solver
  constructor: (@grid) ->

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

  # Return whether a particular strategy result was a success (ie, if it filled
  # in any values or updated the knowldege base at all).
  success: (strat_result) ->
    strat_result.vals > 0 or strat_result.knowledge > 0

  # See if any of the strategies from the specified index onwards have been
  # successful.
  update_since: (idx) ->
    results = _.rest(@prev_results, idx)

    for result in results
      return true if result.vals > 0 or result.knowledge > 0
    return false

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

  # Wrapper for `@grid.set` which will update the knowledge base and fill in
  # values if setting this value makes others obvious. Also requires a string
  # specifying the strategy used to find this value, so that it can
  # appropriately be stored in the record (this needs to be done in the set
  # function since it recursively calls the `fill_obvious` functions).
  set: (i, v, strat) ->
    @grid.set i,v
    @record.push {type: "fill", idx: i, val: v, strat: strat}
    log "Setting (#{util.base_to_cart(i)}) to #{v} by #{strat}"

    @occurrences[v] += 1

    [x,y] = util.base_to_cart i
    [b_x,b_y,s_x,s_y] = util.base_to_box i

    @fill_obvious_row(y)
    @fill_obvious_col(x)
    @fill_obvious_box(b_x, b_y)

  # Wrapper for `@grid.set_c` which will update the knowledge base if it needs
  # to and fill in values if setting this value makes others obvious.
  set_c: (x,y,v,strat) ->
    @set(util.cart_to_base(x,y), v, strat)

  # Wrapper for `@grid.set_b` which will update the knowldege base if it needs
  # to and fill in values if setting this value makes others obvious.
  set_b: (b_x, b_y, s_x, s_y, strat) ->
    @set(util.cart_to_base util.box_to_cart(b_x, b_y, s_x, s_y)..., v, strat)

  # If the specified group of indices has only one value missing, then will fill
  # in that value.
  fill_obvious_group: (idxs, type) ->
    vals = (@grid.get(i) for i in idxs)

    if util.num_pos(vals) == 8
      # Get the value which is missing.
      v = 1
      v += 1 until v not in vals

      # Get the position which is missing a value.
      i = 0
      i += 1 until @grid.get(idxs[i]) == 0
      idx = idxs[i]

      @set(idx, v, "#{type}-obvious")

  # Calls `fill_obvious_group` for a row.
  fill_obvious_row: (y) ->
    idxs = @grid.get_row_idxs(y)
    @fill_obvious_group(idxs, "row")

  # Calls `fill_obvious_group` for a col.
  fill_obvious_col: (x) ->
    idxs = @grid.get_col_idxs(x)
    @fill_obvious_group(idxs, "col")

  # Calls `fill_obvious_group` for a box.
  fill_obvious_box: (b_x, b_y) ->
    idxs = @grid.get_box_idxs(b_x, b_y)
    @fill_obvious_group(idxs, "box")


  ### Basic Logic ###

  # Get an array of all naively impossible values to fill into the cell at base
  # index i in the grid. If the cell already has a value, then will return all
  # other values; this seems a little unnecessary, but turns out to make other
  # things cleaner.
  naive_impossible_values: (i) ->
    if @grid.get(i) > 0
      return _.without([1..9], @grid.get(i))
    else
      @grid.get_row_vals_of(i).
        concat(@grid.get_col_vals_of(i)).
          concat(@grid.get_box_vals_of(i))

  # FIXME!
  informed_impossible_values: (i) ->

  # FIXME!
  informed_possible_positions_in_box: (v, x, y) ->

  # Iets a list of positions in a specified box where v can be filled in based
  # on `naive_impossible_values`. The box can be specified either as (x,y) in
  # [0..2]x[0..2] or with a single index in [0..8]. Positions are returned as
  # base indices of the grid.
  naive_possible_positions_in_box: (v, x, y) ->
    if y?
      [nx, ny] = [x, y]
    else
      [nx, ny] = [Math.floor(x%3), Math.floor(x/3)]

    ps = []
    for b in [0..2]
      for a in [0..2]
        i = util.box_to_base nx,ny,a,b
        ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # Gets a list of positions in a specified row where v can be filled in based
  # on `naive_impossible_values`. The row is specified as a y-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the
  # grid.
  naive_possible_positions_in_row: (v, y) ->
    ps = []
    for x in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # Gets a list of positions in a specified col where v can be filled in based
  # on `naive_impossible_values`. The row is specified as an x-coordinate of
  # cartesian coordinates, and positions are returned as base indices of the grid.
  naive_possible_positions_in_col: (v, x) ->
    ps = []
    for y in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) unless v in @naive_impossible_values(i)

    return ps

  # Returns an array of values in order of the number of their occurrences,
  # in order of most prevalent to least prevalent. Only includes values which
  # occur 5 or more times.
  vals_by_occurrences_above_4: ->
    ord = []
    for o in [9..5]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord

  # Returns an array of values in order of the number of their occurrences, in
  # order of most prevalent to least prevalent.
  vals_by_occurrences: ->
    ord = []
    for o in [9..1]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord

  # If the base indices are all in the same row, then returns the index of that
  # row; otherwise returns false.
  same_row: (idxs) ->
    first_row = util.base_to_cart(idxs[0])[1]
    idxs = _.rest(idxs)
    for idx in idxs
      return false if util.base_to_cart(idx)[1] != first_row
    return first_row

  # If the base indices are all in the same column, then returns the index of
  # that col; otherwise returns false.
  same_col: (idxs) ->
    first_col = util.base_to_cart(idxs[0])[0]
    idxs = _.rest(idxs)
    for idx in idxs
      return false if util.base_to_cart(idx)[0] != first_col
    return first_col

  # If the base indices are all in the same box, then returns the index of that
  # box; otherwise returns false.
  same_box: (idxs) ->
    first_box = util.base_to_box(idx[0])
    idxs = _.rest(idxs)
    for idx in idxs
      box = util.base_to_box(idx)
      return false if box[0] != first_box[0] or box[1] != first_box[1]
    return first_box[0]+first_box[0]*3


  ### New Strategies ###


  #### Grid Scan ####
  # Considers each value that occurs 5 or more times, in order of currently most
  # present on the grid to currently least present (pre-computed, so adding new
  # values will not affect the order values are iterated through; this is
  # roughly similar to what a real person would do, as they would basically look
  # over the grid once, then start looking through values, keeping a mental list
  # of what values they'd already tried and not returning back to them). For
  # each value v, consider the boxes b where v has not yet been filled in.

  gridScan: ->
    @record.push {type: "strat", strat: "gridScan"}
    @prev_results.push {strat: "gridScan", vals: 0, knowledge: 0}
    result = _.last(@prev_results)
    log "Trying Grid Scan"

    # Iterate through each value occuring 5 or more times, from most prevalent
    # to least prevalent.
    vals = @vals_by_occurrences_above_4()
    for v in vals
      @record.push {type: "gridscan-val", val: v}
      debug "- Grid Scan examining value #{v}"

      # Iterate through each box which v does not occur in.
      for b in [0..8]
        if v not in @grid.get_box_vals(b)
          @record.push {type: "gridscan-box", box: b}
          debug "-- Grid Scan examining box #{b}"

          ps = @naive_possible_positions_in_box v, b

          if ps.length == 1
            result.vals += 1
            @set(ps[0], v, "gridScan")


  # Run Grid Scan if no other strategies have been tried, or if the last
  # operation was a Grid Scan and it worked (meaning it set at least one value).
  should_gridScan: ->
    if @prev_results.length == 0
      return true
    else
      last = _.last(@prev_results)
      return last.strat == "GridScan" and last.vals > 0

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
  # FIXME: actually consider something more strict than naively impossible
  # vaules, and also completely restructure this: should only store restrictions
  # if a set of restrictions already exists, and something like Exhaustion
  # Search should instead create them initially.

  smartGridScan: ->
    @record.push {type: "strat", strat: "smartGridScan"}
    @prev_results.push {strat: "smartGridScan", vals: 0, knowledge: 0}
    result = _.last(@prev_results)
    log "Trying Smart Grid Scan"

    vals = @vals_by_occurrences()

    for v in vals
      @record.push {type: "smartgridscan-val", val: v}
      debug "- Smart Grid Scan examining value #{v}"

      # Get the boxes which don't contain v.
      boxes = []
      boxes.push(b) if v not in @grid.get_box_vals(b) for b in [0..8]

      for b in boxes
        @record.push {type: "smartgridscan-box", box: b}
        debug "-- Smart Grid Scan examining box #{b}"

        ps = @informed_possible_positions_in_box v, b

        switch ps.length
          when 1
            result.vals += 1
            @set(ps[0], v, "gridScan")
          when 2,3
            if @same_row(ps)
              y = @same_row(ps)
              debug "--- Smart Grid Scan found positions all in the same row, #{y}"
              for x in [0..8]
                i = util.cart_to_base x,y
                unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
                  result.knowledge += 1 if @add_restriction(i,v)
            else if @same_col(ps)
              x = @same_col(ps)
              debug "--- Smart Grid Scan found positions all in the same col, #{x}"
              for y in [0..8]
                i = util.cart_to_base x,y
                unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
                  result.knowledge += 1 if @add_restriction(i,v)

  # Run Smart Grid Scan if the last attempt at Grid Scan failed, unless there
  # hasn't been any new info since the last attempt at Smart Grid Scan.
  should_smartGridScan: ->
    last_gs = -1
    _.each(@prev_result, (result, i) ->
      last_gs = i if result.strat == "gridScan" )
    last_sgs = -1
    _.each(@prev_results, (result, i) ->
      last_sgs = i if result.strat == "smartGridScan" )
    return @prev_results[last_gs].vals == 0 and not @update_since(last_sgs)


  #### Think Inside the Box ####
  # For each box b and for each value v which has not yet been filled in within
  # b, see where v could possibly be placed within b (consulting th evalues in
  # corresponding rows/cols and any cant/must arrays filled in within b); if v
  # can only be placed in one position in b, then fill it in.

  thinkInsideTheBox: ->
    @record.push {type: "strat", strat: "thinkInsideTheBox"}
    @prev_results.push {strat: "thinkInsideTheBox", vals: 0, knowledge: 0}
    result = _.last(@prev_results)
    log "Trying Think Inside the Box"

    for b in [0..8]
      debug "- Think Inside the Box examining box #{b}"
      vals = _.without([1..9], @grid.get_box_vals(b)...)

      for v in vals
        debug "-- Think Inside the Box examining value #{v}"
        ps = @naive_possible_positions_in_box v, b

        if ps.length == 1
          result.vals += 1
          @set(ps[0], v, "thinkInsideTheBox")


  # Run Think Inside the Box unless the last attempt failed.
  should_thinkInsideTheBox: ->
    last = -1
    _.each(@prev_results, (result, i) ->
      last = i if result.strat == "ThinkInsideTheBox" )
    return last == -1 or success(@prev_results[last])




  choose_strategy: ->
    # FIXME: should make this more complicated, maybe choose order to test based
    # on how successful they've been so far?

    if @should_gridScan()
      return @gridScan()

    if @should_thinkInsideTheBox()
      return @thinkInsideTheBox()

    if @should_smartGridScan()
      return @smartGridScan()

    # FIXME
    # if @should_thinkOutsideTheBox()
    # if @should_exhaustionSearch()
    # if @should_desperationSearch()

  # Solves the grid and returns an array of steps used to animate those steps.
  solve: ->
    @record = []
    @strat_results = []
    iter = 1

    until @grid.is_solved() or iter > max_solve_iter
      log "Iteration #{iter}"
      @choose_strategy()
      iter += 1


    log if @grid.is_solved() then "Grid solved! :)" else "Grid not solved :("

    dom.solve_done_animate()




## Wrap Up ##
# Export the Solver class to the window for access in the main file.
root.Solver = Solver