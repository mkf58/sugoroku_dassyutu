class_name GameOverScreen
extends Control

signal retry_pressed()
signal title_pressed()

@onready var reason_label: Label = $Panel/ReasonLabel
@onready var retry_btn: Button = $Panel/RetryButton
@onready var title_btn: Button = $Panel/TitleButton

func _ready() -> void:
    retry_btn.pressed.connect(func(): emit_signal("retry_pressed"))
    title_btn.pressed.connect(func(): emit_signal("title_pressed"))
    visible = false

func show_game_over(reason: String) -> void:
    reason_label.text = "死因: %s" % reason
    visible = true
