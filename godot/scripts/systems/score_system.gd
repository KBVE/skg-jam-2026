class_name ScoreSystem
extends System
## Consumes C_Popped: award score by kind, apply time effects (clock/mine),
## flood chain bubbles, emit the POP event, then despawn each bubble through a
## CommandBuffer so all removals resolve at one safe point after the drain loop
## (no mid-iteration structural mutation of the set being processed).

var stats_entity: Entity     # injected by RunController
var board: Board             # injected by RunController
var camera: Camera2D         # injected by RunController (for pop-point mapping)


func query() -> QueryBuilder:
	return q.with_all([C_Popped])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := stats_entity.get_component(C_RunStats) as C_RunStats
	# Queue every removal; flush once after the loop so despawns don't mutate the
	# snapshot mid-iteration and all resolve in a defined order.
	var cb := CommandBuffer.new(ECS.world)
	var splits: Array = []   # [{cell: C_Cell, split: Dictionary}] — spawned after flush
	for entity in entities:
		var kc := entity.get_component(C_Kind) as C_Kind
		var kind := kc.id if kc else Kinds.PLAIN
		var def := Kinds.of(kind)

		var points: int = def.points
		stats.score += points
		stats.pops += 1

		stats.time_delta += def.time
		if def.chain:
			_flood_chain(entity)

		var cell := entity.get_component(C_Cell) as C_Cell
		var screen := _screen_pos(cell) if cell else Vector2.ZERO

		ECS.world.emit_event(GameEvents.POP, entity, {"kind": kind, "points": points, "x": screen.x, "y": screen.y})

		# Bosses that split: record the footprint now, spawn children after the flush
		# frees these cells (so the children have room).
		var split: Dictionary = def.get("split", {})
		if cell and not split.is_empty():
			splits.append({"col": cell.col, "row": cell.row, "w": cell.w, "h": cell.h, "split": split})

		# Single atomic exit (frees cells, animates the view, removes the entity),
		# deferred to the flush below.
		if board:
			cb.add_custom(board.despawn.bind(entity))
		else:
			cb.remove_entity(entity)
	cb.execute()   # despawns run here; footprint cells are now free
	for req in splits:
		_spawn_split(req)


## Fill a popped boss's footprint with a grid of its split child kind, at half hp
## (min 1) so a mega-boss isn't an endless wall.
func _spawn_split(req: Dictionary) -> void:
	if board == null:
		return
	var child_id: String = req.split.get("kind", Kinds.PLAIN)
	var cdef := Kinds.of(child_id)
	var cw: int = int(cdef.w)
	var ch: int = int(cdef.h)
	var child_hp: int = maxi(1, int(ceil(float(cdef.hp) / 2.0)))
	var dy := 0
	while dy < req.h:
		var dx := 0
		while dx < req.w:
			board.spawn_bubble_at(ECS.world, Vector2i(req.col + dx, req.row + dy), child_id, child_hp)
			dx += cw
		dy += ch


## Tag every bubble in the chain bubble's row + column as popped.
func _flood_chain(entity: Entity) -> void:
	var cell := entity.get_component(C_Cell) as C_Cell
	if cell == null or board == null:
		return
	ECS.world.emit_event(GameEvents.CHAIN, entity, {"origin_cell": Vector2i(cell.col, cell.row)})
	var seen := {}   # dedup: a multi-cell boss appears under several row/col cells
	for other in board.cross_of(Vector2i(cell.col, cell.row)):
		if not seen.has(other):
			seen[other] = true
			board.hit(other)   # chip hp (multi-hit bugs survive a single flood)


## Cell -> DOM/screen pixel (Godot canvas == Phaser overlay == full window).
## Applies the camera transform (center + zoom-to-fit) so overlay points track
## the grid at any sheet size.
func _screen_pos(cell: C_Cell) -> Vector2:
	# Anchor at the bubble's region center so a boss's pop FX/score float from its
	# middle, not its top-left cell.
	var world := board.region_center(cell.col, cell.row, cell.w, cell.h) if board \
		else Vector2(cell.col * Config.CELL, cell.row * Config.CELL)
	var vp := get_viewport().get_visible_rect().size
	var zoom := camera.zoom if camera else Vector2.ONE
	var cam := camera.position if camera else Vector2.ZERO
	return (world - cam) * zoom + vp * 0.5
