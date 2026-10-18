class_name CellNode
extends Node2D

@onready var background: ColorRect = $Background
@onready var label: Label = $Label
@onready var highlight: ReferenceRect = $Highlight

var cell_data: CellData

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
