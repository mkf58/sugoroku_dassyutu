class_name TestGridBoard
extends TestCase

func run_all() -> void:
    test_find_shortest_path_simple_line()
    test_find_shortest_path_unreachable()
    test_reachable_cells_with_steps_allowing_turnaround()

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
