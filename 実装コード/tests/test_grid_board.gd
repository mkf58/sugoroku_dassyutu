class_name TestGridBoard
extends TestCase

func run_all() -> void:
	test_find_shortest_path_simple_line()
	test_find_shortest_path_unreachable()
	test_reachable_cells_with_steps_allowing_turnaround()
	test_find_path_with_steps_turnaround()
	test_reachable_cells_excludes_obstacles()
	test_find_path_detours_obstacles()
	test_find_farthest_linear_cell()

## UT-BOARD-01: 最短経路探索（BFS）の検証
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
	assert_eq(path.size(), 3, "UT-BOARD-01: Path size should be 3")
	if path.size() == 3:
		assert_eq(path[0], Vector2i(0, 0), "UT-BOARD-01: Start should be (0,0)")
		assert_eq(path[1], Vector2i(1, 0), "UT-BOARD-01: Mid should be (1,0)")
		assert_eq(path[2], Vector2i(2, 0), "UT-BOARD-01: Goal should be (2,0)")

## UT-BOARD-02: 壁・未接続による到達不能の検証
func test_find_shortest_path_unreachable() -> void:
	var board = GridBoard.new()
	var c0 = CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL)
	var c1 = CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL)
	board.add_cell(c0)
	board.add_cell(c1)
	# 接続しない
	var path = board.find_shortest_path(Vector2i(0, 0), Vector2i(1, 0))
	assert_true(path.is_empty(), "UT-BOARD-02: Path should be empty when disconnected")

## UT-BOARD-03: 出目消費時の折り返し移動可能判定
func test_reachable_cells_with_steps_allowing_turnaround() -> void:
	var board = GridBoard.new()
	var c0 = CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL)
	var c1 = CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL)
	var c2 = CellData.new(Vector2i(2, 0), Enums.CellType.NORMAL)
	board.add_cell(c0)
	board.add_cell(c1)
	board.add_cell(c2)
	board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
	board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
	
	# 出目2での到達可能マスを取得
	var reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 2)
	assert_true(reachables.has(Vector2i(2, 0)), "UT-BOARD-03: (2,0) should be reachable with 2 steps")
	assert_true(reachables.has(Vector2i(0, 0)), "UT-BOARD-03: (0,0) turnaround should be reachable with 2 steps")
	assert_false(reachables.has(Vector2i(1, 0)), "UT-BOARD-03: (1,0) should not be stopped at with 2 steps")

## UT-BOARD-04: 指定歩数での折り返し経路生成の検証
func test_find_path_with_steps_turnaround() -> void:
	var board = GridBoard.new()
	for x in range(3):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	# (0,0) から出目2で (0,0) へ戻る経路
	var path = board.find_path_with_steps(Vector2i(0, 0), Vector2i(0, 0), 2)
	assert_eq(path.size(), 3, "UT-BOARD-04: Path size should be 3 for 2 steps turnaround")
	if path.size() == 3:
		assert_eq(path[0], Vector2i(0, 0), "UT-BOARD-04: Start at (0,0)")
		assert_eq(path[1], Vector2i(1, 0), "UT-BOARD-04: Step 1 at (1,0)")
		assert_eq(path[2], Vector2i(0, 0), "UT-BOARD-04: End at (0,0)")

## UT-BOARD-05: 障害物（未潜行魔女）マスを考慮した到達可能マス除外の検証
func test_reachable_cells_excludes_obstacles() -> void:
	var board = GridBoard.new()
	for x in range(4):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	# (1,0) に障害物（未潜行魔女）を指定
	var obstacles: Array[Vector2i] = [Vector2i(1, 0)]
	var reachables = board.get_reachable_cells_with_steps(Vector2i(0, 0), 2, obstacles)
	
	assert_false(reachables.has(Vector2i(1, 0)), "UT-BOARD-05: 障害物マス(1,0)は到達可能に含まれないこと")
	assert_false(reachables.has(Vector2i(2, 0)), "UT-BOARD-05: 障害物の先の(2,0)へは通り抜けできないこと")
	assert_true(reachables.is_empty(), "UT-BOARD-05: 直線で障害物を越えられないため到達可能マスは0件")

## UT-BOARD-06: 障害物マスを回避する迂回経路探索の検証
func test_find_path_detours_obstacles() -> void:
	var board = GridBoard.new()
	# (0,0) - (1,0) - (2,0) メインストリート
	#   |               |
	# (0,1) - (1,1) - (2,1) 迂回路
	for y in range(2):
		for x in range(3):
			board.add_cell(CellData.new(Vector2i(x, y), Enums.CellType.NORMAL))
			if x > 0:
				board.connect_cells(Vector2i(x - 1, y), Vector2i(x, y))
	board.connect_cells(Vector2i(0, 0), Vector2i(0, 1))
	board.connect_cells(Vector2i(2, 0), Vector2i(2, 1))

	# メインストリート中央 (1,0) を障害物に指定
	var obstacles: Array[Vector2i] = [Vector2i(1, 0)]
	var path = board.find_shortest_path(Vector2i(0, 0), Vector2i(2, 0), obstacles)
	
	assert_false(path.is_empty(), "UT-BOARD-06: 迂回路を通って到達できること")
	assert_false(path.has(Vector2i(1, 0)), "UT-BOARD-06: 経路に障害物マスが含まれないこと")
	assert_eq(path.size(), 5, "UT-BOARD-06: 迂回経路の長さは5 (0,0)->(0,1)->(1,1)->(2,1)->(2,0)")

## UT-BOARD-07: 直線走査による最遠マス特定の検証
func test_find_farthest_linear_cell() -> void:
	var board = GridBoard.new()
	for x in range(5):
		board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
		if x > 0:
			board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
			
	var farthest = board.find_farthest_linear_cell(Vector2i(1, 0), Vector2i(1, 0))
	assert_eq(farthest, Vector2i(4, 0), "UT-BOARD-07: 右方向走査で(4,0)が最遠マスとして返ること")
