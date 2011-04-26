# Internal representation of Sudoku grid. Provides simple getters, setters, some
# basic utility methods, and some more advanced getters. This contains
# everything related to the computer representation of the grid, whereas
# [solver.coffee] contains everything that operates on the grid but represents
# human-level inference.

## Import Statements ##

root = exports ? this

dom = root.dom
log = dom.log
util = root.util

## Grid Class ##

class Grid
  constructor: ->
    @base_array = @collect_input()

  ### Accesssor Methods ###

  # Access an element from the grid by a base index. Throws an error if an
  # invalid input is specified.
  get: (i) ->
    throw "Invalid base index" if i < 0 or i > 80
    @base_array[i]

  # Access an element from the grid using cartesian coordinates.
  get_c: (x,y) ->
    @get util.cart_to_base(x,y)

  # Access an element from the grid using box coordinates.
  get_b: (b_x, b_y, s_x, s_y) ->
    @get util.cart_to_base util.box_to_cart(b_x, b_y, s_x, s_y)...

  ### Mutator Methods ###

  # Set a cell specified by a base index to a value. Does not update the DOM
  # representation of the array, as we pre-compute the solution to the grid and
  # then process the solution to display the steps.
  set: (i, v) ->
    @base_array[i] = v

  # Set a cell specified by cartesian coordinates to a value.
  set_c: (x,y,v) ->
    @set(util.cart_to_base(x,y), v)

  # Set a cell specified by box coordinates to a value.
  set_b: (b_x, b_y, s_x, s_y) ->
    @set(util.cart_to_base util.box_to_cart(b_x, b_y, s_x, s_y)..., v)

  ### Utility Methods ###

  # Collect the inputted cell values from the DOM.
  collect_input: ->
    a = []
    for j in [0..8]
      for i in [0..8]
        v = dom.get_input_val i, j
        a.push if v is '' then 0 else parseInt(v)
    return a

  # Determines if an array of numbers has one of each of the value 1..9 without
  # any repeats.
  valid_array: (xs) ->
    hits = []

    for x in xs
      if hits[x]? then hits[x] += 1 else hits[x] = 1

    for hit in hits[1...9]
      return false if hit isnt 1

    return true

  # Determine if the grid is solved.
  is_solved: ->
    for i in [0..8]
      return false unless @valid_array @get_col_vals i
      return false unless @valid_array @get_row_vals i
      return false unless @valid_array @get_box_vals i
    return true

  # Return whether base index i is in row r.
  idx_in_row: (i, r) ->
    util.base_to_cart(i)[1] == r

  # Return whether base index i is in col c.
  idx_in_col: (i, c) ->
    util.base_to_cart(i)[0] == c

  # Return whether base index i is in box b.
  idx_in_box: (i, b) ->
    [b_x, b_y] = util.base_to_box i
    return 3*b_y + b_x == b

  ### Convenient Advanced Accessors ###

  # Returns an array of the indices of the cells in the specified type of
  # group. To specify a group type, row = 0, col = 1, and box = 2. The group
  # must be specified by a single index (not by x and y for a box).
  get_group_idxs: (group_type, group_idx) ->
    switch group_type
      # For rows
      when 0
        y = group_idx
        a = (util.cart_to_base(x,y) for x in [0..8])
      # For cols
      when 1
        x = group_idx
        a = (util.cart_to_base(x,y) for y in [0..8])
      # For boxes
      when 2
        a = []
        [b_x, b_y] = [Math.floor(group_idx%3), Math.floor(group_idx/3)]
        for s_y in [0..2]
          for s_x in [0..2]
            a.push(util.box_to_base b_x, b_y, s_x, s_y)
      # Should only specify one of the three valid types of groups.
      else
        throw "Error"

  # Returns an array of the indices of the cells adjacent to cell i in the group
  # type specified.
  get_group_idxs_of: (group_type, i) ->
    [x,y] = util.base_to_cart i
    [b_x, b_y, s_x, s_y] = util.base_to_box i

    switch group_type
      # For rows
      when 0
        @get_group_idxs(group_type, y)
      # For cols
      when 1
        @get_group_idxs(group_type, x)
      # For boxes
      when 2
        @get_group_idsx(group_type, 3*b_y+b_x)
      # Should only specify one of the three valid types of groups.
      else
        throw "Error"

  # Get the indices of all the cells in all the groups which cell i occupies.
  get_all_group_idxs_of: (i) ->
    a = []
    a.concat(@get_group_vals_of(j, i) for j in [0..2])

  # Get the value of each cell in the specified group.
  get_group_vals: (group_type, group_idx) ->
    (@get(i) for i in @get_group_idxs(group_type, group_idx))

  # Get the value of each cell in the specified group containing cell i.
  get_group_vals_of: (group_type, i) ->
    (@get(j) for j in @get_group_idxs_of(group_type, i))

  # Get the values of all the cells in all the groups which cell i occupies.
  get_all_group_vals_of: (i) ->
    (@get(j) for j in @get_all_group_idxs_of(i))

  # If the base indices are all in the same row, then returns the index of that
  # row; otherwise returns -1.
  same_row: (idxs) ->
    first_row = util.base_to_cart(idxs[0])[1]
    idxs = _.rest(idxs)
    for idx in idxs
      return -1 if util.base_to_cart(idx)[1] != first_row
    return first_row

  # If the base indices are all in the same column, then returns the index of
  # that col; otherwise returns -1.
  same_col: (idxs) ->
    first_col = util.base_to_cart(idxs[0])[0]
    idxs = _.rest(idxs)
    for idx in idxs
      return -1 if util.base_to_cart(idx)[0] != first_col
    return first_col

  # If the base indices are all in the same box, then returns the index of that
  # box; otherwise returns -1.
  same_box: (idxs) ->
    first_box = util.base_to_box(idx[0])
    idxs = _.rest(idxs)
    for idx in idxs
      box = util.base_to_box(idx)
      return -1 if box[0] != first_box[0] or box[1] != first_box[1]
    return first_box[0]+first_box[0]*3


## Wrap Up ##

# Attach grid class to the window object for access in other files.
root.Grid = Grid