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
## 戻り値: Dictionary (Vector2i -> bool)
func get_reachable_cells_with_steps(start: Vector2i, steps: int, obstacles: Array[Vector2i] = []) -> Dictionary:
    var current_states: Dictionary = {start: true}
    for s in range(steps):
        var next_states: Dictionary = {}
        for c in current_states.keys():
            for n in get_accessible_neighbors(c, obstacles):
                next_states[n] = true
        current_states = next_states
    return current_states

## 指定された経路（座標配列）が出目と合致し、接続が有効か検証する
func validate_path(path: Array[Vector2i], expected_steps: int) -> bool:
    if path.size() != expected_steps + 1:
        return false
    for i in range(path.size() - 1):
        var c = path[i]
        var n = path[i + 1]
        var diff = n - c
        if not cells.has(c) or not cells[c].connections.get(diff, false):
            return false
    return true

## startからgoalへ、正確にsteps歩で到達する有効な経路（折り返し含む）を探索する
func find_path_with_steps(start: Vector2i, goal: Vector2i, steps: int, obstacles: Array[Vector2i] = []) -> Array[Vector2i]:
    if steps <= 0:
        return [start] if start == goal else []
    if goal in obstacles:
        return []
        
    # 最短経路と歩数が一致する場合はそれを優先
    var shortest = find_shortest_path(start, goal, obstacles)
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


