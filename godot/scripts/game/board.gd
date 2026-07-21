class_name Board
extends Node2D
## Owns the sheet: spawns bubble entities of mixed kinds, maps clicks to cells,
## tracks which entity occupies each cell. Bubble visuals (ColorRect) are
## parented to this Board (a CanvasItem) and referenced via entity meta("rect").

var _by_cell := {}   # Vector2i(col,row) -> Entity
var _rng := RandomNumberGenerator.new()


func clear_sheet() -> void:
	for e in _by_cell.values():
		var view = e.get_meta("view", null)
		if view and is_instance_valid(view):
			view.queue_free()
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


## True while any non-mine bubble remains. Mines don't block sheet completion,
## so a player can finish a sheet without eating mine penalties.
func has_poppable() -> bool:
	return not poppable_entities().is_empty()


## Remaining bubbles that aren't mines and aren't already popped (for clear
## check + auto-pop). GECS query: bubbles minus mines minus already-popped.
func poppable_entities() -> Array:
	return ECS.world.query.with_all([C_Bubble]).with_none([C_Mine, C_Popped]).execute()


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
			var id := Kinds.pick(sheet_index, _rng)
			var def := Kinds.of(id)
			var e := Entity.new()
			e.name = "Bubble_%d_%d" % [c, r]

			var bubble := C_Bubble.new()
			bubble.hp = def.hp
			e.add_component(bubble)

			var cell := C_Cell.new()
			cell.col = c
			cell.row = r
			e.add_component(cell)

			var kind := C_Kind.new()
			kind.id = id
			e.add_component(kind)

			# Mine is the one kind that needs a marker: poppable queries filter on it.
			if def.mine:
				e.add_component(C_Mine.new())

			var view := BubbleView.new()
			view.position = cell_center(c, r)
			view.color = def.color
			add_child(view)
			e.set_meta("view", view)

			world.add_entity(e)
			_by_cell[Vector2i(c, r)] = e
