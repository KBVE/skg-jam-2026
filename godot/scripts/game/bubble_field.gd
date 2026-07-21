class_name BubbleField
extends MultiMeshInstance2D
## One draw call for the whole sheet: every bubble is a MultiMesh instance drawn by
## bubble.gdshader. Board acquires a slot per bubble, chips it for hit feedback, and
## pops it (expand + fade) on removal — no per-bubble nodes, no spawn/free churn.

const CAP := Config.GRID_MAX_COLS * Config.GRID_MAX_ROWS   # 140 max cells per sheet
const POP_DURATION := 0.16   # must match bubble.gdshader

var _free: Array[int] = []          # available instance indices
var _base_color: PackedColorArray   # per-slot un-darkened fill (for chip darkening)
var _cdata: PackedColorArray        # per-slot custom data mirror (hp_ratio, bar, pop_start, _)
var _popping: Array = []            # [{i, t}] fading-out slots awaiting reclaim
var _clock := 0.0                   # accumulated-delta clock, shared with the shader


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	var d := Config.BUBBLE_RADIUS * 2.0
	quad.size = Vector2(d, d)
	mm.mesh = quad
	mm.instance_count = CAP
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/bubble.gdshader")
	material = mat

	_base_color.resize(CAP)
	_cdata.resize(CAP)
	clear()


func _process(delta: float) -> void:
	_clock += delta
	(material as ShaderMaterial).set_shader_parameter("u_time", _clock)
	if _popping.is_empty():
		return
	for entry in _popping:
		entry.t -= delta
	var still := []
	for entry in _popping:
		if entry.t > 0.0:
			still.append(entry)
		else:
			_release(entry.i)
	_popping = still


## Reset to an empty sheet: hide every instance and reclaim all slots.
func clear() -> void:
	_free.clear()
	_popping.clear()
	for i in CAP:
		_hide(i)
		_free.append(i)


## Take a slot for a new bubble. Returns the instance index, or -1 if full.
func acquire(pos: Vector2, color: Color, radius: float, max_hp: int) -> int:
	if _free.is_empty():
		return -1
	var i: int = _free.pop_back()
	var s := radius / Config.BUBBLE_RADIUS
	multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(s, s), 0.0, pos))
	_base_color[i] = color
	multimesh.set_instance_color(i, color)
	var bar := 1.0 if max_hp > 1 else 0.0
	_set_custom(i, Color(1.0, bar, -1.0, 0.0))   # hp_ratio 1, bar flag, not popping
	return i


## Partial-hit feedback: darken the dome and update the health-bar fill.
func chip(i: int, hp: int, max_hp: int) -> void:
	if i < 0:
		return
	var col := _base_color[i].darkened(0.22 * float(max_hp - hp))
	multimesh.set_instance_color(i, col)
	var ratio := float(hp) / float(max_hp)
	var bar := 1.0 if max_hp > 1 else 0.0
	_set_custom(i, Color(ratio, bar, -1.0, 0.0))


## Start the pop (shader expands + fades over POP_DURATION); slot reclaimed after.
func pop(i: int) -> void:
	if i < 0:
		return
	var c := _cdata[i]
	_set_custom(i, Color(c.r, c.g, _clock, 0.0))   # pop_start = now
	_popping.append({"i": i, "t": POP_DURATION})


func _release(i: int) -> void:
	_hide(i)
	_free.append(i)


func _hide(i: int) -> void:
	multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
	_set_custom(i, Color(1.0, 0.0, -1.0, 0.0))


func _set_custom(i: int, c: Color) -> void:
	_cdata[i] = c
	multimesh.set_instance_custom_data(i, c)
