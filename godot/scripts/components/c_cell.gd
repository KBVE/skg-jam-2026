class_name C_Cell
extends Component
## Grid footprint of a bubble. (col,row) is the top-left origin; w,h is the span
## in cells. Most bubbles are 1x1; a boss can occupy e.g. 4x4. The board maps
## every covered cell to the same entity, so a click on any of them hits it.

@export var col: int = 0
@export var row: int = 0
@export var w: int = 1
@export var h: int = 1
