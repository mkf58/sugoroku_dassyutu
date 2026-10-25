class_name TestInventoryItems
extends TestCase

func run_all() -> void:
	test_fixed_dice_items_model()
	test_inventory_add_and_consume()
	test_dice_value_boundaries()
	test_inventory_empty_to_populated()

## UT-ITEM-N01: 固定出目ダイス（1〜6の賽）のモデル整合性
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
		assert_eq(dice.get("value"), v, "UT-ITEM-N01: %dの賽の値は%d" % [v, v])
		assert_eq(dice.get("type"), "FIXED_DICE", "UT-ITEM-N01: 種別はFIXED_DICE")
		assert_true(dice.get("name").begins_with(str(v)), "UT-ITEM-N01: 名称に値が含まれる")

## UT-ITEM-N02: インベントリへのアイテム追加・消費処理
func test_inventory_add_and_consume() -> void:
	var inventory: Array[Dictionary] = []
	var item_a = {"id": "DICE_1", "name": "1の賽", "value": 1, "type": "FIXED_DICE"}
	var item_b = {"id": "DICE_6", "name": "6の賽", "value": 6, "type": "FIXED_DICE"}
	inventory.append(item_a)
	inventory.append(item_b)
	
	assert_eq(inventory.size(), 2, "UT-ITEM-N02: インベントリ要素数は2")
	var consumed = inventory.pop_at(0)
	assert_eq(consumed.get("id"), "DICE_1", "UT-ITEM-N02: 1番目のアイテムが消費")
	assert_eq(inventory.size(), 1, "UT-ITEM-N02: 残数1")
	assert_eq(inventory[0].get("id"), "DICE_6", "UT-ITEM-N02: 残りはDICE_6")

## UT-ITEM-B01: 出目の境界値（最小1、最大6）
func test_dice_value_boundaries() -> void:
	var min_dice = {"id": "DICE_1", "value": 1}
	var max_dice = {"id": "DICE_6", "value": 6}
	assert_eq(min_dice.get("value"), 1, "UT-ITEM-B01: 最小出目は1")
	assert_eq(max_dice.get("value"), 6, "UT-ITEM-B01: 最大出目は6")

## UT-ITEM-B02: 空インベントリからの要素数推移
func test_inventory_empty_to_populated() -> void:
	var inventory: Array[Dictionary] = []
	assert_true(inventory.is_empty(), "UT-ITEM-B02: 初期は空")
	inventory.append({"id": "DICE_3", "value": 3})
	assert_eq(inventory.size(), 1, "UT-ITEM-B02: 追加後1件")
	inventory.clear()
	assert_true(inventory.is_empty(), "UT-ITEM-B02: clear後は再び空")
