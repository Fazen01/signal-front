extends SceneTree
## Minimal headless test runner.
## Usage: godot --headless --path . -s res://tests/run_tests.gd [-- name_filter]
## Loads every res://tests/test_*.gd, runs each test_* method and exits
## non-zero if anything failed.


## Counts engine and script errors so a test that crashes half-way (GDScript
## abandons the function and carries on) is reported as failed, not as ok.
class ErrorCounter:
	extends Logger
	var count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		count += 1


func _init() -> void:
	var errors: ErrorCounter = ErrorCounter.new()
	OS.add_logger(errors)
	var filter: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	var files: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://tests")
	if dir == null:
		print("TESTS FAILED: cannot open res://tests")
		quit(1)
		return
	for f: String in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()

	var total_tests: int = 0
	var total_checks: int = 0
	var all_failures: Array[String] = []
	var started: int = Time.get_ticks_msec()

	for f: String in files:
		var script: GDScript = load("res://tests/" + f) as GDScript
		if script == null:
			all_failures.append("%s: could not load script" % f)
			continue
		var methods: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var mname: String = m["name"]
			if mname.begins_with("test_") and not methods.has(mname):
				methods.append(mname)
		for mname: String in methods:
			if filter != "" and not (f + "." + mname).contains(filter):
				continue
			var obj: Object = script.new()
			var tc: TestCase = obj as TestCase
			if tc == null:
				all_failures.append("%s: does not extend TestCase" % f)
				break
			tc.current_test = "%s.%s" % [f.trim_suffix(".gd"), mname]
			var t0: int = Time.get_ticks_msec()
			var errors_before: int = errors.count
			tc.call(mname)
			var dt: int = Time.get_ticks_msec() - t0
			if errors.count > errors_before:
				tc.failures.append("%s: %d error(s) were raised while it ran" % [tc.current_test, errors.count - errors_before])
			total_tests += 1
			total_checks += tc.checks
			var status: String = "ok"
			if tc.failures.size() > 0:
				status = "FAIL"
				all_failures.append_array(tc.failures)
			elif tc.checks == 0:
				status = "FAIL"
				all_failures.append("%s: made no checks (crashed early?)" % tc.current_test)
			print("  [%s] %s (%d checks, %d ms)" % [status, tc.current_test, tc.checks, dt])

	var elapsed: int = Time.get_ticks_msec() - started
	if total_tests == 0:
		all_failures.append("no tests were found")
	if all_failures.size() > 0:
		print("TESTS FAILED: %d failure(s) in %d tests" % [all_failures.size(), total_tests])
		for line: String in all_failures:
			print("  - " + line)
		quit(1)
	else:
		print("TESTS PASSED: %d tests, %d checks, %d ms" % [total_tests, total_checks, elapsed])
		quit(0)
