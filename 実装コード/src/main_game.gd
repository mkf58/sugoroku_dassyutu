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

# セーブ対象のステージ間引き継ぎ状態（inventory と併せて保存される）
var active_slot: int = 1
var visited_event_ids: Array = []
var progress_flags: Dictionary = {}
var clear_flags: Dictionary = {}
var achievement_counters: Dictionary = {}
var is_enemy_turn: bool = false
var suspend_btn: Button = null
var is_selecting_water_target: bool = false   ## 水魔術の設置先を選択中
var water_target_cells: Array[Vector2i] = []
enum WindSelect { NONE, TARGET, DIRECTION }
var wind_select_state: WindSelect = WindSelect.NONE  ## 風魔術の選択段階
var wind_target_ids: Array[String] = []
var wind_target_id: String = ""
var wind_landing_map: Dictionary = {}   ## 着地マス -> 方向
var moving_piece_id: String = ""        ## 移動アニメ中のピース（空なら操作中キャラ）
var is_selecting_earth_target: bool = false   ## 土魔術の対象を選択中
var earth_target_ids: Array[String] = []
const EARTH_MENU_DESC = "射程6マス以内の味方を潜らせる／魔女を1ターン止める"

## 魔法の対象・設置先を選択中か（コマンドメニュー表示・中断セーブを止める）
func _is_selecting_magic_target() -> bool:
	return is_selecting_water_target or wind_select_state != WindSelect.NONE or is_selecting_earth_target


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
			if e.is_dangerous():  # スタン中の魔女は無害なので通れる
				obstacles.append(e.current_coord)
	return obstacles



func _ready() -> void:
	_bind_events()
	_create_suspend_button()
	var start_id = "STAGE_1"
	var resume: SaveData = null
	var suspend: SuspendData = null
	var sm = get_node_or_null("/root/SceneManager")
	if sm:
		start_id = sm.get_param("stage_id", "STAGE_1")
		active_slot = int(sm.get_param("active_slot", 1))
		resume = sm.get_param("resume_save", null)
		suspend = sm.get_param("resume_suspend", null)
		sm.set_param("resume_save", null)
		sm.set_param("resume_suspend", null)
	if suspend != null:
		_resume_from_suspend(suspend)
	elif resume != null:
		_apply_save_data(resume)
		load_stage(resume.next_stage_id, true)
	else:
		# タイトルを経由せずに直接起動された場合（開発用）：スロットに初期セーブを作って開始する
		_start_new_run(start_id)

## 新しい周回を開始：active_slot に初期セーブを作成し、そこから開始する
func _start_new_run(first_stage_id: String = "STAGE_1") -> void:
	var data = SaveData.new_game(first_stage_id)
	if not SaveManager.save_slot(active_slot, data):
		DebugLogger.error("MainGame._start_new_run", "初期セーブの作成に失敗しました", {"slot": active_slot})
	_apply_save_data(data)
	load_stage(first_stage_id, true)

## セーブ（ステージ開始時の状態）をロードしてやり直す。リトライ・タイトル復帰後の「つづきから」と同じ挙動。
func _restore_checkpoint() -> void:
	var data = SaveManager.load_slot(active_slot)
	if data == null:
		DebugLogger.error("MainGame._restore_checkpoint", "セーブの読込に失敗しました。最初から開始します", {"slot": active_slot})
		_start_new_run("STAGE_1")
		return
	_apply_save_data(data)
	hud.log_message("[Load] スロット%dのセーブから再開します。" % active_slot)
	load_stage(data.next_stage_id, true)
## セーブデータの内容を引き継ぎ状態へ反映する
func _apply_save_data(data: SaveData) -> void:
	inventory = data.inventory.duplicate(true)
	visited_event_ids = data.visited_event_ids.duplicate()
	progress_flags = data.progress_flags.duplicate(true)
	clear_flags = data.clear_flags.duplicate(true)
	achievement_counters = data.achievement_counters.duplicate(true)

