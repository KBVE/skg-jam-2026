class_name AutoClickSystem
extends System
## Auto-pops a random remaining bubble at a rate proportional to loadout.autoclick.

var loadout_entity: Entity   # injected by RunController
var board: Board             # injected by RunController
var _accum := 0.0


func query() -> QueryBuilder:
	return q.with_all([C_Loadout])


func process(entities: Array[Entity], _components: Array, delta: float) -> void:
	if entities.is_empty():
		return
	var lo := entities[0].get_component(C_Loadout) as C_Loadout
	if lo.autoclick <= 0:
		return
	_accum += delta
	var interval := 1.0 / float(lo.autoclick)   # autoclick=1 -> 1/s, 2 -> 2/s
	while _accum >= interval:
		_accum -= interval
		_pop_random()


func _pop_random() -> void:
	if board == null or board.is_empty():
		return
	var keys := board._by_cell.keys()
	var e: Entity = board._by_cell[keys[randi() % keys.size()]]
	if e.get_component(C_Popped) == null:
		e.add_component(C_Popped.new())
