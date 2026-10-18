class_name TestStepMovement
extends TestCase

func run_all() -> void:
    test_hero_step_overlap_with_witch_causes_game_over()
    test_burrowed_hero_can_pass_witch_safely()
    test_water_trap_stops_movement_immediately()

## UT-STEP-01: 主人公が未潜行で魔女のマスへ侵入した際の即時ゲームオーバー判定
func test_hero_step_overlap_with_witch_causes_game_over() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(3):
        var c = CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL)
        board.add_cell(c)
    board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
    board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
    
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
    
    tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
    
    # 1歩目：(1,0) 魔女のいるマスへ侵入
    var result = tm.step_unit(hero, Vector2i(1, 0), 1)
    assert_eq(result.get("result"), "GAME_OVER", "UT-STEP-01: Result should be GAME_OVER")
    assert_eq(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-STEP-01: Current phase should be GAME_OVER")

## UT-STEP-02: 土魔法で潜行中のユニットが魔女のマスを通過した際のやり過ごし検証
func test_burrowed_hero_can_pass_witch_safely() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(3):
        var c = CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL)
        board.add_cell(c)
    board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
    board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
    
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    hero.is_burrowed = true # 潜行中
    var witch = EnemyData.new("WITCH_1", Enums.EnemyType.TRACKING, Vector2i(1, 0))
    
    tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
    
    var result = tm.step_unit(hero, Vector2i(1, 0), 1)
    assert_eq(result.get("result"), "CONTINUE", "UT-STEP-02: Result should be CONTINUE due to burrow")
    assert_ne(tm.current_phase, Enums.TurnPhase.GAME_OVER, "UT-STEP-02: Should not be GAME_OVER")

## UT-STEP-03: 水魔術トラップマス侵入時の残歩数破棄・即時ターン終了検証
func test_water_trap_stops_movement_immediately() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
    board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.WATER_TRAP)) # 水トラップ
    board.add_cell(CellData.new(Vector2i(2, 0), Enums.CellType.NORMAL))
    board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
    board.connect_cells(Vector2i(1, 0), Vector2i(2, 0))
    
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    tm.setup_stage(board, [hero], [], "STAGE_TEST")
    
    # 残り歩数2で (1,0) の水トラップに侵入
    var result = tm.step_unit(hero, Vector2i(1, 0), 2)
    assert_eq(result.get("result"), "WATER_TRAP_STOP", "UT-STEP-03: Result should be WATER_TRAP_STOP")
    assert_eq(hero.current_coord, Vector2i(1, 0), "UT-STEP-03: Current coord should be (1,0)")
