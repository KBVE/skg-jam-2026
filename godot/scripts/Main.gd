extends Node3D
## Main scene: a spinning cube. Emits a heartbeat to JS and accepts
## JS -> Godot commands (set_speed / set_color / pointer) via JsBridge.

var _speed := 1.0
var _frame := 0

@onready var _cube: MeshInstance3D = $Cube


func _ready() -> void:
	JsBridge.register_target(self)


func _process(delta: float) -> void:
	_cube.rotate_y(_speed * delta)
	_cube.rotate_x(_speed * 0.6 * delta)
	_frame += 1
	# ~2 Hz heartbeat (at 60 fps) so the React/Phaser HUD can mirror it.
	if _frame % 30 == 0:
		JsBridge.emit_event("godot:tick", {
			"frame": _frame,
			"rot": _cube.rotation.y,
			"speed": _speed,
		})


## Dispatched from JsBridge when JavaScript calls send(cmd, payload).
func handle_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"set_speed":
			_speed = float(payload.get("value", 1.0))
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "speed": _speed})
		"set_color":
			var hex := str(payload.get("value", "#f97316"))
			var mat: StandardMaterial3D = _cube.get_surface_override_material(0)
			if mat == null:
				mat = StandardMaterial3D.new()
				_cube.set_surface_override_material(0, mat)
			mat.albedo_color = Color(hex)
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "color": hex})
		"pointer":
			# Forwarded from the Phaser overlay; echo back for the round-trip demo.
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "x": payload.get("x"), "y": payload.get("y")})
		_:
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "unknown": true})
