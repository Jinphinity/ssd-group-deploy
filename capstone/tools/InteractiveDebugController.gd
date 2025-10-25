extends Node

## Interactive Debug Controller
## Provides GUI-based runtime error monitoring and analysis
## Can be attached to any scene for real-time debugging feedback

signal debug_session_started()
signal debug_session_ended(summary: Dictionary)
signal error_threshold_reached(error_count: int)

var debug_ui: Control
var error_display: RichTextLabel
var stats_display: Label
var control_panel: VBoxContainer

var monitoring_active: bool = false
var session_start_time: float = 0.0
var error_threshold: int = 5
var auto_analysis_interval: float = 10.0  # seconds

var _analysis_timer: Timer
var _last_error_count: int = 0

func _ready() -> void:
	if not RuntimeErrorAggregator:
		print("❌ RuntimeErrorAggregator not available - interactive debugging disabled")
		return

	_create_debug_ui()
	_setup_error_monitoring()
	print("🎮 Interactive Debug Controller ready")

func _create_debug_ui():
	"""Create debug overlay UI"""
	# Main debug container
	debug_ui = Control.new()
	debug_ui.name = "DebugUI"
	debug_ui.anchors_preset = Control.PRESET_FULL_RECT
	debug_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(debug_ui)

	# Background panel
	var bg_panel := Panel.new()
	bg_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	bg_panel.position = Vector2(get_viewport().size.x - 400, 10)
	bg_panel.size = Vector2(380, 300)
	bg_panel.modulate = Color(0, 0, 0, 0.8)
	debug_ui.add_child(bg_panel)

	# Control panel
	control_panel = VBoxContainer.new()
	control_panel.position = Vector2(10, 10)
	control_panel.size = Vector2(360, 280)
	bg_panel.add_child(control_panel)

	# Title
	var title := Label.new()
	title.text = "🔧 Runtime Debug Monitor"
	title.add_theme_color_override("font_color", Color.CYAN)
	control_panel.add_child(title)

	# Stats display
	stats_display = Label.new()
	stats_display.text = "Status: Inactive"
	stats_display.add_theme_color_override("font_color", Color.WHITE)
	control_panel.add_child(stats_display)

	# Control buttons
	var button_container := HBoxContainer.new()
	control_panel.add_child(button_container)

	var start_btn := Button.new()
	start_btn.text = "Start Monitoring"
	start_btn.pressed.connect(_start_monitoring)
	button_container.add_child(start_btn)

	var stop_btn := Button.new()
	stop_btn.text = "Stop"
	stop_btn.pressed.connect(_stop_monitoring)
	button_container.add_child(stop_btn)

	var report_btn := Button.new()
	report_btn.text = "Report"
	report_btn.pressed.connect(_generate_report)
	button_container.add_child(report_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_clear_errors)
	button_container.add_child(clear_btn)

	# Error display
	var error_scroll := ScrollContainer.new()
	error_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control_panel.add_child(error_scroll)

	error_display = RichTextLabel.new()
	error_display.bbcode_enabled = true
	error_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	error_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	error_display.text = "[color=gray]Start monitoring to see runtime errors...[/color]"
	error_scroll.add_child(error_display)

	# Toggle visibility button
	var toggle_btn := Button.new()
	toggle_btn.text = "🔍"
	toggle_btn.position = Vector2(get_viewport().size.x - 50, 10)
	toggle_btn.size = Vector2(40, 30)
	toggle_btn.pressed.connect(_toggle_debug_ui)
	debug_ui.add_child(toggle_btn)

	# Start hidden
	bg_panel.visible = false

func _toggle_debug_ui():
	"""Toggle debug UI visibility"""
	if control_panel and control_panel.get_parent():
		control_panel.get_parent().visible = not control_panel.get_parent().visible

func _setup_error_monitoring():
	"""Setup automatic error monitoring"""
	# Connect to RuntimeErrorAggregator signals
	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.error_detected.connect(_on_error_detected)
		RuntimeErrorAggregator.critical_error_detected.connect(_on_critical_error_detected)
		RuntimeErrorAggregator.pattern_detected.connect(_on_pattern_detected)

	# Setup analysis timer
	_analysis_timer = Timer.new()
	_analysis_timer.wait_time = auto_analysis_interval
	_analysis_timer.timeout.connect(_perform_periodic_analysis)
	add_child(_analysis_timer)

