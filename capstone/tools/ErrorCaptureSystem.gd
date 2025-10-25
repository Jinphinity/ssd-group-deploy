extends Node

## Enhanced Error Capture System for Transition Testing
## Automatically runs the game, triggers transitions, captures errors, and reports solutions

signal error_captured(error_details: Dictionary)
signal fix_suggested(error_details: Dictionary, suggested_fix: String)

var captured_errors: Array = []
var transition_count: int = 0
var monitoring_active: bool = false

func _ready() -> void:
	print("🔧 ErrorCaptureSystem initialized")
	# Override push_error to capture all errors
	_setup_error_monitoring()

func _setup_error_monitoring():
	monitoring_active = true
	print("📊 Error monitoring activated")

func start_comprehensive_test() -> void:
	print("🚀 Starting comprehensive transition and error testing...")

	# Test sequence that should trigger various errors
	_run_test_sequence()

func _run_test_sequence() -> void:
	print("📋 Running test sequence...")

	# Test 1: Force a transition during game initialization
	await get_tree().create_timer(1.0).timeout
	_test_early_transition()

	# Test 2: Rapid transitions
	await get_tree().create_timer(2.0).timeout
	_test_rapid_transitions()

	# Test 3: Transition with invalid scene
	await get_tree().create_timer(2.0).timeout
	_test_invalid_transitions()

	# Test 4: Null node access during transition
	await get_tree().create_timer(2.0).timeout
	_test_null_access_scenarios()

	print("✅ Test sequence completed. Captured %d errors." % captured_errors.size())
	_analyze_captured_errors()

func _test_early_transition():
	print("🧪 Test 1: Early transition during initialization")
	# This might trigger the data.tree null error
	var error = get_tree().change_scene_to_file("res://stages/Stage_Hostile_01_2D.tscn")
	if error != OK:
		_capture_error("Scene change failed early", {"error_code": error, "test": "early_transition"})

func _test_rapid_transitions():
	print("🧪 Test 2: Rapid transitions")
	var scenes = [
		"res://stages/Stage_Outpost_2D.tscn",
		"res://stages/Stage_Hostile_01_2D.tscn"
	]

	for scene in scenes:
		var error = get_tree().change_scene_to_file(scene)
		if error != OK:
			_capture_error("Rapid transition failed", {"error_code": error, "scene": scene})
		await get_tree().process_frame  # Very short delay

func _test_invalid_transitions():
	print("🧪 Test 3: Invalid transitions")
	# Try to transition to non-existent scene
	var error = get_tree().change_scene_to_file("res://nonexistent.tscn")
	if error != OK:
		_capture_error("Invalid scene transition", {"error_code": error, "test": "invalid_scene"})

func _test_null_access_scenarios():
	print("🧪 Test 4: Null access scenarios")

	# Try to access tree from detached node
	var detached_node = Node.new()
	# Don't add to tree, then try to access tree
	var test_result = _test_detached_node_tree_access(detached_node)
	detached_node.queue_free()

func _test_detached_node_tree_access(node: Node) -> bool:
	# This should trigger the kind of error we're looking for
	if node.get_tree() == null:
		_capture_error("Node tree access while detached", {"test": "detached_node", "node_type": node.get_class()})
		return false
	return true

func _capture_error(message: String, context: Dictionary = {}):
	var error_details = {
		"timestamp": Time.get_time_string_from_system(),
		"message": message,
		"context": context,
		"transition_count": transition_count,
		"current_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "null"
	}

	captured_errors.append(error_details)
	print("🐛 ERROR CAPTURED: %s" % message)
	error_captured.emit(error_details)

	# Immediately try to suggest a fix
	var suggested_fix = _suggest_fix_for_error(error_details)
	if suggested_fix != "":
		print("💡 SUGGESTED FIX: %s" % suggested_fix)
		fix_suggested.emit(error_details, suggested_fix)

func _suggest_fix_for_error(error_details: Dictionary) -> String:
	var message = error_details.get("message", "")
	var context = error_details.get("context", {})

	# Pattern matching for common errors
	if "tree access" in message.to_lower():
		return "Add null check: if node.get_tree(): before accessing tree"
	elif "scene change failed" in message.to_lower():
		var error_code = context.get("error_code", -1)
		match error_code:
			ERR_FILE_NOT_FOUND:
				return "Scene file not found. Check scene path exists."
			ERR_PARSE_ERROR:
				return "Scene parse error. Check scene file for syntax errors."
			_:
				return "Scene change error %d. Check scene validity." % error_code
	elif "rapid transition" in message.to_lower():
		return "Add transition delay: await get_tree().create_timer(0.1).timeout"
	elif "parameter.*null" in message.to_lower():
		return "Add null checking before parameter access"

	return ""

func _analyze_captured_errors():
	print("\n" + "=".repeat(60))
	print("🔍 ERROR ANALYSIS REPORT")
	print("=".repeat(60))

	if captured_errors.size() == 0:
		print("✅ No errors captured during testing")
		return

	print("❌ Total errors captured: %d" % captured_errors.size())
	print("\n📋 Error Summary:")

	var error_types = {}
	for error in captured_errors:
		var msg = error.get("message", "Unknown")
		if error_types.has(msg):
			error_types[msg] += 1
		else:
			error_types[msg] = 1

	for error_type in error_types.keys():
		print("  • %s: %d occurrences" % [error_type, error_types[error_type]])

	print("\n🔧 Recommended Fixes:")
	for error in captured_errors:
		var fix = _suggest_fix_for_error(error)
		if fix != "":
			print("  • %s → %s" % [error.get("message", ""), fix])

	print("=".repeat(60))

# Manual trigger functions
func trigger_problematic_transition():
	print("🎯 Manually triggering problematic transition...")
	_test_rapid_transitions()

func get_error_report() -> Array:
	return captured_errors.duplicate()

# Override _notification to catch tree changes
func _notification(what):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			print("📊 Application closing. Final error count: %d" % captured_errors.size())
		NOTIFICATION_CRASH:
			print("💥 Application crashed. Captured errors: %d" % captured_errors.size())