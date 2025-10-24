extends Node

## Debug System Integration Example
## Demonstrates how to use all the iterative debugging components together
## This can be attached to your main scene for comprehensive error monitoring

var runtime_aggregator: RuntimeErrorAggregator
var debug_orchestrator: IterativeDebugOrchestrator
var autofix_engine: AutoFixEngine
var interactive_controller: Node

var debug_session_active: bool = false

func _ready() -> void:
	print("🚀 Initializing Comprehensive Debug System Integration")
	_setup_debug_components()
	_connect_signals()

func _setup_debug_components() -> void:
	"""Initialize all debug system components"""

	# AutoFix Engine
	autofix_engine = AutoFixEngine.new()
	autofix_engine.name = "AutoFixEngine"
	add_child(autofix_engine)

	# Debug Orchestrator
	debug_orchestrator = IterativeDebugOrchestrator.new()
	debug_orchestrator.name = "DebugOrchestrator"
	add_child(debug_orchestrator)

	# Interactive Debug Controller
	interactive_controller = preload("res://tools/InteractiveDebugController.gd").new()
	interactive_controller.name = "InteractiveController"
	add_child(interactive_controller)

	print("✅ All debug components initialized")

func _connect_signals() -> void:
	"""Connect signals between debug components"""

	# Connect RuntimeErrorAggregator signals (if available globally)
	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.error_detected.connect(_on_error_detected)
		RuntimeErrorAggregator.critical_error_detected.connect(_on_critical_error)
		RuntimeErrorAggregator.pattern_detected.connect(_on_pattern_detected)

	# Connect AutoFix Engine signals
	if autofix_engine:
		autofix_engine.fix_generated.connect(_on_fix_generated)
		autofix_engine.fix_applied.connect(_on_fix_applied)
		autofix_engine.fix_failed.connect(_on_fix_failed)

	# Connect Debug Orchestrator signals
	if debug_orchestrator:
		debug_orchestrator.iteration_started.connect(_on_iteration_started)
		debug_orchestrator.iteration_completed.connect(_on_iteration_completed)
		debug_orchestrator.pattern_detected.connect(_on_orchestrator_pattern_detected)
		debug_orchestrator.debug_session_completed.connect(_on_debug_session_completed)

	print("✅ Debug system signals connected")

## Signal Handlers

func _on_error_detected(error_data: Dictionary) -> void:
	"""Handle error detection from RuntimeErrorAggregator"""
	print("🔍 Error detected: %s - %s" % [error_data.get("type", "Unknown"), error_data.get("message", "No message")])

	# Generate and potentially apply fix
	if autofix_engine and debug_session_active:
		var fix: Dictionary = autofix_engine.generate_fix(error_data)
		if not fix.is_empty():
			# Apply fix with high confidence
			if fix.get("confidence", 0) >= AutoFixEngine.FixConfidence.HIGH:
				autofix_engine.apply_fix(fix)

func _on_critical_error(error_data: Dictionary) -> void:
	"""Handle critical error detection"""
	print("🚨 CRITICAL ERROR: %s" % error_data.get("message", "Unknown critical error"))

	# Always attempt to fix critical errors
	if autofix_engine:
		var fix: Dictionary = autofix_engine.generate_fix(error_data)
		if not fix.is_empty():
			autofix_engine.apply_fix(fix)

func _on_pattern_detected(pattern_name: String, pattern_data: Dictionary) -> void:
	"""Handle pattern detection"""
	print("🔄 Pattern detected: %s" % pattern_name)

	# Generate pattern-based fixes
	if autofix_engine and pattern_data.get("severity", "") == "high":
		# Create error data from pattern for fix generation
		var synthetic_error: Dictionary = {
			"type": pattern_name,
			"message": "Pattern-based error: %s" % pattern_name,
			"context": pattern_data
		}
		var fix: Dictionary = autofix_engine.generate_fix(synthetic_error)
		if not fix.is_empty():
			autofix_engine.apply_fix(fix)

func _on_fix_generated(fix_data: Dictionary) -> void:
	"""Handle fix generation"""
	print("💡 Fix generated: %s (Confidence: %d)" % [fix_data.get("description", "Unknown"), fix_data.get("confidence", 0)])

func _on_fix_applied(fix_data: Dictionary, success: bool) -> void:
	"""Handle fix application result"""
	if success:
		print("✅ Fix applied successfully: %s" % fix_data.get("description", "Unknown"))
	else:
		print("❌ Fix application failed: %s" % fix_data.get("description", "Unknown"))

func _on_fix_failed(fix_data: Dictionary, reason: String) -> void:
	"""Handle fix failure"""
	print("⚠️ Fix failed: %s - Reason: %s" % [fix_data.get("description", "Unknown"), reason])

func _on_iteration_started(iteration: int) -> void:
	"""Handle iteration start"""
	print("🔄 Debug iteration %d started" % iteration)

func _on_iteration_completed(iteration: int, results: Dictionary) -> void:
	"""Handle iteration completion"""
	print("✅ Debug iteration %d completed - Errors: %d" % [iteration, results.get("error_count", 0)])

	# Process errors from iteration
	if autofix_engine and results.get("critical_errors", []).size() > 0:
		var fixes: Array = autofix_engine.process_error_batch(results["critical_errors"])
		if fixes.size() > 0:
			autofix_engine.apply_fix_batch(fixes, 3)  # Apply up to 3 fixes per iteration

