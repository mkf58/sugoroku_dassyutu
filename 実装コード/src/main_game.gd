class_name MainGame
extends Node2D

@export var cell_scene: PackedScene
@export var unit_piece_scene: PackedScene

@onready var board_view: BoardView = $BoardView
@onready var hud: HUD = $CanvasLayer/HUD
@onready var help_modal: HelpModal = $CanvasLayer/HelpModal
@onready var game_over_screen: GameOverScreen = $CanvasLayer/GameOverScreen

var tm: TurnManager
var current_dice_roll: int = 0
var reachable_cells: Dictionary = {}
var selected_path: Array[Vector2i] = []
var is_moving: bool = false

func _ready() -> void:
    _init_poc_stage()
    _bind_events()

func _init_poc_stage() -> void:
    tm = TurnManager.new()
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
    
    hud.update_turn_info(tm.current_turn, "主人公の行動を選択")

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
    
    tm.game_over_triggered.connect(func(reason):
        hud.set_action_buttons_enabled(false)
        game_over_screen.show_game_over(reason)
    )
    
    tm.stage_cleared.connect(func(_id):
        hud.update_turn_info(tm.current_turn, "脱出成功！ステージクリア！")
        hud.set_action_buttons_enabled(false)
    )

func _on_roll_dice() -> void:
    if is_moving or tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        return
    current_dice_roll = randi_range(1, 6)
    hud.show_dice_result(current_dice_roll)
    
    var hero = tm.characters["HERO"]
    # 折り返し移動を含む到達可能マスを計算
    reachable_cells = tm.board.get_reachable_cells_with_steps(hero.current_coord, current_dice_roll)
    board_view.clear_highlights()
    for c in reachable_cells.keys():
        board_view.set_cell_highlight(c, true, Color(0.3, 0.8, 1.0, 0.8))
        
    hud.update_turn_info(tm.current_turn, "移動先をクリック (出目: %d)" % current_dice_roll)
    hud.set_action_buttons_enabled(false)

func _on_cell_hovered(coord: Vector2i) -> void:
    if is_moving or current_dice_roll <= 0:
        return
    if reachable_cells.has(coord):
        var hero = tm.characters["HERO"]
        var preview_path = tm.board.find_path_with_steps(hero.current_coord, coord, current_dice_roll)
        if not preview_path.is_empty():
            board_view.update_route_preview(preview_path)

func _on_magic_pressed() -> void:
    # PoCでは土潜行（魔女やり過ごし）を発動
    if is_moving or tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        return
    var hero = tm.characters["HERO"]
    hero.is_burrowed = true
    var piece = board_view.get_piece("HERO")
    if piece:
        piece.set_burrowed(true)
    hero.has_acted = true
    hud.update_turn_info(tm.current_turn, "土魔術で地中に潜行した！")
    _advance_to_enemy_turn()

func _on_wait_pressed() -> void:
    if is_moving or tm.current_phase != Enums.TurnPhase.PLAYER_ACTION_SELECT:
        return
    tm.execute_wait("HERO")
    hud.update_turn_info(tm.current_turn, "祈りを捧げて待機した")
    _advance_to_enemy_turn()

func _on_cell_clicked(coord: Vector2i) -> void:
    # コマ移動中に画面クリックでスキップ
    if is_moving:
        var hero_piece = board_view.get_piece("HERO")
        if hero_piece and selected_path.size() > 0:
            hero_piece.skip_current_move(selected_path[-1])
        return

    if current_dice_roll > 0 and reachable_cells.has(coord):
        var hero = tm.characters["HERO"]
        selected_path = tm.board.find_path_with_steps(hero.current_coord, coord, current_dice_roll)
        if not selected_path.is_empty():
            board_view.update_route_preview(selected_path)
            _start_hero_movement(selected_path)


func _on_right_click() -> void:
    if is_moving:
        return
    # キャンセル操作
    current_dice_roll = 0
    reachable_cells.clear()
    board_view.clear_highlights()
    board_view.clear_route_preview()
    hud.hide_dice_result()
    hud.set_action_buttons_enabled(true)
    hud.update_turn_info(tm.current_turn, "主人公の行動を選択")

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
            if tm.current_phase != Enums.TurnPhase.GAME_OVER and tm.current_phase != Enums.TurnPhase.STAGE_CLEAR:
                _advance_to_enemy_turn()
    )

func _advance_to_enemy_turn() -> void:
    hud.set_action_buttons_enabled(false)
    hud.update_turn_info(tm.current_turn, "魔女の行動中...")
    
    # 魔女の思考・ターゲット決定
    var witch = tm.enemies["WITCH"]
    var target = tm.select_witch_target(witch)
    var witch_piece = board_view.get_piece("WITCH")
    
    if target:
        witch_piece.set_target_name(target.name)
        var target_coord = target.current_coord
        var path = tm.board.find_shortest_path(witch.current_coord, target_coord)
        
        # 魔女は2マス移動（PoC固定歩数）
        var witch_steps = 2
        var actual_path: Array[Vector2i] = []
        for i in range(min(path.size(), witch_steps + 1)):
            actual_path.append(path[i])
            
        if actual_path.size() > 1:
            witch_piece.animate_path(
                actual_path,
                func(to_c: Vector2i, _rem: int):
                    witch.current_coord = to_c
                    # 主人公との接触判定
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
            _on_enemy_turn_finished()
    else:
        witch_piece.set_target_name("")
        _on_enemy_turn_finished()

func _on_enemy_turn_finished() -> void:
    if tm.current_phase == Enums.TurnPhase.GAME_OVER:
        return
    # 次のターンへ
    tm.end_turn_and_advance()
    var hero_piece = board_view.get_piece("HERO")
    if hero_piece:
        hero_piece.set_burrowed(false) # 潜行解除
    hud.update_turn_info(tm.current_turn, "主人公の行動を選択")
    hud.set_action_buttons_enabled(true)

func _on_retry() -> void:
    game_over_screen.visible = false
    hud.set_action_buttons_enabled(true)
    _init_poc_stage()
