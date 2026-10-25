extends SceneTree

const TestGridBoard = preload("res://tests/test_grid_board.gd")
const TestStepMovement = preload("res://tests/test_step_movement.gd")
const TestEnemyAI = preload("res://tests/test_enemy_ai.gd")
const TestMagicSystem = preload("res://tests/test_magic_system.gd")
const TestTurnLifecycle = preload("res://tests/test_turn_lifecycle.gd")
const TestInventoryItems = preload("res://tests/test_inventory_items.gd")

func _init() -> void:
	print("========================================")
	print("  RUNNING ALL UNIT TESTS (GDScript 4)   ")
	print("========================================")
	
	var suites: Array = [
		{"name": "UT-BOARD", "instance": TestGridBoard.new()},
		{"name": "UT-STEP", "instance": TestStepMovement.new()},
		{"name": "UT-ENEMY", "instance": TestEnemyAI.new()},
		{"name": "UT-MAGIC", "instance": TestMagicSystem.new()},
		{"name": "UT-TURN", "instance": TestTurnLifecycle.new()},
		{"name": "UT-ITEM", "instance": TestInventoryItems.new()}
	]
	
	var total_passed = 0
	var total_failed = 0
	
	for s in suites:
		print("\n--- Running Suite: %s ---" % s.name)
		s.instance.run_all()
		total_passed += s.instance.passed_count
		total_failed += s.instance.failed_count
		print("  Passed: %d, Failed: %d" % [s.instance.passed_count, s.instance.failed_count])
		if s.instance.failed_count > 0:
			for f in s.instance.failures:
				print("  [ERROR] %s" % f)
				
	print("\n========================================")
	print("  TEST SUMMARY")
	print("  TOTAL PASSED: %d" % total_passed)
	print("  TOTAL FAILED: %d" % total_failed)
	print("========================================")
	
	quit(0 if total_failed == 0 else 1)
