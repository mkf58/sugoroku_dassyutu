# 結合テスト用基底クラス
# CIヘッドレス環境での確実な実行のため、外部依存を排した自己完結型テストベース
extends RefCounted

var test_name: String = ""
var passed_count: int = 0
var failed_count: int = 0
var failures: Array[String] = []

func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		passed_count += 1
	else:
		failed_count += 1
		var msg = "FAIL: [%s] %s (Expected true, got false)" % [test_name, message]
		failures.append(msg)
		printerr(msg)

func assert_false(condition: bool, message: String = "") -> void:
	if not condition:
		passed_count += 1
	else:
		failed_count += 1
		var msg = "FAIL: [%s] %s (Expected false, got true)" % [test_name, message]
		failures.append(msg)
		printerr(msg)

func assert_eq(actual, expected, message: String = "") -> void:
	if actual == expected:
		passed_count += 1
	else:
		failed_count += 1
		var msg = "FAIL: [%s] %s (Expected %s, got %s)" % [test_name, message, str(expected), str(actual)]
		failures.append(msg)
		printerr(msg)

func assert_ne(actual, expected, message: String = "") -> void:
	if actual != expected:
		passed_count += 1
	else:
		failed_count += 1
		var msg = "FAIL: [%s] %s (Expected NOT %s, got %s)" % [test_name, message, str(expected), str(actual)]
		failures.append(msg)
		printerr(msg)
