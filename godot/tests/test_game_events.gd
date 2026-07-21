## Event-bus tests for the GECS-native game event system (GameEvents + observers).
## Verifies entity-scoped delivery, broadcast (null entity) delivery, and that every
## JS-facing event name is deliverable through World.emit_event -> Observer.on_event.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func after_test():
	world.purge(false)


## Captures every subscribed event for assertions.
class CaptureObserver:
	extends Observer
	var events: Array = []   # [{event, entity, payload}]

	func sub_observers() -> Array[Array]:
		return [
			[q.on_event(GameEvents.POP), _cap],
			[q.on_event(GameEvents.CHAIN), _cap],
			[q.on_event(GameEvents.HIT), _cap],
			[q.on_event(GameEvents.STATE_CHANGED), _cap],
			[q.on_event(GameEvents.SHEET_CLEAR), _cap],
			[q.on_event(GameEvents.UPGRADE_PICKED), _cap],
			[q.on_event(GameEvents.SCORE_CHANGED), _cap],
			[q.on_event(GameEvents.TIME_CHANGED), _cap],
			[q.on_event(GameEvents.RUN_OVER), _cap],
		]

	func _cap(event: Variant, entity: Entity, payload: Variant) -> void:
		events.append({"event": event, "entity": entity, "payload": payload})


func test_entity_scoped_pop_delivers_entity_and_payload() -> void:
	var obs := CaptureObserver.new()
	world.add_observer(obs)
	var e := Entity.new()
	world.add_entity(e)

	world.emit_event(GameEvents.POP, e, {"kind": "plain", "points": 1, "x": 5.0, "y": 6.0})

	assert_int(obs.events.size()).is_equal(1)
	assert_object(obs.events[0].entity).is_same(e)
	assert_str(obs.events[0].payload.kind).is_equal("plain")
	assert_int(obs.events[0].payload.points).is_equal(1)


func test_broadcast_reaches_subscriber_with_null_entity() -> void:
	var obs := CaptureObserver.new()
	world.add_observer(obs)

	world.emit_event(GameEvents.STATE_CHANGED, null, {"state": "PLAYING"})

	assert_int(obs.events.size()).is_equal(1)
	assert_object(obs.events[0].entity).is_null()
	assert_str(obs.events[0].payload.state).is_equal("PLAYING")


func test_all_js_facing_broadcast_events_deliver() -> void:
	var obs := CaptureObserver.new()
	world.add_observer(obs)

	world.emit_event(GameEvents.SCORE_CHANGED, null, {"score": 10})
	world.emit_event(GameEvents.TIME_CHANGED, null, {"remaining": 3.0})
	world.emit_event(GameEvents.RUN_OVER, null, {"score": 10, "currencyEarned": 0})
	world.emit_event(GameEvents.UPGRADE_PICKED, null, {"ricochet": 1, "area": 0, "autoclick": 0})
	world.emit_event(GameEvents.SHEET_CLEAR, null, {"sheet": 0, "choices": []})

	assert_int(obs.events.size()).is_equal(5)