func _on_orchestrator_pattern_detected(pattern: Dictionary) -> void:
	"""Handle pattern detection from orchestrator"""
	print("📊 Orchestrator pattern detected: %s" % pattern.get("type", "Unknown"))

func _on_debug_session_completed(final_results: Dictionary) -> void:
	"""Handle debug session completion"""
	debug_session_active = false
	print("🏁 Debug session completed!")
	print("  Total iterations: %d" % final_results.get("total_iterations", 0))
	print("  Final error count: %d" % final_results.get("final_error_count", 0))
	print("  Zero errors achieved: %s" % final_results.get("zero_errors_achieved", false))

	# Generate comprehensive report
	_generate_final_report(final_results)

## Public API for manual control

func start_comprehensive_debugging() -> void:
	"""Start comprehensive debugging session with all components"""
	if debug_session_active:
		print("⚠️ Debug session already active")
		return

	print("🚀 Starting comprehensive debugging session...")
	debug_session_active = true

	# Configure orchestrator
	debug_orchestrator.set_iteration_config(5, 30.0, 3)  # 5 iterations, 30s each, 3-iteration convergence
	debug_orchestrator.enable_auto_fix(true)
	debug_orchestrator.enable_pattern_detection(true)

	# Start interactive controller
	if interactive_controller and interactive_controller.has_method("enable_auto_start"):
		interactive_controller.enable_auto_start()

	# Start orchestrated debugging
	debug_orchestrator.start_iterative_debugging()

func start_interactive_monitoring() -> void:
	"""Start only interactive monitoring without orchestrator"""
	if interactive_controller and interactive_controller.has_method("enable_auto_start"):
		interactive_controller.enable_auto_start()
		print("🎮 Interactive monitoring started")

func stop_all_debugging() -> void:
	"""Stop all debugging components"""
	debug_session_active = false

	if debug_orchestrator:
		debug_orchestrator.stop_iterative_debugging()

	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.stop_monitoring()

	print("⏹️ All debugging stopped")

func generate_comprehensive_report() -> void:
	"""Generate comprehensive debugging report"""
	print("\n" + "="*60)
	print("📊 COMPREHENSIVE DEBUG SYSTEM REPORT")
	print("="*60)

	# RuntimeErrorAggregator report
	if RuntimeErrorAggregator:
		print("\n🔍 Runtime Error Aggregator:")
		RuntimeErrorAggregator.print_comprehensive_report()

	# FailureLogger report
	if FailureLogger:
		print("\n🧪 Failure Logger:")
		FailureLogger.print_error_report()

	# AutoFix Engine report
	if autofix_engine:
		print("\n🔧 AutoFix Engine:")
		var fix_analysis: Dictionary = autofix_engine.analyze_fix_patterns()
		print("  Total fixes applied: %d" % fix_analysis["total_fixes_applied"])

		var success_rates: Dictionary = autofix_engine.get_fix_success_rate()
		for fix_type in success_rates:
			var rate_data: Dictionary = success_rates[fix_type]
			print("  %s success rate: %.1f%% (%d/%d)" % [
				fix_type,
				rate_data["success_rate"] * 100,
				rate_data["successes"],
				rate_data["attempts"]
			])

	# Orchestrator status
	if debug_orchestrator:
		print("\n📈 Debug Orchestrator:")
		var status: Dictionary = debug_orchestrator.get_session_status()
		print("  Session active: %s" % status["active"])
		print("  Iterations completed: %d/%d" % [status["iterations_completed"], status["max_iterations"]])
		print("  Patterns detected: %d" % status["patterns_detected"])
		print("  Fixes applied: %d" % status["fixes_applied"])

	print("="*60 + "\n")

func _generate_final_report(final_results: Dictionary) -> void:
	"""Generate and export final comprehensive report"""
	var report_data: Dictionary = {
		"session_info": final_results,
		"runtime_aggregator": RuntimeErrorAggregator.get_error_summary() if RuntimeErrorAggregator else {},
		"failure_logger": FailureLogger.get_error_summary() if FailureLogger else {},
		"autofix_engine": autofix_engine.analyze_fix_patterns() if autofix_engine else {},
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Export individual component reports
	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.export_errors_to_file()

	if autofix_engine:
		autofix_engine.export_fix_report()

	# Export combined report
	var export_path: String = "user://comprehensive_debug_report_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open(export_path, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(report_data))
		file.close()
		print("📄 Comprehensive report exported to: %s" % export_path)

## Input handling for quick commands

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F9:  # Start comprehensive debugging
				start_comprehensive_debugging()
			KEY_F10: # Start interactive monitoring only
				start_interactive_monitoring()
			KEY_F11: # Generate report
				generate_comprehensive_report()
			KEY_F12: # Stop all debugging
				stop_all_debugging()

## Example usage in your main scene:
##
## func _ready():
##     var debug_integration = preload("res://tools/DebugSystemIntegration.gd").new()
##     add_child(debug_integration)
##
##     # Optional: Start debugging automatically
##     # debug_integration.start_comprehensive_debugging()
##
##     # Or start just interactive monitoring
##     # debug_integration.start_interactive_monitoring()

## Keyboard shortcuts:
## F9  - Start comprehensive debugging session
## F10 - Start interactive monitoring only
## F11 - Generate comprehensive report
## F12 - Stop all debugging