class_name Kinds
extends RefCounted
## Data-driven bubble kind registry. ADD A KIND = ADD ONE ENTRY to DEFS.
## Behavior (color/points/hp/time/chain/spawn-weight) is data; systems read it
## via Kinds.of(id). The only kind that also needs an ECS marker component is
## `mine` (C_Mine) — poppability queries filter on it. Everything else is data.

const PLAIN := "plain"
const TOUGH := "tough"
const GOLD := "gold"
const CLOCK := "clock"
const CHAIN := "chain"
const MINE := "mine"

# color:       bubble fill.
# points:      score awarded on pop.
# hp:          hits needed to pop (>1 darkens on partial hit).
# time:        seconds added on pop (negative = penalty).
# chain:       popping it also pops its whole row + column.
# mine:        excluded from spread/auto/clear; gets a C_Mine marker at spawn.
# weight_base + sheet * weight_ramp = spawn odds (relative weight).
const DEFS := {
	PLAIN: {color = Color(0.22, 0.74, 0.97), points = 1, hp = 1, time = 0.0, chain = false, mine = false, weight_base = 60.0, weight_ramp = 0.0},
	TOUGH: {color = Color(0.55, 0.60, 0.70), points = 3, hp = 2, time = 0.0, chain = false, mine = false, weight_base = 12.0, weight_ramp = 2.0},
	GOLD:  {color = Color(0.98, 0.80, 0.20), points = 10, hp = 1, time = 0.0, chain = false, mine = false, weight_base = 8.0, weight_ramp = 0.0},
	CLOCK: {color = Color(0.30, 0.85, 0.55), points = 1, hp = 1, time = 2.0, chain = false, mine = false, weight_base = 6.0, weight_ramp = 0.0},
	CHAIN: {color = Color(0.78, 0.45, 0.95), points = 1, hp = 1, time = 0.0, chain = true, mine = false, weight_base = 4.0, weight_ramp = 0.0},
	MINE:  {color = Color(0.92, 0.28, 0.32), points = 1, hp = 1, time = -2.0, chain = false, mine = true, weight_base = 3.0, weight_ramp = 2.0},
}


## Kind def for an id (falls back to plain for unknown ids).
static func of(id: String) -> Dictionary:
	return DEFS.get(id, DEFS[PLAIN])


## Weighted kind pick, ramping difficulty by sheet index.
static func pick(sheet: int, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in DEFS:
		total += _weight(id, sheet)
	var roll := rng.randf() * total
	for id in DEFS:
		roll -= _weight(id, sheet)
		if roll <= 0.0:
			return id
	return PLAIN


static func _weight(id: String, sheet: int) -> float:
	var d: Dictionary = DEFS[id]
	return d.weight_base + sheet * d.weight_ramp
