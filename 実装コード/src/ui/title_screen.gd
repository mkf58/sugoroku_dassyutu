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
var confirm_overlay: ColorRect = null

func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	help_btn.pressed.connect(_on_help_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	_refresh_continue_button()
	new_game_btn.grab_focus()

func _refresh_continue_button() -> void:
	var has_save = false
	if Engine.has_singleton("SceneManager"):
		var sm = Engine.get_singleton("SceneManager")
		has_save = sm.has_save_data()
	elif get_node_or_null("/root/SceneManager"):
		var sm = get_node("/root/SceneManager")
		has_save = sm.has_save_data()
	else:
		has_save = SaveManager.has_any_save() or SaveManager.has_suspend()

	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.tooltip_text = "セーブデータが存在しません"
	else:
		continue_btn.tooltip_text = ""

func _unhandled_input(event: InputEvent) -> void:
	var is_back = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		is_back = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		is_back = true

	if is_back:
		if confirm_overlay != null:
			_close_confirm_overlay()
			get_viewport().set_input_as_handled()
		elif slot_overlay != null:
			_close_slot_select()
			get_viewport().set_input_as_handled()

func _on_new_game_pressed() -> void:
	DebugLogger.info("TitleScreen._on_new_game_pressed", "「はじめから」が選択されました")
	_open_slot_select(true)

func _on_continue_pressed() -> void:
	DebugLogger.info("TitleScreen._on_continue_pressed", "「つづきから」が選択されました")
	_open_slot_select(false)

## スロット表示文字列の整形（初期セーブは「開始前」と表示）
static func format_slot_text(slot_no: int, d: SaveData) -> String:
	if d == null:
		return "スロット%d：（空き）" % slot_no
	if d.is_initial():
		return "スロット%d：開始前（次: %s）\n%s" % [slot_no, d.next_stage_id, d.saved_at]
	return "スロット%d：%s クリア → 次: %s\n%s" % [slot_no, d.cleared_stage_name, d.next_stage_id, d.saved_at]

## スロット選択ポップアップをコードで構築して表示する（is_new_game=true: 新規保存先選択 / false: ロード対象選択）
func _open_slot_select(is_new_game: bool = false) -> void:
	_close_slot_select()
	slot_overlay = ColorRect.new()
	slot_overlay.color = Color(0, 0, 0, 0.75)
	slot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(480, 0)
	box.position = Vector2(-240, -150)
	box.add_theme_constant_override("separation", 12)
	slot_overlay.add_child(box)

	var header = Label.new()
	header.text = "セーブ先スロットを選択（はじめから）" if is_new_game else "ロードするスロットを選択（つづきから）"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)

	var slots = SaveManager.list_slots()
	for i in range(slots.size()):
		var slot_no = i + 1
		var d: SaveData = slots[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.text = format_slot_text(slot_no, d)
		if is_new_game:
			btn.pressed.connect(_on_new_game_slot_selected.bind(slot_no, d != null))
		else:
			if d == null:
				btn.disabled = true
			else:
				btn.pressed.connect(_on_slot_selected.bind(slot_no))
		box.add_child(btn)

	# ロードモード時のみ中断データ（一時離席用・ロードすると消える）を表示
	if not is_new_game and SaveManager.has_suspend():
		var sd = SaveManager.load_suspend()
		var sbtn = Button.new()
		sbtn.custom_minimum_size = Vector2(0, 56)
		if sd != null:
			sbtn.text = "中断データ：%s ターン%d（ロードすると消えます）\n%s" % [sd.stage_id, sd.current_turn, sd.saved_at]
			sbtn.pressed.connect(_on_suspend_selected)
		else:
			sbtn.text = "中断データ：（読込不可）"
			sbtn.disabled = true
		box.add_child(sbtn)

	var cancel = Button.new()
	cancel.text = "戻る"
	cancel.pressed.connect(_close_slot_select)
	box.add_child(cancel)
	$CanvasLayer.add_child(slot_overlay)

func _close_slot_select() -> void:
	_close_confirm_overlay()
	if slot_overlay != null:
		slot_overlay.queue_free()
		slot_overlay = null

func _on_new_game_slot_selected(slot_no: int, has_existing: bool) -> void:
	if has_existing:
		_open_overwrite_confirm(slot_no)
	else:
		_start_new_game_in_slot(slot_no)

## 使用済みスロット上書き確認ダイアログを表示
func _open_overwrite_confirm(slot_no: int) -> void:
	_close_confirm_overlay()
	confirm_overlay = ColorRect.new()
	confirm_overlay.color = Color(0, 0, 0, 0.85)
	confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -80)
	box.add_theme_constant_override("separation", 16)
	confirm_overlay.add_child(box)

	var msg = Label.new()
	msg.text = "スロット%dのデータは消えます。\n上書きして最初から始めますか？" % slot_no
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(msg)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	box.add_child(hbox)

	var yes_btn = Button.new()
	yes_btn.custom_minimum_size = Vector2(140, 44)
	yes_btn.text = "はい（上書き）"
	yes_btn.pressed.connect(func(): _start_new_game_in_slot(slot_no))
	hbox.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.custom_minimum_size = Vector2(140, 44)
	no_btn.text = "いいえ（戻る）"
	no_btn.pressed.connect(_close_confirm_overlay)
	hbox.add_child(no_btn)

	$CanvasLayer.add_child(confirm_overlay)

func _close_confirm_overlay() -> void:
	if confirm_overlay != null:
		confirm_overlay.queue_free()
		confirm_overlay = null

## 指定スロットに初期セーブデータを即作成してゲームを開始する
func _start_new_game_in_slot(slot_no: int) -> void:
	var init_data = SaveData.new_game("STAGE_1")
	if not SaveManager.save_slot(slot_no, init_data):
		DebugLogger.error("TitleScreen._start_new_game_in_slot", "初期セーブデータの保存に失敗しました: slot=%d" % slot_no)
		_close_slot_select()
		return
	# 新規開始時も中断データは消去する
	SaveManager.delete_suspend()
	_close_slot_select()
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.set_param("active_slot", slot_no)
		sm.set_param("resume_save", init_data)
		sm.set_param("resume_suspend", null)
		sm.change_to_main_game(init_data.next_stage_id)
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_slot_selected(slot_no: int) -> void:
	# どのスロットをロードしても中断データは消える
	var data = SaveManager.load_slot_and_clear_suspend(slot_no)
	if data == null:
		DebugLogger.error("TitleScreen._on_slot_selected", "セーブデータの読込に失敗しました: slot=%d" % slot_no)
		_close_slot_select()
		return
	_close_slot_select()
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.set_param("active_slot", slot_no)
		sm.set_param("resume_save", data)
		sm.set_param("resume_suspend", null)
		sm.change_to_main_game(data.next_stage_id)
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

## 中断データからの再開（読み込むと中断データは消える）
func _on_suspend_selected() -> void:
	var data = SaveManager.consume_suspend()
	if data == null:
		DebugLogger.error("TitleScreen._on_suspend_selected", "中断データの読込に失敗しました")
		_close_slot_select()
		return
	_close_slot_select()
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		sm.set_param("active_slot", data.active_slot)
		sm.set_param("resume_suspend", data)
		sm.set_param("resume_save", null)
		sm.change_to_main_game(data.stage_id)
	else:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func _on_help_pressed() -> void:
	if help_modal:
		help_modal.show_modal()

func _on_quit_pressed() -> void:
	DebugLogger.info("TitleScreen._on_quit_pressed", "ゲームを終了します")
	get_tree().quit()
