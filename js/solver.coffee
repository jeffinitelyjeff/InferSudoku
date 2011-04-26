# `solver.coffee` contains all logic for human-level inference to find a
# solution to the Sudoku grid.


## Import Statements ##

root = exports ? this

FILL_DELAY = root.FILL_DELAY
STRAT_DELAY = root.STRAT_DELAY
max_solve_iter = root.max_solve_iter

util = root.util
dom = root.dom
log = dom.log
debug = dom.debug

## Solver Class ##
# A Solver object is constructed once every time the solve button is hit, so all
# the relevant parameters are set to their defaults in the constructor.
#
# - `possibles`: An array for each base index marking the possible values that
#   base index can take on. From the computer's perspective, this will basically
#   just be a cache of the last call to `possible_values` (which is updated
#   whenever new values are recorded), and in this respect it offers only a
#   minor performance boost; the real point of it is to simulate the human
#   process of recording a couple possible values when there are only a couple
#   possible values.
#
# - `clusters`: An array of array of arrays of cell positions representing the
#   clusters of positions which a value is restricted to inhabiting in
#   particular groups. We add clusters thinking about a cluster belonging to a
#   particular group (as in, "this value is only possible in these 3 spots in
#   this box"), but the information is actually relevant to any group which
#   contains all the positions of the cluster. A cluster is represented as a
#   list of cell positions, assigned to a specific position in the `clusters`
#   array to indicate the value which it is clustering. For example,
#   `clusters[3]` is a list of clusters for the value 3; `clusters[3][0]` is a
#   cluster, a list of positions.
# - `occurrences`: Tracks the number of occurrences of each value in the entire
#   grid.
# - `record`: Tracks every important operation performed in order. Each object
#   added to the record will have a `type` field indicating whta kind of
#   operation (`"fill"`, `"start-strat"`, `"end-strat"`, and more detailed,
#   strategy-specific operations). These operations will then be parsed in
#   `dom.animate_solution`.