## 現在の引き継ぎ状態からセーブデータを生成する（ステージクリア時用）
func _build_save_data() -> SaveData:
	var data = SaveData.new()
	data.saved_at = Time.get_datetime_string_from_system(false, true)
	data.next_stage_id = current_stage_data.next_stage_id if current_stage_data else ""
	data.cleared_stage_name = current_stage_data.stage_name if current_stage_data else ""
	data.inventory = inventory.duplicate(true)
	data.visited_event_ids = visited_event_ids.duplicate()
	data.progress_flags = progress_flags.duplicate(true)
	data.clear_flags = clear_flags.duplicate(true)
	data.achievement_counters = achievement_counters.duplicate(true)
	return data

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
		inventory = SaveData.initial_inventory()

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
		var has_next = current_stage_data != null and not current_stage_data.next_stage_id.is_empty()
		if current_stage_data:
			clear_flags[current_stage_data.stage_id] = true
		# ステージクリア時のオートセーブ（次ステージが存在する場合のみ）
		if has_next:
			if SaveManager.save_slot(active_slot, _build_save_data()):
				hud.log_message("[Save] スロット%dにオートセーブしました。" % active_slot)
			else:
				hud.log_message("[Save] オートセーブに失敗しました。")
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
	is_enemy_turn = false
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
	if is_moving or current_dice_roll > 0 or _is_selecting_magic_target():
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
			can_magic = not tm.get_earth_targets(current_acting_unit_id).is_empty()
			magic_desc = EARTH_MENU_DESC if can_magic else "土魔術の対象がいません"
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
		can_magic = not tm.get_water_trap_targets(current_acting_unit_id).is_empty()
		magic_desc = "選んだマスに水魔術トラップを設置" if can_magic else "水魔術トラップを置けるマスがありません"
	elif unit.available_magics.has(Enums.ElementType.WIND):
		magic_name = "風魔術"
		can_magic = not tm.get_wind_targets(current_acting_unit_id).is_empty()
		magic_desc = "選んだユニットを直線の最も遠いマスまで吹き飛ばす" if can_magic else "吹き飛ばせるユニットがいません"
	elif unit.available_magics.has(Enums.ElementType.EARTH):
		magic_name = "土魔術"
		can_magic = not tm.get_earth_targets(current_acting_unit_id).is_empty()
		magic_desc = EARTH_MENU_DESC if can_magic else "土魔術の対象がいません"
	
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
	# 踏んだイベントマスを記録（セーブ対象）
	var stage_key = current_stage_data.stage_id if current_stage_data else ""
	var ev_key = cell_data.event_id if not cell_data.event_id.is_empty() else "%s_%d_%d" % [stage_key, cell_data.coord.x, cell_data.coord.y]
	if not visited_event_ids.has(ev_key):
		visited_event_ids.append(ev_key)
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
	if not is_moving and wind_select_state == WindSelect.DIRECTION:
		# 風魔術の着地マス上：吹き飛ぶ経路をプレビュー
		if wind_landing_map.has(coord):
			board_view.update_route_preview(tm.compute_wind_blow(wind_target_id, wind_landing_map[coord])["path"])
		return
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
		_begin_water_target_selection()

	elif unit.available_magics.has(Enums.ElementType.EARTH):
		_begin_earth_target_selection()
		
	elif unit.available_magics.has(Enums.ElementType.WIND):
		_begin_wind_target_selection()

	else:
		DebugLogger.warn("MainGame._on_magic_pressed", "使用可能な魔法がありません", {"unit_id": current_acting_unit_id})
		_show_action_command_menu()

## 水魔術：設置可能マスをハイライトし、設置先の選択モードへ入る
func _begin_water_target_selection() -> void:
	water_target_cells = tm.get_water_trap_targets(current_acting_unit_id)
	if water_target_cells.is_empty():
		DebugLogger.warn("MainGame._begin_water_target_selection", "水魔術トラップを置けるマスがありません")
		_show_action_command_menu()
		return
	is_selecting_water_target = true
	board_view.clear_highlights()
	for c in water_target_cells:
		board_view.set_cell_highlight(c, true, Color(0.2, 0.5, 1.0, 0.9))
	var unit = tm.characters[current_acting_unit_id]
	hud.update_turn_info(tm.current_turn, "【%s】水魔術トラップの設置先をクリック [右クリック: 戻る]" % unit.name)
	hud.set_action_buttons_enabled(false)

