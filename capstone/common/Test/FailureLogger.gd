extends Node

## Enhanced Runtime Error Detection & Logging System
## Captures runtime errors, failed validations, missing paths, and system failures
## Designed for iterative debugging workflows with comprehensive error analysis

enum LogLevel {
	SILENT,     # No output when things work (Production)
	FAILURE,    # Only log failures and missing paths (Development)
	DEBUG       # Full debug mode (Testing/Troubleshooting)
}

static var current_level: LogLevel = LogLevel.FAILURE
static var _expected_paths: Dictionary = {}
static var _component_access: Dictionary = {}
static var _test_mode: bool = false
static var _runtime_errors: Array = []
static var _error_patterns: Dictionary = {}
static var _session_start_time: float = 0.0

## Core Logging Functions

static func log_failure(message: String, context: Dictionary = {}):
	"""Always log failures regardless of level"""
	var context_str = ""
	if not context.is_empty():
		context_str = " | Context: %s" % context
	print("❌ FAILURE: %s%s" % [message, context_str])

static func log_missing_path(expected_path: String, actual_path: String = ""):
	"""Log when expected code paths aren't reached"""
	if actual_path == "":
		print("🚫 MISSING PATH: Expected '%s' but never reached" % expected_path)
	else:
		print("🚫 MISSING PATH: Expected '%s' but reached '%s'" % [expected_path, actual_path])

static func log_success(message: String):
	"""Only log success in DEBUG mode"""
	if current_level == LogLevel.DEBUG:
		print("✅ SUCCESS: %s" % message)

static func log_test_failure(test_name: String, expected: Variant, actual: Variant):
	"""Log test assertion failures with detailed comparison"""
	print("🧪 TEST FAILED: %s" % test_name)
	print("   Expected: %s" % expected)
	print("   Actual:   %s" % actual)

## Enhanced Runtime Error Detection

static func log_runtime_error(error_type: String, message: String, context: Dictionary = {}):
	"""Log comprehensive runtime errors with timestamps and context"""
	var timestamp: float = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
	var error_data: Dictionary = {
		"type": error_type,
		"message": message,
		"context": context,
		"timestamp": timestamp,
		"session_time": timestamp - _session_start_time
	}
	_runtime_errors.append(error_data)

	var context_str: String = ""
	if not context.is_empty():
		context_str = " | Context: %s" % context
	print("💥 RUNTIME ERROR [%s]: %s%s" % [error_type, message, context_str])

static func log_null_reference(node_path: String, accessing_script: String = ""):
	"""Log null reference errors"""
	var context: Dictionary = {"node_path": node_path}
	if accessing_script != "":
		context["script"] = accessing_script
	log_runtime_error("NULL_REFERENCE", "Attempted to access null node: %s" % node_path, context)

static func log_missing_node(node_path: String, parent_node: String = ""):
	"""Log when expected nodes are missing from scene tree"""
	var context: Dictionary = {"expected_path": node_path}
	if parent_node != "":
		context["parent"] = parent_node
	log_runtime_error("MISSING_NODE", "Node not found in scene tree: %s" % node_path, context)

static func log_signal_connection_failure(signal_name: String, source_node: String, target_node: String, target_method: String):
	"""Log signal connection failures"""
	var context: Dictionary = {
		"signal": signal_name,
		"source": source_node,
		"target": target_node,
		"method": target_method
	}
	log_runtime_error("SIGNAL_CONNECTION_FAILED", "Failed to connect signal %s from %s to %s.%s" % [signal_name, source_node, target_node, target_method], context)

static func log_resource_load_failure(resource_path: String, resource_type: String = ""):
	"""Log resource loading failures"""
	var context: Dictionary = {"path": resource_path}
	if resource_type != "":
		context["type"] = resource_type
	log_runtime_error("RESOURCE_LOAD_FAILED", "Failed to load resource: %s" % resource_path, context)

static func log_scene_instantiation_failure(scene_path: String):
	"""Log scene instantiation failures"""
	var context: Dictionary = {"scene_path": scene_path}
	log_runtime_error("SCENE_INSTANTIATION_FAILED", "Failed to instantiate scene: %s" % scene_path, context)

