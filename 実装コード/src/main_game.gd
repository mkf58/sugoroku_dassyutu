class_name MainGame
extends Node2D

@export var cell_scene: PackedScene
@export var unit_piece_scene: PackedScene

@onready var board_view: BoardView = $BoardView
@onready var hud: HUD = $CanvasLayer/HUD
@onready var help_modal: HelpModal = $CanvasLayer/HelpModal
@onready var game_over_screen: GameOverScreen = $CanvasLayer/GameOverScreen
@onready var stage_clear_screen: StageClearScreen = $CanvasLayer/StageClearScreen
@onready var action_command_menu: ActionCommandMenu = $CanvasLayer/ActionCommandMenu
@onready var item_select_modal: ItemSelectModal = $CanvasLayer/ItemSelectModal
@onready var camera: Camera2D = $Camera2D

var tm: TurnManager
var current_dice_roll: int = 0
var reachable_cells: Dictionary = {}
var selected_path: Array[Vector2i] = []
var is_moving: bool = false
var is_dragging_camera: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var has_dragged_camera: bool = false
var pending_additional_steps: int = 0
var has_pending_additional_move: bool = false
var has_pending_roll_again: bool = false
var inventory: Array[Dictionary] = []
var current_stage_data: StageData = null
var current_acting_unit_id: String = "HERO"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				is_dragging_camera = true
				drag_start_pos = event.position
				has_dragged_camera = false
			else:
				is_dragging_camera = false
				if event.button_index == MOUSE_BUTTON_RIGHT and not has_dragged_camera:
					_on_right_click()
	elif event is InputEventMouseMotion and is_dragging_camera:
		if (event.position - drag_start_pos).length() > 4.0:
			has_dragged_camera = true
		camera.position -= event.relative / camera.zoom
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_go_back()


func _get_enemy_obstacles() -> Array[Vector2i]:
	var obstacles: Array[Vector2i] = []
	var unit = tm.characters.get(current_acting_unit_id, null)
	if unit and not unit.is_burrowed:
		for e in tm.enemies.values():
			if e.is_alive:
				obstacles.append(e.current_coord)
	return obstacles



func _ready() -> void:
	_bind_events()
	var start_id = "STAGE_1"
	if get_node_or_null("/root/SceneManager"):
		start_id = get_node("/root/SceneManager").get_param("stage_id", "STAGE_1")
	load_stage(start_id, false)

func _init_poc_stage(preserve_inventory: bool = false) -> void:
	load_stage("STAGE_1", preserve_inventory)

func load_stage(stage_id: String, preserve_inventory: bool = false) -> void:
	var stage_data = StageRepository.get_stage(stage_id)
	if not stage_data:
		DebugLogger.error("MainGame.load_stage", "ステージデータが見つかりません: %s" % stage_id)
		stage_data = StageRepository.get_stage("STAGE_1")
	current_stage_data = stage_data

	# 盤面表示・ハイライト・経路・コマを完全初期化
	board_view.clear_all()
	game_over_screen.visible = false
	stage_clear_screen.visible = false
	action_command_menu.visible = false
	item_select_modal.visible = false
	pending_additional_steps = 0
	has_pending_additional_move = false
	has_pending_roll_again = false

	# インベントリ初期化（引き継ぎ指定がない場合のみ初期ダイスをセット）
	if not preserve_inventory:
		inventory.clear()
		inventory.append({
			"id": "DICE_1_INIT",
			"name": "1の賽",
			"desc": "出目が必ず【1】になる固定ダイス",
			"value": 1,
			"type": "FIXED_DICE",
			"icon_text": "🎲"
		})

	tm = TurnManager.new()
	_bind_turn_manager_events()

	# 盤面ノードの生成
	board_view.setup_board(stage_data.board, cell_scene)

	# 主人公と少女（味方ユニット）の生成
	var characters: Array[CharacterData] = []
	var hero = CharacterData.new("HERO", "主人公", stage_data.hero_coord)
	characters.append(hero)
	board_view.add_piece(unit_piece_scene, "HERO", "主人公", stage_data.hero_coord, true, false)

	for comp in stage_data.companions:
		var c_id = comp.get("id", "GIRL")
		var c_name = comp.get("name", "少女")
		var c_elem = comp.get("element", Enums.ElementType.NONE)
		var c_coord = comp.get("coord", Vector2i(2, 3))
		# 防御的チェック：盤面にマスが存在しない座標なら主人公座標へフォールバック
		if stage_data.board and not stage_data.board.has_cell(c_coord):
			DebugLogger.error("MainGame.load_stage", "少女の初期座標にマスが存在しません。補正します", {"coord": c_coord, "fallback": stage_data.hero_coord})
			c_coord = stage_data.hero_coord
		var girl = CharacterData.new(c_id, c_name, c_coord)
		var magics: Array[Enums.ElementType] = []
		if c_elem != Enums.ElementType.NONE:
			magics.append(c_elem as Enums.ElementType)
		girl.available_magics = magics
		characters.append(girl)
		board_view.add_piece(unit_piece_scene, c_id, c_name, c_coord, false, false)

	# 魔女の生成
	var enemies: Array[EnemyData] = []
	for en in stage_data.enemies:
		var e_id = en.get("id", "WITCH")
		var e_name = en.get("name", "魔女")
		var e_type = en.get("type", Enums.EnemyType.TRACKING)
		var e_coord = en.get("coord", Vector2i(12, 3))
		if stage_data.board and not stage_data.board.has_cell(e_coord):
			DebugLogger.error("MainGame.load_stage", "魔女の初期座標にマスが存在しません。補正します", {"coord": e_coord})
		var witch = EnemyData.new(e_id, e_type, e_coord)
		enemies.append(witch)
		board_view.add_piece(unit_piece_scene, e_id, e_name, e_coord, false, true)

	# カメラ設定
	camera.position = stage_data.initial_camera_pos
	camera.zoom = stage_data.initial_camera_zoom

	tm.setup_stage(stage_data.board, characters, enemies, stage_data.stage_id)
	hud.log_message("[%s] 開始！" % stage_data.stage_name)
	_start_player_turn_flow()

