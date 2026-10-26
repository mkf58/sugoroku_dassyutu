class_name TestGridBoard
extends TestCase

func run_all() -> void:
	test_find_shortest_path_simple_line()
	test_reachable_cells_with_steps_allowing_turnaround()
	test_find_farthest_linear_cell()
	test_line_of_sight_clear()
	test_find_shortest_path_unreachable()
	test_find_path_goal_is_obstacle()
	test_validate_path_disconnected()
	test_reachable_cells_min_step_one()
	test_reachable_cells_odd_vs_even_turnaround()
	test_reachable_cells_blocked_by_obstacles()
	test_find_path_detours_obstacles()
	test_reachable_cells_and_path_to_exit_with_excess_steps()


## UT-BOARD-N01: 2点間最短経路探索
func test_find_shortest_path_simple_line() -> void:
	var board = GridBoard.new()
	var c0 = CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL)
	var c1 = CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL)
	var c2 = CellData.new(Vector2i(2, 0), Enums.CellType.NORMAL)
	board.add_cell(c0)
	board.add_cell(c1)
	board.add_cell(c2)
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	var path = board.find_shortest_path(Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(path.size(), 3, "UT-BOARD-N01: 経路長は3")
	if path.size() == 3:
		assert_eq(path[0], Vector2i(0, 0), "UT-BOARD-N01: 始点は(0,0)")
		assert_eq(path[1], Vector2i(1, 0), "UT-BOARD-N01: 中継は(1,0)")
		assert_eq(path[2], Vector2i(2, 0), "UT-BOARD-N01: 終点は(2,0)")

## UT-BOARD-N02: 出目通りの到達マス集合（折り返し含む）
func test_reachable_cells_with_steps_allowing_turnaround() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
	
	var reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 2)
	assert_true(reachables.has(Vector2i(2, 0)), "UT-BOARD-N02: 直進(2,0)へ到達可能")
	assert_true(reachables.has(Vector2i(0, 0)), "UT-BOARD-N02: 折り返し(0,0)へ到達可能")
	assert_false(reachables.has(Vector2i(1, 0)), "UT-BOARD-N02: (1,0)は出目2では停止不可")

## UT-BOARD-N03: 直線走査（最遠マス）
func test_find_farthest_linear_cell() -> void:
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var farthest = board.find_farthest_linear_cell(Vector2i(1, 0), Vector2i(1, 0))
	assert_eq(farthest, Vector2i(4, 0), "UT-BOARD-N03: 右方向走査で(4,0)が最遠マス")

## UT-BOARD-N04: 直線視界判定
func test_line_of_sight_clear() -> void:
	var board = GridBoard.new()
	for x in range(4):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var has_los = board.has_clear_line_of_sight(Vector2i(0, 0), Vector2i(3, 0))
	assert_true(has_los, "UT-BOARD-N04: 直線上に壁がなければ視界クリア")

## UT-BOARD-E01: 未接続・孤立マスへの探索
func test_find_shortest_path_unreachable() -> void:
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	# 接続しない
	var path = board.find_shortest_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(path.is_empty(), "UT-BOARD-E01: 未接続時は空配列が返却されること")

## UT-BOARD-E02: 障害物マスへの直接進入拒否
func test_find_path_goal_is_obstacle() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var obstacles: Array[Vector2i] = [Vector2i(2, 0)]
	var path = board.find_path_with_steps(Vector2i(0, 0), Vector2i(2, 0), 2, obstacles)
	assert_true(path.is_empty(), "UT-BOARD-E02: 目的地自体が障害物の場合は到達不可")

## UT-BOARD-E03: 不正経路のバリデーション
func test_validate_path_disconnected() -> void:
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	# 未接続
	var invalid_path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var is_valid = board.validate_path(invalid_path, 1)
	assert_false(is_valid, "UT-BOARD-E03: 未接続マス間の経路は無効と判定されること")

## UT-BOARD-B01: 最小出目（出目1）の移動
func test_reachable_cells_min_step_one() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var reachables = board.get_reachable_cells_with_steps(Vector2i(1, 0), 1)
	assert_eq(reachables.size(), 2, "UT-BOARD-B01: 出目1では左右2マスのみ到達可能")
	assert_true(reachables.has(Vector2i(0, 0)), "UT-BOARD-B01: 左マス到達可能")
	assert_true(reachables.has(Vector2i(2, 0)), "UT-BOARD-B01: 右マス到達可能")
	assert_false(reachables.has(Vector2i(1, 0)), "UT-BOARD-B01: 現在地へは戻れない")

## UT-BOARD-B02: 偶数出目 vs 奇数出目での現在地停止判定
func test_reachable_cells_odd_vs_even_turnaround() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var odd_reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 3)
	var even_reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 2)
	assert_false(odd_reachables.has(Vector2i(0, 0)), "UT-BOARD-B02: 奇数出目(3)では現在地へ停止不可")
	assert_true(even_reachables.has(Vector2i(0, 0)), "UT-BOARD-B02: 偶数出目(2)では現在地へ停止可能")

## UT-BOARD-B03: 障害物による完全封鎖
func test_reachable_cells_blocked_by_obstacles() -> void:
	var board = GridBoard.new()
	for x in range(4):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var obstacles: Array[Vector2i] = [Vector2i(1, 0)]
	var reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 2, obstacles)
	assert_true(reachables.is_empty(), "UT-BOARD-B03: 通路が障害物で封鎖された場合、到達可能マスは0件")

## UT-BOARD-D01: 障害物マスを回避する迂回経路探索
func test_find_path_detours_obstacles() -> void:
	var board = GridBoard.new()
	for y in range(2):
		for x in range(3):
			board.add_cell(CellData.new(Vector2i(x, y), Enums.CellType.NORMAL))
			if x > 0:
				board.connect_cells(Vector2i(x - 1, y), Vector2i(x, y))
	board.connect_cells(Vector2i(0, 0), Vector2i(0, 1))
	board.connect_cells(Vector2i(2, 0), Vector2i(2, 1))

	var obstacles: Array[Vector2i] = [Vector2i(1, 0)]
	var path = board.find_shortest_path(Vector2i(0, 0), Vector2i(2, 0), obstacles)
	assert_false(path.is_empty(), "UT-BOARD-D01: 迂回路経由で到達できること")
	assert_false(path.has(Vector2i(1, 0)), "UT-BOARD-D01: 障害物マスを含まないこと")
	assert_eq(path.size(), 5, "UT-BOARD-D01: 迂回経路長は5")

## UT-BOARD-N05: EXITマスへの出目余り到達（ぴったりでなくても到達可能）
func test_reachable_cells_and_path_to_exit_with_excess_steps() -> void:
	var board = GridBoard.new()
	board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
	board.add_cell(CellData.new(Vector2i(2, 0), Enums.CellType.EXIT))
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	# 距離は2マスだが、出目5（余り3）で振った場合
	var reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 5)
	assert_true(reachables.has(Vector2i(2, 0)), "UT-BOARD-N05: 出目が余っていてもEXITマスは到達可能に含まれること")
	
	var path = board.find_path_with_steps(Vector2i(0, 0), Vector2i(2, 0), 5)
	assert_eq(path.size(), 3, "UT-BOARD-N05: EXITマスへの経路は最短2歩で返却されること")
	assert_eq(path[-1], Vector2i(2, 0), "UT-BOARD-N05: 経路の終点がEXITマスであること")
	assert_true(board.validate_path(path, 5), "UT-BOARD-N05: 出目余りでもEXITへの経路は有効と判定されること")

