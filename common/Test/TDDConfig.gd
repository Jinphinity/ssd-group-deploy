extends Node

## TDD Configuration and Workflow Management
## Enforces Test-Driven Development practices with failure-only logging

enum Mode {
	PRODUCTION,  # Silent success, failure-only logging
	DEVELOPMENT, # Moderate logging for debugging
	TDD_STRICT   # Enforce TDD workflow, log violations
}

# Global configuration
static var current_mode: Mode = Mode.DEVELOPMENT
static var enforce_tdd: bool = false
static var log_successful_tests: bool = false
static var validate_component_access: bool = true
static var require_test_before_implementation: bool = false

# TDD workflow tracking
static var _current_test_cycle: Dictionary = {}
static var _implementation_allowed: bool = true
static var _tests_written: Array[String] = []
static var _implementations_created: Array[String] = []

func _ready():
	"""Initialize TDD configuration"""
	_setup_default_mode()
	_connect_to_test_events()

func _setup_default_mode():
	"""Set up default TDD mode based on environment"""
	if OS.has_feature("debug"):
		set_tdd_mode(Mode.DEVELOPMENT)
	else:
		set_tdd_mode(Mode.PRODUCTION)

func _connect_to_test_events():
	"""Connect to test execution events"""
	# Connect to scene tree changes to detect test runs
	if get_tree():
		get_tree().node_added.connect(_on_node_added)

## Mode Management

static func set_tdd_mode(mode: Mode):
	"""Set TDD mode and configure logging accordingly"""
	current_mode = mode

	match mode:
		Mode.PRODUCTION:
			FailureLogger.set_log_level(FailureLogger.LogLevel.SILENT)
			enforce_tdd = false
			log_successful_tests = false
			validate_component_access = true

		Mode.DEVELOPMENT:
			FailureLogger.set_log_level(FailureLogger.LogLevel.FAILURE)
			enforce_tdd = false
			log_successful_tests = false
			validate_component_access = true

		Mode.TDD_STRICT:
			FailureLogger.set_log_level(FailureLogger.LogLevel.DEBUG)
			enforce_tdd = true
			log_successful_tests = true
			validate_component_access = true
			require_test_before_implementation = true

	FailureLogger.log_success("TDD mode set to: %s" % Mode.keys()[mode])

static func enable_strict_tdd():
	"""Enable strict TDD enforcement"""
	set_tdd_mode(Mode.TDD_STRICT)

static func enable_failure_only_logging():
	"""Enable failure-only logging mode"""
	set_tdd_mode(Mode.DEVELOPMENT)

static func enable_production_mode():
	"""Enable silent production mode"""
	set_tdd_mode(Mode.PRODUCTION)

## TDD Workflow Management

static func start_test_cycle(test_name: String, feature_description: String = ""):
	"""Start a new TDD cycle"""
	if enforce_tdd and _implementation_allowed:
		FailureLogger.tdd_violation("Implementation created before test", test_name)

	_current_test_cycle = {
		"test_name": test_name,
		"feature": feature_description,
		"phase": "RED",
		"start_time": Time.get_ticks_msec(),
		"test_written": false,
		"test_failed_initially": false,
		"implementation_created": false,
		"test_passed": false
	}

	_implementation_allowed = false
	FailureLogger.start_tdd_cycle(test_name)

static func mark_test_written(test_name: String):
	"""Mark that a test has been written"""
	_tests_written.append(test_name)
	if _current_test_cycle.get("test_name", "") == test_name:
		_current_test_cycle["test_written"] = true

static func mark_test_failed_initially(test_name: String):
	"""Mark that test failed initially (Red phase)"""
	if _current_test_cycle.get("test_name", "") == test_name:
		_current_test_cycle["test_failed_initially"] = true
		_current_test_cycle["phase"] = "RED"
		_implementation_allowed = true
		FailureLogger.test_should_fail(test_name)

static func mark_implementation_created(feature_name: String):
	"""Mark that implementation has been created"""
	if not _implementation_allowed and enforce_tdd:
		FailureLogger.tdd_violation("Implementation created before test failure", feature_name)

	_implementations_created.append(feature_name)
	if _current_test_cycle.has("feature") and _current_test_cycle["feature"] == feature_name:
		_current_test_cycle["implementation_created"] = true
		_current_test_cycle["phase"] = "GREEN"

static func mark_test_passed(test_name: String):
	"""Mark that test now passes (Green phase)"""
	if _current_test_cycle.get("test_name", "") == test_name:
		_current_test_cycle["test_passed"] = true
		_current_test_cycle["phase"] = "GREEN"
		FailureLogger.test_should_pass(test_name)

		# Validate complete TDD cycle
		_validate_tdd_cycle()

