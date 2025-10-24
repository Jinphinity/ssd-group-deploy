extends Node

## Runtime Error Aggregation System
## Monitors multiple log sources and provides unified error analysis
## Designed for iterative debugging workflows with pattern detection

# Removed class_name to avoid conflict with autoload singleton

signal error_detected(error_data: Dictionary)
signal critical_error_detected(error_data: Dictionary)
signal pattern_detected(pattern_name: String, pattern_data: Dictionary)

## Configuration
var godot_log_path: String = ""
var custom_log_path: String = ""
var monitoring_enabled: bool = false
var auto_analysis_enabled: bool = true

## Internal state
var _log_watcher_timer: Timer
var _last_godot_log_size: int = 0
var _last_custom_log_size: int = 0
var _aggregated_errors: Array = []
var _session_patterns: Dictionary = {}
var _critical_threshold: int = 3

func _ready() -> void:
	# Set up log paths
	godot_log_path = OS.get_user_data_dir() + "/logs/godot.log"
	custom_log_path = OS.get_user_data_dir() + "/logs/capstone_runtime.log"

	# Create timer for log monitoring
	_log_watcher_timer = Timer.new()
	_log_watcher_timer.wait_time = 1.0  # Check every second
	_log_watcher_timer.timeout.connect(_check_logs)
	add_child(_log_watcher_timer)

	print("🔍 RuntimeErrorAggregator initialized")
	print("  Godot log path: %s" % godot_log_path)
	print("  Custom log path: %s" % custom_log_path)

func start_monitoring():
	"""Start real-time log monitoring"""
	monitoring_enabled = true
	_reset_log_positions()
	_log_watcher_timer.start()
	FailureLogger.start_session()
	print("🚀 Error monitoring started")

func stop_monitoring():
	"""Stop log monitoring"""
	monitoring_enabled = false
	_log_watcher_timer.stop()
	print("⏹️ Error monitoring stopped")

func _reset_log_positions():
	"""Reset log file positions for fresh monitoring"""
	_last_godot_log_size = _get_file_size(godot_log_path)
	_last_custom_log_size = _get_file_size(custom_log_path)

func _get_file_size(file_path: String) -> int:
	"""Get current file size, returns 0 if file doesn't exist"""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = file.get_length()
	file.close()
	return size

func _check_logs():
	"""Check for new log entries and process them"""
	if not monitoring_enabled:
		return

	_check_godot_log()
	_check_custom_log()

	if auto_analysis_enabled and _aggregated_errors.size() > 0:
		_analyze_error_patterns()

func _check_godot_log():
	"""Check Godot's native log for new errors"""
	var current_size: int = _get_file_size(godot_log_path)
	if current_size <= _last_godot_log_size:
		return

	var file := FileAccess.open(godot_log_path, FileAccess.READ)
	if file == null:
		return

	file.seek(_last_godot_log_size)
	var new_content: String = file.get_as_text()
	file.close()

	_last_godot_log_size = current_size
	_process_godot_log_content(new_content)

func _check_custom_log():
	"""Check custom application log for new entries"""
	var current_size: int = _get_file_size(custom_log_path)
	if current_size <= _last_custom_log_size:
		return

	var file := FileAccess.open(custom_log_path, FileAccess.READ)
	if file == null:
		return

	file.seek(_last_custom_log_size)
	var new_content: String = file.get_as_text()
	file.close()

	_last_custom_log_size = current_size
	_process_custom_log_content(new_content)

func _process_godot_log_content(content: String):
	"""Process new Godot log content for errors"""
	var lines: PackedStringArray = content.split("\n")

	for line in lines:
		if line.strip_edges() == "":
			continue

		# Detect various Godot error patterns
		if line.contains("ERROR:") or line.contains("SCRIPT ERROR:"):
			_create_error_from_godot_line(line, "GODOT_ERROR")
		elif line.contains("WARNING:"):
			_create_error_from_godot_line(line, "GODOT_WARNING")
		elif line.contains("Cannot call method") or line.contains("Invalid call"):
			_create_error_from_godot_line(line, "METHOD_CALL_ERROR")
		elif line.contains("Null Variant"):
			_create_error_from_godot_line(line, "NULL_VARIANT")
		elif line.contains("Node not found"):
			_create_error_from_godot_line(line, "NODE_NOT_FOUND")

