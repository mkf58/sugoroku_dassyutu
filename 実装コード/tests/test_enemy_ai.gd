class_name TestEnemyAI
extends TestCase

func run_all() -> void:
    test_witch_targets_nearest_unburrowed_unit()
    test_witch_targets_hero_on_equal_distance()
    test_witch_returns_to_initial_when_all_burrowed()

## UT-ENEMY-01: 最短距離の未潜行ユニット優先選定
func test_witch_targets_nearest_unburrowed_unit() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(6):
        board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
        if x > 0:
            board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
            
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0)) # 距離5
    var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(3, 0)) # 距離2
    var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(5, 0))
    
    tm.setup_stage(board, [hero, fire_girl], [witch], "STAGE_TEST")
    
    var target = tm.select_witch_target(witch)
    assert_ne(target, null, "UT-ENEMY-01: Target should not be null")
    if target:
        assert_eq(target.character_id, "GIRL_FIRE", "UT-ENEMY-01: Nearest unit (GIRL_FIRE) should be targeted")

## UT-ENEMY-02: 同距離時のタイブレーク優先順位（主人公最優先）
func test_witch_targets_hero_on_equal_distance() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(5):
        board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
        if x > 0:
            board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
            
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0)) # 距離2
    var fire_girl = CharacterData.new("GIRL_FIRE", "炎の少女", Vector2i(4, 0)) # 距離2
    var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
    
    tm.setup_stage(board, [hero, fire_girl], [witch], "STAGE_TEST")
    
    var target = tm.select_witch_target(witch)
    assert_ne(target, null, "UT-ENEMY-02: Target should not be null")
    if target:
        assert_eq(target.character_id, "HERO", "UT-ENEMY-02: Hero should be targeted when distance is equal")

## UT-ENEMY-03: 潜行中ユニットのターゲット除外と全員潜行時の初期位置移動
func test_witch_returns_to_initial_when_all_burrowed() -> void:
    var tm = TurnManager.new()
    var board = GridBoard.new()
    for x in range(6):
        board.add_cell(CellData.new(Vector2i(x, 0), Enums.CellType.NORMAL))
        if x > 0:
            board.connect_cells(Vector2i(x - 1, 0), Vector2i(x, 0))
            
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 0))
    hero.is_burrowed = true # 潜行
    var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(2, 0))
    witch.initial_coord = Vector2i(5, 0)
    
    tm.setup_stage(board, [hero], [witch], "STAGE_TEST")
    
    var target = tm.select_witch_target(witch)
    assert_eq(target, null, "UT-ENEMY-03: Target should be null when all units burrowed")
