extends Node3D
## Main scene, now driven by GECS (Entity Component System).
##
## Builds a World with one SpinSystem and one cube Entity (C_Spin + a Mesh
## child). The JS bridge heartbeat + commands mutate ECS data:
##   set_speed -> C_Spin.speed        set_color -> mesh material albedo

var _world: World
var _entity: Entity
var _mat: StandardMaterial3D
var _frame := 0


func _ready() -> void:
	JsBridge.register_target(self)

	# World must be in-tree before assigning ECS.world (its setter otherwise
	# tries to auto-parent under a node named "Root").
	_world = World.new()
	_world.name = "World"
	add_child(_world)
	ECS.world = _world
	_world.add_system(SpinSystem.new())

	# Cube entity: C_Spin component + a MeshInstance3D child named "Mesh".
	_entity = Entity.new()
	_entity.name = "CubeEntity"
	_entity.add_component(C_Spin.new())

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.976, 0.451, 0.086)
	mesh.material_override = _mat
	_entity.add_child(mesh)

	_world.add_entity(_entity)


func _process(delta: float) -> void:
	ECS.process(delta)

	_frame += 1
	if _frame % 30 == 0:
		var spin := _entity.get_component(C_Spin) as C_Spin
		JsBridge.emit_event("godot:tick", {
			"frame": _frame,
			"speed": spin.speed if spin else 0.0,
			"entities": _world.entities.size() if _world else 0,
		})


## Dispatched from JsBridge when JavaScript calls send(cmd, payload).
func handle_command(cmd: String, payload: Dictionary) -> void:
	match cmd:
		"set_speed":
			var spin := _entity.get_component(C_Spin) as C_Spin
			if spin:
				spin.speed = float(payload.get("value", 1.0))
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "speed": spin.speed if spin else 0.0})
		"set_color":
			var hex := str(payload.get("value", "#f97316"))
			_mat.albedo_color = Color(hex)
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "color": hex})
		"pointer":
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "x": payload.get("x"), "y": payload.get("y")})
		_:
			JsBridge.emit_event("godot:ack", {"cmd": cmd, "unknown": true})
