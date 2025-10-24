#!/usr/bin/env -S godot --headless --script

## Automated Function Testing Launcher
## Simple launcher for comprehensive runtime function testing
## Usage: godot --headless --script tools/run_automated_function_tests.gd

extends SceneTree

func _init():
	print("🚀 LAUNCHING AUTOMATED FUNCTION TESTING SUITE")
	print("=".repeat(60))
	print("🎯 Testing ALL runtime-only functions automatically")
	print("🔍 No manual gameplay required!")
	print("📊 Complete error capture and analysis")
	print("=".repeat(60))

	# Launch the comprehensive testing suite
	_launch_testing_suite()

func _launch_testing_suite():
	print("\n🔧 Initializing automated testing systems...")

	# Load and run the main testing suite
	var tester = preload("res://tools/AutomatedFunctionTester.gd").new()

	# The tester will handle everything automatically
	print("✅ Automated Function Testing Suite launched successfully!")
	print("📝 All results will be captured and analyzed automatically")
	print("⏳ Testing in progress... Please wait for completion")

	# The testing suite will quit automatically when complete
	await create_timer(1.0).timeout
	quit(0)