## 水魔術：設置先の選択を終了する（ハイライト解除）
func _end_water_target_selection() -> void:
	is_selecting_water_target = false
	water_target_cells.clear()
	board_view.clear_highlights()

## 水魔術：選んだマスにトラップを設置して行動終了
func _place_water_trap(coord: Vector2i) -> void:
	var unit = tm.characters[current_acting_unit_id]
	_end_water_target_selection()
	if not tm.execute_magic(current_acting_unit_id, Enums.ElementType.WATER, coord):
		hud.log_message("[Magic] そのマスには水魔術トラップを設置できません。")
		_show_action_command_menu()
		return
	var piece = board_view.get_piece(current_acting_unit_id)
	if piece:
		piece.set_burrowed(false)
	var cell_node = board_view.cell_nodes.get(coord, null)
	if cell_node:
		cell_node.setup(tm.board.get_cell(coord))
	hud.log_message("[Magic] 【水魔術】発動！%s が座標 %s を水トラップマスに変化させました。" % [unit.name, str(coord)])
	_on_unit_action_finished(current_acting_unit_id)

## 風魔術：対象にできるユニットのマスをハイライトし、対象選択モードへ入る
func _begin_wind_target_selection() -> void:
	wind_target_ids = tm.get_wind_targets(current_acting_unit_id)
	if wind_target_ids.is_empty():
		DebugLogger.warn("MainGame._begin_wind_target_selection", "風魔術で吹き飛ばせるユニットがいません")
		_end_wind_selection()
		_show_action_command_menu()
		return
	wind_select_state = WindSelect.TARGET
	wind_target_id = ""
	wind_landing_map.clear()
	board_view.clear_highlights()
	board_view.clear_route_preview()
	for uid in wind_target_ids:
		var u = tm.get_unit(uid)
		if u:
			board_view.set_cell_highlight(u.current_coord, true, Color(0.4, 1.0, 0.6, 0.9))
	var caster = tm.characters[current_acting_unit_id]
	hud.update_turn_info(tm.current_turn, "【%s】風魔術で吹き飛ばすユニットをクリック [右クリック: 戻る]" % caster.name)
	hud.set_action_buttons_enabled(false)

## 風魔術：指定ユニットの着地マス（方向ごと）をハイライトし、方向選択モードへ入る
func _begin_wind_direction_selection(unit_id: String) -> void:
	wind_select_state = WindSelect.DIRECTION
	wind_target_id = unit_id
	wind_landing_map.clear()
	board_view.clear_highlights()
	board_view.clear_route_preview()
	var u = tm.get_unit(unit_id)
	if u:
		board_view.set_cell_highlight(u.current_coord, true, Color(0.4, 1.0, 0.6, 0.9))
	for d in tm.get_wind_directions(unit_id):
		var blow = tm.compute_wind_blow(unit_id, d)
		wind_landing_map[blow["to"]] = d
		board_view.set_cell_highlight(blow["to"], true, Color(1.0, 0.6, 0.2, 0.9))
	hud.update_turn_info(tm.current_turn, "吹き飛ばす先（着地マス）をクリック [右クリック: 対象選択へ戻る]")

## 風魔術：選択を終了する（ハイライト・経路プレビュー解除）
func _end_wind_selection() -> void:
	wind_select_state = WindSelect.NONE
	wind_target_ids.clear()
	wind_target_id = ""
	wind_landing_map.clear()
	board_view.clear_highlights()
	board_view.clear_route_preview()

## 風魔術：クリックしたマスにいる対象ユニットIDを返す（いなければ ""）
func _find_wind_target_at(coord: Vector2i) -> String:
	for uid in wind_target_ids:
		var u = tm.get_unit(uid)
		if u and u.current_coord == coord:
			return uid
	return ""

## 風魔術：盤面クリック時の処理（対象選択 / 着地マス選択）
func _on_wind_cell_clicked(coord: Vector2i) -> void:
	if wind_select_state == WindSelect.DIRECTION and wind_landing_map.has(coord):
		_execute_wind(wind_landing_map[coord])
		return
	var uid = _find_wind_target_at(coord)
	if not uid.is_empty():
		_begin_wind_direction_selection(uid)
	else:
		DebugLogger.warn("MainGame._on_wind_cell_clicked", "風魔術の対象・着地マスではありません", {"clicked_coord": coord})

