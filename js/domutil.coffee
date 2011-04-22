# Helper functions for tasks related to accessing/manipulating the DOM. These
# mostly involve using JQuery to access/set display elemens in the DOM, and to
# animate things to make them look pretty.

# Attach functions to the window object for access in other files.
root = exports ? this

root.dom =
  ## Logging ##

  # Basic logging function. Appends the given string to the stderr textbox, and
  # then returns the value of the string so that log statements can be returned if
  # it's the last line in a function or for loop.
  log: (s) ->
    t = $('#stderr')
    t.val(t.val() + s + '\n')
    t.scrollTop(9999999)
    return s

  ## JQuery Selectors ##

  # Returns a selector for the cell specified in cartesian coordinates.
  sel: (x, y) ->
    [b_x, b_y, s_x, s_y] = cart_to_box x,y
    return ".gr#{b_y} .gc#{b_x} .r#{s_y} .c#{s_x}"

  # Returns a selector for all the cells in the same row as the cell specified
  # in cartesian coordinates.
  sel_row: (x,y) ->
    [b_x, b_y, s_x, s_y] = cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{i} .r#{s_y} .c#{j}, " unless i == b_x and j == s_x
    return s

  # Returns a selector for all the cells in the same col as the cell specified
  # in cartesian coordinates.
  sel_col: (x,y) ->
    [b_x, b_y, s_x, s_y] = cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{i} .gc#{b_x} .r#{j} .c#{s_x}, " unless i == b_y and j == s_y
    return s

  # Returns a selector for all the cells in the same box as the cell specified
  # in cartesian coordinates.
  sel_box: (x,y) ->
    [b_x, b_y, s_x, s_y] = cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{b_x} .r#{j} .c#{i}, " unless i == s_x and j == s_y
    return s


  ## Grid Accessors/Setters ##

  # Get the value in the input HTML element corresponding to the cell specified
  # in cartesian coordinates.
  get_input_val: (x, y) ->
    $(sel(x,y) + " .num").val()

  # Set the value in the input HTML element corresponding to the cell specified
  # in cartesian coordinates.
  set_input_val: (x, y, v) ->
    $(sel(x,y) + " .num").val(v)


  ## Animation Functions ##

  # Adds the proper CSS classes for cell highlighting to the specified JQuery
  # selectors.
  highlight: (box_sel, row_sel, col_sel) ->
    $(box_sel).addClass("adj-box")
    $(row_sel).addClass("adj-row")
    $(col_sel).addClass("adj-col")

  # Removes CSS classes for cell highlighting from the specified JQuery selectors.
  dehighlight: (box_sel, row_sel, col_sel) ->
    $(box_sel).removeClass("adj-box")
    $(row_sel).removeClass("adj-row")
    $(col_sel).removeClass("adj-col")

  # Assigns hover callbacks to the cell specified in cartesian coordinates which
  # highlight the cells in the same row, col, and box as the specified cell.
  color_adjacent: (x,y) ->
    box_s = sel_box(x,y)
    row_s = sel_row(x,y)
    col_s = sel_col(x,y)
    fn1 = -> highlight(box_s, row_s, col_s)
    fn2 = -> dehighlight(box_s, row_s, col_s)
    $(sel(x,y)).hover(fn1, fn2)

  # Assigns hover callbacks to the cell specified in cartesian coordinates which
  # updates the position label with the cell's coordinates.
  display_pos: (x,y) ->
    fn = ->
      $("#pos-label").html("(#{x},#{y})")
    $(sel(x,y)).hover(fn)

  # Updates the display with a new strategy.
  announce_strategy: (s) ->
    $("#strat").html(s)


# Export the log function to window for convenience in other files.
root.log = dom.log
