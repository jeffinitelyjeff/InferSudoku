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

    @clusters = (( -> [])() for i in [0..9])

    @occurrences = [undefined,0,0,0,0,0,0,0,0,0]
    for v in [1..9]
      for i in [0...81]
        @occurrences[v] += 1 if @grid.get(i) == v

    for y in [0..8]
      for x in [0..8]
        v = @grid.get_c(x,y)
        @record_cluster(v, [util.cart_to_base x,y]) if v > 0

    debug "Occurrences:"
    debug _.reduce @occurrences, ((mem, o, v) -> mem + "#{v}: #{o}\n"), ""

    @record = []


  ### Variable Access ###
  # Some of the data structures used by Solver are relatively complicated and
  # structured strangely. These methods provide better interfaces for
  # interacting with (ie, getting/setting/adding to) these variables.

  #### `print_clusters` ####
  print_clusters: ->
    _.reduce @clusters, ((m, cs, v) ->
      m + "\n#{v}: " +  _.reduce cs, ((m2, c) ->
        m2 + "(#{c})"), "", "")

  #### `print_possibles` ####
  print_possibles: ->
    _.reduce @possibles, ((m, vals, i) ->
      m + "\n#{i}: [" + vals + "]"), ""

  #### `print_results` ####
  print_results: ->
    _.reduce @prev_results(), ((m, result, idx) ->
      m + "\n#{idx} #{result.strat}: v -> #{result.vals} k -> #{result.knowledge}"), ""


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

  #### `strict_success` ####
  # Return whether a particular strategy result was a strict success (ie, if it
  # filled in any values). The argument can either be an index into
  # `prev_results()`, or an actual end-strat object.
  strict_success: (strat_idx) ->
    if strat_idx.vals?
      result = strat_idx
    else
      result = @prev_results()[strat_idx]
    result.vals > 0

  #### `update_since` ####
  # See if any of the strategies from the specified index onwards have been
  # successful (not including the specified index).
  update_since: (idx) ->
    _.any(_.rest(@prev_results(), idx+1), (result) ->
      result.vals > 0 or result.knowledge > 0)

  #### `tired` ####
  # See if it has been sufficiently long since a value has been filled in, or if
  # there are many (10x) more strategies that haven't added values than ones that
  # have. For this implementation, we define sufficiently long as over 5
  # iterations and a streak of strategies that don't fill in values as long as
  # the total number of strategies which have filled in values. This is a rough
  # approximation of how a human would act; if they've only been successful with
  # a few strategies, then not being successful in just a few would burn them
  # out, but if they've been minorly successful with a bunch, then they'd be
  # more willing to try out a bunch of strategies before giving up. We restrict
  # it to being over 5 iterations because we don't want weird behavior at the
  # beginning of the solve loop (if they don't get a strict success on the
  # second strategy, then it'd get tired), and because there are 5 different
  # strategies.
  tired: ->
    stricts = _.reduce @prev_results(), ((mem, result, idx) =>
      mem += if @strict_success(idx) then 1 else 0), 0
    non_stricts = _.reduce @prev_results(), ((mem, result, idx) =>
      mem += if @success(idx) and not @strict_success(idx) then 1 else 0), 0

    last = -1
    _.each @prev_results(), (result, idx) =>
      last = idx if @strict_success(idx)

    since = @iter() - last

    since > Math.max(5, stricts) or non_stricts > 10 * stricts

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
    Math.max(2, @iter()/5 + 1)

  # #### `possible_values` ####
  # This will just read the cache of possible values if it exists, or will
  # compute the informed possible values. Will cache the result if the cache
  # parameter is provided and is truthy and there are few enough possibilities
  # (as determined by `possibles_cache_threshold`, which dynamically adjusts to
  # the difficulty the solver is facing.
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
  possible_values: (i, cache) ->
    if @possibles[i]?
      @possibles[i]
    else
      vals = @informed_possible_values(i)

      if cache
        @possibles[i] = vals if 1 < vals.length < @possibles_cache_threshold()

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
    if 0 < positions.length < @record_cluster_threshold()
      @record_cluster(val, positions)
    else
      @visualize_cluster(val, positions)

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
    # If a more specific cluster already exists, then don't add this cluster.
    if _.any @clusters[val], ((cluster) -> _.without(cluster, positions...).length == 0)
      return 0
    else
      # Replace all clusters to which this cluster is a subset. This will create
      # duplicate clusters, since the cluster is also always added on, but this
      # shouldn't hurt anything.
      _.each @clusters[val], ((cluster, idx) =>
        if _.without(positions, cluster...).length == 0
          @clusters[val][idx] = positions)
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

    if @grid.same_row positions != -1
      r = @grid.same_row positions
      row_idxs = @get_group_idxs(0, r)
      unclustered_idxs = _.without(row_idxs, positions...)
      (k++ if @restrict(i, val)) for i in unclustered_idxs

    if @grid.same_col positions != -1
      c = @grid.same_col positions
      col_idxs = @get_group_idxs(1, c)
      unclustered_idxs = _.without(col_idxs, positions...)
      (k++ if @restrict(i, val)) for i in unclustered_idxs

    if @grid.same_box positions != -1
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
      debug "Restricting (#{util.base_to_cart i}) from being #{v}"
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
  # Get an array of all informed possible values for a specific cell. Narrows
  # down values by seeing if there are any clusters such that the cluster makes
  # the value unattainable for the cell (by seeing if any cluster exists for the
  # value such that all the cluster's positions and the cell in question are in
  # the same group). This also handles values which are filled in the grid,
  # because clusters of size 1 are created for them when they're filled.
  informed_possible_values: (i) ->
    if @grid.get(i) > 0
      []
    else
      _.reject [1..9], (v) =>
        clusters = @clusters[v]
        _.any clusters, (cluster) =>
          i not in cluster and
          (@grid.same_row(cluster.concat([i])) != -1 or
           @grid.same_col(cluster.concat([i])) != -1 or
           @grid.same_box(cluster.concat([i])) != -1)

  #### `naive_possible_values` ####
  # Get an array of all naively possible values for a specified cell. Returns an
  # empty array if the cell is already set.
  naive_possible_values: (i) ->
    if @grid.get(i) > 0
      []
    else
      ps = _.without([1..9], @grid.get_all_group_vals_of(i)...)
      throw "Error" if ps.length == 0
      return ps

  #### `possible_positions_in_box` ####
  # Gets a list of positions in a specified box where v can be filled in based
  # on filled in values and whatever knowledge we currently have. The box can be
  # specified either as (x,y) in [0..2]x[0..2] or with a single index in
  # [0..8]. Positions are returned as base indices of the grid.
  possible_positions_in_box: (v, x, y) ->
    b = if y? then 3*y + x else x

    ps = _.select @grid.get_group_idxs(2, b), (i) =>
      v in @possible_values(i)

    if ps.length == 0 and v not in @grid.get_group_vals(2, b)
      throw "Error" # this means v isn't possible in the group, which is bad.
    else
      return ps

  #### `possible_positions_in_row` ####
  # Gets a list of positions in a specified row where v can be filled in based
  # on filled in values and whatever knowledge we currently have. Positions are
  # returned as base indices of the grid.
  possible_positions_in_row: (v, y) ->
    ps = _.select @grid.get_group_idxs(0, y), (i) =>
      v in @possible_values(i)

    if ps.length == 0 and v not in @grid.get_group_vals(0, y)
      throw "Error"
    else
      return ps

  #### `possible_positions_in_col` ####
  # Gets a list of positions in a specified col where v can be filled in based
  # on filled in values and whatever knowledge we currently have. Positions are
  # returned as base indices of the grid.
  possible_positions_in_col: (v, x) ->
    ps = _.select @grid.get_group_idxs(1, x), (i) =>
      v in @possible_values(i)

    if ps.length == 0 and v not in @grid.get_group_vals(1, x)
      throw "Error"
    else
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

          switch ps.length
            when 0 then throw "Error"
            when 1
              result.vals += 1
              result.knowledge += @set(ps[0], v, "gridScan")
            else
              result.knowledge += @announce_cluster(v, ps)

    @record.push result

  ##### `should_gridScan` #####
  # Run Grid Scan if no other strategies have been tried, or if the last
  # operation was a Grid Scan and it worked (meaning it set at least one value).
  should_gridScan: ->
    last = @last_attempt("gridScan")
    return last == -1 or @strict_success(last) or @update_since(last)

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

        ps = @possible_positions_in_box v, b

        if ps.length == 1
          result.vals += 1
          result.knowledge += @set(ps[0], v, "thinkInsideTheBox")
        else
          result.knowledge += @announce_cluster(v, ps)

    @record.push result

  ##### `should_thinkInsideTheBox` #####
  # Run Think Inside the Box unless the last attempt failed.
  should_thinkInsideTheBox: ->
    last = @last_attempt("thinkInsideTheBox")
    return last == -1 or @strict_success(last) or @update_since(last)

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

        ps = @possible_positions_in_row v,y

        if ps.length == 1
          result.vals += 1
          result.knowledge += @set(ps[0], v, "thinkInsideTheRow")
        else
          result.knowledge += @announce_cluster(v, ps)

    @record.push result

  #### `should_thinkInsideTheRow` ####
  # Run Think Inside the Row unless the last attempt failed.
  should_thinkInsideTheRow: ->
    last = @last_attempt("thinkInsideTheRow")
    return last == -1 or @strict_success(last) or @update_since(last)

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

        ps = @possible_positions_in_col v,x

        if ps.length == 1
          result.vals += 1
          result.knowledge += @set(ps[0], v, "thinkInsideTheCol")
        else
          result.knowledge += @announce_cluster(v, ps)

    @record.push result

  ##### `should_thinkInsideTheCol` #####
  # Run Think Inside the Col unless the last attempt failed.
  should_thinkInsideTheCol: ->
    last = @last_attempt("thinkInsideTheCol")
    return last == -1 or @strict_success(last) or @update_since(last)

  #### Exhaustion Search ####
  # Consider each cell c, and see what values v c cannot be based on values in
  # the groups it's in and any cluster info we've written down pertaining to
  # those groups. Let w be the values in [1..9] not in v; if w is a single
  # value, then fill it in, and otherwise record the possibilities if w is
  # sufficiently short (as determined by `possibles_cache_threshold`).

  exhaustionSearch: ->
    @record.push type: "start-strat", strat: "exhaustionSearch", iter: @iter()
    result = type: "end-strat", strat: "exhaustionSearch", vals: 0, knowledge: 0
    log "Trying Exhaustion Search, #{@possibles_cache_threshold()}"

    for i in [0..80]
      if @grid.get(i) == 0
        debug "- Exhaustion Search examining cell (#{util.base_to_cart i})"
        o = @possibles[i]
        vals = @possible_values(i, true)
        n = @possibles[i]
        result.knowledge += 1 if n != o
        debug "- Vals: #{vals}"
        if vals.length == 1
          result.vals += 1
          result.knowledge += @set(i, vals[0], "exhaustionSearch")

    @record.push result

  should_exhaustionSearch: ->
    last = @last_attempt("exhaustionSearch")
    return last == -1 or @strict_success(last) or @update_since(last)


  #### `choose_strategy` ####
  # Will choose a strategy and execute it. If no strategies are chosen, then
  # will return `false`, at which point the solve loop should stop. If the
  # solver is not tired, then will choose whichever in the order gridScan ->
  # thinkInsideTheBox -> thinkInsideTheRow -> thinkInsideTheCol ->
  # exhaustionSearch happens to qualify (based on their should_xxx functions);
  # if the solver is tired, then will try out a strategy it's never done before
  # before giving up.
  choose_strategy: ->
    unless @tired()
      if @should_gridScan()
        return @gridScan()

      if @should_thinkInsideTheBox()
        return @thinkInsideTheBox()

      if @should_thinkInsideTheRow()
        return @thinkInsideTheRow()

      if @should_thinkInsideTheCol()
        return @thinkInsideTheCol()

      if @should_exhaustionSearch()
        return @exhaustionSearch()

    if @tired()
      if @last_attempt("gridScan") == -1
        return @gridScan()

      if @last_attempt("thinkInsideTheBox") == -1
        return @thinkInsideTheBox()

      if @last_attempt("thinkInsideTheRow") == -1
        return @thinkInsideTheRow()

      if @last_attempt("thinkInsideTheCol") == -1
        return @thinkInsideTheCol()

      if @last_attempt("exhaustionSearch") == -1
        return @exhaustionSearch()


    return false

  #### `solve` ####
  # Solves the grid and returns an array of steps used to animate those steps.
  solve: ->
    log "Iteration 1"
    debug @grid.print()

    # We keep going until the grid is solved or until no more strategies are
    # chosen. This iterates because `choose_strategy` will actually perform the
    # chosen strategy.
    until @grid.is_solved() or not @choose_strategy()
      log "Iteration #{@iter()}"
      debug "Grid", @grid.print()
      debug "Clusters", @print_clusters()
      debug "Possibles", @print_possibles()


    debug "Results", @print_results()
    log "Quit becasue I was tired..." if @tired()

    log if @grid.is_solved() then "Grid solved! :)" else "Grid not solved :("


    dom.animate_solution(@record, dom.wrap_up_animation)




## Wrap Up ##
# Export the Solver class to the window for access in the main file.
root.Solver = Solver