class_name CellNode
extends Node2D

signal clicked(coord: Vector2i)
signal right_clicked()
signal hovered(coord: Vector2i)

@onready var background: ColorRect = $Background
@onready var label: Label = $Label
@onready var highlight: ReferenceRect = $Highlight

var cell_data: CellData

func _ready() -> void:
    background.gui_input.connect(_on_background_gui_input)
    background.mouse_entered.connect(_on_mouse_entered)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_background_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if cell_data:
                emit_signal("clicked", cell_data.coord)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            emit_signal("right_clicked")

func _on_mouse_entered() -> void:
    if cell_data:
        emit_signal("hovered", cell_data.coord)

func setup(p_data: CellData) -> void:
    cell_data = p_data
    position = Vector2(p_data.coord.x * 64, p_data.coord.y * 64)
    update_visual()


func update_visual() -> void:
    if not cell_data:
        return
    match cell_data.cell_type:
        Enums.CellType.NORMAL:
            background.color = Color(0.18, 0.20, 0.25, 0.9)
            label.text = ""
        Enums.CellType.EXIT:
            background.color = Color(0.2, 0.6, 0.3, 0.9)
            label.text = "EXIT"
        Enums.CellType.EVENT:
            background.color = Color(0.6, 0.5, 0.2, 0.9)
            label.text = "宝箱"
        Enums.CellType.ADDITIONAL_MOVE:
            background.color = Color(0.2, 0.5, 0.7, 0.9)
            label.text = "+2"
        Enums.CellType.RETURN_TO_START:
            background.color = Color(0.7, 0.2, 0.2, 0.9)
            label.text = "戻る"
        Enums.CellType.SKIP_TURN:
            background.color = Color(0.4, 0.2, 0.5, 0.9)
            label.text = "休み"
        Enums.CellType.ROLL_AGAIN:
            background.color = Color(0.3, 0.6, 0.7, 0.9)
            label.text = "もう1回"
        Enums.CellType.WATER_TRAP:
            background.color = Color(0.1, 0.3, 0.7, 0.9)
            label.text = "水罠"

func set_highlight(active: bool, color: Color = Color.YELLOW) -> void:
    highlight.visible = active
    highlight.border_color = color
