extends Node3D
## Standalone sandbox for the WRAD arms. Open ArmsPlayground.tscn and press F6 to
## run it on its own. The arms are a plain scene instance you can pose in the 3D
## viewport; this script optionally wires SkeletonIK to the two Target markers and
## makes the active target follow the mouse, so you can experiment with the solver
## live (drag the @export values in the inspector while it runs).
##
## To try the editor's own IK nodes instead: set enable_script_ik = false, turn on
## "Editable Children" on the Arms node, and add IK nodes under its Skeleton3D.

@export var enable_script_ik := true
@export var follow_mouse := true
@export_group("Solver")
@export var use_magnet := false
@export var override_tip_basis := false
@export var magnet := Vector3(1.0, -1.0, 0.0)
@export var target_depth := 8.0

@onready var _cam: Camera3D = $Camera3D
@onready var _arms: Node3D = $Arms
@onready var _tr: Marker3D = $TargetR
@onready var _tl: Marker3D = $TargetL

var _skel: Skeleton3D


func _ready() -> void:
	_skel = _find_skel(_arms)
	if _skel == null:
		push_warning("ArmsPlayground: no Skeleton3D found under Arms")
		return
	if enable_script_ik:
		_ik("bicep.r", "wrist.r", _tr)
		_ik("bicep.l", "wrist.l", _tl)


func _ik(root: String, tip: String, target: Marker3D) -> void:
	var ik := SkeletonIK3D.new()
	ik.root_bone = root
	ik.tip_bone = tip
	ik.use_magnet = use_magnet
	ik.magnet = magnet
	ik.override_tip_basis = override_tip_basis
	ik.interpolation = 1.0
	_skel.add_child(ik)
	ik.target_node = ik.get_path_to(target)
	ik.start()


func _process(_delta: float) -> void:
	if not follow_mouse:
		return
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var p := _cam.project_position(m, target_depth)
	# Cursor's screen half drives that side's target; the other stays put.
	if m.x > vp.x * 0.5:
		_tr.global_position = p
	else:
		_tl.global_position = p


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null
