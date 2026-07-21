extends Node2D
## Owns the run: state machine, ECS world, native click -> pop, timer, sheet
## refill, and the HUD bridge emits.

enum State { IDLE, PLAYING, SHEET_CLEAR, GAME_OVER }

var _state: int = State.IDLE
var _time_left := 0.0
var _sheet := 0
var _world: World
var _stats: Entity
var _loadout: Entity
var _score_system: ScoreSystem
var _bonus_system: BonusSystem
var _autoclick_system: AutoClickSystem
var _emit_accum := 0.0

const POOL := ["P_RICOCHET", "P_AREA", "P_AUTOCLICK"]

@onready var _camera: Camera2D = $Camera2D
@onready var _board: Board = $Board


func _ready() -> void:
	JsBridge.register_target(self)
	_camera.position = Vector2(
		(Config.GRID_COLS - 1) * Config.CELL * 0.5,
		(Config.GRID_ROWS - 1) * Config.CELL * 0.5,
	)

	# World must be in-tree before assigning ECS.world.
	_world = World.new()
	_world.name = "World"
	add_child(_world)
	ECS.world = _world

	_stats = Entity.new()
	_stats.name = "RunStats"
	_stats.add_component(C_RunStats.new())
	_world.add_entity(_stats)

	_loadout = Entity.new()
	_loadout.name = "Loadout"
	_loadout.add_component(C_Loadout.new())
	_world.add_entity(_loadout)

	_score_system = ScoreSystem.new()
	_score_system.stats_entity = _stats
	_score_system.board = _board
	_world.add_system(_score_system)

	_autoclick_system = AutoClickSystem.new()
	_autoclick_system.loadout_entity = _loadout
	_autoclick_system.board = _board
	_world.add_system(_autoclick_system)

	_bonus_system = BonusSystem.new()
	_world.add_system(_bonus_system)

	_set_state(State.IDLE)


func _set_state(s: int) -> void:
	_state = s
	JsBridge.emit_event("game:state", {"state": State.keys()[s]})


func handle_command(cmd: String, _payload: Dictionary) -> void:
	match cmd:
		"start_run", "restart":
			_start_run(_payload)
		"pick_upgrade":
			_pick_upgrade(str(_payload.get("id", "")))
		"debug_pop":
			_debug_pop(int(_payload.get("n", 1)))
		"debug_end":
			if _state == State.PLAYING or _state == State.SHEET_CLEAR:
				_end_run()


## payload = loadout from meta: { baseTime, ricochet, area, autoclick }.
func _start_run(payload: Dictionary) -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	stats.score = 0
	stats.pops = 0
	stats.time_delta = 0.0
	_bonus_system.reset()

	var lo := _loadout.get_component(C_Loadout) as C_Loadout
	lo.ricochet = int(payload.get("ricochet", 0))
	lo.area = int(payload.get("area", 0))
	lo.autoclick = int(payload.get("autoclick", 0))

	_sheet = 0
	_time_left = float(payload.get("baseTime", Config.BASE_TIME))
	_board.spawn_sheet(_world, _sheet)
	_set_state(State.PLAYING)
	_emit_score()
	_emit_time()
	_emit_loadout()


## Dev/test helper: tag N remaining bubbles as popped (ScoreSystem handles them).
func _debug_pop(n: int) -> void:
	if _state != State.PLAYING:
		return
	var popped := 0
	for cell in _board._by_cell.keys():
		if popped >= n:
			break
		var e: Entity = _board._by_cell[cell]
		if e.get_component(C_Popped) == null:
			e.add_component(C_Popped.new())
			popped += 1


func _unhandled_input(event: InputEvent) -> void:
	if _state != State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _board.cell_at(_camera.get_global_mouse_position())
		if cell.x < 0:
			return
		var e := _board.entity_at(cell)
		if e == null:
			return
		var bubble := e.get_component(C_Bubble) as C_Bubble
		bubble.hp -= 1
		if bubble.hp <= 0:
			e.add_component(C_Popped.new())
			# Power-up spread applies to player clicks only (not auto/spread pops),
			# so area/ricochet don't chain-react the whole sheet.
			_apply_spread(cell)
		else:
			# Tough bubble survived a hit — darken it for feedback.
			var rect = e.get_meta("rect", null)
			if rect and is_instance_valid(rect):
				rect.color = rect.color.darkened(0.25)


## Area (Chebyshev radius) + ricochet (N nearest) spread from a clicked cell.
func _apply_spread(cell: Vector2i) -> void:
	var lo := _loadout.get_component(C_Loadout) as C_Loadout

	if lo.area > 0:
		for dr in range(-lo.area, lo.area + 1):
			for dc in range(-lo.area, lo.area + 1):
				if dr == 0 and dc == 0:
					continue
				var n := _board.entity_at(Vector2i(cell.x + dc, cell.y + dr))
				if n != null and n.get_component(C_Popped) == null:
					n.add_component(C_Popped.new())

	if lo.ricochet > 0:
		var here := Vector2(cell.x, cell.y)
		var cands := []
		for c in _board._by_cell.keys():
			var ce: Entity = _board._by_cell[c]
			if ce.get_component(C_Popped) == null:
				cands.append([Vector2(c.x, c.y).distance_to(here), ce])
		cands.sort_custom(func(a, b): return a[0] < b[0])
		for i in min(lo.ricochet, cands.size()):
			cands[i][1].add_component(C_Popped.new())


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	ECS.process(delta)

	# Apply time gained/lost this frame (clock/mine bubbles + pop bonuses).
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	if stats.time_delta != 0.0:
		_time_left += stats.time_delta
		stats.time_delta = 0.0

	# Sheet cleared -> pause and offer 3 upgrade choices.
	if _board.is_empty():
		_enter_sheet_clear()
		return

	_time_left -= delta
	_emit_accum += delta
	if _emit_accum >= 0.1:
		_emit_accum = 0.0
		_emit_time()
		_emit_score()

	if _time_left <= 0.0:
		_end_run()


func _enter_sheet_clear() -> void:
	_set_state(State.SHEET_CLEAR)
	var choices := []
	for i in 3:
		choices.append(POOL[randi() % POOL.size()])
	JsBridge.emit_event("game:sheet_clear", {"sheet": _sheet, "choices": choices})


func _pick_upgrade(id: String) -> void:
	if _state != State.SHEET_CLEAR:
		return
	var lo := _loadout.get_component(C_Loadout) as C_Loadout
	match id:
		"P_RICOCHET": lo.ricochet += 1
		"P_AREA": lo.area += 1
		"P_AUTOCLICK": lo.autoclick += 1
	_emit_loadout()
	_sheet += 1
	_board.spawn_sheet(_world, _sheet)
	_set_state(State.PLAYING)


func _emit_loadout() -> void:
	var lo := _loadout.get_component(C_Loadout) as C_Loadout
	JsBridge.emit_event("game:loadout", {
		"ricochet": lo.ricochet,
		"area": lo.area,
		"autoclick": lo.autoclick,
	})


func _emit_score() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	JsBridge.emit_event("game:score", {"score": stats.score})


func _emit_time() -> void:
	JsBridge.emit_event("game:time", {"remaining": max(0.0, _time_left)})


func _end_run() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	_set_state(State.GAME_OVER)
	JsBridge.emit_event("game:run_over", {
		"score": stats.score,
		"currencyEarned": int(floor(stats.score / 100.0)),
	})
