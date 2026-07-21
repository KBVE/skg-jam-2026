class_name ScoreSystem
extends System
## Consumes C_Popped: award score by kind, apply time effects (clock/mine),
## flood chain bubbles, emit game:pop, free the visual, remove the entity.

var stats_entity: Entity   # injected by RunController
var board: Board           # injected by RunController


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
		if cell and board:
			board.remove_cell(Vector2i(cell.col, cell.row))

		var rect = entity.get_meta("rect", null)
		if rect and is_instance_valid(rect):
			rect.queue_free()

		JsBridge.emit_event("game:pop", {"kind": kind, "points": points})
		ECS.world.remove_entity(entity)


## Tag every bubble in the chain bubble's row + column as popped.
func _flood_chain(entity: Entity) -> void:
	var cell := entity.get_component(C_Cell) as C_Cell
	if cell == null or board == null:
		return
	for other in board.cross_of(Vector2i(cell.col, cell.row)):
		if other.get_component(C_Popped) == null:
			other.add_component(C_Popped.new())
