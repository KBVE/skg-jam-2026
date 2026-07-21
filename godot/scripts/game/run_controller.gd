extends Node2D
## Owns the run: state machine, ECS world, native click -> pop, timer, sheet
## refill, and the HUD bridge emits.

enum State { IDLE, PLAYING, SHEET_CLEAR, GAME_OVER }

var _state: int = State.IDLE
var _time_left := 0.0
var _sheet := 0
var _world: World
var _stats: Entity
var _score_system: ScoreSystem
var _emit_accum := 0.0

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

	_score_system = ScoreSystem.new()
	_score_system.stats_entity = _stats
	_score_system.board = _board
	_world.add_system(_score_system)

	_set_state(State.IDLE)


func _set_state(s: int) -> void:
	_state = s
	JsBridge.emit_event("game:state", {"state": State.keys()[s]})


func handle_command(cmd: String, _payload: Dictionary) -> void:
	match cmd:
		"start_run", "restart":
			_start_run()


func _start_run() -> void:
	var stats := _stats.get_component(C_RunStats) as C_RunStats
	stats.score = 0
	stats.pops = 0
	_sheet = 0
	_time_left = Config.BASE_TIME
	_board.spawn_sheet(_world, _sheet)
	_set_state(State.PLAYING)
	_emit_score()
	_emit_time()


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


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	ECS.process(delta)

	# Sheet cleared -> refill (upgrade cards arrive in M3).
	if _board.is_empty():
		_sheet += 1
		_board.spawn_sheet(_world, _sheet)

	_time_left -= delta
	_emit_accum += delta
	if _emit_accum >= 0.1:
		_emit_accum = 0.0
		_emit_time()
		_emit_score()

	if _time_left <= 0.0:
		_end_run()


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
