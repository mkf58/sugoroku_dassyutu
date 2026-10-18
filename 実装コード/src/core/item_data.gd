class_name ItemData
extends RefCounted

var item_id: String = ""
var name: String = ""
var item_type: Enums.ItemType = Enums.ItemType.FIXED_DICE
var fixed_value: int = 1

func _init(p_id: String, p_name: String, p_type: Enums.ItemType, p_val: int = 1) -> void:
    item_id = p_id
    name = p_name
    item_type = p_type
    fixed_value = p_val
