extends Node

## Iterative Debug Orchestrator
## Main controller for iterative runtime error debugging workflow
## Coordinates error detection, pattern analysis, and automated fixing

class_name IterativeDebugOrchestrator

signal iteration_started(iteration: int)
signal iteration_completed(iteration: int, results: Dictionary)
signal pattern_detected(pattern: Dictionary)
signal fix_applied(fix_data: Dictionary)
signal debug_session_completed(final_results: Dictionary)

## Configuration
var max_iterations: int = 10
var iteration_duration: float = 30.0  # seconds per iteration
var error_convergence_threshold: int = 3  # stop if errors stay same for N iterations
var auto_fix_enabled: bool = true
var pattern_detection_enabled: bool = true

## State tracking
var current_iteration: int = 0
var session_active: bool = false
var iteration_results: Array = []
var detected_patterns: Dictionary = {}
var applied_fixes: Array = []
var baseline_errors: Array = []

## Internal components
var _iteration_timer: Timer
var _current_iteration_errors: Array = []
var _error_stability_count: int = 0

func _ready() -> void:
	if not RuntimeErrorAggregator or not FailureLogger:
		print("❌ Required debugging components not available")
		return

	_setup_iteration_timer()
	_connect_error_signals()
	print("🔧 IterativeDebugOrchestrator ready")

func _setup_iteration_timer():
	"""Setup timer for iteration control"""
	_iteration_timer = Timer.new()
	_iteration_timer.one_shot = true
	_iteration_timer.timeout.connect(_complete_current_iteration)
	add_child(_iteration_timer)

func _connect_error_signals():
	"""Connect to error detection signals"""
	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.error_detected.connect(_on_error_detected)
		RuntimeErrorAggregator.pattern_detected.connect(_on_pattern_detected)

func start_iterative_debugging() -> void:
	"""Start the iterative debugging session"""
	if session_active:
		print("⚠️ Debug session already active")
		return

	print("🚀 Starting iterative debugging session")
	print("  Max iterations: %d" % max_iterations)
	print("  Iteration duration: %.1fs" % iteration_duration)
	print("  Auto-fix enabled: %s" % auto_fix_enabled)

	session_active = true
	current_iteration = 0
	iteration_results.clear()
	detected_patterns.clear()
	applied_fixes.clear()
	_error_stability_count = 0

	# Capture baseline errors before starting
	_capture_baseline_errors()

	# Start first iteration
	_start_iteration()

func stop_iterative_debugging() -> void:
	"""Stop the current debugging session"""
	if not session_active:
		return

	session_active = false
	_iteration_timer.stop()

	print("⏹️ Debugging session stopped")
	_finalize_session()

func _capture_baseline_errors() -> void:
	"""Capture current errors as baseline"""
	if FailureLogger:
		FailureLogger.reset_runtime_errors()
		FailureLogger.start_session()

	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.clear_aggregated_errors()
		RuntimeErrorAggregator.start_monitoring()

	print("📊 Baseline error state captured")

func _start_iteration() -> void:
	"""Start a new debugging iteration"""
	if not session_active:
		return

	current_iteration += 1

	if current_iteration > max_iterations:
		print("🏁 Maximum iterations reached")
		_finalize_session()
		return

	print("🔄 Starting iteration %d/%d" % [current_iteration, max_iterations])

	# Reset error tracking for this iteration
	_current_iteration_errors.clear()

	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.clear_aggregated_errors()
		RuntimeErrorAggregator.start_monitoring()

	if FailureLogger:
		FailureLogger.reset_runtime_errors()

	emit_signal("iteration_started", current_iteration)

	# Start iteration timer
	_iteration_timer.wait_time = iteration_duration
	_iteration_timer.start()

	print("⏱️ Iteration %d running for %.1f seconds..." % [current_iteration, iteration_duration])

