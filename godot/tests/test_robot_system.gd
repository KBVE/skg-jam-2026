## FSM test for RobotSystem: a robot seeks the nearest poppable bubble, walks to it,
## jumps, and pops it (board.hit -> C_Popped -> ScoreSystem despawn). Uses a stub
## visual so we skip the 3D SubViewport; the system only needs position + play/face.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var board: Board


## Minimal stand-in for RobotVisual: a Node2D with the methods RobotSystem calls.
class StubVisual:
	extends Node2D
	func play(_clip: String) -> void: pass
	func orient(_dir: Vector2) -> void: pass


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	board = Board.new()
	add_child(board)   # Board._ready builds the BubbleField
	var stats := Entity.new()
	stats.add_component(C_RunStats.new())
	world.add_entity(stats)
	var ss := ScoreSystem.new()
	ss.stats_entity = stats
	ss.board = board
	world.add_system(ss)
	var rs := RobotSystem.new()
	rs.board = board
	world.add_system(rs)


func after_test():
	if is_instance_valid(board):
		board.queue_free()
	world.purge(false)


func _add_robot(at: Vector2) -> Entity:
	var e := Entity.new()
	e.add_component(C_Robot.new())
	world.add_entity(e)
	var rob := e.get_component(C_Robot) as C_Robot
	var vis := StubVisual.new()
	add_child(vis)
	vis.position = at
	rob.visual = vis
	return e


func test_robot_walks_to_nearest_bubble_and_pops_it() -> void:
	board.spawn_sheet(world, 0)
	var target: Entity = board.poppable_entities()[0]
	var cell := target.get_component(C_Cell) as C_Cell
	# Spawn the robot right on the target so it reaches it on the first step.
	_add_robot(board.entity_center(target))
	var before := board.poppable_entities().size()

	# Walk(reach) -> jump(0.55s) -> pop (C_Popped) -> ScoreSystem despawn (deferred a
	# frame). Run a fixed span so the pop AND the deferred cell-free both complete.
	for _i in 40:
		ECS.process(0.05)

	assert_object(board.entity_at(Vector2i(cell.col, cell.row))).is_null()
	assert_int(board.poppable_entities().size()).is_less(before)


func test_two_robots_claim_distinct_targets() -> void:
	board.spawn_sheet(world, 0)
	assert_int(board.poppable_entities().size()).is_greater(1)
	var r1 := _add_robot(Vector2(0, 0))
	var r2 := _add_robot(Vector2(0, 0))

	ECS.process(0.01)   # one seek step: each claims a bubble

	var t1 := (r1.get_component(C_Robot) as C_Robot).target
	var t2 := (r2.get_component(C_Robot) as C_Robot).target
	assert_object(t1).is_not_null()
	assert_object(t2).is_not_null()
	assert_bool(t1 == t2).is_false()   # no dogpiling the same bubble


func test_zero_robots_is_a_noop() -> void:
	board.spawn_sheet(world, 0)
	var before := board.poppable_entities().size()
	ECS.process(0.05)   # RobotSystem present, no robot entities -> must not crash or pop
	assert_int(board.poppable_entities().size()).is_equal(before)
