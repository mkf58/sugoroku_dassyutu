class_name GridBoard
extends RefCounted

var cells: Dictionary = {}  ## Vector2i -> CellData
var grid_size: Vector2i = Vector2i(10, 10)
var start_coord: Vector2i = Vector2i.ZERO
var exit_coord: Vector2i = Vector2i.ZERO

func add_cell(cell: CellData) -> void:
    cells[cell.coord] = cell

func get_cell(coord: Vector2i) -> CellData:
    return cells.get(coord, null)

func has_cell(coord: Vector2i) -> bool:
    return cells.has(coord)

## 双方向の隣接接続を設定
func connect_cells(coord_a: Vector2i, coord_b: Vector2i) -> void:
    var diff = coord_b - coord_a
    if cells.has(coord_a) and cells.has(coord_b):
        cells[coord_a].connections[diff] = true
        cells[coord_b].connections[-diff] = true
    else:
        DebugLogger.error("GridBoard.connect_cells", "接続対象のセルが存在しません", {"coord_a": coord_a, "coord_b": coord_b, "has_a": cells.has(coord_a), "has_b": cells.has(coord_b)})

## 隣接する通行可能な座標リストを取得（障害物マス除外対応）
func get_accessible_neighbors(coord: Vector2i, obstacles: Array[Vector2i] = []) -> Array[Vector2i]:
    var neighbors: Array[Vector2i] = []
    if not cells.has(coord):
        DebugLogger.warn("GridBoard.get_accessible_neighbors", "指定座標のセルが存在しません", {"coord": coord})
        return neighbors
    var cell = cells[coord]
    for dir in cell.connections.keys():
        if cell.connections[dir]:
            var target_coord = coord + dir
            if cells.has(target_coord) and not (target_coord in obstacles):
                neighbors.append(target_coord)
    return neighbors

## 最短経路探索（BFS）: startからgoalまでの座標配列を返す（start含む）
func find_shortest_path(start: Vector2i, goal: Vector2i, obstacles: Array[Vector2i] = []) -> Array[Vector2i]:
    if not cells.has(start) or not cells.has(goal):
        DebugLogger.warn("GridBoard.find_shortest_path", "開始または終了セルが存在しません", {"start": start, "goal": goal})
        return []
    if goal in obstacles:
        return []
        
    if start == goal:
        return [start]
    var queue: Array[Vector2i] = [start]
    var visited: Dictionary = {start: null}
    
    while queue.size() > 0:
        var current = queue.pop_front()
        if current == goal:
            break
        for n in get_accessible_neighbors(current, obstacles):
            if not visited.has(n):
                visited[n] = current
                queue.append(n)
                
    if not visited.has(goal):
        return []  ## 到達不可
        
    var path: Array[Vector2i] = []
    var curr = goal
    while curr != null:
        path.push_front(curr)
        curr = visited[curr]
    return path

## 指定歩数（出目）で到達可能なマスの集合を計算（折り返し移動許可、障害物回避対応）
## なお、EXIT（脱出）マスは出目が余っていても（移動可能距離内であれば）到達可能マスに含める
## 戻り値: Dictionary (Vector2i -> bool)
func get_reachable_cells_with_steps(start: Vector2i, steps: int, obstacles: Array[Vector2i] = []) -> Dictionary:
    var current_states: Dictionary = {start: true}
    var reachable_exits: Dictionary = {}
    for s in range(steps):
        var next_states: Dictionary = {}
        for c in current_states.keys():
            for n in get_accessible_neighbors(c, obstacles):
                next_states[n] = true
                if cells.has(n) and cells[n].cell_type == Enums.CellType.EXIT:
                    reachable_exits[n] = true
        current_states = next_states
        
    for ec in reachable_exits.keys():
        current_states[ec] = true
        
    return current_states