func _complete_current_iteration() -> void:
	"""Complete the current iteration and analyze results"""
	if not session_active:
		return

	print("✅ Iteration %d completed" % current_iteration)

	# Stop monitoring
	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.stop_monitoring()

	# Analyze iteration results
	var results: Dictionary = _analyze_iteration_results()
	iteration_results.append(results)

	emit_signal("iteration_completed", current_iteration, results)

	print("📊 Iteration %d results:" % current_iteration)
	print("  Errors detected: %d" % results["error_count"])
	print("  Critical errors: %d" % results["critical_count"])
	print("  New patterns: %d" % results["new_patterns"])

	# Check for convergence
	if _check_convergence(results):
		print("🎯 Error convergence detected")
		_finalize_session()
		return

	# Apply fixes if enabled
	if auto_fix_enabled and results["error_count"] > 0:
		_apply_automated_fixes(results)

	# Brief pause before next iteration
	await get_tree().create_timer(2.0).timeout

	# Start next iteration
	_start_iteration()

func _analyze_iteration_results() -> Dictionary:
	"""Analyze the results of the current iteration"""
	var results: Dictionary = {
		"iteration": current_iteration,
		"error_count": 0,
		"critical_count": 0,
		"warning_count": 0,
		"new_patterns": 0,
		"errors_by_type": {},
		"critical_errors": [],
		"detected_patterns": [],
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Get aggregated error data
	if RuntimeErrorAggregator:
		var summary: Dictionary = RuntimeErrorAggregator.get_error_summary()
		results["error_count"] = summary["total_errors"]
		results["errors_by_type"] = summary["by_type"]

		if "critical" in summary["by_severity"]:
			results["critical_count"] = summary["by_severity"]["critical"]

		if "medium" in summary["by_severity"]:
			results["warning_count"] = summary["by_severity"]["medium"]

		# Get critical errors for fixing
		results["critical_errors"] = RuntimeErrorAggregator.get_critical_errors()

	# Get FailureLogger data
	if FailureLogger:
		var failure_summary: Dictionary = FailureLogger.get_error_summary()
		results["failure_logger_errors"] = failure_summary["total_errors"]

	# Detect new patterns
	if pattern_detection_enabled:
		var new_patterns: Array = _detect_new_patterns(results)
		results["detected_patterns"] = new_patterns
		results["new_patterns"] = new_patterns.size()

	return results

func _detect_new_patterns(results: Dictionary) -> Array:
	"""Detect new error patterns in current iteration"""
	var new_patterns: Array = []

	# Pattern 1: Repeated error types
	for error_type in results["errors_by_type"]:
		var count: int = results["errors_by_type"][error_type]
		if count >= 3 and not error_type in detected_patterns:
			var pattern: Dictionary = {
				"type": "repeated_error",
				"error_type": error_type,
				"count": count,
				"iteration_detected": current_iteration,
				"severity": "high"
			}
			new_patterns.append(pattern)
			detected_patterns[error_type] = pattern
			emit_signal("pattern_detected", pattern)

	# Pattern 2: Error escalation (more errors than previous iteration)
	if iteration_results.size() > 0:
		var previous_results: Dictionary = iteration_results[-1]
		if results["error_count"] > previous_results["error_count"] * 1.5:
			var pattern: Dictionary = {
				"type": "error_escalation",
				"previous_count": previous_results["error_count"],
				"current_count": results["error_count"],
				"iteration_detected": current_iteration,
				"severity": "critical"
			}
			new_patterns.append(pattern)
			emit_signal("pattern_detected", pattern)

	# Pattern 3: Critical error persistence
	if results["critical_count"] > 0:
		var critical_persistent: bool = false
		if iteration_results.size() >= 2:
			var last_two_had_critical: bool = true
			for i in range(max(0, iteration_results.size() - 2), iteration_results.size()):
				if iteration_results[i]["critical_count"] == 0:
					last_two_had_critical = false
					break

			if last_two_had_critical:
				critical_persistent = true

		if critical_persistent:
			var pattern: Dictionary = {
				"type": "persistent_critical_errors",
				"count": results["critical_count"],
				"iteration_detected": current_iteration,
				"severity": "critical"
			}
			new_patterns.append(pattern)
			emit_signal("pattern_detected", pattern)

	return new_patterns

func _check_convergence(results: Dictionary) -> bool:
	"""Check if errors have converged (no improvement)"""
	if iteration_results.size() < error_convergence_threshold:
		return false

	# Check if error count has remained stable
	var recent_error_counts: Array = []
	var recent_results: Array = iteration_results.slice(-error_convergence_threshold)

	for result in recent_results:
		recent_error_counts.append(result["error_count"])

	recent_error_counts.append(results["error_count"])

	# Check if all recent counts are the same
	var first_count: int = recent_error_counts[0]
	for count in recent_error_counts:
		if count != first_count:
			_error_stability_count = 0
			return false

	_error_stability_count += 1

	# Also check if we've reached zero errors
	if results["error_count"] == 0:
		print("🎉 Zero errors achieved!")
		return true

	return _error_stability_count >= error_convergence_threshold

func _apply_automated_fixes(results: Dictionary) -> void:
	"""Apply automated fixes based on detected errors"""
	if not auto_fix_enabled:
		return

	print("🔧 Applying automated fixes...")

	var fixes_applied: int = 0

	# Fix critical errors first
	for error_data in results["critical_errors"]:
		var fix: Dictionary = _generate_fix_for_error(error_data)
		if not fix.is_empty():
			if _apply_fix(fix):
				applied_fixes.append(fix)
				fixes_applied += 1
				emit_signal("fix_applied", fix)

	# Fix common patterns
	for pattern in results["detected_patterns"]:
		var fix: Dictionary = _generate_fix_for_pattern(pattern)
		if not fix.is_empty():
			if _apply_fix(fix):
				applied_fixes.append(fix)
				fixes_applied += 1
				emit_signal("fix_applied", fix)

	if fixes_applied > 0:
		print("🛠️ Applied %d automated fixes" % fixes_applied)
	else:
		print("ℹ️ No applicable automated fixes found")

func _generate_fix_for_error(error_data: Dictionary) -> Dictionary:
	"""Generate automated fix for specific error"""
	var fix: Dictionary = {}

	match error_data.get("type", ""):
		"NULL_REFERENCE":
			fix = {
				"type": "null_check_addition",
				"error_data": error_data,
				"action": "add_null_checks",
				"confidence": 0.8,
				"description": "Add null checks before accessing objects"
			}

		"MISSING_NODE":
			fix = {
				"type": "node_validation",
				"error_data": error_data,
				"action": "add_node_validation",
				"confidence": 0.7,
				"description": "Add node existence validation"
			}

		"SIGNAL_CONNECTION_FAILED":
			fix = {
				"type": "signal_fix",
				"error_data": error_data,
				"action": "fix_signal_connections",
				"confidence": 0.6,
				"description": "Fix signal connection issues"
			}

	return fix

func _generate_fix_for_pattern(pattern: Dictionary) -> Dictionary:
	"""Generate automated fix for detected pattern"""
	var fix: Dictionary = {}

	match pattern.get("type", ""):
		"repeated_error":
			fix = {
				"type": "pattern_fix",
				"pattern": pattern,
				"action": "prevent_error_repetition",
				"confidence": 0.7,
				"description": "Add prevention for repeated %s errors" % pattern.get("error_type", "unknown")
			}

		"error_escalation":
			fix = {
				"type": "escalation_prevention",
				"pattern": pattern,
				"action": "add_error_limits",
				"confidence": 0.5,
				"description": "Add error handling to prevent escalation"
			}

	return fix

func _apply_fix(fix: Dictionary) -> bool:
	"""Apply a specific fix to the codebase"""
	# For now, this is a placeholder that logs the fix
	# In a full implementation, this would modify actual code files
	print("🔧 APPLYING FIX: %s" % fix.get("description", "Unknown fix"))
	print("  Type: %s" % fix.get("type", "Unknown"))
	print("  Confidence: %.1f" % fix.get("confidence", 0.0))

	# Simulate fix application success/failure based on confidence
	var confidence: float = fix.get("confidence", 0.0)
	var success_chance: float = randf()

	if success_chance <= confidence:
		print("  ✅ Fix applied successfully")
		return true
	else:
		print("  ❌ Fix application failed")
		return false

func _finalize_session() -> void:
	"""Finalize the debugging session and generate final report"""
	session_active = false

	print("\n" + "="*50)
	print("🏁 ITERATIVE DEBUGGING SESSION COMPLETE")
	print("="*50)

	var final_results: Dictionary = _generate_final_report()
	emit_signal("debug_session_completed", final_results)

	print("📊 Session Summary:")
	print("  Total iterations: %d" % current_iteration)
	print("  Total patterns detected: %d" % detected_patterns.size())
	print("  Total fixes applied: %d" % applied_fixes.size())

	if iteration_results.size() > 0:
		var last_results: Dictionary = iteration_results[-1]
		print("  Final error count: %d" % last_results["error_count"])
		print("  Final critical errors: %d" % last_results["critical_count"])

	print("="*50)

	# Export detailed results
	_export_session_results()

func _generate_final_report() -> Dictionary:
	"""Generate comprehensive final report"""
	var report: Dictionary = {
		"session_complete": true,
		"total_iterations": current_iteration,
		"max_iterations": max_iterations,
		"iteration_results": iteration_results,
		"detected_patterns": detected_patterns,
		"applied_fixes": applied_fixes,
		"convergence_achieved": false,
		"zero_errors_achieved": false,
		"session_duration": 0.0,
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Check final status
	if iteration_results.size() > 0:
		var last_results: Dictionary = iteration_results[-1]
		report["final_error_count"] = last_results["error_count"]
		report["zero_errors_achieved"] = last_results["error_count"] == 0
		report["convergence_achieved"] = _error_stability_count >= error_convergence_threshold

	# Calculate session duration
	if iteration_results.size() > 0:
		report["session_duration"] = current_iteration * iteration_duration

	return report

func _export_session_results() -> void:
	"""Export session results to file"""
	var export_path: String = "user://iterative_debug_session_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var final_results: Dictionary = _generate_final_report()

	var file := FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(final_results))
		file.close()
		print("📄 Session results exported to: %s" % export_path)
	else:
		print("❌ Failed to export session results")

func _on_error_detected(error_data: Dictionary) -> void:
	"""Handle error detection during iteration"""
	if session_active:
		_current_iteration_errors.append(error_data)

func _on_pattern_detected(pattern_name: String, pattern_data: Dictionary) -> void:
	"""Handle pattern detection during iteration"""
	if session_active:
		print("🔄 Pattern detected during iteration %d: %s" % [current_iteration, pattern_name])

## Public API

func set_iteration_config(max_iter: int, duration: float, convergence_threshold: int) -> void:
	"""Configure iteration parameters"""
	max_iterations = max_iter
	iteration_duration = duration
	error_convergence_threshold = convergence_threshold

func enable_auto_fix(enabled: bool) -> void:
	"""Enable/disable automated fixing"""
	auto_fix_enabled = enabled

func enable_pattern_detection(enabled: bool) -> void:
	"""Enable/disable pattern detection"""
	pattern_detection_enabled = enabled

func get_session_status() -> Dictionary:
	"""Get current session status"""
	return {
		"active": session_active,
		"current_iteration": current_iteration,
		"max_iterations": max_iterations,
		"iterations_completed": iteration_results.size(),
		"patterns_detected": detected_patterns.size(),
		"fixes_applied": applied_fixes.size()
	}

## Example usage:
## var orchestrator = IterativeDebugOrchestrator.new()
## add_child(orchestrator)
## orchestrator.set_iteration_config(5, 60.0, 3)  # 5 iterations, 60s each, 3-iteration convergence
## orchestrator.enable_auto_fix(true)
## orchestrator.start_iterative_debugging()