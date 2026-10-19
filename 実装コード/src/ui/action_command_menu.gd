class_name ActionCommandMenu
extends PanelContainer

signal dice_pressed()
signal item_pressed()
signal magic_pressed()
signal wait_pressed()
signal close_pressed()

@onready var portrait_rect: TextureRect = $HBox/LeftColumn/PortraitContainer/PortraitRect
@onready var char_name_label: Label = $HBox/LeftColumn/CharNameLabel
@onready var status_label: Label = $HBox/LeftColumn/StatusLabel

@onready var dice_button: Button = $HBox/RightColumn/DiceButton
@onready var item_button: Button = $HBox/RightColumn/ItemButton
@onready var magic_button: Button = $HBox/RightColumn/MagicButton
@onready var wait_button: Button = $HBox/RightColumn/WaitButton
@onready var close_button: Button = $HBox/RightColumn/CloseButton

@onready var dice_desc_label: Label = $HBox/RightColumn/DiceButton/HBox/VBox/Desc
@onready var item_desc_label: Label = $HBox/RightColumn/ItemButton/HBox/VBox/Desc
@onready var magic_title_label: Label = $HBox/RightColumn/MagicButton/HBox/VBox/Title
@onready var magic_desc_label: Label = $HBox/RightColumn/MagicButton/HBox/VBox/Desc
@onready var wait_desc_label: Label = $HBox/RightColumn/WaitButton/HBox/VBox/Desc

var current_unit_id: String = ""

func _ready() -> void:
	_apply_styling()
	_connect_signals()
	_create_placeholder_portrait()
	visible = false

func _apply_styling() -> void:
	# 全体のダークゴシック調スタイル
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.09, 0.14, 0.95)
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color(0.77, 0.62, 0.30, 0.9) # 落ち着いたゴールド
	bg_style.set_corner_radius_all(8)
	bg_style.shadow_color = Color(0, 0, 0, 0.6)
	bg_style.shadow_size = 8
	bg_style.shadow_offset = Vector2(0, 4)
	bg_style.content_margin_left = 14
	bg_style.content_margin_right = 14
	bg_style.content_margin_top = 12
	bg_style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", bg_style)

	# 各ボタンのスタイル設定
	for btn in [dice_button, item_button, magic_button, wait_button, close_button]:
		if btn:
			_style_command_button(btn)

