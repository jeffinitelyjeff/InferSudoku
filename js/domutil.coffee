# Helper functions for tasks related to accessing/manipulating the DOM. These
# mostly involve using JQuery to access/set display elemens in the DOM, and to
# animate things to make them look pretty.

# Attach functions to the window object for access in other files.
root = exports ? this

puzzles = root.puzzles
util = root.util
HIGHLIGHT_FADEIN_TIME = root.HIGHLIGHT_FADEIN_TIME
HIGHLIGHT_DURATION = root.HIGHLIGHT_DURATION
HIGHLIGHT_FADEOUT_TIME = root.HIGHLIGHT_FADEOUT_TIME

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
    [b_x, b_y, s_x, s_y] = util.cart_to_box x,y
    return ".gr#{b_y} .gc#{b_x} .r#{s_y} .c#{s_x}"

  # Returns a selector for all the cells in the same row as the cell specified
  # in cartesian coordinates.
  sel_row: (x,y) ->
    [b_x, b_y, s_x, s_y] = util.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{i} .r#{s_y} .c#{j}, " unless i == b_x and j == s_x
    return s

  # Returns a selector for all the cells in the same col as the cell specified
  # in cartesian coordinates.
  sel_col: (x,y) ->
    [b_x, b_y, s_x, s_y] = util.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{i} .gc#{b_x} .r#{j} .c#{s_x}, " unless i == b_y and j == s_y
    return s

  # Returns a selector for all the cells in the same box as the cell specified
  # in cartesian coordinates.
  sel_box: (x,y) ->
    [b_x, b_y, s_x, s_y] = util.cart_to_box x, y
    s = ""
    for i in [0..2]
      for j in [0..2]
        s += ".gr#{b_y} .gc#{b_x} .r#{j} .c#{i}, " unless i == s_x and j == s_y
    return s


  ## Grid Accessors/Setters ##

  # Get the value in the input HTML element corresponding to the cell specified
  # in cartesian coordinates.
  get_input_val: (x, y) ->
    $(@sel(x,y) + " .num").val()

  # Set the value in the input HTML element corresponding to the cell specified
  # in cartesian coordinates. Will insert a blank space if v is 0 or a dot.
  set_input_val: (x, y, v, given) ->
    if v is 0 or v is '.'
      v = ''

    $(@sel(x,y) + " .num").val(v)

    if given
      $(@sel(x,y) + " .num").addClass('given')
    else
      $(@sel(x,y) + " .num").removeClass('given')


  ## Animation Functions ##

  # Set the value in the input HTMl element corresponding to the cell specified
  # in cartesian coordinates. Will insert a blank space if v is 0 or a dot, and
  # otherwise will highlight the set cell.
  set_input_val_and_highlight: (x, y, v) ->
    @set_input_val(x,y,v)

    unless v is 0 or v is '.'
      $(@sel(x,y)).addClass('highlight', HIGHLIGHT_FADEIN_TIME).
        delay(HIGHLIGHT_DURATION).
        removeClass('highlight', HIGHLIGHT_FADEOUT_TIME)
      setTimeout(( =>
        $(@sel(x,y)).removeClass('highlight')
        $(@sel(x,y)).removeAttr('style') ),
        2*(HIGHLIGHT_FADEIN_TIME+HIGHLIGHT_DURATION+HIGHLIGHT_FADEOUT_TIME))


  # Adds the proper CSS classes for adjacent cell highlighting to the specified
  # JQuery selectors.
  highlight_adj: (box_sel, row_sel, col_sel) ->
    $(box_sel).addClass("adj-box")
    $(row_sel).addClass("adj-row")
    $(col_sel).addClass("adj-col")
    $(box_sel).removeAttr('style')
    $(row_sel).removeAttr('style')
    $(col_sel).removeAttr('style')

  # Removes CSS classes for adjacent cell highlighting from the specified JQuery
  # selectors.
  dehighlight_adj: (box_sel, row_sel, col_sel) ->
    $(box_sel).removeClass("adj-box")
    $(row_sel).removeClass("adj-row")
    $(col_sel).removeClass("adj-col")
    $(box_sel).removeAttr('style')
    $(row_sel).removeAttr('style')
    $(col_sel).removeAttr('style')

  # Assigns hover callbacks to the cell specified in cartesian coordinates which
  # highlight the cells in the same row, col, and box as the specified cell.
  color_adjacent: (x,y) ->
    box_s = @sel_box(x,y)
    row_s = @sel_row(x,y)
    col_s = @sel_col(x,y)
    fn1 = => @highlight_adj(box_s, row_s, col_s)
    fn2 = => @dehighlight_adj(box_s, row_s, col_s)
    $(@sel(x,y)).hover(fn1, fn2)

  # Assigns hover callbacks to the cell specified in cartesian coordinates which
  # updates the position label with the cell's coordinates.
  display_pos: (x,y) ->
    fn = ->
      $("#pos-label").html("(#{x},#{y})")
    $(@sel(x,y)).hover(fn)


  ## Other Utilities ##
  # These are mostly wrapper functions purely so that `main.coffee` doesn't ever
  # have to refer to dom elements explicitly by name.

  # Updates the display with a new strategy.
  announce_strategy: (s) ->
    $("#strat").html(s)

  # Hide the strategy display.
  hide_strat: (e) ->
    $("#strat").fadeTo(0, 0)

  # Hide the position label.
  hide_pos_label: (e) ->
    $("#pos-label").css('display', 'none')

  # Show the position label.
  show_pos_label: (e) ->
    $("#pos-label").css('display', 'block')

  # Attach hover callbacks to the grid to display the pos label when hovered and
  # hide the label when not hovered.
  grid_hide_show_pos_label: ->
    show = => @show_pos_label()
    hide = => @hide_pos_label()
    $("#grid").hover(show, hide)

  # Fill the input text box with the specified string (should be a grid
  # representation).
  fill_stdin: (s) ->
    $("#stdin").val(s)

  # Get the name of the selected puzzle from dropdown menu.
  get_selected_puzzle: ->
    puzzles[$("#puzzle-select").val()]

  # Attaches a callback to the puzzle select dropdown menu to update the input
  # textbox with the new puzzle selected.
  update_stdin_on_puzzle_select: ->
    $("#puzzle-select").change( => @fill_stdin(@get_selected_puzzle))

  # Parse the input in the input textbox and fill in the dom grid with those
  # values.
  inject_input: ->
    text = $("#stdin").val()

    rows = text.split("\n")

    for r in [0...rows.length]
      row = rows[r]
      vs = row.split('')

      for c in [0...vs.length]
        v = vs[c]
        @set_input_val(c, r, v, true)

  # Attaches a callback to the input button to inject the input text into the
  # dom grid.
  input_b_inject: ->
    $("#input-b").click( => @inject_input())

  # Attach click callback to the solve button to perform animation when clicked,
  # and then perform the specified callback. The animation will fade out the
  # solve button, and then fade in the strategy display.
  solve_b_animate: (callback) ->
    strat_options = {opacity: 1, top: '-=75px'}
    strat_animate = ->
      $("#strat").animate(strat_options, 250, 'easeInQuad', callback)
    solve_options = {opacity: 0, top: '+=50px'}
    solve_animate = (c) ->
      $("#solve-b").animate(solve_options, 250, 'easeOutQuad', strat_animate)

    $("#solve-b").click ->
      $("#solve-b, #input-b, input.num").attr('disabled', true)
      solve_animate()

  solve_done_animate: ->
    strat_options = {opacity: 0, top: '+=75px'}
    strat_animate = ->
      $("#strat").animate(strat_options, 250, 'easeOutQuad', solve_animate)
    solve_options = {opacity: 1, top: '-=50px'}
    solve_animate = ->
      $("#solve-b").animate(solve_options, 250, 'easeInQuad', enable)
    enable = ->
      $("#solve-b, #input-b, input.num").attr('disabled', false)

    strat_animate()

