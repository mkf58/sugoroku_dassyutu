class_name MainGame
extends Node2D

@export var cell_scene: PackedScene
@export var unit_piece_scene: PackedScene

@onready var board_view: BoardView = $BoardView
@onready var hud: HUD = $CanvasLayer/HUD
@onready var help_modal: HelpModal = $CanvasLayer/HelpModal
@onready var game_over_screen: GameOverScreen = $CanvasLayer/GameOverScreen
@onready var stage_clear_screen: StageClearScreen = $CanvasLayer/StageClearScreen
@onready var camera: Camera2D = $Camera2D

var tm: TurnManager
var current_dice_roll: int = 0
var reachable_cells: Dictionary = {}
var selected_path: Array[Vector2i] = []
var is_moving: bool = false
var is_dragging_camera: bool = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(2.5, 2.5))
        elif event.button_index == MOUSE_BUTTON_MIDDLE:
            is_dragging_camera = event.pressed
    elif event is InputEventMouseMotion and is_dragging_camera:
        camera.position -= event.relative / camera.zoom

func _get_enemy_obstacles() -> Array[Vector2i]:
    var obstacles: Array[Vector2i] = []
    var hero = tm.characters.get("HERO", null)
    if hero and not hero.is_burrowed:
        for e in tm.enemies.values():
            if e.is_alive:
                obstacles.append(e.current_coord)
    return obstacles


func _ready() -> void:
    _bind_events()
    _init_poc_stage()

func _init_poc_stage() -> void:
    # 既存の盤面表示・ハイライト・経路・コマを完全初期化
    board_view.clear_all()
    game_over_screen.visible = false
    stage_clear_screen.visible = false

    tm = TurnManager.new()
    _bind_turn_manager_events()
    
    var board = GridBoard.new()
    
    # PoC用盤面（10x6 のグリッド、直線・分岐・水トラップ・宝箱・ゴール）
    # (0,2) から (8,2) までのメインストリート
    for x in range(9):
        var type = Enums.CellType.NORMAL
        if x == 0:
            type = Enums.CellType.NORMAL
        elif x == 3:
            type = Enums.CellType.WATER_TRAP # 水トラップ
        elif x == 5:
            type = Enums.CellType.EVENT      # 宝箱マス
        elif x == 8:
            type = Enums.CellType.EXIT       # ゴール
        board.add_cell(CellData.new(Vector2i(x, 2), type))
        if x > 0:
            board.connect_cells(Vector2i(x - 1, 2), Vector2i(x, 2))
            
    # 上側への迂回路 (2,1) - (3,1) - (4,1)
    board.add_cell(CellData.new(Vector2i(2, 1), Enums.CellType.NORMAL))
    board.add_cell(CellData.new(Vector2i(3, 1), Enums.CellType.ADDITIONAL_MOVE)) # +2マス
    board.add_cell(CellData.new(Vector2i(4, 1), Enums.CellType.NORMAL))
    board.connect_cells(Vector2i(2, 2), Vector2i(2, 1))
    board.connect_cells(Vector2i(2, 1), Vector2i(3, 1))
    board.connect_cells(Vector2i(3, 1), Vector2i(4, 1))
    board.connect_cells(Vector2i(4, 1), Vector2i(4, 2))

    # 主人公と魔女の生成
    var hero = CharacterData.new("HERO", "主人公", Vector2i(0, 2))
    var witch = EnemyData.new("WITCH", Enums.EnemyType.TRACKING, Vector2i(6, 2))
    
    board_view.setup_board(board, cell_scene)
    board_view.add_piece(unit_piece_scene, "HERO", "主人公", Vector2i(0, 2), true, false)
    board_view.add_piece(unit_piece_scene, "WITCH", "魔女", Vector2i(6, 2), false, true)
    
    tm.setup_stage(board, [hero], [witch], "POC_STAGE")
    tm.start_player_turn()
    tm.select_character("HERO")
    
    current_dice_roll = 0
    reachable_cells.clear()
    selected_path.clear()
    is_moving = false
    
    hud.update_turn_info(tm.current_turn, "主人公の行動を選択")
    hud.set_action_buttons_enabled(true)
    hud.log_message("[Stage] PoCステージ初期化完了。主人公: (0,2), 魔女: (6,2)")
    hud.log_message("[Turn 1] プレイヤーターン開始。ダイスまたは行動を選択してください。")