## 風魔術：選んだ方向へ吹き飛ばし、アニメーション後に行動終了
func _execute_wind(dir: Vector2i) -> void:
	var target_id = wind_target_id
	var caster = tm.characters[current_acting_unit_id]
	_end_wind_selection()
	var res = tm.execute_wind(current_acting_unit_id, target_id, dir)
	if res.get("result") == "ERROR":
		hud.log_message("[Magic] 風魔術を発動できませんでした。")
		_show_action_command_menu()
		return
	var caster_piece = board_view.get_piece(current_acting_unit_id)
	if caster_piece:
		caster_piece.set_burrowed(false)
	var target_unit = tm.get_unit(target_id)
	var t_name = target_unit.name if target_id in tm.characters else target_id
	hud.log_message("[Magic] 【風魔術】発動！%s が %s を %s まで吹き飛ばしました。" % [caster.name, t_name, str(res["to"])])
	if res.get("result") == "GIRL_DIED" or res.get("result") == "GAME_OVER":
		hud.log_message("[Magic] %s は吹き飛ばされた先で魔女にぶつかった！" % t_name)

	var piece = board_view.get_piece(target_id)
	var finish = func():
		is_moving = false
		moving_piece_id = ""
		if piece:
			piece.position = Vector2(res["to"].x * 64 + 16, res["to"].y * 64 + 16)
		if tm.current_phase != Enums.TurnPhase.GAME_OVER:
			_on_unit_action_finished(current_acting_unit_id)
	if piece == null:
		finish.call()
		return
	is_moving = true
	moving_piece_id = target_id
	selected_path = res["path"]
	piece.animate_path(res["path"], func(_c: Vector2i, _r: int): return {"result": "CONTINUE"}, finish)

## 土魔術：対象にできるユニットのマスをハイライトし、対象選択モードへ入る
func _begin_earth_target_selection() -> void:
	earth_target_ids = tm.get_earth_targets(current_acting_unit_id)
	if earth_target_ids.is_empty():
		DebugLogger.warn("MainGame._begin_earth_target_selection", "土魔術の対象がいません")
		_show_action_command_menu()
		return
	is_selecting_earth_target = true
	board_view.clear_highlights()
	for uid in earth_target_ids:
		var u = tm.get_unit(uid)
		if u:
			board_view.set_cell_highlight(u.current_coord, true, Color(0.8, 0.55, 0.25, 0.9))
	var caster = tm.characters[current_acting_unit_id]
	hud.update_turn_info(tm.current_turn, "【%s】土魔術の対象（味方：潜行／魔女：1ターン停止）をクリック [右クリック: 戻る]" % caster.name)
	hud.set_action_buttons_enabled(false)

## 土魔術：選択を終了する（ハイライト解除）
func _end_earth_selection() -> void:
	is_selecting_earth_target = false
	earth_target_ids.clear()
	board_view.clear_highlights()

