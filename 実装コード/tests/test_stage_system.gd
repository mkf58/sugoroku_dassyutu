class_name TestStageSystem
extends TestCase

const StageDataClass = preload("res://src/core/stage_data.gd")
const StageRepositoryClass = preload("res://src/core/stage_repository.gd")

func run_all() -> void:
    test_get_stage_data_returns_valid_stage()
    test_stage_transition_chain()
    test_companion_elements_per_stage()
    test_get_invalid_stage_returns_null()
    test_all_stage_ids_registered()

## UT-STAGE-N01: Stage 1のデータ取得と基本プロパティ検証
func test_get_stage_data_returns_valid_stage() -> void:
    var stage = StageRepositoryClass.get_stage("STAGE_1")
    assert_not_null(stage, "UT-STAGE-N01: Stage 1のデータが取得できること")
    assert_eq(stage.stage_id, "STAGE_1", "UT-STAGE-N01: stage_idがSTAGE_1であること")
    assert_eq(stage.floor_number, 1, "UT-STAGE-N01: floor_numberが1であること")
    assert_not_null(stage.board, "UT-STAGE-N01: boardが存在すること")
    assert_false(stage.board.cells.is_empty(), "UT-STAGE-N01: マスが定義されていること")
    assert_false(stage.enemies.is_empty(), "UT-STAGE-N01: 魔女が配置されていること")

## UT-STAGE-N02: 階層間の遷移チェーン検証（STAGE_1〜STAGE_6）
func test_stage_transition_chain() -> void:
    var current_id = StageRepositoryClass.get_first_stage_id()
    assert_eq(current_id, "STAGE_1", "UT-STAGE-N02: 最初のステージはSTAGE_1")
    
    var visited_stages: Array[String] = []
    while not current_id.is_empty():
        visited_stages.append(current_id)
        var s = StageRepositoryClass.get_stage(current_id)
        assert_not_null(s, "UT-STAGE-N02: チェーン上のステージが存在すること")
        current_id = s.next_stage_id
        
    assert_eq(visited_stages.size(), 6, "UT-STAGE-N02: 6階層すべてチェーンされていること")
    assert_eq(visited_stages[0], "STAGE_1", "UT-STAGE-N02: 始点はSTAGE_1")
    assert_eq(visited_stages[-1], "STAGE_6", "UT-STAGE-N02: 終点はSTAGE_6")

## UT-STAGE-N03: 各ステージの同行少女と魔法属性の整合性
func test_companion_elements_per_stage() -> void:
    var s1 = StageRepositoryClass.get_stage("STAGE_1")
    assert_true(s1.companions.is_empty(), "UT-STAGE-N03: Stage 1はチュートリアルのため少女なし")
    
    var s2 = StageRepositoryClass.get_stage("STAGE_2")
    assert_eq(s2.companions.size(), 1, "UT-STAGE-N03: Stage 2は少女1人")
    assert_eq(s2.companions[0].get("element"), Enums.ElementType.FIRE, "UT-STAGE-N03: Stage 2は炎の少女")
    
    var s3 = StageRepositoryClass.get_stage("STAGE_3")
    assert_eq(s3.companions.size(), 1, "UT-STAGE-N03: Stage 3は少女1人")
    assert_eq(s3.companions[0].get("element"), Enums.ElementType.WATER, "UT-STAGE-N03: Stage 3は水の少女")
    
    var s4 = StageRepositoryClass.get_stage("STAGE_4")
    assert_eq(s4.companions.size(), 1, "UT-STAGE-N03: Stage 4は少女1人")
    assert_eq(s4.companions[0].get("element"), Enums.ElementType.WIND, "UT-STAGE-N03: Stage 4は風の少女")
    
    var s5 = StageRepositoryClass.get_stage("STAGE_5")
    assert_eq(s5.companions.size(), 1, "UT-STAGE-N03: Stage 5は少女1人")
    assert_eq(s5.companions[0].get("element"), Enums.ElementType.EARTH, "UT-STAGE-N03: Stage 5は土の少女")
    
    var s6 = StageRepositoryClass.get_stage("STAGE_6")
    assert_true(s6.companions.is_empty(), "UT-STAGE-N03: Stage 6は最終階（解放前）のため同行なし")

## UT-STAGE-E01: 不正なステージIDの防御
func test_get_invalid_stage_returns_null() -> void:
    var invalid_stage = StageRepositoryClass.get_stage("STAGE_NON_EXISTENT")
    assert_null(invalid_stage, "UT-STAGE-E01: 存在しないステージIDに対してnullが返却されること")

## UT-STAGE-B01: 全ステージID登録数
func test_all_stage_ids_registered() -> void:
    var ids = StageRepositoryClass.get_all_stage_ids()
    assert_eq(ids.size(), 6, "UT-STAGE-B01: 全6ステージのIDが登録されていること")
    assert_true(ids.has("STAGE_1") and ids.has("STAGE_6"), "UT-STAGE-B01: 境界ステージが含まれること")
