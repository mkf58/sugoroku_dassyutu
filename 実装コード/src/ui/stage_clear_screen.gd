class_name StageClearScreen
extends Control

signal retry_pressed()
signal title_pressed()

@onready var message_label: Label = $Panel/MessageLabel
@onready var retry_btn: Button = $Panel/RetryButton
@onready var title_btn: Button = $Panel/TitleButton

func _ready() -> void:
    retry_btn.pressed.connect(func(): emit_signal("retry_pressed"))
    title_btn.pressed.connect(func(): emit_signal("title_pressed"))
    visible = false

func show_clear(turn_count: int, stage_name: String = "", has_next_stage: bool = true) -> void:
    if has_next_stage:
        if stage_name != "":
            message_label.text = "%s を脱出しました！\n経過ターン数: %d ターン" % [stage_name, turn_count]
        else:
            message_label.text = "階層の脱出に成功しました！\n経過ターン数: %d ターン" % turn_count
        retry_btn.text = "次の階層へ進む"
    else:
        message_label.text = "館からの完全脱出に成功しました！\n総経過ターン数: %d ターン" % turn_count
        retry_btn.text = "最初からもう一度"
    visible = true
