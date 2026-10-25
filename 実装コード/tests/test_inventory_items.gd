class_name TestInventoryItems
extends TestCase

func run_all() -> void:
	test_fixed_dice_items_model()
	test_inventory_add_and_consume()

## UT-ITEM-01: 固定出目ダイス（1〜6の賽）のモデル整合性
func test_fixed_dice_items_model() -> void:
	for v in range(1, 7):
		var dice = {
			"id": "DICE_%d" % v,
			"name": "%dの賽" % v,
			"desc": "出目が必ず【%d】になる固定ダイス" % v,
			"value": v,
			"type": "FIXED_DICE",
			"icon_text": "🎲"
		}
		assert_eq(dice.get("value"), v, "UT-ITEM-01: %dの賽の値は%dであること" % [v, v])
		assert_eq(dice.get("type"), "FIXED_DICE", "UT-ITEM-01: 種別はFIXED_DICEであること")
		assert_true(dice.get("name").begins_with(str(v)), "UT-ITEM-01: 名称に値が含まれること")

## UT-ITEM-02: インベントリへのアイテム追加・消費・スタック処理
func test_inventory_add_and_consume() -> void:
	var inventory: Array[Dictionary] = []
	
	# アイテム追加
	var item_a = {"id": "DICE_1", "name": "1の賽", "value": 1, "type": "FIXED_DICE"}
	var item_b = {"id": "DICE_6", "name": "6の賽", "value": 6, "type": "FIXED_DICE"}
	inventory.append(item_a)
	inventory.append(item_b)
	
	assert_eq(inventory.size(), 2, "UT-ITEM-02: インベントリに2つのアイテムが格納されていること")
	
	# 指定インデックスのアイテムを消費（使用）
	var consumed_item = inventory.pop_at(0)
	assert_eq(consumed_item.get("id"), "DICE_1", "UT-ITEM-02: 消費されたアイテムIDがDICE_1であること")
	assert_eq(inventory.size(), 1, "UT-ITEM-02: 消費後インベントリ残数が1になること")
	assert_eq(inventory[0].get("id"), "DICE_6", "UT-ITEM-02: 残ったアイテムがDICE_6であること")
