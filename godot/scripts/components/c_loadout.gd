class_name C_Loadout
extends Component
## The run's stacked power-ups, held on a singleton entity.

@export var ricochet: int = 0   # extra nearest bubbles popped per pop
@export var area: int = 0       # pop radius in cells (Chebyshev)
@export var robots: int = 0     # helper robots deployed (each walks over + pops bubbles)
@export var bonus_weight: Dictionary = {
	0: 0,
	1: 0,
	2: 0,
	3: 0,
	4: 0,
	5: 0,
	6: 0,
	7: 0,
	8: 0
}  # bumps spawn odds via Kinds._weight
