#!/usr/bin/env -S godot --headless --script

## Automated transition testing runner
## Run this script to automatically test transitions and capture errors

extends SceneTree

var tester: Node
var error_found: bool = false

func _init():
	print("🚀 Starting automated transition testing...")

	# Create and add the tester
	tester = preload("res://tools/AutoTransitionTester.gd").new()
	root.add_child(tester)

	# Connect to error detection
	tester.transition_error_detected.connect(_on_error_detected)
	tester.test_cycle_completed.connect(_on_tests_completed)

	# Wait a moment then start testing
	await create_timer(1.0).timeout

	# Load a basic scene first
	var error = change_scene_to_file("res://common/UI/Menu.tscn")
	if error != OK:
		print("❌ Failed to load initial scene: %d" % error)
		quit(1)
		return

	await create_timer(2.0).timeout

	# Start the automated testing
	tester.start_automated_testing()

func _on_error_detected(error_details: Dictionary):
	error_found = true
	print("🐛 ERROR DETECTED: %s" % error_details)

	# Extract useful information for debugging
	print("📍 Location: Test %d" % error_details.get("test_index", -1))
	print("🔍 Details: %s" % error_details.get("details", {}))
	print("🎬 Scene: %s" % error_details.get("current_scene", "unknown"))

func _on_tests_completed(results: Dictionary):
	print("\n📋 TEST CYCLE COMPLETED")
	print("Total tests: %d" % results.get("total_tests", 0))
	print("Errors found: %d" % results.get("errors", []).size())

	var errors = results.get("errors", [])
	if errors.size() > 0:
		print("\n🔧 ACTIONABLE ERRORS TO FIX:")
		for error in errors:
			print("  ❌ %s" % error.get("message", "Unknown error"))
			var details = error.get("details", {})
			if details.size() > 0:
				print("     Details: %s" % details)

	# Exit with appropriate code
	quit(1 if error_found else 0)