func _process_custom_log_content(content: String):
	"""Process custom application log content"""
	var lines: PackedStringArray = content.split("\n")

	for line in lines:
		if line.strip_edges() == "":
			continue

		# Process FailureLogger output
		if line.contains("💥 RUNTIME ERROR"):
			_parse_failure_logger_error(line)
		elif line.contains("❌ FAILURE:"):
			_parse_failure_logger_failure(line)

func _create_error_from_godot_line(line: String, error_type: String):
	"""Create structured error data from Godot log line"""
	var error_data: Dictionary = {
		"source": "GODOT_ENGINE",
		"type": error_type,
		"message": line.strip_edges(),
		"timestamp": Time.get_time_dict_from_system(),
		"severity": _get_severity_for_type(error_type)
	}

	_add_aggregated_error(error_data)

func _parse_failure_logger_error(line: String):
	"""Parse FailureLogger error output"""
	# Extract error type and message from FailureLogger format
	var regex := RegEx.new()
	regex.compile(r"💥 RUNTIME ERROR \[(.+?)\]: (.+?)(?:\s*\|\s*Context: (.+))?$")
	var result := regex.search(line)

	if result:
		var error_data: Dictionary = {
			"source": "FAILURE_LOGGER",
			"type": result.get_string(1),
			"message": result.get_string(2),
			"context": result.get_string(3) if result.get_group_count() > 2 else "",
			"timestamp": Time.get_time_dict_from_system(),
			"severity": _get_severity_for_type(result.get_string(1))
		}

		_add_aggregated_error(error_data)

func _parse_failure_logger_failure(line: String):
	"""Parse FailureLogger general failure output"""
	var error_data: Dictionary = {
		"source": "FAILURE_LOGGER",
		"type": "GENERAL_FAILURE",
		"message": line.replace("❌ FAILURE:", "").strip_edges(),
		"timestamp": Time.get_time_dict_from_system(),
		"severity": "medium"
	}

	_add_aggregated_error(error_data)

func _get_severity_for_type(error_type: String) -> String:
	"""Determine severity level for error type"""
	match error_type:
		"NULL_REFERENCE", "AUTOLOAD_FAILED", "SCENE_INSTANTIATION_FAILED", "GODOT_ERROR":
			return "critical"
		"MISSING_NODE", "SIGNAL_CONNECTION_FAILED", "METHOD_CALL_ERROR":
			return "high"
		"RESOURCE_LOAD_FAILED", "PROPERTY_ACCESS_FAILED", "GODOT_WARNING":
			return "medium"
		_:
			return "low"

func _add_aggregated_error(error_data: Dictionary):
	"""Add error to aggregated collection and emit signals"""
	_aggregated_errors.append(error_data)

	emit_signal("error_detected", error_data)

	if error_data["severity"] == "critical":
		emit_signal("critical_error_detected", error_data)
		print("🚨 CRITICAL ERROR DETECTED: %s" % error_data["message"])

func _analyze_error_patterns():
	"""Analyze aggregated errors for patterns"""
	if _aggregated_errors.size() < 2:
		return

	var type_counts: Dictionary = {}
	var recent_errors: Array = []
	var current_time := Time.get_time_dict_from_system()

	# Count error types and filter recent errors (last 60 seconds)
	for error_data in _aggregated_errors:
		var error_type: String = error_data["type"]
		type_counts[error_type] = type_counts.get(error_type, 0) + 1

		var error_time: Dictionary = error_data["timestamp"]
		var time_diff: float = (current_time["hour"] * 3600 + current_time["minute"] * 60 + current_time["second"]) - \
			(error_time["hour"] * 3600 + error_time["minute"] * 60 + error_time["second"])

		if time_diff < 60:  # Last 60 seconds
			recent_errors.append(error_data)

	# Detect patterns
	for error_type in type_counts:
		var count: int = type_counts[error_type]

		if count >= _critical_threshold and not error_type in _session_patterns:
			var pattern_data: Dictionary = {
				"type": "repeated_error",
				"error_type": error_type,
				"count": count,
				"severity": "high"
			}
			_session_patterns[error_type] = pattern_data
			emit_signal("pattern_detected", "repeated_error", pattern_data)
			print("🔄 PATTERN DETECTED: %s occurred %d times" % [error_type, count])

	# Detect error bursts (multiple errors in short time)
	if recent_errors.size() >= 5:
		var pattern_data: Dictionary = {
			"type": "error_burst",
			"count": recent_errors.size(),
			"timeframe": "60_seconds",
			"severity": "high"
		}
		emit_signal("pattern_detected", "error_burst", pattern_data)
		print("💥 ERROR BURST DETECTED: %d errors in last 60 seconds" % recent_errors.size())

