class_name JsBridgeObserver
extends Observer
## The single Godot->JS forwarding point. Subscribes to the JS-facing gameplay events
## and mirrors each to the React shell via JsBridge.emit_event. Producers only emit GECS
## events (decoupled); this observer is the one place that knows the JS wire names.
##
## The bound String is appended after (event, entity, payload) by Callable.bind, so
## _fwd's last param is the JS event name.

func sub_observers() -> Array[Array]:
	return [
		[q.on_event(GameEvents.POP),            _fwd.bind("game:pop")],
		[q.on_event(GameEvents.STATE_CHANGED),  _fwd.bind("game:state")],
		[q.on_event(GameEvents.SHEET_CLEAR),    _fwd.bind("game:sheet_clear")],
		[q.on_event(GameEvents.UPGRADE_PICKED), _fwd.bind("game:loadout")],
		[q.on_event(GameEvents.SCORE_CHANGED),  _fwd.bind("game:score")],
		[q.on_event(GameEvents.TIME_CHANGED),   _fwd.bind("game:time")],
		[q.on_event(GameEvents.RUN_OVER),       _fwd.bind("game:run_over")],
	]


func _fwd(_event: Variant, _entity: Entity, payload: Variant, js_name: String) -> void:
	JsBridge.emit_event(js_name, payload if payload is Dictionary else {})