func _bind_events() -> void:
	hud.roll_dice_pressed.connect(_on_roll_dice)
	hud.magic_pressed.connect(_on_magic_pressed)
	hud.wait_pressed.connect(_on_wait_pressed)
	hud.help_pressed.connect(func(): help_modal.open())
	hud.open_menu_pressed.connect(_show_action_command_menu)
	
	action_command_menu.dice_pressed.connect(_on_roll_dice)
	action_command_menu.item_pressed.connect(_on_item_menu_pressed)
	action_command_menu.magic_pressed.connect(_on_magic_pressed)
	action_command_menu.wait_pressed.connect(_on_wait_pressed)
	action_command_menu.close_pressed.connect(_on_command_menu_closed)
	
	item_select_modal.item_selected.connect(_on_item_used)
	item_select_modal.cancelled.connect(_show_action_command_menu)
	
	board_view.cell_clicked.connect(_on_cell_clicked)
	board_view.cell_hovered.connect(_on_cell_hovered)
	board_view.right_clicked.connect(_on_right_click)
	
	game_over_screen.retry_pressed.connect(_on_retry)
	game_over_screen.title_pressed.connect(_on_title_return)
	
	stage_clear_screen.retry_pressed.connect(_on_stage_clear_retry)
	stage_clear_screen.title_pressed.connect(_on_title_return)

func _bind_turn_manager_events() -> void:
	if not tm:
		return
	tm.game_over_triggered.connect(func(reason):
		action_command_menu.visible = false
		item_select_modal.visible = false
		hud.set_action_buttons_enabled(false)
		hud.log_message("[GAME OVER] " + reason)
		game_over_screen.show_game_over(reason)
	)
	
	tm.stage_cleared.connect(func(_id):
		action_command_menu.visible = false
		item_select_modal.visible = false
		hud.update_turn_info(tm.current_turn, "脱出成功！ステージクリア！")
		hud.set_action_buttons_enabled(false)
		hud.log_message("[CLEAR] EXITマスに到達！館からの脱出に成功しました！")
		if get_node_or_null("/root/SceneManager"):
			get_node("/root/SceneManager").set_param("has_cleared_stage", true)
		var has_next = current_stage_data != null and not current_stage_data.next_stage_id.is_empty()
		var s_name = current_stage_data.stage_name if current_stage_data else ""
		stage_clear_screen.show_clear(tm.current_turn, s_name, has_next)
	)

	tm.water_trap_triggered.connect(func(unit_id, coord):
		hud.log_message("[TRAP] %s が水魔術トラップ %s に侵入！残歩数破棄・即ターンエンド" % [unit_id, str(coord)])
	)

	tm.unit_killed.connect(func(unit_id):
		var cp = board_view.get_piece(unit_id)
		if cp:
			cp.visible = false
		var u = tm.characters.get(unit_id, null)
		var u_name = u.name if u else unit_id
		hud.log_message("[Kill] %s が魔女に捕まり倒された！（3ターン後に初期位置で復活）" % u_name)
	)

	tm.cell_event_triggered.connect(func(cell_data: CellData):
		_handle_cell_event(cell_data)
	)

	tm.additional_move_granted.connect(func(unit_id, steps):
		if unit_id == current_acting_unit_id:
			has_pending_additional_move = true
			pending_additional_steps = steps
	)

	tm.roll_again_granted.connect(func(unit_id):
		if unit_id == current_acting_unit_id:
			has_pending_roll_again = true
	)

	tm.returned_to_start_applied.connect(func(unit_id):
		var unit = tm.characters.get(unit_id, null)
		var p = board_view.get_piece(unit_id)
		if p and unit:
			if p.current_tween and p.current_tween.is_valid():
				p.current_tween.kill()
			p.position = Vector2(unit.initial_coord.x * 64 + 16, unit.initial_coord.y * 64 + 16)
		var u_name = unit.name if unit else unit_id
		hud.log_message("[Cell] 振り出しマス！%s はスタート位置に戻されました。" % u_name)
	)