func _start_monitoring():
	"""Start runtime error monitoring"""
	if not RuntimeErrorAggregator:
		_log_to_ui("[color=red]❌ RuntimeErrorAggregator not available[/color]")
		return

	monitoring_active = true
	session_start_time = Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]
	_last_error_count = 0

	RuntimeErrorAggregator.start_monitoring()
	FailureLogger.start_session()
	_analysis_timer.start()

	_log_to_ui("[color=green]🚀 Runtime monitoring started[/color]")
	_update_stats_display()
	emit_signal("debug_session_started")

	print("🎮 Interactive debug monitoring started")

func _stop_monitoring():
	"""Stop runtime error monitoring"""
	monitoring_active = false
	_analysis_timer.stop()

	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.stop_monitoring()

	var session_duration: float = (Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]) - session_start_time
	_log_to_ui("[color=yellow]⏹️ Monitoring stopped after %.1f seconds[/color]" % session_duration)

	var summary: Dictionary = _get_session_summary()
	emit_signal("debug_session_ended", summary)

	print("🎮 Interactive debug monitoring stopped")

func _on_error_detected(error_data: Dictionary):
	"""Handle error detection"""
	if not monitoring_active:
		return

	var severity_color: String = _get_severity_color(error_data.get("severity", "medium"))
	var error_text: String = "[color=%s]💥 %s: %s[/color]" % [severity_color, error_data.get("type", "UNKNOWN"), error_data.get("message", "No message")]

	_log_to_ui(error_text)
	_update_stats_display()

	# Check error threshold
	var current_error_count: int = RuntimeErrorAggregator.get_error_summary()["total_errors"]
	if current_error_count >= error_threshold and _last_error_count < error_threshold:
		_log_to_ui("[color=red]🚨 ERROR THRESHOLD REACHED: %d errors detected![/color]" % current_error_count)
		emit_signal("error_threshold_reached", current_error_count)

	_last_error_count = current_error_count

func _on_critical_error_detected(error_data: Dictionary):
	"""Handle critical error detection"""
	if not monitoring_active:
		return

	var critical_text: String = "[color=red]🚨 CRITICAL: %s - %s[/color]" % [error_data.get("type", "UNKNOWN"), error_data.get("message", "No message")]
	_log_to_ui(critical_text)

	# Force immediate analysis for critical errors
	_perform_immediate_analysis()

func _on_pattern_detected(pattern_name: String, pattern_data: Dictionary):
	"""Handle pattern detection"""
	if not monitoring_active:
		return

	var pattern_text: String = "[color=orange]🔄 PATTERN: %s detected[/color]" % pattern_name
	_log_to_ui(pattern_text)

func _perform_periodic_analysis():
	"""Perform periodic error analysis"""
	if not monitoring_active or not RuntimeErrorAggregator:
		return

	var summary: Dictionary = RuntimeErrorAggregator.get_error_summary()
	if summary["total_errors"] > _last_error_count:
		_log_to_ui("[color=cyan]📊 Analysis: %d new errors since last check[/color]" % (summary["total_errors"] - _last_error_count))
		_last_error_count = summary["total_errors"]

	_update_stats_display()

func _perform_immediate_analysis():
	"""Perform immediate analysis after critical error"""
	if not RuntimeErrorAggregator:
		return

	var critical_errors: Array = RuntimeErrorAggregator.get_critical_errors()
	_log_to_ui("[color=red]🚨 Critical analysis: %d critical errors require attention[/color]" % critical_errors.size())