func _bind_events() -> void:
    hud.roll_dice_pressed.connect(_on_roll_dice)
    hud.magic_pressed.connect(_on_magic_pressed)
    hud.wait_pressed.connect(_on_wait_pressed)
    hud.help_pressed.connect(func(): help_modal.open())
    
    board_view.cell_clicked.connect(_on_cell_clicked)
    board_view.cell_hovered.connect(_on_cell_hovered)
    board_view.right_clicked.connect(_on_right_click)
    
    game_over_screen.retry_pressed.connect(_on_retry)
    game_over_screen.title_pressed.connect(_on_retry)
    
    stage_clear_screen.retry_pressed.connect(_on_retry)
    stage_clear_screen.title_pressed.connect(_on_retry)

func _bind_turn_manager_events() -> void:
    if not tm:
        return
    tm.game_over_triggered.connect(func(reason):
        hud.set_action_buttons_enabled(false)
        hud.log_message("[GAME OVER] " + reason)
        game_over_screen.show_game_over(reason)
    )
    
    tm.stage_cleared.connect(func(_id):
        hud.update_turn_info(tm.current_turn, "脱出成功！ステージクリア！")
        hud.set_action_buttons_enabled(false)
        hud.log_message("[CLEAR] EXITマスに到達！館からの脱出に成功しました！")
        stage_clear_screen.show_clear(tm.current_turn)
    )
    
    tm.water_trap_triggered.connect(func(unit_id, coord):
        hud.log_message("[TRAP] %s が水魔術トラップ %s に侵入！残歩数破棄・即ターンエンド" % [unit_id, str(coord)])
    )


func _on_roll_dice() -> void:
    if is_moving:
        DebugLogger.warn("MainGame._on_roll_dice", "コマ移動中のためダイスを振れません")
        return
    if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        DebugLogger.warn("MainGame._on_roll_dice", "行動選択フェーズ以外ではダイスを振れません", {"phase": tm.current_phase})
        return
        
    current_dice_roll = randi_range(1, 6)
    hud.show_dice_result(current_dice_roll)
    
    var hero = tm.characters["HERO"]
    var obstacles = _get_enemy_obstacles()
    reachable_cells = tm.board.get_reachable_cells_with_steps(hero.current_coord, current_dice_roll, obstacles)
    board_view.clear_highlights()
    for c in reachable_cells.keys():
        board_view.set_cell_highlight(c, true, Color(0.3, 0.8, 1.0, 0.8))
        
    hud.update_turn_info(tm.current_turn, "移動先をクリック (出目: %d)" % current_dice_roll)
    hud.set_action_buttons_enabled(false)
    DebugLogger.info("MainGame._on_roll_dice", "ダイス出目 %d (到達可能マス: %d箇所)" % [current_dice_roll, reachable_cells.size()])

func _on_cell_hovered(coord: Vector2i) -> void:
    if is_moving or current_dice_roll <= 0:
        return
    if reachable_cells.has(coord):
        var hero = tm.characters["HERO"]
        var obstacles = _get_enemy_obstacles()
        var preview_path = tm.board.find_path_with_steps(hero.current_coord, coord, current_dice_roll, obstacles)
        if not preview_path.is_empty():
            board_view.update_route_preview(preview_path)

