extends Node

## Automated Transition Testing System
## Automatically triggers transitions to find and help fix errors

signal transition_error_detected(error_details: Dictionary)
signal test_cycle_completed(results: Dictionary)

var test_scenarios: Array = [
	{
		"name": "Outpost to Hostile",
		"from_scene": "res://stages/Stage_Outpost_2D.tscn",
		"to_scene": "res://stages/Stage_Hostile_01_2D.tscn",
		"trigger_method": "automatic"
	},
	{
		"name": "Hostile back to Outpost",
		"from_scene": "res://stages/Stage_Hostile_01_2D.tscn",
		"to_scene": "res://stages/Stage_Outpost_2D.tscn",
		"trigger_method": "automatic"
	}
]

var current_test_index: int = 0
var test_results: Dictionary = {}
var error_log: Array = []
var test_timer: Timer
var transition_timeout: float = 10.0
var is_testing: bool = false

func _ready() -> void:
	print("🔧 AutoTransitionTester initialized")

	# Set up test timer
	test_timer = Timer.new()
	test_timer.wait_time = 3.0  # Wait 3 seconds between tests
	test_timer.one_shot = true
	test_timer.timeout.connect(_run_next_test)
	add_child(test_timer)

	# Connect to transition manager if available
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game.has_method("get_transition_manager"):
			var tm = game.get_transition_manager()
			if tm and tm.has_signal("transition_completed"):
				tm.transition_completed.connect(_on_transition_completed)
			if tm and tm.has_signal("transition_failed"):
				tm.transition_failed.connect(_on_transition_failed)

func start_automated_testing() -> void:
	if is_testing:
		print("⚠️ Testing already in progress")
		return

	print("🚀 Starting automated transition testing...")
	is_testing = true
	current_test_index = 0
	test_results.clear()
	error_log.clear()

	# Start the first test
	test_timer.start()

func stop_testing() -> void:
	is_testing = false
	if test_timer:
		test_timer.stop()
	print("⏹️ Automated testing stopped")

func _run_next_test() -> void:
	if not is_testing or current_test_index >= test_scenarios.size():
		_complete_testing()
		return

	var scenario = test_scenarios[current_test_index]
	print("🧪 Running test %d/%d: %s" % [current_test_index + 1, test_scenarios.size(), scenario.name])

	# Trigger the transition
	_trigger_transition(scenario)

func _trigger_transition(scenario: Dictionary) -> void:
	var to_scene = scenario.get("to_scene", "")

	if to_scene == "":
		_log_error("Invalid scenario: missing to_scene", scenario)
		_advance_to_next_test()
		return

	print("🔄 Triggering transition to: %s" % to_scene)

	# Try multiple methods to trigger transition
	var success = false

	# Method 1: Direct TransitionManager call
	if has_node("/root/TransitionManager"):
		var tm = get_node("/root/TransitionManager")
		if tm.has_method("transition_to"):
			tm.transition_to(to_scene)
			success = true
			print("✅ Transition triggered via TransitionManager")

	# Method 2: Scene tree change
	if not success:
		var error = get_tree().change_scene_to_file(to_scene)
		if error == OK:
			success = true
			print("✅ Transition triggered via scene change")
		else:
			print("❌ Scene change failed with error: %d" % error)

	if not success:
		_log_error("Failed to trigger transition", scenario)

	# Set up timeout for this test
	await get_tree().create_timer(transition_timeout).timeout
	if is_testing:
		_advance_to_next_test()

func _on_transition_completed(scene_path: String) -> void:
	print("✅ Transition completed to: %s" % scene_path)
	if is_testing:
		_log_success("Transition successful", {"scene": scene_path})
		_advance_to_next_test()

func _on_transition_failed(error_message: String) -> void:
	print("❌ Transition failed: %s" % error_message)
	if is_testing:
		_log_error("Transition failed", {"error": error_message})
		_advance_to_next_test()

func _log_error(message: String, details: Dictionary = {}) -> void:
	var error_entry = {
		"timestamp": Time.get_time_string_from_system(),
		"test_index": current_test_index,
		"message": message,
		"details": details,
		"current_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "unknown"
	}
	error_log.append(error_entry)
	print("🐛 ERROR LOGGED: %s" % message)
	transition_error_detected.emit(error_entry)

func _log_success(message: String, details: Dictionary = {}) -> void:
	var scenario = test_scenarios[current_test_index] if current_test_index < test_scenarios.size() else {}
	var result_key = scenario.get("name", "test_%d" % current_test_index)
	test_results[result_key] = {
		"status": "success",
		"message": message,
		"details": details,
		"timestamp": Time.get_time_string_from_system()
	}

func _advance_to_next_test() -> void:
	current_test_index += 1
	if current_test_index < test_scenarios.size():
		test_timer.start()
	else:
		_complete_testing()

func _complete_testing() -> void:
	is_testing = false
	print("🏁 Automated transition testing completed")
	print("📊 Results: %d tests, %d errors found" % [test_scenarios.size(), error_log.size()])

	_print_summary()
	test_cycle_completed.emit({
		"total_tests": test_scenarios.size(),
		"errors": error_log,
		"results": test_results
	})

func _print_summary() -> void:
	print("\n" + "=".repeat(50))
	print("🔍 AUTOMATED TRANSITION TEST SUMMARY")
	print("=".repeat(50))

	for i in range(test_scenarios.size()):
		var scenario = test_scenarios[i]
		var result_key = scenario.get("name", "test_%d" % i)

		if test_results.has(result_key):
			print("✅ %s: %s" % [scenario.name, test_results[result_key].message])
		else:
			print("❌ %s: Failed or timed out" % scenario.name)

	if error_log.size() > 0:
		print("\n🐛 ERRORS DETECTED:")
		for error in error_log:
			print("  - %s: %s" % [error.message, error.details])
	else:
		print("\n✨ No errors detected!")

	print("=".repeat(50) + "\n")

# Manual trigger functions for debugging
func trigger_single_transition(to_scene: String) -> void:
	print("🎯 Manual transition trigger to: %s" % to_scene)
	_trigger_transition({"to_scene": to_scene, "name": "Manual Test"})

func get_error_summary() -> Array:
	return error_log.duplicate()

func get_test_results() -> Dictionary:
	return test_results.duplicate()

# Command line interface
func run_quick_test() -> void:
	print("⚡ Running quick transition test...")
	trigger_single_transition("res://stages/Stage_Hostile_01_2D.tscn")
	await get_tree().create_timer(3.0).timeout
	trigger_single_transition("res://stages/Stage_Outpost_2D.tscn")