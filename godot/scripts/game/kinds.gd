class_name Kinds
extends RefCounted
## Data-driven bubble kind registry. ADD A KIND = ADD ONE ENTRY to DEFS.
## Behavior (color/points/hp/time/chain/spawn-weight) is data; systems read it
## via Kinds.of(id). The only kind that also needs an ECS marker component is
## `mine` (C_Mine) — poppability queries filter on it. Everything else is data.

const PLAIN := "plain"
const TOUGH := "tough"
const ARMOR := "armor"
const GOLD := "gold"
const CLOCK := "clock"
const CHAIN := "chain"
const MINE := "mine"
const BOSS2 := "boss2"   # 2x2 boss
const BOSS4 := "boss4"   # 4x4 boss (splits into boss2s on pop)

# color:       bubble fill.
# points:      score awarded on pop.
# hp:          hits needed to pop (>1 darkens on partial hit).
# time:        seconds added on pop (negative = penalty).
# chain:       popping it also pops its whole row + column.
# mine:        excluded from spread/auto/clear; gets a C_Mine marker at spawn.
# w/h:         footprint in cells (>1 = multi-cell, e.g. a 4x4 boss).
# weight_base + sheet * weight_ramp = spawn odds (relative weight).
# min_sheet:   earliest sheet a kind may spawn (optional, default 0). Bosses use it.
# split:       {kind = "..."} — on pop, fill this bubble's footprint with a grid of
#              that child kind at half hp (optional, default {}). Boss4 splits to boss2.
# rare_boost:  extra spawn weight per point of loadout.bonus_weight (optional, default 0).
#              Only put it on desirable rares so power-ups skew the roll toward them.
const DEFS := {
	PLAIN: {color = Color(0.22, 0.74, 0.97), points = 1, hp = 1, time = 0.0, chain = false, mine = false, w = 1, h = 1, weight_base = 60.0, weight_ramp = 0.0},
	TOUGH: {color = Color(0.55, 0.60, 0.70), points = 3, hp = 2, time = 0.0, chain = false, mine = false, w = 1, h = 1, weight_base = 12.0, weight_ramp = 2.0},
	ARMOR: {color = Color(0.90, 0.55, 0.25), points = 5, hp = 3, time = 0.0, chain = false, mine = false, w = 1, h = 1, weight_base = 5.0, weight_ramp = 1.5},
	GOLD:  {color = Color(0.98, 0.80, 0.20), points = 10, hp = 1, time = 0.0, chain = false, mine = false, w = 1, h = 1, weight_base = 8.0, weight_ramp = 0.0, rare_boost = 2.0},
	CLOCK: {color = Color(0.30, 0.85, 0.55), points = 1, hp = 1, time = 2.0, chain = false, mine = false, w = 1, h = 1, weight_base = 6.0, weight_ramp = 0.0, rare_boost = 0.05},
	CHAIN: {color = Color(0.78, 0.45, 0.95), points = 1, hp = 1, time = 0.0, chain = true, mine = false, w = 1, h = 1, weight_base = 4.0, weight_ramp = 0.0, rare_boost = 1.5},
	MINE:  {color = Color(0.92, 0.28, 0.32), points = 1, hp = 1, time = -2.0, chain = false, mine = true, w = 1, h = 1, weight_base = 3.0, weight_ramp = 2.0},
	# Bosses: tanky + big score + bonus time. Rare, capped per sheet (see Board.spawn_sheet).
	BOSS2: {color = Color(0.60, 0.30, 0.85), points = 40, hp = 4, time = 2.0, chain = false, mine = false, w = 2, h = 2, weight_base = 3.0, weight_ramp = 1.5, min_sheet = 2},
	BOSS4: {color = Color(0.85, 0.20, 0.35), points = 150, hp = 8, time = 4.0, chain = false, mine = false, w = 4, h = 4, weight_base = 1.0, weight_ramp = 1.0, min_sheet = 5, split = {kind = "boss2"}},
}


## Kind def for an id (falls back to plain for unknown ids).
static func of(id: String) -> Dictionary:
	return DEFS.get(id, DEFS[PLAIN])


## Weighted kind pick, ramping difficulty by sheet index.
static func pick(sheet: int, rng: RandomNumberGenerator, bonus_weight: Dictionary) -> String:
	var total := 0.0
	for id in DEFS:
		total += _weight(id, sheet, bonus_weight.get(id, 0.0))
	var roll := rng.randf() * total
	for id in DEFS:
		roll -= _weight(id, sheet, bonus_weight.get(id, 0.0))
		if roll <= 0.0:
			return id
	return PLAIN


static func _weight(id: String, sheet: int, bonus_weight: float = 0.0) -> float:
	var d: Dictionary = DEFS[id]
	# rare_boost scales the loadout bonus PER kind, so a powerup skews the roll
	# toward desirable rares instead of lifting every weight equally.
	return (d.weight_base + (sheet * d.weight_ramp)) + ((bonus_weight * d.get("rare_boost", 0.0)) * d.weight_base)
