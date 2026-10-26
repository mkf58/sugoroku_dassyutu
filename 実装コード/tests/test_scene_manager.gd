class_name TestSceneManager
extends TestCase

const SceneManagerScript = preload("res://src/core/scene_manager.gd")

func run_all() -> void:
    test_change_scene_registers_target()
    test_scene_param_get_and_set()
    test_convenience_methods()
    test_prevent_double_transition()
    test_invalid_param_key()
    test_empty_params_dictionary()

## UT-SCENE-N01: 遷移要求時に目的シーンとパラメータが正しく記録されること
func test_change_scene_registers_target() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    
    sm.change_scene("res://scenes/test_target.tscn", {"stage_id": "STAGE_1", "score": 100}, false)
    assert_eq(sm.target_scene_path, "res://scenes/test_target.tscn", "UT-SCENE-N01: 遷移先パスが記録されること")
    assert_eq(sm.get_param("stage_id"), "STAGE_1", "UT-SCENE-N01: 渡したパラメータが保持されること")
    assert_eq(sm.get_param("score"), 100, "UT-SCENE-N01: 数値パラメータが保持されること")

## UT-SCENE-N02: パラメータの設定・取得・デフォルト値返却
func test_scene_param_get_and_set() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    
    sm.set_param("hero_alive", true)
    assert_eq(sm.get_param("hero_alive"), true, "UT-SCENE-N02: set_paramした値がget_paramで取得できること")

## UT-SCENE-N03: 定数パスへの簡易遷移メソッド
func test_convenience_methods() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    
    sm.change_to_title(false)
    assert_eq(sm.target_scene_path, sm.SCENE_TITLE, "UT-SCENE-N03: change_to_titleでSCENE_TITLEがターゲットになること")
    
    sm.change_to_main_game("STAGE_2", false)
    assert_eq(sm.target_scene_path, sm.SCENE_MAIN_GAME, "UT-SCENE-N03: change_to_main_gameでSCENE_MAIN_GAMEがターゲットになること")
    assert_eq(sm.get_param("stage_id"), "STAGE_2", "UT-SCENE-N03: 指定ステージIDがパラメータに保存されること")

## UT-SCENE-E01: 遷移中フラグ中の重複実行防御
func test_prevent_double_transition() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    sm.is_transitioning = true
    
    sm.target_scene_path = "res://scenes/original.tscn"
    sm.change_scene("res://scenes/hacked.tscn", {}, false)
    assert_eq(sm.target_scene_path, "res://scenes/original.tscn", "UT-SCENE-E01: is_transitioning中は新たな遷移要求が無視されること")

## UT-SCENE-E02: 存在しないキーのデフォルト値取得
func test_invalid_param_key() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    
    var val = sm.get_param("non_existing_key", "default_val")
    assert_eq(val, "default_val", "UT-SCENE-E02: 未定義キーは指定のデフォルト値を返却すること")
    var nil_val = sm.get_param("another_missing")
    assert_eq(nil_val, null, "UT-SCENE-E02: デフォルト値省略時はnullを返却すること")

## UT-SCENE-B01: 空の辞書を渡した場合の境界動作
func test_empty_params_dictionary() -> void:
    var sm = SceneManagerScript.new()
    sm.is_test_mode = true
    
    sm.set_param("old_key", "old_val")
    sm.change_scene("res://scenes/another.tscn", {}, false)
    assert_eq(sm.target_scene_path, "res://scenes/another.tscn", "UT-SCENE-B01: 空辞書でも正常に遷移先が設定されること")
    assert_eq(sm.get_param("old_key"), "old_val", "UT-SCENE-B01: 空辞書渡しで既存パラメータは破壊されないこと")
