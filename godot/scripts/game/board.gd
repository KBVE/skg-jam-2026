class_name Board
extends Node2D
## Owns the sheet: spawns bubble entities of mixed kinds, maps clicks to cells,
## tracks which entity occupies each cell. Bubble visuals are a single MultiMesh
## (BubbleField) — each bubble is an instance slot, referenced via entity meta("slot").

var _by_cell := {}   # Vector2i(col,row) -> Entity
var _rng := RandomNumberGenerator.new()
var cols := Config.GRID_BASE_COLS   # current sheet dims, set per spawn_sheet
var rows := Config.GRID_BASE_ROWS
var _field: BubbleField = null   # one draw call for all bubble visuals


func _ready() -> void:
	_field = BubbleField.new()
	_field.name = "BubbleField"
	add_child(_field)


## World-space center of the current grid (for camera + pop-point mapping).
func grid_center() -> Vector2:
	return Vector2((cols - 1) * Config.CELL * 0.5, (rows - 1) * Config.CELL * 0.5)


## World-space footprint of the current grid (cell-to-cell span + one cell pad).
func grid_size() -> Vector2:
	return Vector2(cols * Config.CELL, rows * Config.CELL)


func clear_sheet() -> void:
	_by_cell.clear()
	# Hide every instance and reclaim all slots (also drops any still-fading pops).
	if _field:
		_field.clear()


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


## Apply one hit to a bubble: chip hp, pop at 0, else darken for feedback.
## Returns true if it popped. No-op on already-popped bubbles (so a spread that
## overlaps a multi-cell boss chips it once, not once per covered cell).
func hit(e: Entity) -> bool:
	if e == null or e.get_component(C_Popped) != null:
		return false
	var b := e.get_component(C_Bubble) as C_Bubble
	if b == null:
		return false
	b.hp -= 1
	if b.hp <= 0:
		e.add_component(C_Popped.new())
		return true
	# Partial hit: darken + update the health bar for multi-hit bubbles.
	_field.chip(e.get_meta("slot", -1), b.hp, b.max_hp)
	return false


## Atomic removal: the single exit for any bubble. Frees its cells, pops its visual
## slot (expand + fade in the shader), and removes the entity — all together, so
## occupancy, logic, and visuals can never desync (no clickable ghosts).
func despawn(e: Entity) -> void:
	var cell := e.get_component(C_Cell) as C_Cell
	if cell:
		for p in footprint_cells(Vector2i(cell.col, cell.row), cell.w, cell.h):
			_by_cell.erase(p)
	_field.pop(e.get_meta("slot", -1))
	e.set_meta("slot", -1)   # the slot is animating out — no longer this bubble's
	ECS.world.remove_entity(e)


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
	bubble.max_hp = def.hp
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

	# Same span rule the old BubbleView used: 1x1 keeps the default radius; a
	# multi-cell bubble fills its region's shortest side (with a small gap).
	var radius := Config.BUBBLE_RADIUS
	if def.w > 1 or def.h > 1:
		radius = min(def.w, def.h) * Config.CELL * 0.5 * 0.9
	var pos := region_center(origin.x, origin.y, def.w, def.h)
	var slot := _field.acquire(pos, def.color, radius, def.hp)
	e.set_meta("slot", slot)

	world.add_entity(e)
	# Register the entity under every cell it covers, so a click on any hits it.
	for p in footprint_cells(origin, def.w, def.h):
		_by_cell[p] = e
