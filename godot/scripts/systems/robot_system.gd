class_name RobotSystem
extends System
## Drives every C_Robot through SEEKING -> WALKING -> JUMPING -> COOLDOWN. A robot
## picks the nearest unclaimed poppable bubble, walks to it (slow), jumps, and pops
## it like a click. Claims keep two robots from dogpiling one bubble. Only runs while
## the run is PLAYING (RunController gates ECS.process), so robots freeze on overlays.

var board: Board   # injected by RunController

# Slow + deliberate: a walk across the board dominates the ~5s per-pop cadence.
const WALK_SPEED := 44.0     # px/sec in board space
const REACH_DIST := 6.0      # px: close enough to a target to start the jump
const JUMP_TIME := 0.55      # jump anim length before the pop lands
const COOLDOWN := 0.9        # idle beat between jumps / before seeking again

var _claims := {}   # bubble Entity -> robot Entity that claimed it


func query() -> QueryBuilder:
	return q.with_all([C_Robot])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	for r in entities:
		var rob := r.get_component(C_Robot) as C_Robot
		if rob == null or rob.visual == null:
			continue
		_step(r, rob, delta)


func _step(r: Entity, rob: C_Robot, delta: float) -> void:
	var vis := rob.visual as Node2D
	match rob.state:
		C_Robot.State.SEEKING:
			var t := _pick_target(r, vis.position)
			if t == null:
				vis.call("play", "Robot_Idle")
				return
			rob.target = t
			_claims[t] = r
			rob.state = C_Robot.State.WALKING
			vis.call("play", "Robot_Walking")

		C_Robot.State.WALKING:
			if not _valid(rob.target):
				_release(rob)
				rob.state = C_Robot.State.SEEKING
				return
			var dest := board.entity_center(rob.target)
			var to := dest - vis.position
			vis.call("orient", to)
			if to.length() <= REACH_DIST:
				rob.state = C_Robot.State.JUMPING
				rob.timer = 0.0
				vis.call("play", "Robot_Jump")
			else:
				vis.position += to.normalized() * WALK_SPEED * delta

		C_Robot.State.JUMPING:
			rob.timer += delta
			if rob.timer >= JUMP_TIME:
				# Land the hit. A multi-hp bubble survives, so KEEP the claim and stand
				# on it — the same robot hammers it until it pops, no hand-off to another.
				var popped := false
				if _valid(rob.target):
					popped = board.hit(rob.target)
				if popped or not _valid(rob.target):
					_release(rob)
				rob.state = C_Robot.State.COOLDOWN
				rob.timer = 0.0
				vis.call("play", "Robot_Idle")

		C_Robot.State.COOLDOWN:
			rob.timer += delta
			if rob.timer >= COOLDOWN:
				if _valid(rob.target):
					# Still holding a live bubble (survived the last hit): jump it again.
					rob.state = C_Robot.State.JUMPING
					rob.timer = 0.0
					vis.call("play", "Robot_Jump")
				else:
					rob.state = C_Robot.State.SEEKING


## Nearest poppable bubble not claimed by another robot (mines excluded upstream).
func _pick_target(r: Entity, from: Vector2) -> Entity:
	if board == null:
		return null
	var best: Entity = null
	var best_d := INF
	for b in board.poppable_entities():
		var claimant = _claims.get(b, null)
		if claimant != null and claimant != r:
			continue
		var d: float = from.distance_squared_to(board.entity_center(b))
		if d < best_d:
			best_d = d
			best = b
	return best


func _valid(t: Entity) -> bool:
	return is_instance_valid(t) and t.has_component(C_Bubble) and not t.has_component(C_Popped)


func _release(rob: C_Robot) -> void:
	if rob.target != null:
		_claims.erase(rob.target)
		rob.target = null
