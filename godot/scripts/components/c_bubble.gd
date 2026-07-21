class_name C_Bubble
extends Component
## A poppable bubble. hp 1 = plain, 2-3 = tough (later milestone).

@export var hp: int = 1
@export var max_hp: int = 1   # hp at spawn; health bar + darken feedback reference it
