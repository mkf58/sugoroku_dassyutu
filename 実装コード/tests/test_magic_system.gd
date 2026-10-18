class_name TestMagicSystem
extends TestCase

func run_all() -> void:
    test_fire_magic_defeats_witch()
    test_water_magic_creates_trap()

## UT-MAGIC-01: 炎魔法による魔女撃破と2ターン復活カウンタ設定
func test_fire_magic_defeats_witch() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(3):
        board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
        if x > 0:
            board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
            
    var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(0, 0))
    var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(1, 0))
    
    tm.setup_stage(board, [fire_girl], [witch], "STAGE_TEST")
    
    var success = tm.execute_magic("GIRL_FIRE", Enums.ElementType.FIRE, Vector2i(1, 0))
    assert_true(success, "UT-MAGIC-01: Fire magic should succeed")
    assert_false(witch.is_alive, "UT-MAGIC-01: Witch should be dead")
    assert_eq(witch.revive_turn_count, 2, "UT-MAGIC-01: Revive counter should be 2")
    assert_true(fire_girl.has_acted, "UT-MAGIC-01: Caster should have acted")

## UT-MAGIC-02: 水魔法によるトラップ生成
func test_water_magic_creates_trap() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    board.add_cell(CellData.new(Vector2i(0, 0), Enums.CellType.NORMAL))
    board.add_cell(CellData.new(Vector2i(1, 0), Enums.CellType.NORMAL))
    board.connect_cells(Vector2i(0, 0), Vector2i(1, 0))
    
    var water_girl = CharacterData.new("GIRL_WATER", "水の少女", Vector2i(0, 0))
    tm.setup_stage(board, [water_girl], [], "STAGE_TEST")
    
    var success = tm.execute_magic("GIRL_WATER", Enums.ElementType.WATER, Vector2i(1, 0))
    assert_true(success, "UT-MAGIC-02: Water magic should succeed")
    var target_cell = board.get_cell(Vector2i(1, 0))
    assert_eq(target_cell.cell_type, Enums.CellType.WATER_TRAP, "UT-MAGIC-02: Target cell should become WATER_TRAP")