func _on_magic_pressed() -> void:
    if is_moving:
        DebugLogger.warn("MainGame._on_magic_pressed", "コマ移動中のため魔法を発動できません")
        return
    if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        DebugLogger.warn("MainGame._on_magic_pressed", "行動選択フェーズ以外では魔法を発動できません", {"phase": tm.current_phase})
        return
        
    var hero = tm.characters["HERO"]
    hero.is_burrowed = true
    var piece = board_view.get_piece("HERO")
    if piece:
        piece.set_burrowed(true)
    hero.has_acted = true
    hud.update_turn_info(tm.current_turn, "土魔術で地中に潜行した！")
    DebugLogger.info("MainGame._on_magic_pressed", "土魔術発動！地中に潜行（魔女やり過ごし有効）")
    _advance_to_enemy_turn()

func _on_wait_pressed() -> void:
    if is_moving:
        DebugLogger.warn("MainGame._on_wait_pressed", "コマ移動中のため待機できません")
        return
    if tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        DebugLogger.warn("MainGame._on_wait_pressed", "行動選択フェーズ以外では待機できません", {"phase": tm.current_phase})
        return
        
    tm.execute_wait("HERO")
    hud.update_turn_info(tm.current_turn, "祈りを捧げて待機した")
    DebugLogger.info("MainGame._on_wait_pressed", "主人公は祈りを捧げて待機しました")
    _advance_to_enemy_turn()

func _on_cell_clicked(coord: Vector2i) -> void:
    if is_moving:
        var hero_piece = board_view.get_piece("HERO")
        if hero_piece and selected_path.size() > 0:
            hero_piece.skip_current_move(selected_path[-1])
            DebugLogger.info("MainGame._on_cell_clicked", "クリックにより移動アニメーションをスキップ")
        return

    if current_dice_roll <= 0:
        DebugLogger.info("MainGame._on_cell_clicked", "先にダイスを振るかコマンドを選択してください")
        return

    if not reachable_cells.has(coord):
        DebugLogger.warn("MainGame._on_cell_clicked", "指定マスはこの出目では移動できません", {"clicked_coord": coord, "dice_roll": current_dice_roll})
        return

    var hero = tm.characters["HERO"]
    var obstacles = _get_enemy_obstacles()
    selected_path = tm.board.find_path_with_steps(hero.current_coord, coord, current_dice_roll, obstacles)
    if selected_path.is_empty():
        DebugLogger.error("MainGame._on_cell_clicked", "移動経路の生成に失敗しました", {"from": hero.current_coord, "to": coord, "steps": current_dice_roll})
        return


    board_view.update_route_preview(selected_path)
    DebugLogger.info("MainGame._on_cell_clicked", "移動開始: %s -> %s (歩数: %d)" % [str(hero.current_coord), str(coord), current_dice_roll])
    _start_hero_movement(selected_path)


func _on_right_click() -> void:
    if is_moving:
        return
    if current_dice_roll > 0:
        current_dice_roll = 0
        reachable_cells.clear()
        board_view.clear_highlights()
        board_view.clear_route_preview()
        hud.hide_dice_result()
        hud.set_action_buttons_enabled(true)
        hud.update_turn_info(tm.current_turn, "主人公の行動を選択")
        hud.log_message("[Cancel] 移動先選択をキャンセルしました。")

func _start_hero_movement(path: Array[Vector2i]) -> void:
    is_moving = true
    board_view.clear_highlights()
    board_view.clear_route_preview()
    
    var hero = tm.characters["HERO"]
    var hero_piece = board_view.get_piece("HERO")
    
    hero_piece.animate_path(
        path,
        func(to_coord: Vector2i, remaining: int):
            return tm.step_unit(hero, to_coord, remaining),
        func():
            is_moving = false
            current_dice_roll = 0
            hud.hide_dice_result()
            hud.log_message("[Move] 主人公が %s に停止しました。" % str(hero.current_coord))
            if tm.current_phase != Enums.TurnPhase.GAME_OVER and tm.current_phase != Enums.TurnPhase.STAGE_CLEAR:
                _advance_to_enemy_turn()
    )