## 指定された経路（座標配列）が出目と合致し、接続が有効か検証する
func validate_path(path: Array[Vector2i], expected_steps: int) -> bool:
    if path.is_empty():
        return false
    var is_exit = cells.has(path[-1]) and cells[path[-1]].cell_type == Enums.CellType.EXIT
    if is_exit:
        if path.size() - 1 > expected_steps:
            return false
    else:
        if path.size() != expected_steps + 1:
            return false
    for i in range(path.size() - 1):
        var c = path[i]
        var n = path[i + 1]
        var diff = n - c
        if not cells.has(c) or not cells[c].connections.get(diff, false):
            return false
    return true

## startからgoalへ、正確にsteps歩（またはEXITへの出目余り）で到達する有効な経路（折り返し含む）を探索する
func find_path_with_steps(start: Vector2i, goal: Vector2i, steps: int, obstacles: Array[Vector2i] = []) -> Array[Vector2i]:
    if steps <= 0:
        return [start] if start == goal else []
    if goal in obstacles:
        return []
        
    # EXITマスの場合：出目が余っていても（最短経路長 <= steps + 1）到達可能
    var shortest = find_shortest_path(start, goal, obstacles)
    if cells.has(goal) and cells[goal].cell_type == Enums.CellType.EXIT:
        if not shortest.is_empty() and (shortest.size() - 1) <= steps:
            return shortest
            
    # 最短経路と歩数が一致する場合はそれを優先
    if shortest.size() == steps + 1:
        return shortest

        
    # 折り返し移動を含む歩数固定の探索（重複状態枝刈り付きBFS）
    var queue: Array = [[start]]
    var visited_states: Dictionary = {} # "coord_x,coord_y:step" -> true
    visited_states["%d,%d:0" % [start.x, start.y]] = true
    
    while queue.size() > 0:
        var path: Array = queue.pop_front()
        var step_idx: int = path.size() - 1
        
        if step_idx == steps:
            if path[-1] == goal:
                var typed_path: Array[Vector2i] = []
                for p in path:
                    typed_path.append(p)
                return typed_path
            continue
            
        var current: Vector2i = path[-1]
        for n in get_accessible_neighbors(current, obstacles):
            var state_key = "%d,%d:%d" % [n.x, n.y, step_idx + 1]
            if not visited_states.has(state_key):
                visited_states[state_key] = true
                var new_path = path.duplicate()
                new_path.append(n)
                queue.append(new_path)
                
    if shortest.is_empty():
        DebugLogger.warn("GridBoard.find_path_with_steps", "指定歩数での有効な経路が見つかりませんでした", {"start": start, "goal": goal, "steps": steps})
        return []
    return shortest

## 任意座標から指定方向（dir）へ直線走査し、連続して繋がっている最遠のマスの座標を特定する
func find_farthest_linear_cell(start: Vector2i, dir: Vector2i) -> Vector2i:
    var current = start
    while true:
        var next_coord = current + dir
        if not cells.has(next_coord):
            break
        var current_cell = cells[current]
        if not current_cell.connections.get(dir, false):
            break
        current = next_coord
    return current

## 2点間が直線上にあり、その間の全マスが接続されていて障害物がないか（視界が通るか）
func has_clear_line_of_sight(from_coord: Vector2i, to_coord: Vector2i, obstacles: Array[Vector2i] = []) -> bool:
    if from_coord == to_coord:
        return true
    var diff = to_coord - from_coord
    var dir = Vector2i.ZERO
    if diff.x != 0 and diff.y == 0:
        dir = Vector2i(sign(diff.x), 0)
    elif diff.x == 0 and diff.y != 0:
        dir = Vector2i(0, sign(diff.y))
    else:
        return false # 直線（水平・垂直）ではない
        
    var current = from_coord
    while current != to_coord:
        var next_c = current + dir
        if not cells.has(current) or not cells.has(next_c):
            return false
        var cell = cells[current]
        if not cell.connections.get(dir, false):
            return false
        if next_c in obstacles:
            return false
        current = next_c
    return true



