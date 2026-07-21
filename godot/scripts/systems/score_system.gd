class_name ScoreSystem
extends System
## Consumes C_Popped: award score, emit game:pop, free the visual, remove entity.

var stats_entity: Entity   # injected by RunController
var board: Board           # injected by RunController


func query() -> QueryBuilder:
	return q.with_all([C_Popped])


func process(entities: Array[Entity], _components: Array, _delta: float) -> void:
	if entities.is_empty():
		return
	var stats := stats_entity.get_component(C_RunStats) as C_RunStats
	for entity in entities:
		stats.score += Config.SCORE_PLAIN
		stats.pops += 1

		var cell := entity.get_component(C_Cell) as C_Cell
		if cell and board:
			board.remove_cell(Vector2i(cell.col, cell.row))

		var rect = entity.get_meta("rect", null)
		if rect and is_instance_valid(rect):
			rect.queue_free()

		JsBridge.emit_event("game:pop", {"points": Config.SCORE_PLAIN})
		ECS.world.remove_entity(entity)
