class_name HandOverlay
extends CanvasLayer
## A 3D hand (WRAD ARMS, CC0) composited over the 2D board via a transparent
## SubViewport. The model is anchored (shoulders stay put); each arm is driven by
## SkeletonIK3D toward a target node. The arm on the cursor's half of the screen
## reaches to the cursor; the other springs home. Popping a bubble jabs forward.
##
## Clicks pass straight through (SubViewportContainer mouse-filter = IGNORE).
##
## All @export fields apply every frame, so you can play the scene in the editor,
## drag these in the remote inspector, and see the hand update live — then bake
## the numbers you like back into the defaults.

const ARM_SCENE := preload("res://assets/models/arms.glb")

@export_group("Camera")
@export var cam_z := 8.0
@export var cam_fov := 68.0
@export_group("Arm placement")
@export var arm_pos := Vector3(0.0, -3.6, 1.0)
@export var arm_rot := Vector3(-30.0, 0.0, 0.0)
@export var arm_scale := 0.6
## Horizontal stretch: both shoulders sit at the origin, so the arms only splay
## apart toward the wrists (±X). >1 widens that spread (arms further apart);
## 1.0 = no change. Mild values keep distortion low.
@export var spread_x := 1.0
@export_group("Motion")
## Distance from the camera to the plane the hand reaches on. The cursor is
## projected onto this plane, so the hand lands under the cursor (corners too) —
## as long as the arm is long enough to reach (raise arm_scale if it can't).
@export var target_depth := 6.0
@export var poke_depth := 0.8   # forward jab distance (toward camera)
@export var follow_speed := 12.0
@export var poke_time := 0.16   # jab duration; matches the bubble pop animation

var _sub: SubViewport
var _arm: Node3D
var _cam: Camera3D
var _skel: Skeleton3D
var _iks: Array[SkeletonIK3D] = []   # one per arm (right, left)
var _targets: Array[Marker3D] = []   # world-space IK target node per arm
var _rest_local: Array[Vector3] = [] # each wrist's rest pos in skeleton space
var _sides: Array[float] = []        # +1 = right-hand arm, -1 = left-hand arm
var _pos: Array[Vector3] = []        # per-arm smoothed world target position
var _poke := 0.0                     # 1 -> 0 over one jab


func _ready() -> void:
	layer = 10   # above the 2D board + FX

	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let clicks reach the board
	add_child(cont)

	_sub = SubViewport.new()
	_sub.transparent_bg = true
	_sub.own_world_3d = true
	_sub.size = get_viewport().get_visible_rect().size
	cont.add_child(_sub)

	_cam = Camera3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	_cam.environment = env
	_sub.add_child(_cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	_sub.add_child(light)

	_arm = ARM_SCENE.instantiate()
	_sub.add_child(_arm)
	_apply_transform()   # position/rotate/scale before reading rest poses

	_setup_ik()


## Right + left arm IK, each with a world-space target marker.
func _setup_ik() -> void:
	_skel = _arm.get_node("arms/Skeleton3D") as Skeleton3D
	if _skel == null:
		return
	# magnet = elbow pole hint (mirror x for the left). side = screen half.
	_add_ik("bicep.r", "wrist.r", Vector3(1.0, -1.0, 2.0), 1.0)
	_add_ik("bicep.l", "wrist.l", Vector3(-1.0, -1.0, 2.0), -1.0)


func _add_ik(root: String, tip: String, magnet: Vector3, side: float) -> void:
	var wrist := _skel.find_bone(tip)
	if wrist == -1:
		return
	# Wrist rest position in skeleton space (constant; the world pos is derived
	# each frame from the skeleton transform so it follows live placement/scale).
	_rest_local.append(_skel.get_bone_global_pose(wrist).origin)

	var marker := Marker3D.new()
	_sub.add_child(marker)

	var ik := SkeletonIK3D.new()
	ik.root_bone = root
	ik.tip_bone = tip
	ik.use_magnet = true
	ik.magnet = magnet
	ik.interpolation = 1.0
	_skel.add_child(ik)
	ik.target_node = ik.get_path_to(marker)
	ik.start()

	_iks.append(ik)
	_targets.append(marker)
	_sides.append(side)
	_pos.append(_skel.global_transform * _rest_local[_rest_local.size() - 1])


func _apply_transform() -> void:
	_cam.position = Vector3(0.0, 0.0, cam_z)
	_cam.fov = cam_fov
	_arm.position = arm_pos
	_arm.rotation_degrees = arm_rot
	# Non-uniform X = widen the arm spread without changing hand size much.
	_arm.scale = Vector3(arm_scale * spread_x, arm_scale, arm_scale)


func _process(delta: float) -> void:
	if _iks.is_empty():
		return

	_apply_transform()   # live @export tuning

	# Keep the render target matched to the window.
	var vp := get_viewport().get_visible_rect().size
	if _sub.size != Vector2i(vp):
		_sub.size = vp

	# Cursor in viewport pixels + which screen half it's on.
	var m := get_viewport().get_mouse_position()
	var nx := (m.x / vp.x) * 2.0 - 1.0

	# Poke: decay + sin() = one forward pulse (pulls the reach plane toward camera).
	_poke = maxf(0.0, _poke - delta / poke_time)
	var jab := sin(_poke * PI) * poke_depth

	var k := minf(1.0, delta * follow_speed)

	# Each arm answers only its own half: cursor left -> left arm reaches to the
	# cursor, cursor right -> right arm. Active arm targets the cursor projected
	# onto the reach plane (full-screen swing); idle arm springs home to rest.
	for i in _iks.size():
		var active := signf(nx) == _sides[i]
		var goal: Vector3
		if active:
			goal = _cam.project_position(m, maxf(0.5, target_depth - jab))
		else:
			goal = _skel.global_transform * _rest_local[i]
		_pos[i] = _pos[i].lerp(goal, k)
		_targets[i].global_position = _pos[i]


## Trigger a forward jab. Called when a player click pops a bubble.
func poke() -> void:
	_poke = 1.0
