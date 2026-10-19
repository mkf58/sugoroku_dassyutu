class_name ItemSelectModal
extends Control

signal item_selected(item_id: String)
signal cancelled()

@onready var item_list_container: VBoxContainer = $Panel/ScrollContainer/ItemListContainer
@onready var close_btn: Button = $Panel/CloseButton
@onready var empty_label: Label = $Panel/EmptyLabel

func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_on_close_pressed)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.14, 0.96)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(0.77, 0.62, 0.30, 0.9)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 10
	$Panel.add_theme_stylebox_override("panel", panel_style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			_on_close_pressed()

func _on_close_pressed() -> void:
	visible = false
	cancelled.emit()

func open(items: Array[Dictionary]) -> void:
	visible = true
	# 既存の行をクリア
	for child in item_list_container.get_children():
		child.queue_free()

	if items.is_empty():
		empty_label.visible = true
	else:
		empty_label.visible = false
		for item in items:
			var row = _create_item_row(item)
			item_list_container.add_child(row)

func _create_item_row(item: Dictionary) -> PanelContainer:
	var row_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.22, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.40, 0.55, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	row_panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row_panel.add_child(hbox)

	# 左：小さな絵・アイコンプレースホルダー
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _create_placeholder_icon(item.get("icon_text", "🎲"))
	hbox.add_child(icon_rect)

	# 中央：文章（名前＋説明文）
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var name_label = Label.new()
	name_label.text = item.get("name", "アイテム")
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = item.get("desc", "説明文")
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	desc_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(desc_label)

	# 右：「使う」ボタン
	var use_btn = Button.new()
	use_btn.text = "使う"
	use_btn.custom_minimum_size = Vector2(70, 32)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.20, 0.28, 0.45, 0.9)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.77, 0.62, 0.30, 0.9)
	btn_style.set_corner_radius_all(4)
	use_btn.add_theme_stylebox_override("normal", btn_style)
	
	var item_id = item.get("id", "")
	use_btn.pressed.connect(func():
		visible = false
		item_selected.emit(item_id)
	)
	hbox.add_child(use_btn)

	return row_panel

func _create_placeholder_icon(symbol: String) -> Texture2D:
	var img = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	var bg = Color(0.18, 0.22, 0.32, 1.0)
	var border = Color(0.77, 0.62, 0.30, 1.0)
	img.fill(bg)
	for x in range(36):
		for y in range(36):
			if x < 2 or x >= 34 or y < 2 or y >= 34:
				img.set_pixel(x, y, border)
	return ImageTexture.create_from_image(img)