func _start_player_turn_flow() -> void:
	tm.start_player_turn()
	current_dice_roll = 0
	reachable_cells.clear()
	selected_path.clear()
	is_moving = false
	
	# 生存中の未潜行魔女情報をログ表示
	var witch_info = ""
	for e in tm.enemies.values():
		if e.is_alive:
			witch_info += "%s:%s " % [e.enemy_id, str(e.current_coord)]
	if witch_info.is_empty():
		witch_info = "なし"
	hud.log_message("[Turn %d] プレイヤーターン開始！魔女配置: %s" % [tm.current_turn, witch_info])
	
	_start_next_player_action()

func _get_next_acting_unit_id() -> String:
	# 1. 主人公が生存・未行動・未スキップなら最優先
	if tm.characters.has("HERO"):
		var hero = tm.characters["HERO"]
		if hero.is_alive and not hero.has_acted and not hero.is_skipped:
			return "HERO"

	# 2. 同行仲間キャラ（少女たち）で生存・未行動・未スキップのユニットを探す
	for c_id in tm.characters.keys():
		if c_id == "HERO":
			continue
		var c = tm.characters[c_id]
		if c.is_alive and not c.has_acted and not c.is_skipped:
			return c_id

	return ""

func _start_next_player_action() -> void:
	var next_id = _get_next_acting_unit_id()
	if next_id.is_empty():
		# 全味方ユニットが行動完了（または行動不能）
		# 休み中ユニットのログ出力
		for c in tm.characters.values():
			if c.is_alive and c.is_skipped:
				hud.log_message("[Turn %d] %s は1回休みのため行動をスキップしました。" % [tm.current_turn, c.name])
		
		hud.log_message("[Turn %d] 全味方ユニットの行動が完了しました。魔女のターンへ移行します。" % tm.current_turn)
		_advance_to_enemy_turn()
		return

	current_acting_unit_id = next_id
	tm.select_character(current_acting_unit_id)
	
	var unit = tm.characters[current_acting_unit_id]
	hud.update_turn_info(tm.current_turn, "【%s】の行動を選択 [右クリック: 盤面確認]" % unit.name)
	hud.set_action_buttons_enabled(true)
	hud.set_action_panel_visible(false)
	hud.log_message("[Turn %d] %s の行動選択です (座標: %s)" % [tm.current_turn, unit.name, str(unit.current_coord)])
	
	# 操作キャラのピースを発光表示
	for c_id in tm.characters.keys():
		var p = board_view.get_piece(c_id)
		if p:
			p.set_active_highlight(c_id == current_acting_unit_id)

	call_deferred("_show_action_command_menu")

func _find_alive_enemies_in_range(origin_coord: Vector2i, max_distance: int) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	var list_with_dist: Array[Dictionary] = []
	for e in tm.enemies.values():
		if e.is_alive:
			var path = tm.board.find_shortest_path(origin_coord, e.current_coord) if tm.board else []
			var dist = path.size() - 1 if not path.is_empty() else 999
			if dist <= max_distance:
				list_with_dist.append({"enemy": e, "dist": dist})
	list_with_dist.sort_custom(func(a, b): return a["dist"] < b["dist"])
	for item in list_with_dist:
		result.append(item["enemy"])
	return result

