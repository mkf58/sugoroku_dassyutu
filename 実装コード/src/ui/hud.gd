class_name HUD
extends Control

signal roll_dice_pressed()
signal magic_pressed()
signal wait_pressed()
signal help_pressed()

@onready var turn_label: Label = $TopBar/TurnLabel
@onready var phase_label: Label = $TopBar/PhaseLabel
@onready var dice_btn: Button = $ActionPanel/DiceButton
@onready var magic_btn: Button = $ActionPanel/MagicButton
@onready var wait_btn: Button = $ActionPanel/WaitButton
@onready var help_btn: Button = $TopBar/HelpButton
@onready var dice_result_label: Label = $DiceResult
@onready var log_display: Label = $LogPanel/LogDisplay
@onready var copy_log_btn: Button = $LogPanel/CopyLogButton

var log_history: Array[String] = []

func _ready() -> void:
    dice_btn.pressed.connect(func(): emit_signal("roll_dice_pressed"))
    magic_btn.pressed.connect(func(): emit_signal("magic_pressed"))
    wait_btn.pressed.connect(func(): emit_signal("wait_pressed"))
    help_btn.pressed.connect(func(): emit_signal("help_pressed"))
    copy_log_btn.pressed.connect(_on_copy_log_pressed)
    
    # DebugLoggerのログ自動受信
    DebugLogger.on_log_callback = func(entry: String):
        _append_log(entry)
        
    if log_display:
        log_display.text = "ゲーム開始。ダイス移動を選択してください。"

func _on_copy_log_pressed() -> void:
    var ok = DebugLogger.copy_to_clipboard()
    if ok:
        copy_log_btn.text = "✔ コピー完了!"
        get_tree().create_timer(1.5).timeout.connect(func():
            copy_log_btn.text = "📋 ログコピー"
        )
    else:
        copy_log_btn.text = "空です"
        get_tree().create_timer(1.0).timeout.connect(func():
            copy_log_btn.text = "📋 ログコピー"
        )

func log_message(msg: String) -> void:
    DebugLogger.info("Game", msg)

func _append_log(msg: String) -> void:
    log_history.append(msg)
    if log_history.size() > 8:
        log_history.pop_front()
    if log_display:
        log_display.text = "\n".join(log_history)


func update_turn_info(turn: int, phase_text: String) -> void:
    turn_label.text = "ターン: %d" % turn
    phase_label.text = phase_text

func show_dice_result(val: int) -> void:
    dice_result_label.text = "出目: %d" % val
    dice_result_label.visible = true

func hide_dice_result() -> void:
    dice_result_label.visible = false

func set_action_buttons_enabled(enabled: bool) -> void:
    dice_btn.disabled = not enabled
    magic_btn.disabled = not enabled
    wait_btn.disabled = not enabled

