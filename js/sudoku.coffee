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

# Import stuff from other files.
root = exports ? this

dom = root.dom
puzzles = root.puzzles
Grid = root.Grid
Solver = root.Solver
log = root.dom.log

# Wait for the document to load; this is standard JQuery practice.
$(document).ready ->

  # Hide the strategy display initially.
  dom.hide_strat()

  log 'init webapp', true

  # Set the position label to appear when in the grid and disappear when off the
  # grid.
  dom.grid_hide_show_pos_label()

  # Put a default puzzle into the input textbox.
  dom.fill_stdin(puzzles.easy1)

  # Put a selected puzzle into the input textbox when it's selected from the
  # dropdown menu.
  dom.update_stdin_on_puzzle_select()

  # Attach callbacks to each cell for highlighting adjacent cells and updating
  # the position display.
  for j in [0..8]
    for i in [0..8]
      dom.color_adjacent(i,j)
      dom.display_pos(i,j)

  # Inject the input textbox into the grid when the input button is clicked.
  dom.input_b_inject()

  # Also, inject it intially, too.
  dom.inject_input()

  # On click, perform the solve button animation, and then create a grid object,
  # create a solver object, and then solve!
  solve = ->
    log "Creating a grid object"
    g = new Grid()

    log "Creating a solver object"
    s = new Solver(g)

    log "Solving..."
    s.solve()

  dom.solve_b_animate solve
