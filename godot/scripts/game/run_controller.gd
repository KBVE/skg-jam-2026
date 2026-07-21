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
var _clear_delay := 0.0   # counts up once the board is empty, before the overlay shows
var _pending_choices: Array = []   # upgrades offered this sheet-clear (editor 1/2/3 picks)

const SHEET_CLEAR_DELAY := 0.2   # let pop animations (0.16s) finish before overlay
const POOL := ["P_RICOCHET", "P_AREA", "P_AUTOCLICK"]

@onready var _camera: Camera2D = $Camera2D
@onready var _board: Board = $Board
@onready var _hand: HandOverlay = $HandOverlay


func _ready() -> void:
	JsBridge.register_target(self)

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
	_score_system.camera = _camera
	_world.add_system(_score_system)

	_autoclick_system = AutoClickSystem.new()
	_autoclick_system.loadout_entity = _loadout
	_autoclick_system.board = _board
	_world.add_system(_autoclick_system)

	_bonus_system = BonusSystem.new()
	_world.add_system(_bonus_system)

	# Single Godot->JS forwarding point: mirrors whitelisted GECS events to the shell.
	_world.add_observer(JsBridgeObserver.new())

	_set_state(State.IDLE)

	# On the web the React shell sends "start_run" once the player begins. In the
	# editor (or any non-web run) there is no shell, so auto-start to make the
	# game playable standalone.
	if not OS.has_feature("web"):
		_start_run({})


## Center + zoom the camera so the whole current grid fits the viewport, never
## zooming in past 1:1 (small grids render at base size, like the original 8x6).
func _fit_camera() -> void:
	# Guarantee this camera drives the viewport, so get_global_mouse_position()
	# (click -> cell mapping) uses its center+zoom transform, not a fallback.
	_camera.make_current()
	_camera.position = _board.grid_center()
	var gsize := _board.grid_size()
	var vp := get_viewport().get_visible_rect().size
	var fit: float = min(vp.x / gsize.x, vp.y / gsize.y) * 0.92   # 0.92 = edge padding
	var z: float = min(1.0, fit)
	_camera.zoom = Vector2(z, z)


func _set_state(s: int) -> void:
	_state = s
	ECS.world.emit_event(GameEvents.STATE_CHANGED, null, {"state": State.keys()[s]})


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
	_fit_camera()
	_set_state(State.PLAYING)
	_emit_score()
	_emit_time()
	_emit_loadout()


## Dev/test helper: tag N remaining non-mine bubbles as popped.
func _debug_pop(n: int) -> void:
	if _state != State.PLAYING:
		return
	var popped := 0
	for e in _board.poppable_entities():
		if popped >= n:
			break
		e.add_component(C_Popped.new())
		popped += 1


func _unhandled_input(event: InputEvent) -> void:
	# Editor/standalone meta-command keys. On web the React shell sends these same
	# commands, so keys are gated to non-web; both paths funnel through
	# handle_command — one inbound entry for JS and native input alike.
	if not OS.has_feature("web") and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if _state == State.GAME_OVER:
					handle_command("restart", {})
					return
			KEY_1, KEY_2, KEY_3:
				if _state == State.SHEET_CLEAR:
					var idx: int = event.keycode - KEY_1
					if idx < _pending_choices.size():
						handle_command("pick_upgrade", {"id": _pending_choices[idx]})
					return
			KEY_P:
				handle_command("debug_pop", {"n": 1})
				return
			KEY_E:
				handle_command("debug_end", {})
				return

	# Gameplay click: native on every platform (the canvas owns the mouse; JS never
	# sends clicks). Pops the bubble under the cursor.
	if _state != State.PLAYING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _board.cell_at(_camera.get_global_mouse_position())
		if cell.x < 0:
			return
		var e := _board.entity_at(cell)
		# hit() chips hp (darkens survivors, pops at 0). Spread only when the
		# clicked bubble actually pops, so area/ricochet don't fire on a chip.
		if _board.hit(e):
			_hand.poke()
			_apply_spread(cell)


