class_name TestCase
extends RefCounted
## Base class for headless unit tests. Subclasses live in tests/test_*.gd and
## define methods named test_*. The runner (tests/run_tests.gd) calls each one.

var failures: Array[String] = []
var checks: int = 0
var current_test: String = ""


func check(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [current_test, msg if msg != "" else "check failed"])


func check_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (expected %s, got %s)" % [current_test, msg, str(expected), str(actual)])


func check_near(actual: float, expected: float, eps: float = 0.001, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s: %s (expected ~%s, got %s)" % [current_test, msg, str(expected), str(actual)])
