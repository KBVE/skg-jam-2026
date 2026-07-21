class_name Config
extends RefCounted
## Central tuning constants for the run.

const BASE_TIME := 60.0
const TIME_PURCHASE_COST := 100
const TIME_PURCHASE_SECONDS := 60.0
const CELL := 72.0           # px between cell centers
const BUBBLE_RADIUS := 30.0

# Sheet grid grows with the run: +1 col & row every GRID_GROW_EVERY sheets,
# clamped to the caps. Base 8x6; camera zoom-to-fit keeps it on screen.
const GRID_BASE_COLS := 8
const GRID_BASE_ROWS := 6
const GRID_GROW_EVERY := 2
const GRID_MAX_COLS := 14
const GRID_MAX_ROWS := 10


static func cols_for(sheet: int) -> int:
	return mini(GRID_BASE_COLS + sheet / GRID_GROW_EVERY, GRID_MAX_COLS)


static func rows_for(sheet: int) -> int:
	return mini(GRID_BASE_ROWS + sheet / GRID_GROW_EVERY, GRID_MAX_ROWS)

# Power-up caps
const AREA_MAX := 2          # max Chebyshev pop radius (5x5); board is 8x6, so higher clears whole sheet in one click

# Pop-count bonuses
const BONUS_POINTS_EVERY := 3
const BONUS_POINTS := 10
const BONUS_TIME_EVERY := 10
const BONUS_TIME := 0.1      # +seconds

# Bubble kinds (ids, colors, points, effects, spawn weights) live in Kinds (kinds.gd).
