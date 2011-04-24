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

  # Set a cell specified by a base index to a value. Also handles animation to
  # highlight the cell.
  set: (i, v) ->
    # store in Grid's internal representation.
    @base_array[i] = v

    # change value in DOM and highlight if setting to a non-blank space.
    [x,y] = util.base_to_cart i

    dom.set_input_val_and_highlight(x,y,v)

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

  # Returns an array of the indices of the cells in a specified box. The box can
  # be specified either in cartesian coordinates (of range [0..2]x[0..2]) or
  # indexed 0-8.
  get_box_idxs: (x, y) ->
    unless y?
      y = Math.floor(x/3)
      x = Math.floor(x%3)

    a = []
    for j in [0..2]
      for i in [0..2]
        a.push(util.box_to_base(x,y,i,j))
    return a

  # Returns the array of all the indices of the cells in the box which the
  # specified cell occupies. The cell can be specified either in cartesian
  # coordinates or as a base index.
  get_box_idxs_of: (x,y) ->
    if y?
      x = util.cart_to_base x,y

    [b_x, b_y, s_x, s_y] = util.base_to_box x
    @get_box_idxs b_x, b_y

  # Returns an array of all the values in a specified box. The box can be
  # specified either in cartesian coordinates (of range [0..2]x[0..2]) or
  # indexed 0-8.
  get_box_vals: (x, y) ->
    (@get(i) for i in @get_box_idxs(x,y))

  # Returns the array of all the values in the box which the specified cell
  # occupies. The cell can be specified either in cartesian coordinates or as a
  # base index.
  get_box_vals_of: (x, y) ->
    (@get(i) for i in @get_box_idxs_of(x,y))

  # Returns an array of all the indices of the cells in a specified col.
  get_col_idxs: (x) ->
    (util.cart_to_base(x,y) for y in [0..8])

  # Returns the array of all indices of the cells in the col which this cell
  # occupies. The cell can be specified either in cartesian coordinates or as
  # a base index.
  get_col_idxs_of: (x, y) ->
    if y?
      @get_col_idxs x
    else
      @get_col_idxs util.base_to_cart(x)[0]

  # Returns an array of all the values in a specified col.
  get_col_vals: (x) ->
    (@get(i) for i in @get_col_idxs(x))

  # Returns the array of all values in the col which this cell occupies. The
  # cell can be specified either in cartesian coordinates or as a base index.
  get_col_vals_of: (x, y) ->
    (@get(i) for i in @get_col_idxs_of(x,y))

  # Returns an array of all the indices of the cells in a specified row.
  get_row_idxs: (y) ->
    (util.cart_to_base(x,y) for x in [0..8])

  # Returns the array of all indices of the cells in the row which this cell
  # occupies. The cell can be specified either in cartesian coordinates or as a
  # base index.
  get_row_idxs_of: (x, y) ->
    if y?
      @get_row_idxs y
    else
      @get_row_idxs util.base_to_cart(x)[1]

  # Returns an array of all the values in a specified row.
  get_row_vals: (y) ->
    (@get(i) for i in @get_row_idxs(y))

  # Returns the array of all values in the row which this cell occupies. The
  # cell can be specified either in cartesian coordinates or as a base index.
  get_row_vals_of: (x, y) ->
    (@get(i) for i in @get_row_idxs_of(x,y))

## Wrap Up ##

# Attach grid class to the window object for access in other files.
root.Grid = Grid