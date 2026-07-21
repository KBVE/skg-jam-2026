## Integration test for the pop -> despawn path that a bubble click drives:
## board.hit tags C_Popped, ScoreSystem drains it and despawns through a CommandBuffer.
## Headless-safe (no InputEvent needed) — exercises the deferred removal directly.
extends GdUnitTestSuite

var runner: GdUnitSceneRunner
var world: World
var board: Board


func before():
	runner = scene_runner("res://addons/gecs/tests/test_scene.tscn")
	world = runner.get_property("world")
	ECS.world = world


func before_test():
	board = Board.new()
	add_child(board)   # runs Board._ready() -> builds the BubbleField
	var stats := Entity.new()
	stats.add_component(C_RunStats.new())
	world.add_entity(stats)
	var ss := ScoreSystem.new()
	ss.stats_entity = stats
	ss.board = board
	world.add_system(ss)


func after_test():
	if is_instance_valid(board):
		board.queue_free()
	world.purge(false)


func test_popped_bubble_despawns_and_frees_its_cell() -> void:
	board.spawn_sheet(world, 0)
	var poppable := board.poppable_entities()
	assert_int(poppable.size()).is_greater(0)

	var e: Entity = poppable[0]
	var c := e.get_component(C_Cell) as C_Cell
	var cell := Vector2i(c.col, c.row)
	assert_object(board.entity_at(cell)).is_same(e)

	# What board.hit does on a lethal hit: tag it, then let ScoreSystem drain.
	e.add_component(C_Popped.new())
	ECS.process(0.016)

	# CommandBuffer flush ran board.despawn: the cell is free (no clickable ghost).
	assert_object(board.entity_at(cell)).is_null()
