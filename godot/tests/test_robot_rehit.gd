## Regression: a SINGLE robot must finish a multi-hp bubble on its own — hold the
## target and keep jumping until it pops, instead of releasing after one hit and
## needing another robot to come along.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var board: Board

class StubVisual:
	extends Node2D
	func play(_c: String) -> void: pass
	func orient(_d: Vector2) -> void: pass

func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world

func before_test():
	board = Board.new()
	add_child(board)
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

func test_single_bot_finishes_tough_bubble_alone() -> void:
	board.clear_sheet()
	board.cols = 1
	board.rows = 1
	board.spawn_bubble_at(world, Vector2i(0, 0), "tough")   # hp 2 -> needs two jumps
	var t: Entity = board.poppable_entities()[0]

	var e := Entity.new()
	e.add_component(C_Robot.new())
	world.add_entity(e)
	var rob := e.get_component(C_Robot) as C_Robot
	var vis := StubVisual.new()
	add_child(vis)
	vis.position = board.entity_center(t)
	rob.visual = vis

	# Two jump cycles + deferred despawn. Fixed span so the pop AND cell-free complete.
	for _i in 80:
		ECS.process(0.05)

	assert_object(board.entity_at(Vector2i(0, 0))).is_null()
