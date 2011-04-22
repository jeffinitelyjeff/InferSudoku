# Export settings to the window object for reference in other files.
root = exports ? this

# Delay after filling in cells.
root.FILL_DELAY = 50

# Delay after finishing a strategy.
root.STRAT_DELAY = 100

# FIXME this should be removed in favor of having the loops stop once every
# strat has failed.
# Maximum number of iterations to try for solve loop.
root.max_solve_iter = 10

