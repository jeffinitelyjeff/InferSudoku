root = exports ? this

# Delay after filling in cells.
root.FILL_DELAY = 100

# Delay after finishing a strategy.
root.STRAT_DELAY = 200

# FIXME this should be removed in favor of having the loops stop once every
# strat has failed.
# Maximum number of iterations to try for solve loop.
root.max_solve_iter = 25

# Time it takes for a highlighted cell to fade in.
root.HIGHLIGHT_FADEIN_TIME = 500

# Time a highlighted cell stays fully highlighted.
root.HIGHLIGHT_DURATION = 500

# Time it takes for a highlighted cell to fade out.
root.HIGHLIGHT_FADEOUT_TIME = 500

# Will display more detailed log output for strategies if debug is enabled.
root.DEBUG = true

# Frequency with which to refresh the stderr console/textarea with the contents
# of the log buffer.
root.BUFFER_UPDATE_DELAY = 200