# Basic helper functions for coordinate manipulation and other various
# commonly-used tasks.

root = exports ? this

root.util =
  ## Cordinate Manipulation ##
  # There are three coordinate systems: base index, cartesian coordinates, and box
  # coordinates. These provide functions for converting between any two systems
  # (there are 6 such possible conversions).

  #     Base index -> cartesian coordinates
  #     i -> [x, y]
  base_to_cart: (i) ->
    [Math.floor(i%9), Math.floor(i/9)]

  #     Cartesian coordinates -> base index
  #     x,y -> i
  cart_to_base: (x,y) ->
    9*y + x

  #     Cartesian coordinates -> box coordinates
  #     x,y -> [b_x, b_y, s_x, s_y]
  cart_to_box: (x,y) ->
    [Math.floor(x/3), Math.floor(y/3), Math.floor(x%3), Math.floor(y%3)]

  #     Box coordinates -> cartesian coordinates
  #     b_x,b_y,s_x,s_y -> [x, y]
  box_to_cart: (b_x, b_y, s_x, s_y) ->
    [3*b_x + s_x, 3*b_y + s_y]

  #     Base index -> box coordinates
  #     i -> [b_x, b_y, s_x, s_y]
  base_to_box: (i) ->
    cart_to_box @base_to_cart(i)...

  #     Box coordinates -> base index
  #     b_x,b_y,s_x,s_y -> i
  box_to_base: (b_x, b_y, s_x, s_y) ->
    cart_to_base @box_to_cart(b_x, b_y, s_x, s_y)...

  ## Other Utilities ##

  # Count the number of elements of an array which are greater than 0.
  num_pos: (xs) ->
    _.reduce(xs, ( (memo, x) -> if x > 0 then memo + 1 else memo ), 0)

