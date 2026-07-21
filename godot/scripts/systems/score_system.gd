class_name ScoreSystem
extends System
## Consumes C_Popped: award score by kind, apply time effects (clock/mine),
## flood chain bubbles, emit game:pop, free the visual, remove the entity.

var stats_entity: Entity     # injected by RunController
var board: Board             # injected by RunController


func query() -> QueryBuilder:
	return q.with_all([C_Popped])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := stats_entity.get_component(C_RunStats) as C_RunStats
	for entity in entities:
		var kind := str(entity.get_meta("kind", Config.K_PLAIN))

		var points := Config.SCORE_PLAIN
		if entity.get_component(C_Tough) != null:
			points = Config.SCORE_TOUGH
		elif entity.get_component(C_Gold) != null:
			points = Config.SCORE_GOLD
		stats.score += points
		stats.pops += 1

		if entity.get_component(C_Clock) != null:
			stats.time_delta += Config.CLOCK_BONUS
		if entity.get_component(C_Mine) != null:
			stats.time_delta -= Config.MINE_PENALTY
		if entity.get_component(C_Chain) != null:
			_flood_chain(entity)

		var cell := entity.get_component(C_Cell) as C_Cell
		var screen := Vector2.ZERO
		if cell and board:
			board.remove_cell(Vector2i(cell.col, cell.row))
			screen = _screen_pos(cell)

		var view = entity.get_meta("view", null)
		if view and is_instance_valid(view):
			_pop_tween(view)

		JsBridge.emit_event("game:pop", {"kind": kind, "points": points, "x": screen.x, "y": screen.y})
		ECS.world.remove_entity(entity)


## Tag every bubble in the chain bubble's row + column as popped.
func _flood_chain(entity: Entity) -> void:
	var cell := entity.get_component(C_Cell) as C_Cell
	if cell == null or board == null:
		return
	for other in board.cross_of(Vector2i(cell.col, cell.row)):
		if other.get_component(C_Popped) == null:
			other.add_component(C_Popped.new())


## Cell -> DOM/screen pixel (Godot canvas == Phaser overlay == full window).
func _screen_pos(cell: C_Cell) -> Vector2:
	var world := Vector2(cell.col * Config.CELL, cell.row * Config.CELL)
	var cam := Vector2(
		(Config.GRID_COLS - 1) * Config.CELL * 0.5,
		(Config.GRID_ROWS - 1) * Config.CELL * 0.5,
	)
	var vp := get_viewport().get_visible_rect().size
	return world - cam + vp * 0.5


## Scale-up + fade, then free the visual (Node2D scales from its center origin).
func _pop_tween(view: Node2D) -> void:
	var tw := view.create_tween()
	tw.set_parallel(true)
	tw.tween_property(view, "scale", Vector2(1.5, 1.5), 0.16)
	tw.tween_property(view, "modulate:a", 0.0, 0.16)
	tw.chain().tween_callback(view.queue_free)