## 土魔術：クリックしたマスの対象に詠唱して行動終了
func _on_earth_cell_clicked(coord: Vector2i) -> void:
	var target_id = ""
	for uid in earth_target_ids:
		var u = tm.get_unit(uid)
		if u and u.current_coord == coord:
			target_id = uid
			break
	if target_id.is_empty():
		DebugLogger.warn("MainGame._on_earth_cell_clicked", "土魔術の対象ではありません", {"clicked_coord": coord})
		return
	var caster = tm.characters[current_acting_unit_id]
	_end_earth_selection()
	if not tm.execute_earth(current_acting_unit_id, target_id):
		hud.log_message("[Magic] 土魔術を発動できませんでした。")
		_show_action_command_menu()
		return
	var caster_piece = board_view.get_piece(current_acting_unit_id)
	if caster_piece:
		caster_piece.set_burrowed(caster.is_burrowed)
	var target_piece = board_view.get_piece(target_id)
	if target_id in tm.characters:
		var target = tm.characters[target_id]
		if target_piece:
			target_piece.set_burrowed(true)
		hud.log_message("[Magic] 【土魔術】発動！%s が %s を地中に潜らせました（魔女をやり過ごせます）。" % [caster.name, target.name])
	else:
		if target_piece:
			target_piece.set_target_name("スタン中")
		hud.log_message("[Magic] 【土魔術】発動！%s が %s を1ターン行動不能にしました。" % [caster.name, target_id])
	_on_unit_action_finished(current_acting_unit_id)

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
		var p = board_view.get_piece(moving_piece_id if not moving_piece_id.is_empty() else current_acting_unit_id)
		if p and selected_path.size() > 0:
			p.skip_current_move(selected_path[-1])
			DebugLogger.info("MainGame._on_cell_clicked", "クリックにより移動アニメーションをスキップ")
		return

	if is_selecting_water_target:
		if water_target_cells.has(coord):
			_place_water_trap(coord)
		else:
			DebugLogger.warn("MainGame._on_cell_clicked", "水魔術トラップを設置できないマスです", {"clicked_coord": coord})
		return

	if wind_select_state != WindSelect.NONE:
		_on_wind_cell_clicked(coord)
		return

	if is_selecting_earth_target:
		_on_earth_cell_clicked(coord)
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

	# 3. 水魔術の設置先選択中の場合：選択を取りやめてコマンドメニューへ復帰（まだ行動は未確定）
	if is_selecting_water_target:
		_end_water_target_selection()
		hud.set_action_buttons_enabled(true)
		_show_action_command_menu(mouse_pos)
		DebugLogger.info("MainGame._go_back", "水魔術の設置先選択を取りやめてコマンドメニューへ復帰")
		return

	# 3-0. 土魔術の対象選択中の場合：選択を取りやめてコマンドメニューへ復帰
	if is_selecting_earth_target:
		_end_earth_selection()
		hud.set_action_buttons_enabled(true)
		_show_action_command_menu(mouse_pos)
		DebugLogger.info("MainGame._go_back", "土魔術の対象選択を取りやめてコマンドメニューへ復帰")
		return

	# 3-1. 風魔術の選択中の場合：着地マス選択→対象選択→コマンドメニューの順に1つずつ戻る
	if wind_select_state == WindSelect.DIRECTION:
		_begin_wind_target_selection()
		DebugLogger.info("MainGame._go_back", "風魔術の着地マス選択から対象選択へ戻る")
		return
	if wind_select_state == WindSelect.TARGET:
		_end_wind_selection()
		hud.set_action_buttons_enabled(true)
		_show_action_command_menu(mouse_pos)
		DebugLogger.info("MainGame._go_back", "風魔術の対象選択を取りやめてコマンドメニューへ復帰")
		return

	# 3-2. 移動先選択中（出目確定後）の場合：出目キャンセルは不可（移動必須）
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
	is_enemy_turn = true
	hud.set_action_buttons_enabled(false)
	hud.update_turn_info(tm.current_turn, "魔女の行動中...")
	hud.log_message("[Enemy] 魔女のターン開始。思考中...")
	
	var alive_enemies: Array[EnemyData] = []
	for e in tm.enemies.values():
		if e.is_alive and e.stun_turns <= 0:
			alive_enemies.append(e)
		elif e.is_alive:
			hud.log_message("[Enemy] %s は土魔術で動けない（このターンは行動しない）。" % e.enemy_id)
			
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
			# スタンが解けた魔女の「スタン中」表示を消す
			if e.stun_turns <= 0 and ep.target_icon.text.ends_with("スタン中"):
				ep.set_target_name("")
			if e.is_alive and not ep.visible:
				ep.visible = true
				ep.position = Vector2(e.current_coord.x * 64 + 16, e.current_coord.y * 64 + 16)
				hud.log_message("[Revive] 魔女 %s が初期位置で復活しました！" % e.enemy_id)

	# 復活した魔女に主人公が捕縛された場合はゲームオーバー（画面表示は game_over_triggered 側）
	if tm.current_phase == Enums.TurnPhase.GAME_OVER:
		return

	# プレイヤーターン開始フローを実行
	_start_player_turn_flow()


func _on_retry() -> void:
	game_over_screen.visible = false
	stage_clear_screen.visible = false
	action_command_menu.visible = false
	item_select_modal.visible = false
	hud.set_action_buttons_enabled(true)
	# ゲームオーバー後は、セーブ（無ければ最初）から始め直す。タイトルへ戻った場合も「つづきから」で同じ状態になる
	_restore_checkpoint()
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
		_start_new_run("STAGE_1")

