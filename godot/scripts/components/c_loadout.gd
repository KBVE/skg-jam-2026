class_name C_Loadout
extends Component
## The run's stacked power-ups, held on a singleton entity.

@export var ricochet: int = 0   # extra nearest bubbles popped per pop
@export var area: int = 0       # pop radius in cells (Chebyshev)
@export var autoclick: int = 0  # auto-pops per second
