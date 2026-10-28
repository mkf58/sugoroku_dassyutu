class_name TurnManager
extends RefCounted

signal turn_changed(turn_num: int, phase: Enums.TurnPhase)
signal unit_selected(character_id: String)
signal unit_step_moved(unit_id: String, from_coord: Vector2i, to_coord: Vector2i, remaining_steps: int)
signal unit_killed(unit_id: String)
signal burrow_pass_succeeded(unit_id: String, enemy_id: String)
signal water_trap_triggered(unit_id: String, coord: Vector2i)
signal cell_event_triggered(cell_data: CellData)
signal enemy_target_changed(enemy_id: String, target_unit_id: String)
signal enemy_step_moved(enemy_id: String, from_coord: Vector2i, to_coord: Vector2i)
signal magic_executed(element: Enums.ElementType, user_id: String, target_coord: Vector2i)
signal stage_cleared(stage_id: String)
signal game_over_triggered(reason: String)
signal additional_move_granted(unit_id: String, steps: int)
signal roll_again_granted(unit_id: String)
signal returned_to_start_applied(unit_id: String)


var board: GridBoard
var characters: Dictionary = {}  ## id -> CharacterData
var enemies: Dictionary = {}     ## id -> EnemyData
var current_turn: int = 1
var current_phase: Enums.TurnPhase = Enums.TurnPhase.STAGE_INIT
var active_character_id: String = ""
var stage_id: String = ""

func setup_stage(p_board: GridBoard, p_characters: Array[CharacterData], p_enemies: Array[EnemyData], p_stage_id: String) -> void:
    board = p_board
    characters.clear()
    for c in p_characters:
        characters[c.character_id] = c
    enemies.clear()
    for e in p_enemies:
        enemies[e.enemy_id] = e
    stage_id = p_stage_id
    current_turn = 1
    current_phase = Enums.TurnPhase.PLAYER_UNIT_SELECT

func start_player_turn() -> void:
    current_phase = Enums.TurnPhase.PLAYER_UNIT_SELECT
    active_character_id = ""
    for c in characters.values():
        c.reset_turn_state()
    emit_signal("turn_changed", current_turn, current_phase)

func select_character(character_id: String) -> bool:
    if not characters.has(character_id):
        DebugLogger.error("TurnManager.select_character", "指定されたキャラクターが存在しません", {"id": character_id})
        return false
    var c = characters[character_id]
    if not c.is_alive:
        DebugLogger.warn("TurnManager.select_character", "ユニットは死亡中のため選択できません", {"id": character_id, "revive_turns": c.revive_turn_count})
        return false
    if c.has_acted:
        DebugLogger.warn("TurnManager.select_character", "ユニットは既に行動済みです", {"id": character_id})
        return false
    if c.is_skipped:
        DebugLogger.warn("TurnManager.select_character", "ユニットは1回休み状態のため選択できません", {"id": character_id})
        return false
    active_character_id = character_id
    current_phase = Enums.TurnPhase.PLAYER_ACTION_SELECT
    emit_signal("unit_selected", character_id)
    return true

## 1歩ずつの進行とリアルタイム接触・水トラップ判定
func step_unit(unit: CharacterData, to_coord: Vector2i, remaining_steps: int) -> Dictionary:
    if unit == null:
        DebugLogger.error("TurnManager.step_unit", "対象ユニットがnullです")
        return {"result": "ERROR"}
    if board == null:
        DebugLogger.error("TurnManager.step_unit", "盤面 (board) が未設定です")
        return {"result": "ERROR"}
        
    var from_coord = unit.current_coord
    unit.current_coord = to_coord
    emit_signal("unit_step_moved", unit.character_id, from_coord, to_coord, remaining_steps)

    
    # 1. エネミーとのリアルタイム接触判定
    for enemy in enemies.values():
        if enemy.is_alive and enemy.current_coord == to_coord:
            if unit.is_burrowed:
                # 潜行中：やり過ごし成功
                emit_signal("burrow_pass_succeeded", unit.character_id, enemy.enemy_id)
            else:
                if unit.character_id == "HERO":
                    # 主人公捕縛：即時ゲームオーバー
                    current_phase = Enums.TurnPhase.GAME_OVER
                    emit_signal("game_over_triggered", "魔女に捕縛された")
                    return {"result": "GAME_OVER", "coord": to_coord}
                else:
                    # 少女捕縛：殺害
                    unit.kill()
                    emit_signal("unit_killed", unit.character_id)
                    return {"result": "GIRL_DIED", "coord": to_coord}

    # 2. 地形トラップ判定（水魔術トラップ）
    var cell = board.get_cell(to_coord) if board else null
    if cell and cell.cell_type == Enums.CellType.WATER_TRAP:
        unit.has_acted = true
        emit_signal("water_trap_triggered", unit.character_id, to_coord)
        return {"result": "WATER_TRAP_STOP", "coord": to_coord}

    # 3. 通常進行
    if remaining_steps > 0:
        return {"result": "CONTINUE", "coord": to_coord}
    else:
        # 到着（残り歩数0）：地上に出現し潜行解除
        unit.has_acted = true
        if unit.is_burrowed:
            unit.is_burrowed = false
        if cell:
            resolve_stop_cell(unit, cell)
        return {"result": "ARRIVED", "coord": to_coord}

