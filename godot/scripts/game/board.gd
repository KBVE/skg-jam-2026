class_name Board
extends Node2D
## Owns the sheet: spawns bubble entities, maps clicks to cells, tracks
## which entity occupies each cell. Bubble visuals (ColorRect) are parented
## to this Board (a CanvasItem) and referenced from the entity via meta("rect").

var _by_cell := {}   # Vector2i(col,row) -> Entity


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


func spawn_sheet(world: World, _sheet_index: int) -> void:
	clear_sheet()
	for r in Config.GRID_ROWS:
		for c in Config.GRID_COLS:
			var e := Entity.new()
			e.name = "Bubble_%d_%d" % [c, r]
			e.add_component(C_Bubble.new())
			var cell := C_Cell.new()
			cell.col = c
			cell.row = r
			e.add_component(cell)

			var rect := ColorRect.new()
			# Let clicks fall through to RunController._unhandled_input (Controls
			# default to MOUSE_FILTER_STOP, which would eat the pop click).
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.color = Color(0.22, 0.74, 0.97)
			rect.size = Vector2(Config.BUBBLE_RADIUS * 2.0, Config.BUBBLE_RADIUS * 2.0)
			rect.position = cell_center(c, r) - Vector2(Config.BUBBLE_RADIUS, Config.BUBBLE_RADIUS)
			add_child(rect)
			e.set_meta("rect", rect)

			world.add_entity(e)
			_by_cell[Vector2i(c, r)] = e
