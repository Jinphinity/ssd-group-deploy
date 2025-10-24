#!/usr/bin/env -S godot --headless --script

## Run the comprehensive error capture system
extends SceneTree

var error_capture_system: Node

func _init():
	print("🚀 Starting comprehensive error capture and transition testing...")

	# Add the error capture system
	error_capture_system = preload("res://tools/ErrorCaptureSystem.gd").new()
	root.add_child(error_capture_system)

	# Connect to signals
	error_capture_system.error_captured.connect(_on_error_captured)
	error_capture_system.fix_suggested.connect(_on_fix_suggested)

	# Wait a moment then start
	await create_timer(0.5).timeout

	# Start the comprehensive test
	error_capture_system.start_comprehensive_test()

	# Give it time to complete
	await create_timer(10.0).timeout

	# Print final report
	_print_final_report()

	# Exit
	quit(0)

func _on_error_captured(error_details: Dictionary):
	print("📍 ERROR LOCATION: %s" % error_details.get("current_scene", "unknown"))
	print("🔍 CONTEXT: %s" % error_details.get("context", {}))

func _on_fix_suggested(error_details: Dictionary, suggested_fix: String):
	print("🔧 AUTOMATED FIX SUGGESTION:")
	print("   Problem: %s" % error_details.get("message", ""))
	print("   Solution: %s" % suggested_fix)
	print("")

func _print_final_report():
	print("\n🏁 ERROR CAPTURE TESTING COMPLETED")

	var errors = error_capture_system.get_error_report()

	if errors.size() > 0:
		print("📊 ACTIONABLE RESULTS:")
		print("   • %d errors captured and analyzed" % errors.size())
		print("   • Automated fixes suggested for common patterns")
		print("   • Ready for immediate implementation")
	else:
		print("✅ No errors detected during comprehensive testing")
		print("   • All transition scenarios passed")
		print("   • System appears stable")

	print("\n🎯 NEXT STEPS:")
	if errors.size() > 0:
		print("   1. Review suggested fixes above")
		print("   2. Implement null checks and defensive coding")
		print("   3. Re-run test to validate fixes")
	else:
		print("   1. System appears stable")
		print("   2. Monitor during normal gameplay")
		print("   3. Implement preventive measures as needed")