func _generate_report():
	"""Generate and display comprehensive error report"""
	if not RuntimeErrorAggregator:
		_log_to_ui("[color=red]❌ Cannot generate report - RuntimeErrorAggregator not available[/color]")
		return

	_log_to_ui("[color=cyan]📊 Generating comprehensive error report...[/color]")

	var summary: Dictionary = RuntimeErrorAggregator.get_error_summary()
	var report_text: String = ""

	report_text += "[color=white]📊 ERROR REPORT[/color]\n"
	report_text += "Total Errors: %d\n" % summary["total_errors"]

	if summary["total_errors"] > 0:
		report_text += "\n[color=yellow]By Type:[/color]\n"
		for error_type in summary["by_type"]:
			report_text += "  %s: %d\n" % [error_type, summary["by_type"][error_type]]

		report_text += "\n[color=yellow]By Severity:[/color]\n"
		for severity in summary["by_severity"]:
			var severity_color: String = _get_severity_color(severity)
			report_text += "  [color=%s]%s: %d[/color]\n" % [severity_color, severity.capitalize(), summary["by_severity"][severity]]

		if not summary["recent_errors"].is_empty():
			report_text += "\n[color=red]Recent Errors:[/color]\n"
			for error_data in summary["recent_errors"]:
				report_text += "  • %s: %s\n" % [error_data["type"], error_data["message"]]
	else:
		report_text += "[color=green]✅ No errors detected![/color]\n"

	_log_to_ui(report_text)

	# Also print to console
	RuntimeErrorAggregator.print_comprehensive_report()

func _clear_errors():
	"""Clear error display and aggregated data"""
	error_display.text = "[color=gray]Error log cleared...[/color]"
	_last_error_count = 0

	if RuntimeErrorAggregator:
		RuntimeErrorAggregator.clear_aggregated_errors()

	if FailureLogger:
		FailureLogger.reset_runtime_errors()

	_update_stats_display()
	_log_to_ui("[color=green]🧹 Error data cleared[/color]")

func _log_to_ui(text: String):
	"""Add text to the UI error display"""
	if error_display:
		var timestamp: String = Time.get_time_string_from_system()
		error_display.text += "\n[%s] %s" % [timestamp, text]

		# Limit display to last 50 lines to prevent memory issues
		var lines: PackedStringArray = error_display.text.split("\n")
		if lines.size() > 50:
			var recent_lines: PackedStringArray = lines.slice(-50)
			error_display.text = "\n".join(recent_lines)

func _update_stats_display():
	"""Update the stats display with current information"""
	if not stats_display:
		return

	var status_text: String = ""

	if monitoring_active:
		var session_duration: float = (Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]) - session_start_time
		status_text = "Status: Active (%.1fs)\n" % session_duration

		if RuntimeErrorAggregator:
			var summary: Dictionary = RuntimeErrorAggregator.get_error_summary()
			status_text += "Errors: %d | " % summary["total_errors"]
			status_text += "Critical: %d\n" % summary["by_severity"].get("critical", 0)
			status_text += "Patterns: %d" % summary["patterns"].size()
	else:
		status_text = "Status: Inactive"

	stats_display.text = status_text

func _get_severity_color(severity: String) -> String:
	"""Get color for severity level"""
	match severity.to_lower():
		"critical":
			return "red"
		"high":
			return "orange"
		"medium":
			return "yellow"
		"low":
			return "white"
		_:
			return "gray"

func _get_session_summary() -> Dictionary:
	"""Get comprehensive session summary"""
	var summary: Dictionary = {
		"session_duration": (Time.get_time_dict_from_system()["hour"] * 3600 + Time.get_time_dict_from_system()["minute"] * 60 + Time.get_time_dict_from_system()["second"]) - session_start_time,
		"total_errors": 0,
		"critical_errors": 0,
		"patterns_detected": 0
	}

	if RuntimeErrorAggregator:
		var aggregator_summary: Dictionary = RuntimeErrorAggregator.get_error_summary()
		summary["total_errors"] = aggregator_summary["total_errors"]
		summary["critical_errors"] = aggregator_summary["by_severity"].get("critical", 0)
		summary["patterns_detected"] = aggregator_summary["patterns"].size()

	return summary

## Public API for external scripts

func enable_auto_start():
	"""Enable automatic monitoring when attached to scene"""
	_start_monitoring()

func set_error_threshold(threshold: int):
	"""Set error threshold for alerts"""
	error_threshold = threshold

func set_analysis_interval(interval: float):
	"""Set automatic analysis interval"""
	auto_analysis_interval = interval
	if _analysis_timer:
		_analysis_timer.wait_time = interval

func export_session_data() -> String:
	"""Export session data for external analysis"""
	if RuntimeErrorAggregator:
		return RuntimeErrorAggregator.export_errors_to_file()
	return ""

## Example usage in _ready() of main scene:
## var debug_controller = preload("res://tools/InteractiveDebugController.gd").new()
## add_child(debug_controller)
## debug_controller.enable_auto_start()  # Optional: start monitoring immediately