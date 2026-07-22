class_name RobotVisual
extends Node2D
## 2D-space avatar for a helper robot: a 3D Quaternius robot rendered in a private
## SubViewport and blitted onto the flat board via a Sprite2D. Lives as a child of
## Board, so its `position` is in bubble/cell coordinates. RobotSystem moves it and
## calls play() to switch clips (Robot_Idle / Robot_Walking / Robot_Jump).

const MODEL := preload("res://assets/models/robot.glb")
const VIEW_SIZE := 192           # SubViewport render resolution (square)
const SPRITE_SCALE := 0.50       # texture px -> board px (robot ~1 cell tall)

const TURN_SPEED := 4.0           # rad/sec the model eases toward its heading (lower = softer turns)

var _anim: AnimationPlayer
var _current := ""
var _model: Node3D               # the 3D robot; yawed to face board movement
var _target_yaw := 0.0           # heading it turns toward (radians)

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = false
	# Each robot gets its OWN 3D world; otherwise all SubViewports share one World3D
	# and every camera renders every robot's model (N robots -> N overlaid copies each).
	vp.own_world_3d = true
	add_child(vp)

	var root := Node3D.new()
	vp.add_child(root)

	_model = MODEL.instantiate()
	root.add_child(_model)
	_anim = _find_anim(_model)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	light.light_energy = 1.4
	root.add_child(light)

	# Framing tuned by offscreen render (skinned bind-pose AABB is unreliable): look at
	# the robot's true mid-body (y=1.7) from z=10.5 to fit the whole body with margin.
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.7, 10.5)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.7, 0.0), Vector3.UP)
	cam.fov = 32.0
	root.add_child(cam)

	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture = vp.get_texture()
	spr.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	# Feet sit on the target cell: nudge the sprite up so the feet (near the texture
	# bottom) land on the robot's board position instead of its mid-body.
	spr.offset = Vector2(0, -VIEW_SIZE * 0.38)
	add_child(spr)
	_sprite = spr

	play("Robot_Idle")


func _process(delta: float) -> void:
	# Smoothly rotate the 3D model toward its heading so it turns instead of moonwalking.
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, minf(1.0, TURN_SPEED * delta))


## Switch clip (no-op if already playing it). Looping clips loop; Jump plays once.
func play(clip: String) -> void:
	if _anim == null or clip == _current:
		return
	if not _anim.has_animation(clip):
		return
	_current = clip
	var a := _anim.get_animation(clip)
	if a and clip != "Robot_Jump":
		a.loop_mode = Animation.LOOP_LINEAR
	_anim.play(clip)


## Turn the robot to face its board-movement direction. The model's front is +Z
## (toward the camera), so on-screen: down = toward camera, right = +X. Mapping the
## board delta to yaw = atan2(dx, dy) makes it walk right/left/up/down facing forward.
func orient(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	_target_yaw = atan2(dir.x, dir.y)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