static func log_method_call_failure(object_name: String, method_name: String, error_message: String = ""):
	"""Log method call failures"""
	var context: Dictionary = {"object": object_name, "method": method_name}
	if error_message != "":
		context["error"] = error_message
	log_runtime_error("METHOD_CALL_FAILED", "Failed to call method %s on %s" % [method_name, object_name], context)

static func log_property_access_failure(object_name: String, property_name: String):
	"""Log property access failures"""
	var context: Dictionary = {"object": object_name, "property": property_name}
	log_runtime_error("PROPERTY_ACCESS_FAILED", "Failed to access property %s on %s" % [property_name, object_name], context)

static func log_autoload_failure(autoload_name: String):
	"""Log autoload access failures"""
	var context: Dictionary = {"autoload": autoload_name}
	log_runtime_error("AUTOLOAD_FAILED", "Failed to access autoload: %s" % autoload_name, context)

## Path Validation System

static func expect_path(path_name: String):
	"""Register expected path - will log if not reached"""
	_expected_paths[path_name] = false

static func reached_path(path_name: String):
	"""Mark path as reached"""
	if path_name in _expected_paths:
		_expected_paths[path_name] = true
		if current_level == LogLevel.DEBUG:
			print("🎯 PATH REACHED: %s" % path_name)
	else:
		log_missing_path("Unexpected path reached", path_name)

static func validate_all_paths():
	"""Check if all expected paths were reached"""
	for path_name in _expected_paths:
		if not _expected_paths[path_name]:
			log_missing_path(path_name)

## Component Access Tracking

static func expect_component(component_name: String):
	"""Register expected component access"""
	_component_access[component_name] = false

static func component_accessed(component_name: String):
	"""Mark component as accessed"""
	if component_name in _component_access:
		_component_access[component_name] = true
		if current_level == LogLevel.DEBUG:
			print("🎯 COMPONENT ACCESSED: %s" % component_name)
	else:
		log_failure("Undefined component accessed", {"component": component_name})

static func validate_component_access():
	"""Check if all designed components were accessed"""
	for component_name in _component_access:
		if not _component_access[component_name]:
			log_failure("Designed component never accessed", {"component": component_name})

## TDD Integration

static func start_tdd_cycle(test_name: String):
	"""Start TDD cycle - test should fail initially"""
	_test_mode = true
	log_success("Starting TDD cycle for: %s" % test_name)

static func test_should_fail(test_name: String):
	"""Log when test should fail (Red phase)"""
	if current_level == LogLevel.DEBUG:
		print("🔴 RED PHASE: Test should fail - %s" % test_name)

static func test_should_pass(test_name: String):
	"""Silent success when test passes (Green phase)"""
	if current_level == LogLevel.DEBUG:
		print("🟢 GREEN PHASE: Test passes - %s" % test_name)

static func tdd_violation(violation_type: String, details: String = ""):
	"""Log TDD workflow violations"""
	var message = "TDD violation: %s" % violation_type
	if details != "":
		message += " - %s" % details
	log_failure(message)

## Configuration Management

static func set_log_level(level: LogLevel):
	"""Set logging level"""
	current_level = level
	match level:
		LogLevel.SILENT:
			print("🔇 Logging: SILENT mode - only critical failures")
		LogLevel.FAILURE:
			print("ℹ️ Logging: FAILURE-ONLY mode - failures and missing paths")
		LogLevel.DEBUG:
			print("🔍 Logging: DEBUG mode - full output")

static func set_production_mode():
	"""Set production-safe logging"""
	set_log_level(LogLevel.SILENT)

static func set_development_mode():
	"""Set development logging"""
	set_log_level(LogLevel.FAILURE)

static func set_debug_mode():
	"""Set full debug logging"""
	set_log_level(LogLevel.DEBUG)

## Utility Functions

static func assert_true(condition: bool, message: String = "") -> bool:
	"""TDD-friendly assertion that only logs failures"""
	if not condition:
		if message == "":
			log_failure("Assertion failed: Expected true but got false")
		else:
			log_failure("Assertion failed: %s" % message)
		return false
	return true

static func assert_equal(expected: Variant, actual: Variant, message: String = "") -> bool:
	"""TDD-friendly equality assertion"""
	if expected != actual:
		if message == "":
			log_test_failure("Equality assertion", expected, actual)
		else:
			log_test_failure(message, expected, actual)
		return false
	return true