class Solver
  constructor: (@grid) ->

    @possibles = []

    make_empty_cluster_vals = -> []
    make_empty_cluster_groups = -> (make_empty_cluster_vals() for i in [0..8])
    @clusters = (make_empty_cluster_groups() for i in [0..2])

    @occurrences = [undefined,0,0,0,0,0,0,0,0,0]
    for v in [1..9]
      for i in [0...81]
        @occurrences[v] += 1 if @grid.get(i) == v

    @record = []


  ### Variable Access ###
  # Some of the data structures used by Solver are relatively complicated and
  # structured strangely. These methods provide better interfaces for
  # interacting with (ie, getting/setting/adding to) these variables.

  #### `prev_results` ####
  # Skim the `record` for just the end strategy operations which have info about
  # the performance of each strategy.
  prev_results: ->
    _.select(@record, (op) ->
      op.type == "end-strat")

  #### `last_attempt` ####
  # Get the index of the last occurrence of `strat_name` in the array of
  # previous results.
  last_attempt: (strat_name) ->
    last = -1
    _.each(@prev_results(), (result, i) ->
      last = i if result.strat == strat_name )
    return last

  #### `success` ####
  # Return whether a particular strategy result was a success (ie, if it filled
  # in any values or updated the knowldege base at all). The argument can either
  # be an index into `prev_results()`, or an actual end-strat object.
  success: (strat_idx) ->
    if strat_idx.vals? and strat_idx.knowledge?
      result = strat_idx
    else
      result = @prev_results()[strat_idx]
    result.vals > 0 or result.knowledge > 0

  #### `update_since` ####
  # See if any of the strategies from the specified index onwards have been
  # successful (not including the specified index).
  update_since: (idx) ->
    _.any(_.rest(@prev_results(), idx+1), (result) ->
      result.vals > 0 or result.knowledge > 0)

  #### `iter` ####
  # Simply gets the number of previous results (plus one).
  iter: ->
    @prev_results().length + 1

  #### `possibles_cache_threshold` ####
  # The number of possible values at which or below we would start caching (ie,
  # writing down) the possible values. In my play style, I am more inclined to
  # write down information the more desperate I get. `iter` will serve as a
  # proxy for this level of desperation.
  possibles_cache_threshold: ->
    Math.max(2, (@iter()-1) / 10)

  # #### `possible_values` ####
  # This will just read the cache of possible values if it
  # exists, or will compute the informed possible values and cache it if there
  # are 3 or less possibilities, which reflects how I would act solving a
  # Sudoku.
  #
  # Note1: Once the cache is created for a particular cell, then the
  # `informed_possible_values` function is never going to be called again for
  # that cell, so we must take extra care to update the `possibles` cache
  # whenever a cluster is set.
  #
  # Note2: Informed possibilities are always used, but a lot of the time this
  # will result in the same effect as using naive possibilities, since informed
  # possibilities are only informed once their is knowledge is known. Also,
  # informed possibilities are just based on the knowledge that is recorded;
  # this is akin to a human writing down information on the grid, so it makes
  # sense to always consult this knowledge, since a human would rarely ignore
  # the information they write (this is assuming that, like I, they only record
  # minimal information and do not try to brute-force a strategy).
  possible_values: (i) ->
    if @possibles[i]?
      return @possibles[i]
    else
      vals = @informed_possible_values(i)
      @possibles[i] = vals if vals.length < @possibles_cache_threshold()
      return vals

  #### `record_cluster_threshold` ####
  # The number of possible positions at which or below we would start recording
  # clusters. In my play style, I am more inclined to write down information the
  # more desperate I get. `iter` will serve as a proxy for tihs level of
  # desperation.
  record_cluster_threshold: ->
    @possibles_cache_threshold() # we'll keep them the same for now

  #### `announce_cluster` ####
  # This will either record or visualize a cluster depending on
  # `record_cluster_threshold.
  announce_cluster: (val, positions) ->
    if positions.length < @record_cluster_threshold()
      @record_cluster()
    else
      @visualize_cluster()

  #### `record_cluster` ####
  # This saves the specified cluster in the knowledge bank, and also performs
  # the standard `visualize_cluster` to refine the other information in the
  # knowledge bank. This is analogous to the process I undertake when I'm
  # desperate for information to get somewhere in a puzzle. Returns the number
  # of additions made to the knowledge bank from visualizing the cluster.
  #
  # Adds the list of positions to the appropriate list in `@clusters` as long as
  # the list of positions being added isn't a superset of any clusters already
  # contained.
  record_cluster: (val, positions) ->
    same_positions = (cluster) ->
      _.without(cluster, positions...) == []

    if _.any(@clusters[val], same_positions)
      return 0
    else
      @clusters[val].push(positions)
      return @visualize_cluster(val, positions) + 1

  #### `visualize_cluster` ####
  # Visualizes the specified cluster. This process just updates any `possible`
  # knowledge in cells that are affected by the cluster; it is analogous to the
  # process I undertake normally, before I'm desperate. This really shouldn't do
  # a ton of updating, since `restrict` should only have an effect when there
  # are only a few possible values left for a cell and we're already recording
  # them. Basically, this is just taking the cluster and seeing what we can do
  # with it now, and not taking the effort to write down the cluster in case it
  # might be useful in the future. Returns the number of additions made to the
  # knowledge bank from visualizing the cluster.
  #
  # Sees if the positions are all in the same row, col, or box, and adds
  # restrictions to the rest of the indices in that row, col, or box if they
  # are.
  visualize_cluster: (val, positions) ->
    k = 0 # knowledge gained from visualizing this cluster.

    if @grid.same_row positions
      r = @grid.same_row positions
      row_idxs = @get_group_idxs(0, r)
      unclustered_idxs = _.without(row_idxs, positions...)
      (k++ if @restrict(i, val)) for i in unclustered_idxs

    if @grid.same_col positions
      c = @grid.same_col positions
      col_idxs = @get_group_idxs(1, c)
      unclustered_idxs = _.without(col_idxs, positions...)
      (k++ if @restrict(i, val)) for i in unclustered_idxs

    if @grid.same_box positions
      b = @grid.same_box positions
      box_idxs = @get_group_idxs(2, b)
      unclustered_idxs = _.without(box_idxs, positions...)
      (k++ if @restrict(i, val)) for i in unclustered_idxs

    return k

  #### `restrict` ####
  # Updates the knowledge base with the information that cell i should be
  # restricted from value v; this will only do something if we're already
  # keeping track of possible values for cell i. Returns whether it updated the
  # knowledge base (ie, if we're tracking possible values for that cell and we
  # didn't already know that it couldn't be value v).
  #
  # Makes sure a list of possible vaules is set for i if it should exist (ie, if
  # there are few enough values) by calling `possible_values` before trying
  # anything.
  restrict: (i, v) ->
    @possible_values(i)
    if @possibles[i]? and v in @possibles[i]
      @possibles[i] = _.without(@possibles[i], v)

      throw "Error" if @possibles[i].length == 0 # this wouldn't make sense

      return true
    else
      return false

  ### Setting ###

  #### `set` ####
  # Wrapper for `@grid.set` which will update the knowledge base and fill in
  # values if setting this value makes others obvious. Also requires a string
  # specifying the strategy used to find this value, so that it can
  # appropriately be stored in the record (this needs to be done in the set
  # function since it recursively calls the `fill_obvious` functions). Will also
  # update the possible values (if any are stored) of cells in the same row,
  # col, and box and return the number of refinements made to `possibles`
  # arrays; to do this, it will create a cluster of one position, but this is
  # just a convenience mechanism.
  set: (i, v, strat) ->
    @grid.set i,v
    @possibles[i] = []
    @record.push {type: "fill", idx: i, val: v, strat: strat}
    log "Setting (#{util.base_to_cart(i)}) to #{v} by #{strat}"

    @occurrences[v] += 1

    k = @announce_cluster(v, [i]) # this will always go to record_cluster, since
                                  # the number of positions is less than 2.

    [x,y] = util.base_to_cart i
    [b_x,b_y,s_x,s_y] = util.base_to_box i

    @fill_obvious_row(y)
    @fill_obvious_col(x)
    @fill_obvious_box(b_x, b_y)

    return k

  #### `set_c` ####
  # Wrapper for `@grid.set_c` which will update the knowledge base if it needs
  # to and fill in values if setting this value makes others obvious.
  set_c: (x,y,v,strat) ->
    @set(util.cart_to_base(x,y), v, strat)

  #### `set_b` ####
  # Wrapper for `@grid.set_b` which will update the knowldege base if it needs
  # to and fill in values if setting this value makes others obvious.
  set_b: (b_x, b_y, s_x, s_y, strat) ->
    @set(util.cart_to_base util.box_to_cart(b_x, b_y, s_x, s_y)..., v, strat)

  #### `fill_obvious_group` ####
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

  #### `fill_obvious_row` ####
  # Calls `fill_obvious_group` for a row.
  fill_obvious_row: (y) ->
    idxs = @grid.get_group_idxs(0,y)
    @fill_obvious_group(idxs, "row")

  #### `fill_obvious_col` ####
  # Calls `fill_obvious_group` for a col.
  fill_obvious_col: (x) ->
    idxs = @grid.get_group_idxs(1,x)
    @fill_obvious_group(idxs, "col")

  #### `fill_obvious_box` ####
  # Calls `fill_obvious_group` for a box.
  fill_obvious_box: (b_x, b_y) ->
    idxs = @grid.get_group_idxs(2,3*b_x+b_y)
    @fill_obvious_group(idxs, "box")


  ### Basic Logic ###

  #### `informed_possible_values` ####
  # Get an array of all informed possible values for a specific cell. To get the
  # informed values, rejects any naive values for which there are clusters
  # entirely in the same row, col, or box as the index in question. Because this
  # is a refinement of `naive_possible_values`, will return an empty array if
  # the cell is already set.
  informed_possible_values: (i) ->
    vals = @naive_possible_values(i)

    _.reject(vals, (v) ->
      _.any(@clusters[v], (cluster) ->
        @grid.same_row(cluster.concat([i])) or
        @grid.same_col(cluster.concat([i])) or
        @grid.same_box(cluster.concat([i])) ) )

  #### `naive_possible_values` ####
  # Get an array of all naively possible values for a specified cell. Returns an
  # empty array if the cell is already set.
  naive_possible_values: (i) ->
    if @grid.get(i) > 0
      []
    else
      impossible = @grid.get_all_group_vals_of(i)
      _.without([1..9], impossible...)

  #### `possible_positions_in_box` ####
  # Gets a list of positions in a specified box where v can be filled in based
  # on filled in values and whatever knowledge we currently have. The box can be
  # specified either as (x,y) in [0..2]x[0..2] or with a single index in
  # [0..8]. Positions are returned as base indices of the grid.
  possible_positions_in_box: (v, x, y) ->
    if y?
      [nx, ny] = [x, y]
    else
      [nx, ny] = [Math.floor(x%3), Math.floor(x/3)]

    ps = []
    for b in [0..2]
      for a in [0..2]
        i = util.box_to_base nx,ny,a,b
        ps.push(i) if v in @possible_values(i)

    return ps

  #### `possible_positions_in_row` ####
  # Gets a list of positions in a specified row where v can be filled in based
  # on filled in values and whatever knowledge we currently have. Positions are
  # returned as base indices of the grid.
  possible_positions_in_row: (v, y) ->
    ps = []
    for x in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) if v in @possible_values(i)

    return ps

  #### `possible_positions_in_col` ####
  # Gets a list of positions in a specified col where v can be filled in based
  # on filled in values and whatever knowledge we currently have. Positions are
  # returned as base indices of the grid.
  possible_positions_in_col: (v, x) ->
    ps = []
    for y in [0..8]
      i = util.cart_to_base x,y
      ps.push(i) if v in @possible_values(i)

    return ps

  #### `vals_by_occurrences_above_4` ####
  # Returns an array of values in order of the number of their occurrences,
  # in order of most prevalent to least prevalent. Only includes values which
  # occur 5 or more times.
  vals_by_occurrences_above_4: ->
    ord = []
    for o in [9..5]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord

  #### `vals_by_occurrences` ####
  # Returns an array of values in order of the number of their occurrences, in
  # order of most prevalent to least prevalent.
  vals_by_occurrences: ->
    ord = []
    for o in [9..1]
      for v in [1..9]
        ord.push(v) if @occurrences[v] == o
    return ord




  ### Strategies ###


  #### Grid Scan ####
  # Considers each value that occurs 5 or more times, in order of currently most
  # present on the grid to currently least present (pre-computed, so adding new
  # values will not affect the order values are iterated through; this is
  # roughly similar to what a real person would do, as they would basically look
  # over the grid once, then start looking through values, keeping a mental list
  # of what values they'd already tried and not returning back to them). For
  # each value v, consider the boxes b where v has not yet been filled in.
  gridScan: ->
    @record.push type: "start-strat", strat: "gridScan", iter: @iter()
    result = type: "end-strat", strat: "gridScan", vals: 0, knowledge: 0
    log "Trying Grid Scan"

    vals = @vals_by_occurrences_above_4()
    for v in vals
      @record.push {type: "gridscan-val", val: v}
      debug "- Grid Scan examining value #{v}"

      for b in [0..8]
        if v not in @grid.get_group_vals(2, b)
          @record.push {type: "gridscan-box", box: b}
          debug "-- Grid Scan examining box #{b}"

          ps = @possible_positions_in_box v, b

          if ps.length == 1
            result.vals += 1
            result.knowledge += @set(ps[0], v, "gridScan")
          else
            result.knowledge += @announce_cluster(v, ps)

    @record.push result

  #### `should_gridScan` ####
  # Run Grid Scan if no other strategies have been tried, or if the last
  # operation was a Grid Scan and it worked (meaning it set at least one value).
  should_gridScan: ->
    last = _.last(@prev_results())
    last == undefined or (last.strat == "gridScan" and @success(last))

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
    @record.push type: "start-strat", strat: "smartGridScan", iter: @iter()
    result = type: "end-strat", strat: "smartGridScan", vals: 0, knowledge: 0
    log "Trying Smart Grid Scan"

    vals = @vals_by_occurrences()

    for v in vals
      @record.push {type: "smartgridscan-val", val: v}
      debug "- Smart Grid Scan examining value #{v}"

      for b in [0..8]
        if v not in @grid.get_group_vals(2, b)
          @record.push {type: "smartgridscan-box", box: b}
          debug "-- Smart Grid Scan examining box #{b}"

          ps = @possible_positions_in_box v, b

          switch ps.length
            when 1
              result.vals += 1
              @set(ps[0], v, "smartGridScan")
            when 2,3
              if @same_row(ps) > -1
                y = @same_row(ps)
                debug "--- Smart Grid Scan found positions all in the same row, #{y}"
                for x in [0..8]
                  i = util.cart_to_base x,y
                  unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
                    if @add_restriction(i,v)
                      log "Restricting (#{util.base_to_cart(i)}) from #{v} by Smart Grid Scan"
                      result.knowledge += 1
              else if @same_col(ps) > -1
                x = @same_col(ps)
                debug "--- Smart Grid Scan found positions all in the same col, #{x}"
                for y in [0..8]
                  i = util.cart_to_base x,y
                  unless @grid.idx_in_box(i,b) or @grid.get(i) != 0
                    if @add_restriction(i,v)
                      log "Restricting (#{util.base_to_cart(i)}) from #{v} by Smart Grid Scan"
                      result.knowledge += 1

    @record.push result

  #### `should_smartGridScan` ####
  # Run Smart Grid Scan if the last attempt at Grid Scan failed, unless there
  # hasn't been any new info since the last attempt at Smart Grid Scan.
  should_smartGridScan: ->
    last_grid = @last_attempt("gridScan")
    last_smart = @last_attempt("smartGridScan")
    return last_grid > -1 and
           not @success(last_grid) and
           @update_since(last_smart)

  #### Think Inside the Box ####
  # For each box b and for each value v which has not yet been filled in within
  # b, see where v could possibly be placed within b (consulting th evalues in
  # corresponding rows/cols and any cant/must arrays filled in within b); if v
  # can only be placed in one position in b, then fill it in.

  thinkInsideTheBox: ->
    @record.push type: "start-strat", strat: "thinkInsideTheBox", iter: @iter()
    result = type: "end-strat", strat: "thinkInsideTheBox", vals: 0, knowledge: 0
    log "Trying Think Inside the Box"

    for b in [0..8]
      debug "- Think Inside the Box examining box #{b}"
      vals = _.without([1..9], @grid.get_group_vals(2, b)...)

      for v in vals
        debug "-- Think Inside the Box examining value #{v}"
        # FIXME: ps = @possible_positions_in_box v,b, 'semi-informed'
        ps = @possible_positions_in_box v, b

        if ps.length == 1
          result.vals += 1
          @set(ps[0], v, "thinkInsideTheBox")

    @record.push result

  #### `should_thinkInsideTheBox` ####
  # Run Think Inside the Box unless the last attempt failed.
  should_thinkInsideTheBox: ->
    last = @last_attempt("thinkInsideTheBox")
    return last == -1 or @success(last)

  #### Think Inside the Row ####
  # For each row r and for each value v which has not yet been filled in within
  # r, see where v could possibly be placed within r (using semi-informed
  # possible values); if v can only be placed in one position in r, then fill
  # it in.

  thinkInsideTheRow: ->
    @record.push type: "start-strat", strat: "thinkInsideTheRow", iter: @iter()
    result = type: "end-strat", strat: "thinkInsideTheRow", vals: 0, knowledge: 0
    log "Trying Think Inside the Row"

    for y in [0..8]
      debug "- Think Inside the Row examining row #{y}"
      vals = _.without([1..9], @grid.get_group_vals(0,y)...)

      for v in vals
        debug "-- Think Inside the Row examining value #{v}"
        # FIXME: ps = @possibel_positions_in_row v,b,'semi-informed'
        ps = @possible_positions_in_row v,y

        if ps.length == 1
          result.vals += 1
          @set(ps[0], v, "thinkInsideTheRow")

    @record.push result

  #### `should_thinkInsideTheRow` ####
  # Run Think Inside the Row unless the last attempt failed.
  should_thinkInsideTheRow: ->
    last = @last_attempt("thinkInsideTheRow")
    return last == -1 or @success(last)

  #### Think Inside the Col ####
  # For each col c and for each value v which has not yet been filled in within
  # r, see where v could possibly be placed within c (using semi-informed
  # possible values); if v can only be placed in one position in c, then fill it
  # in.

  thinkInsideTheCol: ->
    @record.push type: "start-strat", strat: "thinkInsideTheCol", iter: @iter()
    result = type: "end-strat", strat: "thinkInsideTheCol", vals: 0, knowledge: 0
    log "Trying Think Inside the Col"

    for x in [0..8]
      debug "- Think Inside the Col examining col #{x}"
      vals = _.without([1..9], @grid.get_group_vals(1,x)...)

      for v in vals
        debug "-- Think Inside the Col examining value #{v}"
        # FIXME: ps = @possible_positions_in_col v,b,'semi-informed'
        ps = @possible_positions_in_col v,x

        if ps.length == 1
          result.vals += 1
          @set(ps[0], v, "thinkInsideTheCol")

    @record.push result

  #### `should_thinkInsideTheCol` ####
  # Run Think Inside the Col unless the last attempt failed.
  should_thinkInsideTheCol: ->
    last = @last_attempt("thinkInsideTheCol")
    return last == -1 or @success(last)


  #### `choose_strategy` ####
  # Will choose a strategy and execute it. If no strategies are chosen, then
  # will return `false`, at which point the solve loop should stop.
  choose_strategy: ->
    # FIXME: should make this more complicated, maybe choose order to test based
    # on how successful they've been so far?

    if @should_gridScan()
      return @gridScan()

    if @should_thinkInsideTheBox()
      return @thinkInsideTheBox()

    if @should_thinkInsideTheRow()
      return @thinkInsideTheRow()

    if @should_thinkInsideTheCol()
      return @thinkInsideTheCol()

    if @should_smartGridScan()
      return @smartGridScan()

    # FIXME
    # if @should_thinkOutsideTheBox()
    # if @should_exhaustionSearch()
    # if @should_desperationSearch()

    return false

  #### `solve` ####
  # Solves the grid and returns an array of steps used to animate those steps.
  solve: ->
    log "Iteration 1"

    # We keep going until the grid is solved or until no more strategies are
    # chosen.
    until @grid.is_solved() or not @choose_strategy()
      log "Iteration #{@iter()}"



    log if @grid.is_solved() then "Grid solved! :)" else "Grid not solved :("

    dom.animate_solution(@record, dom.wrap_up_animation)




## Wrap Up ##
# Export the Solver class to the window for access in the main file.
root.Solver = Solver