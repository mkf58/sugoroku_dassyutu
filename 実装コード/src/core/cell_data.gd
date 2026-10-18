class_name CellData
extends RefCounted

var coord: Vector2i = Vector2i.ZERO
var cell_id: int = 0
var cell_type: Enums.CellType = Enums.CellType.NORMAL
var connections: Dictionary = {
    Vector2i.UP: false,
    Vector2i.DOWN: false,
    Vector2i.LEFT: false,
    Vector2i.RIGHT: false
}
var event_id: String = ""
var element_type: Enums.ElementType = Enums.ElementType.NONE
var is_consumed: bool = false
var event_params: Dictionary = {}

func _init(p_coord: Vector2i = Vector2i.ZERO, p_type: Enums.CellType = Enums.CellType.NORMAL) -> void:
    coord = p_coord
    cell_type = p_type

func to_dict() -> Dictionary:
    return {
        "coord": [coord.x, coord.y],
        "cell_id": cell_id,
        "cell_type": cell_type,
        "connections": {
            "up": connections.get(Vector2i.UP, false),
            "down": connections.get(Vector2i.DOWN, false),
            "left": connections.get(Vector2i.LEFT, false),
            "right": connections.get(Vector2i.RIGHT, false),
        },
        "event_id": event_id,
        "element_type": element_type,
        "is_consumed": is_consumed,
        "event_params": event_params
    }

static func from_dict(data: Dictionary) -> CellData:
    var c = CellData.new(Vector2i(data["coord"][0], data["coord"][1]), data["cell_type"])
    c.cell_id = data.get("cell_id", 0)
    var conn = data.get("connections", {})
    c.connections[Vector2i.UP] = conn.get("up", false)
    c.connections[Vector2i.DOWN] = conn.get("down", false)
    c.connections[Vector2i.LEFT] = conn.get("left", false)
    c.connections[Vector2i.RIGHT] = conn.get("right", false)
    c.event_id = data.get("event_id", "")
    c.element_type = data.get("element_type", Enums.ElementType.NONE)
    c.is_consumed = data.get("is_consumed", false)
    c.event_params = data.get("event_params", {})
    return c
