class_name TestCase
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
        var msg = "FAIL: %s (Expected true, got false)" % message
        failures.append(msg)
        printerr(msg)

func assert_false(condition: bool, message: String = "") -> void:
    if not condition:
        passed_count += 1
    else:
        failed_count += 1
        var msg = "FAIL: %s (Expected false, got true)" % message
        failures.append(msg)
        printerr(msg)

func assert_eq(actual, expected, message: String = "") -> void:
    if actual == expected:
        passed_count += 1
    else:
        failed_count += 1
        var msg = "FAIL: %s (Expected %s, got %s)" % [message, str(expected), str(actual)]
        failures.append(msg)
        printerr(msg)

func assert_ne(actual, expected, message: String = "") -> void:
    if actual != expected:
        passed_count += 1
    else:
        failed_count += 1
        var msg = "FAIL: %s (Expected NOT %s, got %s)" % [message, str(expected), str(actual)]
        failures.append(msg)
        printerr(msg)
