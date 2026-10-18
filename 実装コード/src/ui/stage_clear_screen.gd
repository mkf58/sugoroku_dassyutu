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

func show_clear(turn_count: int) -> void:
    message_label.text = "館からの脱出に成功しました！\n経過ターン数: %d ターン" % turn_count
    visible = true
