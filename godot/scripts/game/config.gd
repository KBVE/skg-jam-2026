class_name Config
extends RefCounted
## Central tuning constants for the run.

const BASE_TIME := 60.0
const GRID_COLS := 8
const GRID_ROWS := 6
const CELL := 72.0           # px between cell centers
const BUBBLE_RADIUS := 30.0

# Scoring
const SCORE_PLAIN := 1
const SCORE_TOUGH := 3
const SCORE_GOLD := 10
const TOUGH_HP := 2

# Kind effects
const CLOCK_BONUS := 2.0     # +seconds
const MINE_PENALTY := 2.0    # -seconds

# Pop-count bonuses
const BONUS_POINTS_EVERY := 3
const BONUS_POINTS := 10
const BONUS_TIME_EVERY := 10
const BONUS_TIME := 0.1      # +seconds

# Kind ids
const K_PLAIN := "plain"
const K_TOUGH := "tough"
const K_GOLD := "gold"
const K_CLOCK := "clock"
const K_CHAIN := "chain"
const K_MINE := "mine"

# Colors per kind
const COLORS := {
	"plain": Color(0.22, 0.74, 0.97),
	"tough": Color(0.55, 0.60, 0.70),
	"gold": Color(0.98, 0.80, 0.20),
	"clock": Color(0.30, 0.85, 0.55),
	"chain": Color(0.78, 0.45, 0.95),
	"mine": Color(0.92, 0.28, 0.32),
}


## Weighted kind pick, ramping difficulty by sheet index.
static func pick_kind(sheet: int, rng: RandomNumberGenerator) -> String:
	var weights := {
		K_PLAIN: 60.0,
		K_TOUGH: 12.0 + sheet * 2.0,
		K_GOLD: 8.0,
		K_CLOCK: 6.0,
		K_CHAIN: 4.0,
		K_MINE: 3.0 + sheet * 2.0,
	}
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := rng.randf() * total
	for kind in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return K_PLAIN
