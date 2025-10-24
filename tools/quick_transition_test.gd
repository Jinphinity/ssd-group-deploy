#!/usr/bin/env -S godot --headless --script

## Quick Transition Test
## Simple, fast transition test that can be run frequently during development

extends SceneTree

var test_results = {
	"transitions_tested": 0,
	"errors_found": 0,
	"start_time": 0
}

func _init():
	print("⚡ QUICK TRANSITION TEST")
	print("=" * 30)

	test_results.start_time = Time.get_ticks_msec()
	_run_quick_tests()

func _run_quick_tests():
	print("🔍 Testing critical transition paths...")

	# Test 1: Menu to Game transition
	await _test_transition("res://common/UI/Menu.tscn", "res://stages/Stage_Outpost_2D.tscn")

	# Test 2: Game to Game transition (common source of timer issues)
	await _test_transition("res://stages/Stage_Outpost_2D.tscn", "res://stages/Stage_Hostile_01_2D.tscn")

	# Test 3: Back to base transition
	await _test_transition("res://stages/Stage_Hostile_01_2D.tscn", "res://stages/Stage_Outpost_2D.tscn")

	# Test 4: Return to menu
	await _test_transition("res://stages/Stage_Outpost_2D.tscn", "res://common/UI/Menu.tscn")

	_print_quick_results()
	quit(0)

func _test_transition(from_scene: String, to_scene: String):
	"""Test a single transition path"""
	print("  🔄 %s → %s" % [from_scene.get_file(), to_scene.get_file()])

	# Load source scene
	var error = change_scene_to_file(from_scene)
	if error != OK:
		test_results.errors_found += 1
		print("    ❌ Failed to load source scene")
		return

	await create_timer(0.8).timeout  # Allow scene to initialize

	# Transition to target scene
	error = change_scene_to_file(to_scene)
	if error != OK:
		test_results.errors_found += 1
		print("    ❌ Transition failed")
		return

	await create_timer(0.5).timeout  # Allow transition to complete
	test_results.transitions_tested += 1
	print("    ✅ Success")

func _print_quick_results():
	var elapsed = (Time.get_ticks_msec() - test_results.start_time) / 1000.0

	print("\n📊 QUICK TEST RESULTS:")
	print("  • Transitions tested: %d" % test_results.transitions_tested)
	print("  • Errors found: %d" % test_results.errors_found)
	print("  • Test time: %.1f seconds" % elapsed)

	if test_results.errors_found == 0:
		print("  ✅ All transitions working!")
	else:
		print("  ⚠️ Issues detected - run full transition test")

	print("=" * 30)