func get_error_summary() -> Dictionary:
	"""Get comprehensive error summary"""
	var summary: Dictionary = {
		"total_errors": _aggregated_errors.size(),
		"by_type": {},
		"by_severity": {},
		"by_source": {},
		"patterns": _session_patterns,
		"recent_errors": []
	}

	var current_time := Time.get_time_dict_from_system()

	for error_data in _aggregated_errors:
		# Count by type
		var error_type: String = error_data["type"]
		summary["by_type"][error_type] = summary["by_type"].get(error_type, 0) + 1

		# Count by severity
		var severity: String = error_data["severity"]
		summary["by_severity"][severity] = summary["by_severity"].get(severity, 0) + 1

		# Count by source
		var source: String = error_data["source"]
		summary["by_source"][source] = summary["by_source"].get(source, 0) + 1

		# Add to recent errors if within last 5 minutes
		var error_time: Dictionary = error_data["timestamp"]
		var time_diff: float = (current_time["hour"] * 3600 + current_time["minute"] * 60 + current_time["second"]) - \
			(error_time["hour"] * 3600 + error_time["minute"] * 60 + error_time["second"])

		if time_diff < 300:  # Last 5 minutes
			summary["recent_errors"].append(error_data)

	return summary

func print_comprehensive_report():
	"""Print detailed error analysis report"""
	print("\n" + "=".repeat(60))
	print("📊 COMPREHENSIVE RUNTIME ERROR REPORT")
	print("=".repeat(60))

	var summary: Dictionary = get_error_summary()
	print("Total Errors Detected: %d" % summary["total_errors"])

	if summary["total_errors"] == 0:
		print("✅ No runtime errors detected during monitoring session!")
		print("=".repeat(60) + "\n")
		return

	print("\n🔍 Error Breakdown by Type:")
	for error_type in summary["by_type"]:
		print("  %s: %d occurrences" % [error_type, summary["by_type"][error_type]])

	print("\n⚠️ Error Breakdown by Severity:")
	for severity in summary["by_severity"]:
		print("  %s: %d errors" % [severity.capitalize(), summary["by_severity"][severity]])

	print("\n📡 Error Breakdown by Source:")
	for source in summary["by_source"]:
		print("  %s: %d errors" % [source, summary["by_source"][source]])

	if not summary["patterns"].is_empty():
		print("\n🔄 Detected Patterns:")
		for pattern_name in summary["patterns"]:
			var pattern_data: Dictionary = summary["patterns"][pattern_name]
			print("  %s: %s" % [pattern_name, pattern_data])

	if not summary["recent_errors"].is_empty():
		print("\n🕐 Recent Errors (Last 5 minutes):")
		for error_data in summary["recent_errors"]:
			print("  [%s] %s: %s" % [error_data["severity"].to_upper(), error_data["type"], error_data["message"]])

	# Get FailureLogger data if available
	if FailureLogger:
		var failure_summary: Dictionary = FailureLogger.get_error_summary()
		if failure_summary["total_errors"] > 0:
			print("\n🧪 FailureLogger Additional Data:")
			print("  Tracked Errors: %d" % failure_summary["total_errors"])
			for error_type in failure_summary["error_types"]:
				print("    %s: %d" % [error_type, failure_summary["error_types"][error_type]])

	print("=".repeat(60) + "\n")

func clear_aggregated_errors():
	"""Clear all aggregated error data"""
	_aggregated_errors.clear()
	_session_patterns.clear()
	print("🧹 Aggregated error data cleared")

func export_errors_to_file(file_path: String = "") -> String:
	"""Export all error data to JSON file"""
	if file_path == "":
		file_path = OS.get_user_data_dir() + "/logs/runtime_errors_" + Time.get_datetime_string_from_system() + ".json"

	var export_data: Dictionary = {
		"session_info": {
			"export_time": Time.get_datetime_string_from_system(),
			"godot_version": Engine.get_version_info(),
			"monitoring_duration": "Session duration not tracked"  # Could be enhanced
		},
		"aggregated_errors": _aggregated_errors,
		"summary": get_error_summary(),
		"failure_logger_data": FailureLogger.export_error_log() if FailureLogger else "Not available"
	}

	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(export_data))
		file.close()
		print("📄 Error data exported to: %s" % file_path)
		return file_path
	else:
		print("❌ Failed to export error data to: %s" % file_path)
		return ""