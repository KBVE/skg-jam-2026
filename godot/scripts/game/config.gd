class_name Config
extends RefCounted
## Central tuning constants for the run.

const BASE_TIME := 60.0
const GRID_COLS := 8
const GRID_ROWS := 6
const CELL := 72.0           # px between cell centers
const BUBBLE_RADIUS := 30.0

# Power-up caps
const AREA_MAX := 2          # max Chebyshev pop radius (5x5); board is 8x6, so higher clears whole sheet in one click

# Pop-count bonuses
const BONUS_POINTS_EVERY := 3
const BONUS_POINTS := 10
const BONUS_TIME_EVERY := 10
const BONUS_TIME := 0.1      # +seconds

# Bubble kinds (ids, colors, points, effects, spawn weights) live in Kinds (kinds.gd).
