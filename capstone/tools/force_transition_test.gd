#!/usr/bin/env -S godot --headless --script

## Force transition test - directly trigger problematic transitions
extends SceneTree

var errors_found: Array = []

func _init():
	print("🎯 Force Transition Test - triggering problematic transitions...")

	# Override error handling to capture everything
	_setup_error_capture()

	# Start the test sequence
	_run_test_sequence()

func _setup_error_capture():
	# Monitor for errors
	Engine.connect("stderr_flush", _on_stderr_output)

func _on_stderr_output():
	print("⚠️ Error output detected")

func _run_test_sequence():
	print("📋 Starting transition test sequence...")

	# Test 1: Direct scene change
	await _test_direct_scene_change()

	# Test 2: Transition manager
	await _test_transition_manager()

	# Test 3: Rapid transitions
	await _test_rapid_transitions()

	print("🏁 Test sequence completed")
	_print_summary()
	quit(0)

func _test_direct_scene_change():
	print("\n🧪 Test 1: Direct scene changes")

	# Load menu first
	print("   Loading Menu...")
	var error = change_scene_to_file("res://common/UI/Menu.tscn")
	if error != OK:
		_log_error("Failed to load Menu.tscn: %d" % error)
	await create_timer(1.0).timeout

	# Try transition to Outpost
	print("   Transitioning to Outpost...")
	error = change_scene_to_file("res://stages/Stage_Outpost_2D.tscn")
	if error != OK:
		_log_error("Failed to load Stage_Outpost_2D.tscn: %d" % error)
	await create_timer(2.0).timeout

	# Try transition to Hostile
	print("   Transitioning to Hostile...")
	error = change_scene_to_file("res://stages/Stage_Hostile_01_2D.tscn")
	if error != OK:
		_log_error("Failed to load Stage_Hostile_01_2D.tscn: %d" % error)
	await create_timer(2.0).timeout

func _test_transition_manager():
	print("\n🧪 Test 2: TransitionManager")

	# Check if TransitionManager exists
	if has_node("/root/TransitionManager"):
		var tm = get_node("/root/TransitionManager")
		print("   TransitionManager found")

		if tm.has_method("transition_to"):
			print("   Testing TransitionManager.transition_to()")
			tm.transition_to("res://stages/Stage_Outpost_2D.tscn")
			await create_timer(3.0).timeout
		else:
			_log_error("TransitionManager missing transition_to method")
	else:
		_log_error("TransitionManager not found in scene tree")

func _test_rapid_transitions():
	print("\n🧪 Test 3: Rapid transitions")

	var scenes = [
		"res://stages/Stage_Outpost_2D.tscn",
		"res://stages/Stage_Hostile_01_2D.tscn",
		"res://stages/Stage_Outpost_2D.tscn"
	]

	for scene in scenes:
		print("   Rapid transition to: %s" % scene)
		var error = change_scene_to_file(scene)
		if error != OK:
			_log_error("Rapid transition failed: %d to %s" % [error, scene])
		await create_timer(0.5).timeout  # Very short delay

func _log_error(message: String):
	errors_found.append({
		"message": message,
		"timestamp": Time.get_time_string_from_system()
	})
	print("❌ ERROR: %s" % message)

func _print_summary():
	print("\n" + "=".repeat(60))
	print("🔍 FORCE TRANSITION TEST SUMMARY")
	print("=".repeat(60))

	if errors_found.size() > 0:
		print("❌ %d errors found:" % errors_found.size())
		for error in errors_found:
			print("  • %s" % error.message)
	else:
		print("✅ No errors detected in transition tests")

	print("=".repeat(60))