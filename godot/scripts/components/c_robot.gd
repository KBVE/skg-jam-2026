class_name C_Robot
extends Component
## A deployed helper robot. Walks to the nearest bubble, jumps, and pops it, then
## seeks the next one. Count is driven by loadout.robots; RunController spawns/frees
## one entity (+ one RobotVisual on the Board) per robot. Pure data — the FSM lives
## in RobotSystem, which reads/writes `state`, `target`, and `timer`.

enum State { SEEKING, WALKING, JUMPING, COOLDOWN }

var state: int = State.SEEKING
var target: Entity = null   # bubble entity currently claimed (null when seeking)
var timer: float = 0.0      # phase clock for JUMPING / COOLDOWN
var visual: Node = null     # RobotVisual on the Board (set after add_entity; not duplicated safely)
