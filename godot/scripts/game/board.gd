class_name Board
extends Node2D
## Owns the sheet: spawns bubble entities of mixed kinds, maps clicks to cells,
## tracks which entity occupies each cell. Bubble visuals (ColorRect) are
## parented to this Board (a CanvasItem) and referenced via entity meta("rect").

var _by_cell := {}   # Vector2i(col,row) -> Entity
var _rng := RandomNumberGenerator.new()
var cols := Config.GRID_BASE_COLS   # current sheet dims, set per spawn_sheet
var rows := Config.GRID_BASE_ROWS


## World-space center of the current grid (for camera + pop-point mapping).
func grid_center() -> Vector2:
	return Vector2((cols - 1) * Config.CELL * 0.5, (rows - 1) * Config.CELL * 0.5)


## World-space footprint of the current grid (cell-to-cell span + one cell pad).
func grid_size() -> Vector2:
	return Vector2(cols * Config.CELL, rows * Config.CELL)


func clear_sheet() -> void:
	for e in _by_cell.values():
		var view = e.get_meta("view", null)
		if view and is_instance_valid(view):
			view.queue_free()
	_by_cell.clear()


func cell_center(col: int, row: int) -> Vector2:
	return Vector2(col * Config.CELL, row * Config.CELL)


## World-space center of a w*h footprint whose top-left cell is (col,row).
func region_center(col: int, row: int, w: int, h: int) -> Vector2:
	return Vector2((col + (w - 1) * 0.5) * Config.CELL, (row + (h - 1) * 0.5) * Config.CELL)


## All cells a w*h bubble at `origin` (top-left) covers.
func footprint_cells(origin: Vector2i, w: int, h: int) -> Array:
	var out := []
	for dr in h:
		for dc in w:
			out.append(Vector2i(origin.x + dc, origin.y + dr))
	return out


func cell_at(world_pos: Vector2) -> Vector2i:
	var c := int(round(world_pos.x / Config.CELL))
	var r := int(round(world_pos.y / Config.CELL))
	if c < 0 or c >= cols or r < 0 or r >= rows:
		return Vector2i(-1, -1)
	if world_pos.distance_to(cell_center(c, r)) > Config.BUBBLE_RADIUS:
		return Vector2i(-1, -1)
	return Vector2i(c, r)


func entity_at(cell: Vector2i) -> Entity:
	return _by_cell.get(cell, null)


## Erase every cell a popped bubble covered (1 for most, w*h for a boss).
func remove_cell(cell: C_Cell) -> void:
	for p in footprint_cells(Vector2i(cell.col, cell.row), cell.w, cell.h):
		_by_cell.erase(p)


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
	cols = Config.cols_for(sheet_index)
	rows = Config.rows_for(sheet_index)
	for r in rows:
		for c in cols:
			var origin := Vector2i(c, r)
			# Skip cells already covered by a larger bubble placed earlier.
			if _by_cell.has(origin):
				continue
			var id := Kinds.pick(sheet_index, _rng)
			var def := Kinds.of(id)
			# Multi-cell bubbles need room; fall back to plain if they don't fit.
			if (def.w > 1 or def.h > 1) and not _fits(origin, def.w, def.h):
				id = Kinds.PLAIN
				def = Kinds.of(id)
			_spawn_bubble(world, origin, id, def)


## True if a w*h bubble at `origin` stays in bounds and covers only free cells.
func _fits(origin: Vector2i, w: int, h: int) -> bool:
	if origin.x + w > cols or origin.y + h > rows:
		return false
	for p in footprint_cells(origin, w, h):
		if _by_cell.has(p):
			return false
	return true


func _spawn_bubble(world: World, origin: Vector2i, id: String, def: Dictionary) -> void:
	var e := Entity.new()
	e.name = "Bubble_%d_%d" % [origin.x, origin.y]

	var bubble := C_Bubble.new()
	bubble.hp = def.hp
	e.add_component(bubble)

	var cell := C_Cell.new()
	cell.col = origin.x
	cell.row = origin.y
	cell.w = def.w
	cell.h = def.h
	e.add_component(cell)

	var kind := C_Kind.new()
	kind.id = id
	e.add_component(kind)

	# Mine is the one kind that needs a marker: poppable queries filter on it.
	if def.mine:
		e.add_component(C_Mine.new())

	var view := BubbleView.new()
	view.position = region_center(origin.x, origin.y, def.w, def.h)
	view.color = def.color
	view.set_span(def.w, def.h)
	add_child(view)
	e.set_meta("view", view)

	world.add_entity(e)
	# Register the entity under every cell it covers, so a click on any hits it.
	for p in footprint_cells(origin, def.w, def.h):
		_by_cell[p] = e
