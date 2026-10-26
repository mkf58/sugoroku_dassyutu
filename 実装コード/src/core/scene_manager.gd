extends Node

## 画面遷移管理Autoloadシングルトン
## 全画面のシーン遷移、パラメータ保持、および黒フェード演出を一元管理する。

const SCENE_TITLE: String = "res://scenes/title_screen.tscn"
const SCENE_MAIN_GAME: String = "res://scenes/main_game.tscn"
const SCENE_STAGE_SELECT: String = "res://scenes/stage_select_screen.tscn"

signal transition_started(target_scene: String)
signal transition_finished(new_scene: String)

var is_transitioning: bool = false
var target_scene_path: String = ""
var current_scene_path: String = ""
var scene_params: Dictionary = {}
var is_test_mode: bool = false

# フェード演出用ノード
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null

func _ready() -> void:
    if not is_test_mode:
        _setup_fade_overlay()
    if get_tree() and get_tree().current_scene:
        current_scene_path = get_tree().current_scene.scene_file_path

func _setup_fade_overlay() -> void:
    fade_layer = CanvasLayer.new()
    fade_layer.layer = 128 # 最前面
    fade_layer.name = "SceneManagerFadeLayer"
    
    fade_rect = ColorRect.new()
    fade_rect.name = "FadeRect"
    fade_rect.color = Color(0, 0, 0, 0)
    fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    fade_layer.add_child(fade_rect)
    add_child(fade_layer)

## シーン遷移実行
func change_scene(target_path: String, params: Dictionary = {}, with_fade: bool = true) -> void:
    if is_transitioning:
        DebugLogger.warn("SceneManager.change_scene", "遷移処理中のため要求を無視しました: %s" % target_path)
        return
        
    is_transitioning = true
    target_scene_path = target_path
    
    for k in params.keys():
        scene_params[k] = params[k]
        
    emit_signal("transition_started", target_path)
    DebugLogger.info("SceneManager.change_scene", "シーン遷移開始 -> %s (with_fade=%s)" % [target_path, str(with_fade)])

    if is_test_mode or not with_fade or fade_rect == null:
        _perform_scene_change()
        return
        
    # フェードアウト（黒く暗転）
    fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
    var tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_callback(func():
        _perform_scene_change()
    )

func _perform_scene_change() -> void:
    var tree = get_tree()
    if tree and not is_test_mode:
        var err = tree.change_scene_to_file(target_scene_path)
        if err != OK:
            DebugLogger.error("SceneManager._perform_scene_change", "シーン読み込み失敗: %s (Error code: %d)" % [target_scene_path, err])
            _finish_transition()
            return
        current_scene_path = target_scene_path
        call_deferred("_fade_in_after_load")
    else:
        _finish_transition()

func _fade_in_after_load() -> void:
    if fade_rect == null or is_test_mode:
        _finish_transition()
        return
        
    var tween = create_tween()
    tween.tween_property(fade_rect, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tween.tween_callback(func():
        fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _finish_transition()
    )

func _finish_transition() -> void:
    is_transitioning = false
    var finished_path = target_scene_path
    emit_signal("transition_finished", finished_path)
    DebugLogger.info("SceneManager._finish_transition", "シーン遷移完了: %s" % finished_path)

## タイトル画面への遷移
func change_to_title(with_fade: bool = true) -> void:
    change_scene(SCENE_TITLE, {}, with_fade)

## メインゲーム画面への遷移
func change_to_main_game(stage_id: String = "STAGE_1", with_fade: bool = true) -> void:
    var params = {}
    if not stage_id.is_empty():
        params["stage_id"] = stage_id
    change_scene(SCENE_MAIN_GAME, params, with_fade)

## パラメータ設定・取得
func set_param(key: String, value: Variant) -> void:
    scene_params[key] = value

func get_param(key: String, default_value: Variant = null) -> Variant:
    return scene_params.get(key, default_value)

## セーブデータ簡易判定（PoC用）
func has_save_data() -> bool:
    return scene_params.has("has_cleared_stage") or FileAccess.file_exists("user://save_data.json")
