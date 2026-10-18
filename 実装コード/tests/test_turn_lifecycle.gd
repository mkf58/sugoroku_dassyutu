class_name TestTurnLifecycle
extends TestCase

func run_all() -> void:
    test_girl_revives_after_three_turns()
    test_turn_advance_and_reselection()

## UT-TURN-01: 少女死亡後の3ターン経過による初期位置復活
func test_girl_revives_after_three_turns() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
    
    var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
    fire_girl.kill() # 死亡状態 (revive_turn_count = 3)
    
    tm.setup_stage(board, [fire_girl], [], "STAGE_TEST")
    
    # 1ターン経過
    tm.end_turn_and_advance()
    assert_false(fire_girl.is_alive, "UT-TURN-01: Turn 1: should still be dead")
    assert_eq(fire_girl.revive_turn_count, 2, "UT-TURN-01: Turn 1: revive counter should be 2")
    
    # 2ターン経過
    tm.end_turn_and_advance()
    assert_false(fire_girl.is_alive, "UT-TURN-01: Turn 2: should still be dead")
    assert_eq(fire_girl.revive_turn_count, 1, "UT-TURN-01: Turn 2: revive counter should be 1")
    
    # 3ターン経過
    tm.end_turn_and_advance()
    assert_true(fire_girl.is_alive, "UT-TURN-01: Turn 3: should be revived")
    assert_eq(fire_girl.revive_turn_count, 0, "UT-TURN-01: Turn 3: revive counter should be 0")
    assert_eq(fire_girl.current_coord, Vector2i(0, 0), "UT-TURN-01: Turn 3: should return to initial coord")

## UT-TURN-02: ターン進行後の味方行動リセットと再選択・行動フェーズ遷移の検証
func test_turn_advance_and_reselection() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
    
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    hero.has_acted = true # 1ターン目の行動済み
    
    tm.setup_stage(board, [hero], [], "STAGE_TEST")
    
    # ターンを進める
    tm.end_turn_and_advance()
    assert_eq(tm.current_turn, 2, "UT-TURN-02: Turn should become 2")
    assert_false(hero.has_acted, "UT-TURN-02: Hero has_acted should be reset to false")
    
    # 主人公を選択
    var selected = tm.select_character("HERO")
    assert_true(selected, "UT-TURN-02: Hero should be selectable in turn 2")
    assert_eq(tm.current_phase, Enums.TurnPhase.PLAYER_ACTION_SELECT, "UT-TURN-02: Phase should be PLAYER_ACTION_SELECT")

