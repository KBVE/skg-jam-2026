class_name C_RunStats
extends Component
## Run-wide counters, held on a singleton entity.

@export var score: int = 0
@export var pops: int = 0
@export var time_delta: float = 0.0   # seconds to add/remove; drained by RunController
