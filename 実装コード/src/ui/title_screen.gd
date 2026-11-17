class_name TitleScreen
extends Control

## タイトル画面制御スクリプト
## 「はじめから」「つづきから」「遊び方/ヘルプ」「ゲーム終了」のアクションを制御する。

@onready var new_game_btn: Button = $MenuContainer/NewGameButton
@onready var continue_btn: Button = $MenuContainer/ContinueButton
@onready var help_btn: Button = $MenuContainer/HelpButton
@onready var quit_btn: Button = $MenuContainer/QuitButton
@onready var help_modal: HelpModal = $CanvasLayer/HelpModal
var slot_overlay: ColorRect = null

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# セーブデータが存在しない場合は「つづきから」を無効化（または薄く表示）
	var has_save = false
	if Engine.has_singleton("SceneManager"):
		var sm = Engine.get_singleton("SceneManager")
		has_save = sm.has_save_data()
	elif get_node_or_null("/root/SceneManager"):
		var sm = get_node("/root/SceneManager")
		has_save = sm.has_save_data()
		
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.tooltip_text = "セーブデータが存在しません"
		
	# 初期フォーカスを「はじめから」へ
	new_game_btn.grab_focus()

func _on_new_game_pressed() -> void:
	DebugLogger.info("TitleScreen._on_new_game_pressed", "「はじめから」が選択されました")
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		# オートセーブ先は空きスロット優先（全使用ならスロット1）
		sm.set_param("active_slot", SaveManager.pick_new_game_slot())
		sm.set_param("resume_save", null)
		sm.change_to_main_game("STAGE_1")
	else:
		# シングルトン未配置時のフォールバック
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_continue_pressed() -> void:
	DebugLogger.info("TitleScreen._on_continue_pressed", "「つづきから」が選択されました")
	_open_slot_select()

## スロット選択ポップアップをコードで構築して表示する
func _open_slot_select() -> void:
	if slot_overlay != null:
		return
	slot_overlay = ColorRect.new()
	slot_overlay.color = Color(0, 0, 0, 0.75)
	slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(480, 0)
	box.position = Vector2(-240, -140)
	box.add_theme_constant_override("separation", 12)
	slot_overlay.add_child(box)
	var header = Label.new()
	header.text = "ロードするスロットを選択"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	var slots = SaveManager.list_slots()
	for i in range(slots.size()):
		var slot_no = i + 1
		var d: SaveData = slots[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		if d == null:
			btn.text = "スロット%d：（空き）" % slot_no
			btn.disabled = true
		else:
			btn.text = "スロット%d：%s クリア → 次: %s\n%s" % [slot_no, d.cleared_stage_name, d.next_stage_id, d.saved_at]
			btn.pressed.connect(_on_slot_selected.bind(slot_no))
		box.add_child(btn)
	var cancel = Button.new()
	cancel.text = "戻る"
	cancel.pressed.connect(_close_slot_select)
	box.add_child(cancel)
	$CanvasLayer.add_child(slot_overlay)

func _close_slot_select() -> void:
	if slot_overlay != null:
		slot_overlay.queue_free()
		slot_overlay = null

func _on_slot_selected(slot_no: int) -> void:
	var data = SaveManager.load_slot(slot_no)
	if data == null:
		DebugLogger.error("TitleScreen._on_slot_selected", "セーブデータの読込に失敗しました: slot=%d" % slot_no)
		_close_slot_select()
		return
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.set_param("active_slot", slot_no)
		sm.set_param("resume_save", data)
		sm.change_to_main_game(data.next_stage_id)
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_help_pressed() -> void:
	if help_modal:
		help_modal.show_modal()

func _on_quit_pressed() -> void:
	DebugLogger.info("TitleScreen._on_quit_pressed", "ゲームを終了します")
	get_tree().quit()
