class_name HelpModal
extends Control

signal closed()

@onready var close_btn: Button = $Panel/CloseButton

func _ready() -> void:
    close_btn.pressed.connect(func():
        visible = false
        emit_signal("closed")
    )
    visible = false

func open() -> void:
    visible = true

func _unhandled_input(event: InputEvent) -> void:
    if visible and event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            visible = false
            emit_signal("closed")