static func start_refactor_phase():
	"""Start refactoring phase"""
	if _current_test_cycle.get("phase", "") == "GREEN":
		_current_test_cycle["phase"] = "REFACTOR"
		FailureLogger.log_success("Starting refactor phase")

static func complete_tdd_cycle():
	"""Complete current TDD cycle"""
	var cycle_summary = _current_test_cycle.duplicate()
	_current_test_cycle.clear()
	_implementation_allowed = true

	if enforce_tdd:
		_generate_cycle_report(cycle_summary)

## Validation Functions

static func _validate_tdd_cycle():
	"""Validate that TDD cycle was followed correctly"""
	if not enforce_tdd:
		return

	var cycle = _current_test_cycle
	var violations: Array[String] = []

	if not cycle.get("test_written", false):
		violations.append("Test was not written")

	if not cycle.get("test_failed_initially", false):
		violations.append("Test did not fail initially (Red phase missing)")

	if not cycle.get("implementation_created", false):
		violations.append("Implementation was not created")

	if not cycle.get("test_passed", false):
		violations.append("Test does not pass after implementation")

	if violations.size() > 0:
		FailureLogger.tdd_violation("Incomplete TDD cycle", str(violations))

static func _generate_cycle_report(cycle: Dictionary):
	"""Generate TDD cycle completion report"""
	var duration = Time.get_ticks_msec() - cycle.get("start_time", 0)
	var success = (cycle.get("test_written", false) and
					cycle.get("test_failed_initially", false) and
					cycle.get("implementation_created", false) and
					cycle.get("test_passed", false))

	if success:
		FailureLogger.log_success("TDD cycle completed: %s (%.2fs)" % [
			cycle.get("test_name", "unknown"),
			duration / 1000.0
		])
	else:
		FailureLogger.log_failure("TDD cycle incomplete", cycle)

## Component Integration

static func validate_designed_components():
	"""Validate that all designed components are accessible"""
	if not validate_component_access:
		return

	if ComponentTracker:
		ComponentTracker.validate_component_access()
		ComponentTracker.validate_expected_flows()

## Test Detection

func _on_node_added(node: Node):
	"""Detect when test nodes are added to scene tree"""
	if enforce_tdd and node.get_script():
		var script_path = node.get_script().resource_path
		if script_path.contains("test_") or script_path.contains("Test"):
			var test_name = script_path.get_file().get_basename()
			mark_test_written(test_name)

## Configuration Validation

static func validate_configuration() -> bool:
	"""Validate TDD configuration is set up correctly"""
	var config_valid = true
	var issues: Array[String] = []

	# Check if FailureLogger is available
	if not FailureLogger:
		issues.append("FailureLogger not available")
		config_valid = false

	# Check if ComponentTracker is available when required
	if validate_component_access and not ComponentTracker:
		issues.append("ComponentTracker not available but component validation enabled")
		config_valid = false

	# Check TDD mode consistency
	if enforce_tdd and current_mode != Mode.TDD_STRICT:
		issues.append("TDD enforcement enabled but not in TDD_STRICT mode")
		config_valid = false

	if issues.size() > 0:
		FailureLogger.log_failure("TDD configuration invalid", {"issues": issues})

	return config_valid

## Utility Functions

static func get_tdd_status() -> Dictionary:
	"""Get current TDD workflow status"""
	return {
		"mode": Mode.keys()[current_mode],
		"enforce_tdd": enforce_tdd,
		"current_cycle": _current_test_cycle,
		"implementation_allowed": _implementation_allowed,
		"tests_written": _tests_written.size(),
		"implementations_created": _implementations_created.size()
	}

static func reset_tdd_tracking():
	"""Reset TDD workflow tracking"""
	_current_test_cycle.clear()
	_implementation_allowed = true
	_tests_written.clear()
	_implementations_created.clear()
	FailureLogger.reset_all()

## Debug Functions (only in DEBUG mode)

static func print_tdd_summary():
	"""Print TDD workflow summary (DEBUG mode only)"""
	if current_mode == Mode.TDD_STRICT:
		var status = get_tdd_status()
		print("🧪 TDD SUMMARY:")
		print("  Mode: %s" % status.mode)
		print("  Tests Written: %d" % status.tests_written)
		print("  Implementations: %d" % status.implementations_created)
		print("  Current Cycle: %s" % status.current_cycle)
		print("  Implementation Allowed: %s" % status.implementation_allowed)