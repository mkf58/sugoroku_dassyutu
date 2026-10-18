class_name UnitPiece
extends Node2D

@onready var sprite: ColorRect = $Sprite
@onready var name_label: Label = $NameLabel
@onready var target_icon: Label = $TargetIcon

var unit_id: String = ""
var is_hero: bool = false
var is_enemy: bool = false
var current_tween: Tween = null
var current_step_callback: Callable
var current_complete_callback: Callable
var remaining_path: Array[Vector2i] = []

func setup(p_id: String, p_name: String, p_coord: Vector2i, p_is_hero: bool, p_is_enemy: bool) -> void:
    unit_id = p_id
    is_hero = p_is_hero
    is_enemy = p_is_enemy
    name_label.text = p_name
    position = Vector2(p_coord.x * 64 + 16, p_coord.y * 64 + 16)
    
    if is_hero:
        sprite.color = Color(0.2, 0.7, 0.9, 1.0)
    elif is_enemy:
        sprite.color = Color(0.9, 0.2, 0.2, 1.0)
    else:
        sprite.color = Color(0.3, 0.9, 0.4, 1.0) # 少女
        
    target_icon.visible = false

func set_target_name(t_name: String) -> void:
    if is_enemy:
        if t_name != "":
            target_icon.text = "🎯 " + t_name
            target_icon.visible = true
        else:
            target_icon.visible = false

func set_burrowed(burrowed: bool) -> void:
    if burrowed:
        modulate = Color(0.5, 0.5, 0.5, 0.5) # 地中潜行中
    else:
        modulate = Color(1.0, 1.0, 1.0, 1.0)

## Tweenによる経路移動アニメーション
func animate_path(path: Array[Vector2i], step_callback: Callable, on_complete: Callable) -> void:
    if path.is_empty():
        DebugLogger.error("UnitPiece.animate_path", "経路が空です", {"unit_id": unit_id})
        if on_complete.is_valid():
            on_complete.call()
        return

    if not step_callback.is_valid():
        DebugLogger.error("UnitPiece.animate_path", "step_callbackが無効です", {"unit_id": unit_id})
    if not on_complete.is_valid():
        DebugLogger.error("UnitPiece.animate_path", "on_completeが無効です", {"unit_id": unit_id})

    current_step_callback = step_callback
    current_complete_callback = on_complete
    remaining_path = path.duplicate()
    
    if path.size() <= 1:
        if on_complete.is_valid():
            on_complete.call()
        return

    _play_next_step()

func _play_next_step() -> void:
    if remaining_path.size() <= 1:
        if current_complete_callback.is_valid():
            current_complete_callback.call()
        else:
            DebugLogger.warn("UnitPiece._play_next_step", "移動完了コールバックが無効です", {"unit_id": unit_id})
        return

    var _from_c = remaining_path[0]
    var to_c = remaining_path[1]
    var remain = remaining_path.size() - 2
    
    # 1歩ごとのロジック判定
    if not current_step_callback.is_valid():
        DebugLogger.error("UnitPiece._play_next_step", "step_callbackが無効です", {"unit_id": unit_id, "to_c": to_c})
        if current_complete_callback.is_valid():
            current_complete_callback.call()
        return

    var result = current_step_callback.call(to_c, remain)
    var target_pos = Vector2(to_c.x * 64 + 16, to_c.y * 64 + 16)
    
    current_tween = create_tween()
    if not current_tween:
        DebugLogger.error("UnitPiece._play_next_step", "Tweenの作成に失敗しました", {"unit_id": unit_id})
        position = target_pos
        remaining_path.pop_front()
        _play_next_step()
        return

    current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    current_tween.tween_property(self, "position", target_pos, 0.15)
    
    current_tween.tween_callback(func():
        remaining_path.pop_front()
        if result.get("result") in ["GAME_OVER", "GIRL_DIED", "WATER_TRAP_STOP"]:
            if current_complete_callback.is_valid():
                current_complete_callback.call()
        else:
            _play_next_step()
    )

## 画面クリックで即時移動完了させるスキップ機構
func skip_current_move(final_coord: Vector2i) -> void:
    if current_tween and current_tween.is_valid():
        current_tween.kill()
        position = Vector2(final_coord.x * 64 + 16, final_coord.y * 64 + 16)
        if current_complete_callback.is_valid():
            current_complete_callback.call()
        else:
            DebugLogger.warn("UnitPiece.skip_current_move", "スキップ完了時のコールバックが無効です", {"unit_id": unit_id})