static func assert_not_null(value: Variant, message: String = "") -> bool:
	"""TDD-friendly null check"""
	if value == null:
		if message == "":
			log_failure("Assertion failed: Value is null")
		else:
			log_failure("Null check failed: %s" % message)
		return false
	return true

## Error Analysis & Reporting

static func start_session():
	"""Initialize error tracking session"""
	_session_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
	_runtime_errors.clear()
	_error_patterns.clear()
	print("🚀 FailureLogger session started")

static func get_error_summary() -> Dictionary:
	"""Get comprehensive error summary for analysis"""
	var summary: Dictionary = {
		"total_errors": _runtime_errors.size(),
		"error_types": {},
		"patterns": _error_patterns,
		"session_duration": (Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]) - _session_start_time
	}

	for error_data in _runtime_errors:
		var error_type: String = error_data["type"]
		if error_type in summary["error_types"]:
			summary["error_types"][error_type] += 1
		else:
			summary["error_types"][error_type] = 1

	return summary

static func export_error_log() -> String:
	"""Export comprehensive error log for external analysis"""
	var export_data: Dictionary = {
		"session_info": {
			"start_time": _session_start_time,
			"duration": (Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]) - _session_start_time,
			"godot_version": Engine.get_version_info()
		},
		"errors": _runtime_errors,
		"summary": get_error_summary()
	}
	return JSON.stringify(export_data)

static func detect_error_patterns():
	"""Analyze errors for patterns and common issues"""
	_error_patterns.clear()

	var null_ref_count: int = 0
	var missing_node_count: int = 0
	var signal_failures: int = 0

	for error_data in _runtime_errors:
		match error_data["type"]:
			"NULL_REFERENCE":
				null_ref_count += 1
			"MISSING_NODE":
				missing_node_count += 1
			"SIGNAL_CONNECTION_FAILED":
				signal_failures += 1

	if null_ref_count > 3:
		_error_patterns["frequent_null_references"] = "High frequency of null reference errors detected (%d occurrences)" % null_ref_count

	if missing_node_count > 2:
		_error_patterns["missing_nodes_pattern"] = "Multiple missing node errors suggest scene structure issues (%d occurrences)" % missing_node_count

	if signal_failures > 1:
		_error_patterns["signal_connection_issues"] = "Signal connection problems detected (%d failures)" % signal_failures

static func get_critical_errors() -> Array:
	"""Get only critical errors that need immediate attention"""
	var critical_errors: Array = []

	for error_data in _runtime_errors:
		if error_data["type"] in ["NULL_REFERENCE", "AUTOLOAD_FAILED", "SCENE_INSTANTIATION_FAILED"]:
			critical_errors.append(error_data)

	return critical_errors

static func print_error_report():
	"""Print comprehensive error report to console"""
	print("\n" + "=".repeat(50))
	print("📊 RUNTIME ERROR ANALYSIS REPORT")
	print("=".repeat(50))

	var summary: Dictionary = get_error_summary()
	print("Session Duration: %.1f seconds" % summary["session_duration"])
	print("Total Errors: %d" % summary["total_errors"])

	if summary["total_errors"] > 0:
		print("\nError Breakdown:")
		for error_type in summary["error_types"]:
			print("  %s: %d occurrences" % [error_type, summary["error_types"][error_type]])

		detect_error_patterns()
		if not _error_patterns.is_empty():
			print("\nDetected Patterns:")
			for pattern in _error_patterns:
				print("  ⚠️ %s: %s" % [pattern, _error_patterns[pattern]])

		var critical: Array = get_critical_errors()
		if not critical.is_empty():
			print("\n🚨 Critical Errors Requiring Immediate Attention:")
			for error_data in critical:
				print("  - [%s] %s" % [error_data["type"], error_data["message"]])
	else:
		print("✅ No runtime errors detected!")

	print("=".repeat(50) + "\n")

## Reset Functions

static func reset_paths():
	"""Reset path tracking for new test"""
	_expected_paths.clear()

static func reset_components():
	"""Reset component tracking for new test"""
	_component_access.clear()

static func reset_all():
	"""Reset all tracking for clean test state"""
	reset_paths()
	reset_components()
	_test_mode = false
	_runtime_errors.clear()
	_error_patterns.clear()

static func reset_runtime_errors():
	"""Reset only runtime error tracking"""
	_runtime_errors.clear()
	_error_patterns.clear()
