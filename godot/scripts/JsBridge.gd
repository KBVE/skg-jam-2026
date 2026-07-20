extends Node
## Autoload bridge between GDScript and the JS app (window.__godotBridge).
##
## Direction of travel:
##   Godot -> JS : emit_event(event, payload)  -> __godotBridge.emit(event, json)
##   JS -> Godot : __godotBridge.send(cmd, obj) -> handler([cmd, json]) -> _on_js
##
## On non-web platforms every call is a no-op, so the project still runs in-editor.

var _target: Object = null
var _js_bridge = null            # JavaScriptObject wrapping window.__godotBridge
var _callback = null             # must be kept alive for the lifetime of the app
var _is_web := false


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return

	# React installs window.__godotBridge BEFORE starting the engine.
	_js_bridge = JavaScriptBridge.get_interface("__godotBridge")
	if _js_bridge == null:
		push_warning("JsBridge: window.__godotBridge not found")
		return

	# Register a Godot callback so JS send() can reach GDScript.
	# The callback receives a single Array of the JS arguments.
	_callback = JavaScriptBridge.create_callback(_on_js)
	_js_bridge.setHandler(_callback)

	# Announce the engine-side bridge is live (drains any queued JS sends).
	emit_event("godot:ready", {})


func register_target(t: Object) -> void:
	_target = t


func emit_event(event: String, payload: Dictionary) -> void:
	if _js_bridge == null:
		return
	_js_bridge.emit(event, JSON.stringify(payload))


func _on_js(args: Array) -> void:
	if args.is_empty():
		return
	var cmd := str(args[0])
	var payload := {}
	if args.size() >= 2 and args[1] != null:
		var parsed = JSON.parse_string(str(args[1]))
		if typeof(parsed) == TYPE_DICTIONARY:
			payload = parsed
	if _target and _target.has_method("handle_command"):
		_target.handle_command(cmd, payload)