func _show_action_command_menu(custom_mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if is_moving or current_dice_roll > 0:
		return
	if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
		return
	var unit = tm.characters.get(current_acting_unit_id, null)
	if not unit or not unit.is_alive or unit.has_acted:
		return
	
	# 操作中キャラの発光表示
	for c_id in tm.characters.keys():
		var p = board_view.get_piece(c_id)
		if p:
			p.set_active_highlight(c_id == current_acting_unit_id)

	# 魔法名・説明・使用可否の判定
	var magic_name = "魔法なし"
	var magic_desc = "使用可能な魔法がありません"
	var can_magic = false
	
	if current_acting_unit_id == "HERO":
		if unit.available_magics.has(Enums.ElementType.EARTH):
			magic_name = "土魔術"
			magic_desc = "地中に潜行して魔女をやり過ごす"
			can_magic = not unit.is_burrowed
		else:
			magic_name = "魔法なし"
			magic_desc = "使用可能な魔法がありません"
			can_magic = false
	elif unit.available_magics.has(Enums.ElementType.FIRE):
		magic_name = "炎魔術"
		var nearby_witches = _find_alive_enemies_in_range(unit.current_coord, 2)
		if nearby_witches.size() > 0:
			var w_names: Array[String] = []
			for w in nearby_witches:
				w_names.append(w.enemy_id)
			magic_desc = "2マス以内の魔女を撃破 (%s)" % ", ".join(w_names)
			can_magic = true
		else:
			magic_desc = "2マス以内に魔女がいません (射程2マス)"
			can_magic = false
	elif unit.available_magics.has(Enums.ElementType.WATER):
		magic_name = "水魔術"
		magic_desc = "現在地に水魔術トラップを設置"
		can_magic = true
	elif unit.available_magics.has(Enums.ElementType.WIND):
		magic_name = "風魔術"
		magic_desc = "直線の魔女または自分を吹き飛ばす"
		can_magic = true
	elif unit.available_magics.has(Enums.ElementType.EARTH):
		magic_name = "土魔術"
		magic_desc = "地中に潜行して魔女をやり過ごす"
		can_magic = not unit.is_burrowed
	
	action_command_menu.setup_unit(
		current_acting_unit_id,
		unit.name,
		magic_name,
		magic_desc,
		can_magic,
		unit.is_burrowed,
		inventory.size()
	)
	action_command_menu.popup_at_mouse(custom_mouse_pos)
	hud.update_turn_info(tm.current_turn, "【%s】の行動を選択 [右クリック: 盤面確認]" % unit.name)
	hud.set_action_panel_visible(false)

func _on_command_menu_closed() -> void:
	# 盤面確認モード時はキャラ発光を標準に戻す
	var p = board_view.get_piece(current_acting_unit_id)
	if p:
		p.set_active_highlight(false)
	hud.update_turn_info(tm.current_turn, "盤面確認中 [味方キャラまたは右クリックで行動選択]")
	DebugLogger.info("MainGame._on_command_menu_closed", "盤面確認モードへ移行")

func _on_item_menu_pressed() -> void:
	action_command_menu.visible = false
	item_select_modal.open(inventory)

func _on_item_used(item_id: String) -> void:
	var used_item: Dictionary = {}
	var index_to_remove = -1
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			used_item = inventory[i]
			index_to_remove = i
			break
	if index_to_remove >= 0:
		inventory.remove_at(index_to_remove)
	
	if used_item.is_empty():
		DebugLogger.error("MainGame._on_item_used", "指定されたアイテムが見つかりません", {"id": item_id})
		_show_action_command_menu()
		return
		
	var dice_val = used_item.get("value", 1)
	current_dice_roll = dice_val
	hud.show_dice_result(current_dice_roll)
	
	var unit = tm.characters[current_acting_unit_id]
	var obstacles = _get_enemy_obstacles()
	var raw_reachables = tm.board.get_reachable_cells_with_steps(unit.current_coord, current_dice_roll, obstacles)
	reachable_cells = _filter_reachable_cells(raw_reachables)
	board_view.clear_highlights()
	for c in reachable_cells.keys():
		board_view.set_cell_highlight(c, true, Color(0.3, 0.8, 1.0, 0.8))
		
	hud.update_turn_info(tm.current_turn, "【%s】使用！%sの移動先をクリック (出目: %d)" % [used_item.get("name", "賽"), unit.name, current_dice_roll])
	hud.log_message("[Item] 【%s】を使用！出目 %d が確定しました。(残り所持: %d個)" % [used_item.get("name", "賽"), current_dice_roll, inventory.size()])
	DebugLogger.info("MainGame._on_item_used", "アイテム使用完了: " + str(used_item.get("name", "")))

func _handle_cell_event(cell_data: CellData) -> void:
	# 宝箱マスでランダムな固定ダイスを獲得
	var random_val = randi_range(1, 6)
	var item_data = {
		"id": "DICE_%d_%d" % [random_val, Time.get_ticks_msec()],
		"name": "%dの賽" % random_val,
		"desc": "出目が必ず【%d】になる固定ダイス" % random_val,
		"value": random_val,
		"type": "FIXED_DICE",
		"icon_text": "🎲"
	}
	inventory.append(item_data)
	hud.log_message("[Chest] 宝箱を開けた！【%dの賽】を手に入れた！(所持: %d個)" % [random_val, inventory.size()])
	DebugLogger.info("MainGame._handle_cell_event", "宝箱マスでアイテム入手: " + item_data.name)

## 他の生存味方ユニットが存在するマスを最終停止候補から除外（同じマスに重複停止不可）
func _filter_reachable_cells(reachables: Dictionary) -> Dictionary:
	var filtered = reachables.duplicate()
	for c in tm.characters.values():
		if c.character_id != current_acting_unit_id and c.is_alive:
			filtered.erase(c.current_coord)
	return filtered

func _on_roll_dice() -> void:
	if is_moving:
		DebugLogger.warn("MainGame._on_roll_dice", "コマ移動中のためダイスを振れません")
		return
	if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
		DebugLogger.warn("MainGame._on_roll_dice", "行動選択フェーズ以外ではダイスを振れません", {"phase": tm.current_phase})
		return
		
	action_command_menu.visible = false
	current_dice_roll = randi_range(1, 6)
	hud.show_dice_result(current_dice_roll)
	
	var unit = tm.characters[current_acting_unit_id]
	var obstacles = _get_enemy_obstacles()
	var raw_reachables = tm.board.get_reachable_cells_with_steps(unit.current_coord, current_dice_roll, obstacles)
	reachable_cells = _filter_reachable_cells(raw_reachables)
	board_view.clear_highlights()
	for c in reachable_cells.keys():
		board_view.set_cell_highlight(c, true, Color(0.3, 0.8, 1.0, 0.8))
		
	hud.update_turn_info(tm.current_turn, "【%s】移動先をクリック (出目: %d)" % [unit.name, current_dice_roll])
	hud.set_action_buttons_enabled(false)
	DebugLogger.info("MainGame._on_roll_dice", "%s ダイス出目 %d (到達可能マス: %d箇所)" % [unit.name, current_dice_roll, reachable_cells.size()])

func _on_cell_hovered(coord: Vector2i) -> void:
	if is_moving or current_dice_roll <= 0:
		return
	if reachable_cells.has(coord):
		var unit = tm.characters[current_acting_unit_id]
		var obstacles = _get_enemy_obstacles()
		var preview_path = tm.board.find_path_with_steps(unit.current_coord, coord, current_dice_roll, obstacles)
		if not preview_path.is_empty():
			board_view.update_route_preview(preview_path)

func _on_magic_pressed() -> void:
	if is_moving:
		DebugLogger.warn("MainGame._on_magic_pressed", "コマ移動中のため魔法を発動できません")
		return
	if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
		DebugLogger.warn("MainGame._on_magic_pressed", "行動選択フェーズ以外では魔法を発動できません", {"phase": tm.current_phase})
		return
		
	action_command_menu.visible = false
	var unit = tm.characters.get(current_acting_unit_id, null)
	if not unit:
		return
		
	var piece = board_view.get_piece(current_acting_unit_id)

	if unit.available_magics.has(Enums.ElementType.FIRE):
		var nearby_witches = _find_alive_enemies_in_range(unit.current_coord, 2)
		if nearby_witches.is_empty():
			DebugLogger.warn("MainGame._on_magic_pressed", "2マス以内に魔女が存在しません")
			_show_action_command_menu()
			return
		var target_witch = nearby_witches[0]
		var ok = tm.execute_magic(current_acting_unit_id, Enums.ElementType.FIRE, target_witch.current_coord)
		if ok:
			if piece:
				piece.set_burrowed(false)
			var wp = board_view.get_piece(target_witch.enemy_id)
			if wp:
				wp.visible = false
			hud.log_message("[Magic] 【炎魔術】発動！%s が %s を撃破しました！（2ターン後に復活）" % [unit.name, target_witch.enemy_id])
			DebugLogger.info("MainGame._on_magic_pressed", "炎魔術発動成功: target=" + target_witch.enemy_id)
		_on_unit_action_finished(current_acting_unit_id)
		
	elif unit.available_magics.has(Enums.ElementType.WATER):
		var ok = tm.execute_magic(current_acting_unit_id, Enums.ElementType.WATER, unit.current_coord)
		if ok:
			if piece:
				piece.set_burrowed(false)
			hud.log_message("[Magic] 【水魔術】発動！座標 %s を水トラップマスに変化させました。" % str(unit.current_coord))
			var cell_node = board_view.cell_nodes.get(unit.current_coord, null)
			if cell_node:
				cell_node.setup(tm.board.get_cell(unit.current_coord))
		_on_unit_action_finished(current_acting_unit_id)
		
	elif unit.available_magics.has(Enums.ElementType.EARTH):
		unit.is_burrowed = true
		if piece:
			piece.set_burrowed(true)
		unit.has_acted = true
		hud.update_turn_info(tm.current_turn, "【%s】土魔術で地中に潜行した！" % unit.name)
		hud.log_message("[Magic] %s が土魔術で地中に潜行しました（魔女をやり過ごせます）。" % unit.name)
		_on_unit_action_finished(current_acting_unit_id)
		
	elif unit.available_magics.has(Enums.ElementType.WIND):
		if piece:
			piece.set_burrowed(false)
		unit.has_acted = true
		hud.log_message("[Magic] %s が風魔術を行使しました。" % unit.name)
		_on_unit_action_finished(current_acting_unit_id)
		
	else:
		DebugLogger.warn("MainGame._on_magic_pressed", "使用可能な魔法がありません", {"unit_id": current_acting_unit_id})
		_show_action_command_menu()

func _on_wait_pressed() -> void:
	if is_moving:
		DebugLogger.warn("MainGame._on_wait_pressed", "コマ移動中のため待機できません")
		return
	if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
		DebugLogger.warn("MainGame._on_wait_pressed", "行動選択フェーズ以外では待機できません", {"phase": tm.current_phase})
		return
		
	action_command_menu.visible = false
	var unit = tm.characters.get(current_acting_unit_id, null)
	var u_name = unit.name if unit else current_acting_unit_id
	tm.execute_wait(current_acting_unit_id)
	hud.update_turn_info(tm.current_turn, "【%s】祈りを捧げて待機した" % u_name)
	hud.log_message("[Wait] %s は祈りを捧げてその場で待機しました。" % u_name)
	DebugLogger.info("MainGame._on_wait_pressed", "%s は待機しました" % u_name)
	_on_unit_action_finished(current_acting_unit_id)

func _on_cell_clicked(coord: Vector2i) -> void:
	if is_moving:
		var p = board_view.get_piece(current_acting_unit_id)
		if p and selected_path.size() > 0:
			p.skip_current_move(selected_path[-1])
			DebugLogger.info("MainGame._on_cell_clicked", "クリックにより移動アニメーションをスキップ")
		return

	if current_dice_roll <= 0:
		# コマンド選択前：クリックしたマスに未行動の味方ユニットがいればそのキャラに切り替え
		for c in tm.characters.values():
			if c.is_alive and not c.has_acted and not c.is_skipped and c.current_coord == coord:
				current_acting_unit_id = c.character_id
				tm.select_character(current_acting_unit_id)
				hud.log_message("[Select] 操作ユニットを【%s】に切り替えました。" % c.name)
				_show_action_command_menu()
				return
				
		if not action_command_menu.visible:
			_show_action_command_menu()
		return

	if not reachable_cells.has(coord):
		DebugLogger.warn("MainGame._on_cell_clicked", "指定マスはこの出目では移動できません", {"clicked_coord": coord, "dice_roll": current_dice_roll})
		return

	var unit = tm.characters[current_acting_unit_id]
	var obstacles = _get_enemy_obstacles()
	selected_path = tm.board.find_path_with_steps(unit.current_coord, coord, current_dice_roll, obstacles)
	if selected_path.is_empty():
		DebugLogger.error("MainGame._on_cell_clicked", "移動経路の生成に失敗しました", {"from": unit.current_coord, "to": coord, "steps": current_dice_roll})
		return

	board_view.update_route_preview(selected_path)
	DebugLogger.info("MainGame._on_cell_clicked", "移動開始: %s -> %s (歩数: %d)" % [str(unit.current_coord), str(coord), current_dice_roll])
	_start_unit_movement(current_acting_unit_id, selected_path)

func _on_right_click() -> void:
	_go_back()

func _go_back() -> void:
	if is_moving:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	
	# 1. ヘルプモーダルが開いている場合
	if help_modal and help_modal.visible:
		help_modal.visible = false
		DebugLogger.info("MainGame._go_back", "ヘルプモーダルを閉じました")
		return

	# 2. アイテム選択モーダルが開いている場合
	if item_select_modal and item_select_modal.visible:
		item_select_modal.visible = false
		_show_action_command_menu(mouse_pos)
		DebugLogger.info("MainGame._go_back", "アイテムモーダルからコマンドメニューへ復帰")
		return

	# 3. 移動先選択中（出目確定後）の場合：出目キャンセルは不可（移動必須）
	if current_dice_roll > 0:
		DebugLogger.info("MainGame._go_back", "出目確定後のためキャンセル不可（移動先を選択してください）")
		return
	
	# 4. コマンドメニューが開いている場合：閉じて盤面確認モードへ
	if action_command_menu and action_command_menu.visible:
		action_command_menu.close_menu()
		DebugLogger.info("MainGame._go_back", "コマンドメニューを閉じて盤面確認モードへ")
		return
		
	# 5. 盤面確認モード中の場合：マウスポインタ位置にコマンドメニューを再展開
	_show_action_command_menu(mouse_pos)
	DebugLogger.info("MainGame._go_back", "盤面確認モードからコマンドメニューを再展開")

func _start_unit_movement(unit_id: String, path: Array[Vector2i]) -> void:
	is_moving = true
	board_view.clear_highlights()
	board_view.clear_route_preview()
	
	var unit = tm.characters[unit_id]
	var unit_piece = board_view.get_piece(unit_id)
	if not unit_piece:
		DebugLogger.error("MainGame._start_unit_movement", "UnitPieceが存在しません", {"id": unit_id})
		is_moving = false
		return
	
	unit_piece.animate_path(
		path,
		func(to_coord: Vector2i, remaining: int):
			return tm.step_unit(unit, to_coord, remaining),
		func():
			is_moving = false
			current_dice_roll = 0
			hud.hide_dice_result()
			unit_piece.position = Vector2(unit.current_coord.x * 64 + 16, unit.current_coord.y * 64 + 16)
			# 移動完了：潜行解除（地上出現）をピース表示にも反映
			if not unit.is_burrowed:
				unit_piece.set_burrowed(false)
			hud.log_message("[Move] %s が %s に停止しました。" % [unit.name, str(unit.current_coord)])
			if tm.current_phase != Enums.TurnPhase.GAME_OVER and tm.current_phase != Enums.TurnPhase.STAGE_CLEAR:
				if has_pending_additional_move:
					has_pending_additional_move = false
					hud.log_message("[Cell] +%dマスに停止！追加で%dマス移動します！" % [pending_additional_steps, pending_additional_steps])
					_trigger_additional_move(pending_additional_steps)
				elif has_pending_roll_again:
					has_pending_roll_again = false
					hud.log_message("[Cell] もう1回マスに停止！ダイスをもう一度振れます！")
					hud.update_turn_info(tm.current_turn, "もう1回！ダイスを振ってください")
					hud.set_action_buttons_enabled(true)
				else:
					_on_unit_action_finished(unit_id)
	)

func _trigger_additional_move(steps: int) -> void:
	current_dice_roll = steps
	hud.show_dice_result(current_dice_roll)
	var unit = tm.characters[current_acting_unit_id]
	var obstacles = _get_enemy_obstacles()
	var raw_reachables = tm.board.get_reachable_cells_with_steps(unit.current_coord, current_dice_roll, obstacles)
	reachable_cells = _filter_reachable_cells(raw_reachables)
	board_view.clear_highlights()
	for c in reachable_cells.keys():
		board_view.set_cell_highlight(c, true, Color(0.3, 0.8, 1.0, 0.8))
	hud.update_turn_info(tm.current_turn, "追加移動！(+%dマス) 移動先をクリック" % steps)
	hud.set_action_buttons_enabled(false)
	DebugLogger.info("MainGame._trigger_additional_move", "追加移動発動: +%dマス (到達可能マス: %d箇所)" % [steps, reachable_cells.size()])

func _on_unit_action_finished(unit_id: String) -> void:
	var unit = tm.characters.get(unit_id, null)
	if unit:
		unit.has_acted = true
	var p = board_view.get_piece(unit_id)
	if p:
		p.set_active_highlight(false)
		
	# 次の未行動味方ユニットへ進む（全員行動済みなら魔女ターンへ）
	_start_next_player_action()


func _advance_to_enemy_turn() -> void:
	hud.set_action_buttons_enabled(false)
	hud.update_turn_info(tm.current_turn, "魔女の行動中...")
	hud.log_message("[Enemy] 魔女のターン開始。思考中...")
	
	var alive_enemies: Array[EnemyData] = []
	for e in tm.enemies.values():
		if e.is_alive and e.stun_turns <= 0:
			alive_enemies.append(e)
			
	if alive_enemies.is_empty():
		hud.log_message("[Enemy] 行動可能な魔女が存在しないため、魔女ターンを終了します。")
		_on_enemy_turn_finished()
		return
		
	_process_enemy_actions(alive_enemies, 0)

func _process_enemy_actions(enemy_list: Array[EnemyData], index: int) -> void:
	if tm.current_phase == Enums.TurnPhase.GAME_OVER:
		return
	if index >= enemy_list.size():
		_on_enemy_turn_finished()
		return
		
	var witch = enemy_list[index]
	var witch_piece = board_view.get_piece(witch.enemy_id)
	var target = tm.select_witch_target(witch)
	
	var target_coord: Vector2i = Vector2i.ZERO
	if target and witch_piece:
		witch_piece.set_target_name(target.name)
		target_coord = target.current_coord
		var path_to_target = tm.board.find_shortest_path(witch.current_coord, target_coord)
		var dist = path_to_target.size() - 1 if not path_to_target.is_empty() else 99
		hud.log_message("[Enemy] %s ターゲット: %s (距離: %dマス)" % [witch.enemy_id, target.name, dist])
	else:
		if witch_piece:
			witch_piece.set_target_name("帰還中")
		target_coord = witch.initial_coord
		hud.log_message("[Enemy] %s は対象を見失いました。初期位置 %s へ帰還移動します。" % [witch.enemy_id, str(target_coord)])

	# 魔女の移動処理（ターゲット追跡 または 初期位置帰還）
	var path = tm.board.find_shortest_path(witch.current_coord, target_coord)
	var witch_steps = 2
	var actual_path: Array[Vector2i] = []
	for i in range(min(path.size(), witch_steps + 1)):
		actual_path.append(path[i])
		
	if actual_path.size() > 1 and witch_piece:
		hud.log_message("[Enemy] %s が %s から %s へ移動開始" % [witch.enemy_id, str(witch.current_coord), str(actual_path[-1])])
		witch_piece.animate_path(
			actual_path,
			func(to_c: Vector2i, _rem: int):
				witch.current_coord = to_c
				# 1. 水魔術トラップ判定
				var cell = tm.board.get_cell(to_c)
				if cell and cell.cell_type == Enums.CellType.WATER_TRAP:
					hud.log_message("[TRAP] %s が水魔術トラップ %s に捕まり、移動が停止した！" % [witch.enemy_id, str(to_c)])
					DebugLogger.info("MainGame._process_enemy_actions", "魔女が水魔術トラップで移動停止", {"coord": to_c})
					return {"result": "WATER_TRAP_STOP"}
				# 2. 味方ユニットとの接触判定
				for c in tm.characters.values():
					if c.is_alive and c.current_coord == to_c:
						if not c.is_burrowed:
							if c.character_id == "HERO":
								tm.current_phase = Enums.TurnPhase.GAME_OVER
								tm.emit_signal("game_over_triggered", "魔女に背後から追いつかれた")
								return {"result": "GAME_OVER"}
							else:
								c.kill()
								tm.emit_signal("unit_killed", c.character_id)
								hud.log_message("[Kill] %s が魔女に捕まり倒された！" % c.name)
								var cp = board_view.get_piece(c.character_id)
								if cp:
									cp.visible = false
								return {"result": "GIRL_DIED"}
				return {"result": "CONTINUE"},
			func():
				_process_enemy_actions(enemy_list, index + 1)
		)
	else:
		hud.log_message("[Enemy] %s は移動先がありませんでした。" % witch.enemy_id)
		_process_enemy_actions(enemy_list, index + 1)

func _on_enemy_turn_finished() -> void:
	if tm.current_phase == Enums.TurnPhase.GAME_OVER:
		return
		
	# 次のターンへ進行（少女・魔女の復活カウント更新、ターン数+1）
	tm.end_turn_and_advance()
	
	# 味方ユニットの潜行解除・復活グラフィック同期
	for c in tm.characters.values():
		var cp = board_view.get_piece(c.character_id)
		if cp:
			if c.is_alive and not cp.visible:
				cp.visible = true
				cp.position = Vector2(c.current_coord.x * 64 + 16, c.current_coord.y * 64 + 16)
				hud.log_message("[Revive] %s が初期位置で復活しました！" % c.name)
			if not c.is_burrowed:
				cp.set_burrowed(false)
				
	# 魔女の復活同期
	for e in tm.enemies.values():
		var ep = board_view.get_piece(e.enemy_id)
		if ep:
			if e.is_alive and not ep.visible:
				ep.visible = true
				ep.position = Vector2(e.current_coord.x * 64 + 16, e.current_coord.y * 64 + 16)
				hud.log_message("[Revive] 魔女 %s が初期位置で復活しました！" % e.enemy_id)

	# プレイヤーターン開始フローを実行
	_start_player_turn_flow()


func _on_retry() -> void:
	game_over_screen.visible = false
	stage_clear_screen.visible = false
	action_command_menu.visible = false
	item_select_modal.visible = false
	hud.set_action_buttons_enabled(true)
	hud.log_message("[Retry] このステージを最初からやり直します。")
	var current_id = current_stage_data.stage_id if current_stage_data else "STAGE_1"
	load_stage(current_id, false)

func _on_stage_clear_retry() -> void:
	game_over_screen.visible = false
	stage_clear_screen.visible = false
	action_command_menu.visible = false
	item_select_modal.visible = false
	hud.set_action_buttons_enabled(true)
	if current_stage_data and not current_stage_data.next_stage_id.is_empty():
		hud.log_message("[Next Stage] 次の階層へ進みます: %s" % current_stage_data.next_stage_id)
		if get_node_or_null("/root/SceneManager"):
			get_node("/root/SceneManager").set_param("stage_id", current_stage_data.next_stage_id)
		load_stage(current_stage_data.next_stage_id, true)
	else:
		hud.log_message("[Clear Finish] 全階層脱出完了！最初からやり直します。")
		load_stage("STAGE_1", false)

func _on_title_return() -> void:

	DebugLogger.info("MainGame._on_title_return", "タイトル画面へ遷移します")
	if get_node_or_null("/root/SceneManager"):
		get_node("/root/SceneManager").change_to_title()
	else:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
