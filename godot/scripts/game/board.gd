class_name Board
extends Node2D
## Owns the sheet: spawns bubble entities of mixed kinds, maps clicks to cells,
## tracks which entity occupies each cell. Bubble visuals (ColorRect) are
## parented to this Board (a CanvasItem) and referenced via entity meta("rect").

var _by_cell := {}   # Vector2i(col,row) -> Entity
var _rng := RandomNumberGenerator.new()


func clear_sheet() -> void:
	for e in _by_cell.values():
		var rect = e.get_meta("rect", null)
		if rect and is_instance_valid(rect):
			rect.queue_free()
	_by_cell.clear()


func cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * Config.CELL, row * Config.CELL)


func cell_at(world_pos: Vector2) -> Vector2i:
	var c := int(round(world_pos.x / Config.CELL))
	var r := int(round(world_pos.y / Config.CELL))
	if c < 0 or c >= Config.GRID_COLS or r < 0 or r >= Config.GRID_ROWS:
		return Vector2i(-1, -1)
	if world_pos.distance_to(cell_center(c, r)) > Config.BUBBLE_RADIUS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


func entity_at(cell: Vector2i) -> Entity:
	return _by_cell.get(cell, null)


func remove_cell(cell: Vector2i) -> void:
	_by_cell.erase(cell)


func is_empty() -> bool:
	return _by_cell.is_empty()


## Every present entity in the same row or column as `cell` (excluding it).
func cross_of(cell: Vector2i) -> Array:
	var out := []
	for other in _by_cell.keys():
		if other == cell:
			continue
		if other.x == cell.x or other.y == cell.y:
			out.append(_by_cell[other])
	return out


func spawn_sheet(world: World, sheet_index: int) -> void:
	clear_sheet()
	for r in Config.GRID_ROWS:
		for c in Config.GRID_COLS:
			var kind := Config.pick_kind(sheet_index, _rng)
			var e := Entity.new()
			e.name = "Bubble_%d_%d" % [c, r]

			var bubble := C_Bubble.new()
			bubble.hp = Config.TOUGH_HP if kind == Config.K_TOUGH else 1
			e.add_component(bubble)

			var cell := C_Cell.new()
			cell.col = c
			cell.row = r
			e.add_component(cell)

			match kind:
				Config.K_TOUGH: e.add_component(C_Tough.new())
				Config.K_GOLD: e.add_component(C_Gold.new())
				Config.K_CLOCK: e.add_component(C_Clock.new())
				Config.K_CHAIN: e.add_component(C_Chain.new())
				Config.K_MINE: e.add_component(C_Mine.new())

			var rect := ColorRect.new()
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.color = Config.COLORS[kind]
			rect.size = Vector2(Config.BUBBLE_RADIUS * 2.0, Config.BUBBLE_RADIUS * 2.0)
			rect.position = cell_center(c, r) - Vector2(Config.BUBBLE_RADIUS, Config.BUBBLE_RADIUS)
			add_child(rect)
			e.set_meta("rect", rect)
			e.set_meta("kind", kind)

			world.add_entity(e)
			_by_cell[Vector2i(c, r)] = e
