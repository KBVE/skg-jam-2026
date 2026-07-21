## Boss-bubble tests: multi-cell placement, click hit-testing on the big body,
## per-sheet spawn cap, and the boss4 -> boss2 split-on-pop mechanic.
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
	board.cols = Config.GRID_MAX_COLS
	board.rows = Config.GRID_MAX_ROWS


func after_test():
	if is_instance_valid(board):
		board.queue_free()
	world.purge(false)


func _score_system() -> ScoreSystem:
	var stats := Entity.new()
	stats.add_component(C_RunStats.new())
	world.add_entity(stats)
	var ss := ScoreSystem.new()
	ss.stats_entity = stats
	ss.board = board
	world.add_system(ss)
	return ss


func test_boss4_covers_its_whole_footprint() -> void:
	board.spawn_bubble_at(world, Vector2i(1, 1), Kinds.BOSS4)
	var e := board.entity_at(Vector2i(1, 1))
	assert_object(e).is_not_null()
	var cell := e.get_component(C_Cell) as C_Cell
	assert_int(cell.w).is_equal(4)
	# Every covered cell resolves to the same entity.
	assert_object(board.entity_at(Vector2i(4, 4))).is_same(e)
	assert_object(board.entity_at(Vector2i(1, 4))).is_same(e)


func test_click_on_boss_body_offset_from_cell_centers_hits() -> void:
	board.spawn_bubble_at(world, Vector2i(0, 0), Kinds.BOSS4)
	# region center = (108,108), radius ~129.6. A point 100px off-center used to
	# miss the old 30px test but is well inside the boss body.
	var hit := board.cell_at(Vector2(208.0, 108.0))
	assert_bool(hit.x >= 0).is_true()
	assert_object(board.entity_at(hit)).is_not_null()
	# A truly empty cell still misses.
	assert_vector(board.cell_at(board.cell_center(7, 5))).is_equal(Vector2i(-1, -1))


func test_spawn_cap_never_exceeded() -> void:
	var cap := clampi(1 + 20 / 8, 1, 2)   # sheet 20 -> cap 2
	for _i in 30:
		board.spawn_sheet(world, 20)
		var bosses := 0
		for e in board.poppable_entities():
			var cell := e.get_component(C_Cell) as C_Cell
			if cell and (cell.w > 1 or cell.h > 1):
				bosses += 1
		assert_int(bosses).is_less_equal(cap)


func test_boss4_splits_into_four_half_hp_boss2_on_pop() -> void:
	var ss := _score_system()
	board.spawn_bubble_at(world, Vector2i(0, 0), Kinds.BOSS4)
	var boss := board.entity_at(Vector2i(0, 0))
	boss.add_component(C_Popped.new())

	ECS.process(0.016)

	var children: Array = []
	for e in board.poppable_entities():
		var kc := e.get_component(C_Kind) as C_Kind
		if kc and kc.id == Kinds.BOSS2:
			children.append(e)
	assert_int(children.size()).is_equal(4)
	# Half of boss2's base hp (4) -> 2.
	for child in children:
		var b := child.get_component(C_Bubble) as C_Bubble
		assert_int(b.hp).is_equal(2)
	# They tile the 4x4 footprint.
	assert_object(board.entity_at(Vector2i(0, 0))).is_not_null()
	assert_object(board.entity_at(Vector2i(2, 2))).is_not_null()
