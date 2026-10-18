class_name BoardView
extends Node2D

signal cell_clicked(coord: Vector2i)
signal right_clicked()
signal skip_requested()

@onready var cells_container: Node2D = $CellsContainer
@onready var pieces_container: Node2D = $PiecesContainer
@onready var route_preview: Line2D = $RoutePreview

var cell_nodes: Dictionary = {}   ## Vector2i -> CellNode
var piece_nodes: Dictionary = {}  ## unit_id -> UnitPiece
var hovered_coord: Vector2i = Vector2i(-999, -999)

func setup_board(board: GridBoard, cell_scene: PackedScene) -> void:
    for c in cells_container.get_children():
        c.queue_free()
    cell_nodes.clear()
    
    for coord in board.cells.keys():
        var cell_data = board.cells[coord]
        var node = cell_scene.instantiate() as CellNode
        cells_container.add_child(node)
        node.setup(cell_data)
        cell_nodes[coord] = node

func add_piece(piece_scene: PackedScene, id: String, name: String, coord: Vector2i, is_hero: bool, is_enemy: bool) -> UnitPiece:
    var node = piece_scene.instantiate() as UnitPiece
    pieces_container.add_child(node)
    node.setup(id, name, coord, is_hero, is_enemy)
    piece_nodes[id] = node
    return node

func get_piece(id: String) -> UnitPiece:
    return piece_nodes.get(id, null)

func clear_highlights() -> void:
    for node in cell_nodes.values():
        node.set_highlight(false)

func set_cell_highlight(coord: Vector2i, active: bool, color: Color = Color.YELLOW) -> void:
    if cell_nodes.has(coord):
        cell_nodes[coord].set_highlight(active, color)

func update_route_preview(path: Array[Vector2i]) -> void:
    route_preview.clear_points()
    for c in path:
        route_preview.add_point(Vector2(c.x * 64 + 32, c.y * 64 + 32))

func clear_route_preview() -> void:
    route_preview.clear_points()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            var local_pos = to_local(get_global_mouse_position())
            var coord = Vector2i(int(floor(local_pos.x / 64.0)), int(floor(local_pos.y / 64.0)))
            emit_signal("cell_clicked", coord)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            emit_signal("right_clicked")