func _on_title_return() -> void:
	DebugLogger.info("MainGame._on_title_return", "タイトル画面へ遷移します")
	if get_node_or_null("/root/SceneManager"):
		get_node("/root/SceneManager").change_to_title()
	else:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


# ===== 中断セーブ（一時離席用・ロードすると消える） =====

func _create_suspend_button() -> void:
	var top_bar = hud.get_node_or_null("TopBar")
	if top_bar == null:
		return
	suspend_btn = Button.new()
	suspend_btn.text = "中断セーブ"
	suspend_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	suspend_btn.anchor_top = 0.5
	suspend_btn.anchor_bottom = 0.5
	suspend_btn.offset_left = -240.0
	suspend_btn.offset_right = -130.0
	suspend_btn.offset_top = -18.0
	suspend_btn.offset_bottom = 18.0
	suspend_btn.focus_mode = Control.FOCUS_NONE
	suspend_btn.pressed.connect(_on_suspend_pressed)
	top_bar.add_child(suspend_btn)

## 中断セーブ可能か：プレイヤーの行動選択待ち中のみ（移動中・魔女ターン・演出中は不可）
func _can_suspend_save() -> bool:
	if tm == null or is_moving or is_enemy_turn:
		return false
	if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
		return false
	if current_dice_roll > 0 or has_pending_additional_move or has_pending_roll_again or _is_selecting_magic_target():
		return false
	if game_over_screen.visible or stage_clear_screen.visible or item_select_modal.visible:
		return false
	return true

func _on_suspend_pressed() -> void:
	if not _can_suspend_save():
		hud.log_message("[Suspend] 今は中断セーブできません（行動選択待ちのときのみ可能）。")
		return
	var fresh = StageRepository.get_stage(tm.stage_id)
	var data = SuspendData.capture(tm, fresh.board if fresh else null)
	data.inventory = inventory.duplicate(true)
	data.visited_event_ids = visited_event_ids.duplicate()
	data.progress_flags = progress_flags.duplicate(true)
	data.clear_flags = clear_flags.duplicate(true)
	data.achievement_counters = achievement_counters.duplicate(true)
	data.active_slot = active_slot
	if SaveManager.save_suspend(data):
		hud.log_message("[Suspend] 中断セーブしました。タイトルへ戻ります。")
		_on_title_return()
	else:
		hud.log_message("[Suspend] 中断セーブに失敗しました。")

## 中断データから再開する（ステージを初期状態で構築→保存状態を上書き）
func _resume_from_suspend(data: SuspendData) -> void:
	inventory = data.inventory.duplicate(true)
	visited_event_ids = data.visited_event_ids.duplicate()
	progress_flags = data.progress_flags.duplicate(true)
	clear_flags = data.clear_flags.duplicate(true)
	achievement_counters = data.achievement_counters.duplicate(true)
	active_slot = data.active_slot
	load_stage(data.stage_id, true)
	if not data.apply_to(tm):
		return
	# 盤面表示（マス・ピース）を保存状態へ同期
	for o in data.cell_overrides:
		var coord = Vector2i(int(o["coord"][0]), int(o["coord"][1]))
		if board_view.cell_nodes.has(coord):
			board_view.cell_nodes[coord].update_visual()
	for c in tm.characters.values():
		var cp = board_view.get_piece(c.character_id)
		if cp:
			cp.position = Vector2(c.current_coord.x * 64 + 16, c.current_coord.y * 64 + 16)
			cp.visible = c.is_alive
			cp.set_burrowed(c.is_burrowed)
	for e in tm.enemies.values():
		var ep = board_view.get_piece(e.enemy_id)
		if ep:
			ep.position = Vector2(e.current_coord.x * 64 + 16, e.current_coord.y * 64 + 16)
			ep.visible = e.is_alive
	hud.log_message("[Resume] 中断データから再開します（ターン%d）。" % tm.current_turn)
	# 保存時点の行動済み状態を保ったまま、次の行動ユニットを選び直す
	_start_next_player_action()