func _style_command_button(btn: Button) -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.22, 0.85)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.35, 0.40, 0.55, 0.8)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	var hover = normal.duplicate()
	hover.bg_color = Color(0.20, 0.24, 0.38, 0.95)
	hover.border_color = Color(0.95, 0.78, 0.35, 1.0) # ゴールド発光
	hover.shadow_color = Color(0.95, 0.78, 0.35, 0.3)
	hover.shadow_size = 4

	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.10, 0.12, 0.18, 1.0)
	pressed.border_color = Color(0.6, 0.5, 0.2, 1.0)

	var disabled = normal.duplicate()
	disabled.bg_color = Color(0.08, 0.08, 0.10, 0.5)
	disabled.border_color = Color(0.2, 0.2, 0.25, 0.4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	
	# ボタン内部のラベルやコンテナがクリックイベントを遮断しないように設定
	_set_mouse_filter_ignore_recursive(btn)

func _set_mouse_filter_ignore_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_mouse_filter_ignore_recursive(child)


func _connect_signals() -> void:
	dice_button.pressed.connect(func():
		DebugLogger.info("ActionCommandMenu", "ダイス移動が選択されました: unit=" + current_unit_id)
		dice_pressed.emit()
	)
	item_button.pressed.connect(func():
		DebugLogger.info("ActionCommandMenu", "アイテム使用が選択されました: unit=" + current_unit_id)
		item_pressed.emit()
	)
	magic_button.pressed.connect(func():
		DebugLogger.info("ActionCommandMenu", "魔法行使が選択されました: unit=" + current_unit_id)
		magic_pressed.emit()
	)
	wait_button.pressed.connect(func():
		DebugLogger.info("ActionCommandMenu", "待機・祈るが選択されました: unit=" + current_unit_id)
		wait_pressed.emit()
	)
	close_button.pressed.connect(func():
		close_menu()
	)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			close_menu()

func setup_unit(unit_id: String, unit_name: String, magic_name: String, magic_desc: String, can_magic: bool, is_burrowed: bool, item_count: int = 0) -> void:
	current_unit_id = unit_id
	char_name_label.text = unit_name
	
	if is_burrowed:
		status_label.text = "状態: [地中潜行中]"
		status_label.modulate = Color(0.4, 0.8, 1.0)
	else:
		status_label.text = "状態: [通常]"
		status_label.modulate = Color(0.8, 0.8, 0.8)

	magic_title_label.text = "✨ %s" % magic_name
	magic_desc_label.text = magic_desc
	magic_button.disabled = not can_magic
	if not can_magic:
		magic_desc_label.text = "%s (使用不可)" % magic_desc

	item_desc_label.text = "所持: %d 個" % item_count
	item_button.disabled = (item_count <= 0)

	if is_burrowed:
		wait_desc_label.text = "潜行状態を維持して待機"
	else:
		wait_desc_label.text = "その場で1ターンやり過ごす"

func set_portrait(texture: Texture2D) -> void:
	if portrait_rect and texture:
		portrait_rect.texture = texture

func _create_placeholder_portrait() -> void:
	# アセット未導入時用のプレースホルダー画像を動的生成（100x100）
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	var bg_col = Color(0.15, 0.18, 0.28, 1.0)
	var border_col = Color(0.77, 0.62, 0.30, 1.0)
	var inner_col = Color(0.25, 0.30, 0.45, 1.0)
	
	img.fill(bg_col)
	# 枠線
	for x in range(100):
		for y in range(100):
			if x < 3 or x >= 97 or y < 3 or y >= 97:
				img.set_pixel(x, y, border_col)
			elif x >= 20 and x <= 80 and y >= 20 and y <= 80:
				# 中央のひし形アイコン
				var dx = abs(x - 50)
				var dy = abs(y - 50)
				if dx + dy <= 25:
					img.set_pixel(x, y, border_col)
				elif dx + dy <= 28:
					img.set_pixel(x, y, inner_col)

	var tex = ImageTexture.create_from_image(img)
	portrait_rect.texture = tex

func popup_at_mouse(custom_mouse_pos: Vector2 = Vector2.ZERO) -> void:
	visible = true
	var viewport_size = get_viewport_rect().size
	var mouse_pos = custom_mouse_pos
	if mouse_pos == Vector2.ZERO:
		mouse_pos = get_viewport().get_mouse_position()
	
	# ダイスボタンの中心がマウス位置に来るように計算
	# ダイスボタンのローカル座標：左カラム(約124px) + 右カラム内(約135px) = 約260px, y方向は上部マージン+ヘッダーで約70px
	var dice_local_center = Vector2(260.0, 70.0)
	if dice_button and dice_button.size != Vector2.ZERO:
		dice_local_center = dice_button.global_position - global_position + (dice_button.size * 0.5)

	var menu_size = size
	if menu_size == Vector2.ZERO:
		menu_size = custom_minimum_size

	var target_pos = mouse_pos - dice_local_center
	target_pos.x = clamp(target_pos.x, 15.0, max(15.0, viewport_size.x - menu_size.x - 15.0))
	target_pos.y = clamp(target_pos.y, 55.0, max(55.0, viewport_size.y - menu_size.y - 15.0))
	
	global_position = target_pos
	DebugLogger.info("ActionCommandMenu", "マウス位置にダイスボタンを合わせて展開: mouse=" + str(mouse_pos) + ", menu=" + str(target_pos))

func popup_at(target_screen_pos: Vector2) -> void:
	popup_at_mouse(target_screen_pos)

func close_menu() -> void:
	if visible:
		visible = false
		DebugLogger.info("ActionCommandMenu", "コマンドメニューを閉じました（盤面確認モードへ）")
		close_pressed.emit()