func _advance_to_enemy_turn() -> void:
    hud.set_action_buttons_enabled(false)
    hud.update_turn_info(tm.current_turn, "魔女の行動中...")
    hud.log_message("[Enemy] 魔女のターン開始。思考中...")
    
    var witch = tm.enemies["WITCH"]
    var target = tm.select_witch_target(witch)
    var witch_piece = board_view.get_piece("WITCH")
    
    if target:
        witch_piece.set_target_name(target.name)
        var target_coord = target.current_coord
        var path = tm.board.find_shortest_path(witch.current_coord, target_coord)
        var dist = path.size() - 1 if not path.is_empty() else 99
        hud.log_message("[Enemy] ターゲット: %s (距離: %dマス)" % [target.name, dist])
        
        # 魔女は2マス移動（PoC固定歩数）
        var witch_steps = 2
        var actual_path: Array[Vector2i] = []
        for i in range(min(path.size(), witch_steps + 1)):
            actual_path.append(path[i])
            
        if actual_path.size() > 1:
            hud.log_message("[Enemy] 魔女が %s から %s へ移動開始" % [str(witch.current_coord), str(actual_path[-1])])
            witch_piece.animate_path(
                actual_path,
                func(to_c: Vector2i, _rem: int):
                    witch.current_coord = to_c
                    # 1. 水魔術トラップ判定
                    var cell = tm.board.get_cell(to_c)
                    if cell and cell.cell_type == Enums.CellType.WATER_TRAP:
                        hud.log_message("[TRAP] 魔女が水魔術トラップ %s に捕まり、移動が停止した！" % str(to_c))
                        DebugLogger.info("MainGame._advance_to_enemy_turn", "魔女が水魔術トラップで移動停止", {"coord": to_c})
                        return {"result": "WATER_TRAP_STOP"}
                    # 2. 主人公との接触判定
                    var hero = tm.characters["HERO"]
                    if hero.is_alive and hero.current_coord == to_c:
                        if not hero.is_burrowed:
                            tm.current_phase = Enums.TurnPhase.GAME_OVER
                            tm.emit_signal("game_over_triggered", "魔女に背後から追いつかれた")
                            return {"result": "GAME_OVER"}
                    return {"result": "CONTINUE"},
                func():
                    _on_enemy_turn_finished()

            )
        else:
            hud.log_message("[Enemy] 魔女は移動先がありませんでした。")
            _on_enemy_turn_finished()
    else:
        witch_piece.set_target_name("")
        hud.log_message("[Enemy] 未潜行の対象が存在しないため、魔女は索敵できませんでした。")
        _on_enemy_turn_finished()

func _on_enemy_turn_finished() -> void:
    if tm.current_phase == Enums.TurnPhase.GAME_OVER:
        return
        
    # 次のターンへ進行
    tm.end_turn_and_advance()
    # 主人公を行動選択状態にする（必須！）
    tm.select_character("HERO")
    
    var hero = tm.characters["HERO"]
    var hero_piece = board_view.get_piece("HERO")
    if hero_piece:
        hero_piece.set_burrowed(false) # 潜行解除
        
    current_dice_roll = 0
    reachable_cells.clear()
    selected_path.clear()
    is_moving = false
    
    hud.update_turn_info(tm.current_turn, "主人公の行動を選択")
    hud.set_action_buttons_enabled(true)
    hud.log_message("[Turn %d] プレイヤーターン開始！主人公: %s, 魔女: %s" % [tm.current_turn, str(hero.current_coord), str(tm.enemies["WITCH"].current_coord)])

func _on_retry() -> void:
    game_over_screen.visible = false
    stage_clear_screen.visible = false
    hud.set_action_buttons_enabled(true)
    hud.log_message("[Retry] ステージを最初からやり直します。")
    _init_poc_stage()

