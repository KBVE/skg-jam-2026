class_name ScoreSystem
extends System
## Consumes C_Popped: award score by kind, apply time effects (clock/mine),
## flood chain bubbles, emit game:pop, free the visual, remove the entity.

var stats_entity: Entity     # injected by RunController
var board: Board             # injected by RunController
var camera: Camera2D         # injected by RunController (for pop-point mapping)


func query() -> QueryBuilder:
	return q.with_all([C_Popped])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := stats_entity.get_component(C_RunStats) as C_RunStats
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

		JsBridge.emit_event("game:pop", {"kind": kind, "points": points, "x": screen.x, "y": screen.y})

		# Single atomic exit: frees cells, animates the view, removes the entity.
		if board:
			board.despawn(entity)
		else:
			ECS.world.remove_entity(entity)


## Tag every bubble in the chain bubble's row + column as popped.
func _flood_chain(entity: Entity) -> void:
	var cell := entity.get_component(C_Cell) as C_Cell
	if cell == null or board == null:
		return
	var seen := {}   # dedup: a multi-cell boss appears under several row/col cells
	for other in board.cross_of(Vector2i(cell.col, cell.row)):
		if not seen.has(other):
			seen[other] = true
			board.hit(other)   # chip hp (multi-hit bugs survive a single flood)


## Cell -> DOM/screen pixel (Godot canvas == Phaser overlay == full window).
## Applies the camera transform (center + zoom-to-fit) so overlay points track
## the grid at any sheet size.
func _screen_pos(cell: C_Cell) -> Vector2:
	var world := Vector2(cell.col * Config.CELL, cell.row * Config.CELL)
	var vp := get_viewport().get_visible_rect().size
	var zoom := camera.zoom if camera else Vector2.ONE
	var cam := camera.position if camera else Vector2.ZERO
	return (world - cam) * zoom + vp * 0.5