## 停止マスイベント解決
func resolve_stop_cell(character: CharacterData, cell: CellData) -> void:
    if cell.cell_type == Enums.CellType.EXIT:
        current_phase = Enums.TurnPhase.STAGE_CLEAR
        emit_signal("stage_cleared", stage_id)
    elif cell.cell_type == Enums.CellType.ADDITIONAL_MOVE:
        var steps = cell.event_params.get("steps", 2)
        character.has_acted = false
        emit_signal("additional_move_granted", character.character_id, steps)
    elif cell.cell_type == Enums.CellType.RETURN_TO_START:
        character.current_coord = character.initial_coord
        emit_signal("returned_to_start_applied", character.character_id)
    elif cell.cell_type == Enums.CellType.SKIP_TURN:
        character.is_skipped = true
    elif cell.cell_type == Enums.CellType.ROLL_AGAIN:
        character.has_acted = false
        emit_signal("roll_again_granted", character.character_id)
    elif cell.cell_type == Enums.CellType.EVENT:
        if not cell.is_consumed:
            cell.is_consumed = true
            emit_signal("cell_event_triggered", cell)



## 魔法実行（移動と二者択一）
func execute_magic(character_id: String, element: Enums.ElementType, target_coord: Vector2i) -> bool:
    if not characters.has(character_id):
        DebugLogger.error("TurnManager.execute_magic", "詠唱者が存在しません", {"id": character_id})
        return false
    var caster = characters[character_id]
    if not caster.is_alive:
        DebugLogger.warn("TurnManager.execute_magic", "死亡中のため魔法を使えません", {"id": character_id})
        return false
    if caster.has_acted:
        DebugLogger.warn("TurnManager.execute_magic", "既に行動済みのため魔法を使えません", {"id": character_id})
        return false
        
    match element:
        Enums.ElementType.FIRE:
            # 2マス以内の魔女を撃破
            var target_enemy: EnemyData = null
            for e in enemies.values():
                if e.is_alive and e.current_coord == target_coord:
                    target_enemy = e
                    break
            if target_enemy:
                target_enemy.defeat()
                caster.is_burrowed = false
                caster.has_acted = true
                emit_signal("magic_executed", element, character_id, target_coord)
                return true
            DebugLogger.warn("TurnManager.execute_magic", "指定座標に対象の魔女が存在しません", {"coord": target_coord})
            return false
            
        Enums.ElementType.WATER:
            # 指定マスを水トラップ化
            var cell = board.get_cell(target_coord) if board else null
            if cell:
                cell.cell_type = Enums.CellType.WATER_TRAP
                caster.is_burrowed = false
                caster.has_acted = true
                emit_signal("magic_executed", element, character_id, target_coord)
                return true
            DebugLogger.error("TurnManager.execute_magic", "指定されたマスが存在しません", {"coord": target_coord})
            return false
            
        Enums.ElementType.EARTH:
            # 潜行または魔女スタン
            var target_enemy: EnemyData = null
            for e in enemies.values():
                if e.is_alive and e.current_coord == target_coord:
                    target_enemy = e
                    break
            if target_enemy:
                target_enemy.stun_turns = 1
            else:
                caster.is_burrowed = true
            caster.has_acted = true
            emit_signal("magic_executed", element, character_id, target_coord)
            return true
            
        Enums.ElementType.WIND:
            # 直線吹き飛ばし
            caster.has_acted = true
            emit_signal("magic_executed", element, character_id, target_coord)
            return true
            
        _:
            DebugLogger.error("TurnManager.execute_magic", "未定義の魔法属性です", {"element": element})
            return false
            
    return false


## 待機・祈る（潜行中は潜行継続）
func execute_wait(character_id: String) -> void:
    if characters.has(character_id):
        var c = characters[character_id]
        c.has_acted = true

## 魔女ターゲット選定ロジック
func select_witch_target(enemy: EnemyData) -> CharacterData:
    var candidates: Array[CharacterData] = []
    for c in characters.values():
        if c.is_alive and not c.is_burrowed:
            candidates.append(c)
            
    if candidates.is_empty():
        return null  ## 全員潜行中
        
    var best_target: CharacterData = null
    var min_dist: int = 999999
    
    var priority_map = {
        "HERO": 0, "GIRL_FIRE": 1, "GIRL_WIND": 2, "GIRL_WATER": 3, "GIRL_EARTH": 4
    }
    
    for c in candidates:
        var path = board.find_shortest_path(enemy.current_coord, c.current_coord) if board else []
        var dist = path.size() - 1 if path.size() > 0 else 999999
        
        if dist < min_dist:
            min_dist = dist
            best_target = c
        elif dist == min_dist and best_target != null:
            var current_prio = priority_map.get(c.character_id, 99)
            var best_prio = priority_map.get(best_target.character_id, 99)
            if current_prio < best_prio:
                best_target = c
                
    return best_target

## ターン終了・復活カウント更新
func end_turn_and_advance() -> void:
    # 少女の復活カウント処理
    for c in characters.values():
        c.tick_revive()
        
    # エネミーの復活カウント処理
    for e in enemies.values():
        e.tick_revive()
        
    current_turn += 1
    start_player_turn()