## Area (Chebyshev radius) + ricochet (N nearest) spread from a clicked cell.
## Each spread chips hp once per bug (dedup by entity), so a multi-cell boss
## takes one hit per blast, not one per covered cell.
func _apply_spread(cell: Vector2i) -> void:
	var lo := _loadout.get_component(C_Loadout) as C_Loadout

	if lo.area > 0:
		var targets := {}   # entity -> true (dedup; a boss covers many cells)
		for dr in range(-lo.area, lo.area + 1):
			for dc in range(-lo.area, lo.area + 1):
				if dr == 0 and dc == 0:
					continue
				var n := _board.entity_at(Vector2i(cell.x + dc, cell.y + dr))
				# Never spread onto mines — draining the timer is player-click-only.
				if n != null and n.get_component(C_Mine) == null:
					targets[n] = true
		for n in targets:
			_board.hit(n)

	if lo.ricochet > 0:
		var here := Vector2(cell.x, cell.y)
		var nearest := {}   # entity -> min distance across its cells
		for c in _board._by_cell.keys():
			var ce: Entity = _board._by_cell[c]
			if ce.get_component(C_Mine) != null or ce.get_component(C_Popped) != null:
				continue
			var d: float = Vector2(c.x, c.y).distance_to(here)
			if not nearest.has(ce) or d < nearest[ce]:
				nearest[ce] = d
		var cands := []
		for ce in nearest:
			cands.append([nearest[ce], ce])
		cands.sort_custom(func(a, b): return a[0] < b[0])
		for i in min(lo.ricochet, cands.size()):
			_board.hit(cands[i][1])


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	ECS.process(delta)

	# Apply time gained/lost this frame (clock/mine bubbles + pop bonuses).
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	if stats.time_delta != 0.0:
		_time_left += stats.time_delta
		stats.time_delta = 0.0

	# Sheet cleared once no non-mine bubbles remain (leftover mines are dropped
	# on the next spawn, so the player can finish without eating penalties).
	# Hold briefly so pop animations finish before the overlay covers the board.
	if not _board.has_poppable():
		_clear_delay += delta
		if _clear_delay >= SHEET_CLEAR_DELAY:
			_enter_sheet_clear()
		return
	_clear_delay = 0.0

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
	_pending_choices = choices   # so editor 1/2/3 picks the same offered upgrades
	ECS.world.emit_event(GameEvents.SHEET_CLEAR, null, {"sheet": _sheet, "choices": choices})


func _pick_upgrade(id: String) -> void:
	if _state != State.SHEET_CLEAR:
		return
	var lo := _loadout.get_component(C_Loadout) as C_Loadout
	match id:
		"P_RICOCHET": lo.ricochet += 1
		"P_AREA": lo.area = min(lo.area + 1, Config.AREA_MAX)
		"P_AUTOCLICK": lo.autoclick += 1
	_emit_loadout()
	_sheet += 1
	_board.spawn_sheet(_world, _sheet)
	_fit_camera()
	_set_state(State.PLAYING)


func _emit_loadout() -> void:
	var lo := _loadout.get_component(C_Loadout) as C_Loadout
	ECS.world.emit_event(GameEvents.UPGRADE_PICKED, null, {
		"ricochet": lo.ricochet,
		"area": lo.area,
		"autoclick": lo.autoclick,
	})


func _emit_score() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	ECS.world.emit_event(GameEvents.SCORE_CHANGED, null, {"score": stats.score})


func _emit_time() -> void:
	ECS.world.emit_event(GameEvents.TIME_CHANGED, null, {"remaining": max(0.0, _time_left)})


func _end_run() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	_set_state(State.GAME_OVER)
	ECS.world.emit_event(GameEvents.RUN_OVER, null, {
		"score": stats.score,
		"currencyEarned": int(floor(stats.score / 100.0)),
	})
