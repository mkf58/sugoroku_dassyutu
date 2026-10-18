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

func _ready() -> void:
    dice_btn.pressed.connect(func(): emit_signal("roll_dice_pressed"))
    magic_btn.pressed.connect(func(): emit_signal("magic_pressed"))
    wait_btn.pressed.connect(func(): emit_signal("wait_pressed"))
    help_btn.pressed.connect(func(): emit_signal("help_pressed"))

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
