extends Node

## Real-time Transition Monitor
## Automatically monitors scene transitions during gameplay and catches errors
## Can be added as an autoload or child node to continuously monitor transitions


signal transition_error_detected(error_details: Dictionary)
signal transition_completed_successfully(transition_info: Dictionary)

var monitoring_enabled: bool = true
var transition_history: Array[Dictionary] = []
var max_history_size: int = 50
var error_count: int = 0
var successful_transitions: int = 0

# Error patterns to watch for
var error_patterns = [
	"data.tree.*null",
	"Parameter.*null",
	"Invalid get index",
	"Object was freed",
	"Node not found",
	"timer.*invalid",
	"callback.*failed"
]

var current_scene_path: String = ""
var transition_start_time: int = 0
var is_transitioning: bool = false

func _ready():
	if not Engine.is_editor_hint():
		_setup_monitoring()

func _setup_monitoring():
	"""Setup transition monitoring hooks"""
	print("🔍 TransitionMonitor: Setting up real-time transition monitoring")

	# Connect to scene changes
	if get_tree():
		get_tree().node_added.connect(_on_node_added)
		get_tree().node_removed.connect(_on_node_removed)
		current_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""

	# Start monitoring timer
	var monitor_timer = Timer.new()
	monitor_timer.wait_time = 0.1  # Check every 100ms
	monitor_timer.timeout.connect(_monitor_scene_state)
	monitor_timer.autostart = true
	add_child(monitor_timer)

	print("✅ TransitionMonitor: Monitoring active")

func _monitor_scene_state():
	"""Continuously monitor scene state for issues"""
	if not monitoring_enabled:
		return

	var tree = get_tree()
	if not tree:
		return

	var current_scene = tree.current_scene
	if not current_scene:
		return

	var new_scene_path = current_scene.scene_file_path

	# Detect scene change
	if new_scene_path != current_scene_path and new_scene_path != "":
		_on_scene_transition_detected(current_scene_path, new_scene_path)
		current_scene_path = new_scene_path

func _on_scene_transition_detected(from_scene: String, to_scene: String):
	"""Handle detected scene transition"""
	transition_start_time = Time.get_ticks_msec()
	is_transitioning = false  # Reset after detection

	var transition_info = {
		"from_scene": from_scene,
		"to_scene": to_scene,
		"timestamp": Time.get_datetime_string_from_system(),
		"transition_time_ms": 0
	}

	print("🔄 TransitionMonitor: Detected transition %s → %s" % [
		from_scene.get_file() if from_scene else "unknown",
		to_scene.get_file()
	])

	# Validate transition after a delay
	await get_tree().create_timer(0.5).timeout
	_validate_transition_completion(transition_info)

func _validate_transition_completion(transition_info: Dictionary):
	"""Validate that transition completed successfully"""
	var end_time = Time.get_ticks_msec()
	transition_info["transition_time_ms"] = end_time - transition_start_time

	# Check for common transition errors
	var errors_detected = _check_for_transition_errors()

	if errors_detected.size() > 0:
		error_count += 1
		transition_info["errors"] = errors_detected
		transition_info["success"] = false

		print("❌ TransitionMonitor: Transition errors detected:")
		for error in errors_detected:
			print("  • %s" % error)

		transition_error_detected.emit(transition_info)
	else:
		successful_transitions += 1
		transition_info["success"] = true

		print("✅ TransitionMonitor: Transition completed successfully in %d ms" % transition_info["transition_time_ms"])
		transition_completed_successfully.emit(transition_info)

	# Add to history
	_add_to_history(transition_info)

func _check_for_transition_errors() -> Array[String]:
	"""Check for common transition errors"""
	var detected_errors: Array[String] = []

	# Check for orphaned nodes
	var orphaned_nodes = _find_orphaned_nodes()
	if orphaned_nodes.size() > 0:
		detected_errors.append("Found %d orphaned nodes after transition" % orphaned_nodes.size())

	# Check for invalid timer callbacks
	var invalid_timers = _check_invalid_timers()
	if invalid_timers > 0:
		detected_errors.append("Found %d potentially invalid timer callbacks" % invalid_timers)

	# Check scene tree integrity
	if not _verify_scene_tree_integrity():
		detected_errors.append("Scene tree integrity check failed")

	return detected_errors

func _find_orphaned_nodes() -> Array[Node]:
	"""Find nodes that might be orphaned after transition"""
	var orphaned: Array[Node] = []
	var tree = get_tree()
	if not tree:
		return orphaned

	# Check for nodes that should have been freed
	var all_nodes = tree.get_nodes_in_group("transition_sensitive")
	for node in all_nodes:
		if not is_instance_valid(node) or not node.is_inside_tree():
			orphaned.append(node)

	return orphaned

func _check_invalid_timers() -> int:
	"""Check for timer callbacks that might be problematic"""
	# This is a placeholder - in a real implementation, you'd track timer objects
	# and check if they're trying to access freed nodes
	return 0

func _verify_scene_tree_integrity() -> bool:
	"""Verify scene tree is in a good state"""
	var tree = get_tree()
	if not tree:
		return false

	var current_scene = tree.current_scene
	if not current_scene:
		return false

	# Check if current scene is properly initialized
	if not is_instance_valid(current_scene):
		return false

	return true

func _add_to_history(transition_info: Dictionary):
	"""Add transition to history log"""
	transition_history.append(transition_info)

	# Maintain history size limit
	while transition_history.size() > max_history_size:
		transition_history.pop_front()

func _on_node_added(node: Node):
	"""Monitor node additions for transition tracking"""
	if node.scene_file_path and node == get_tree().current_scene:
		is_transitioning = true

func _on_node_removed(node: Node):
	"""Monitor node removal for cleanup validation"""
	pass

# Public API methods

func get_transition_stats() -> Dictionary:
	"""Get transition statistics"""
	return {
		"total_transitions": successful_transitions + error_count,
		"successful_transitions": successful_transitions,
		"failed_transitions": error_count,
		"success_rate": (successful_transitions * 100.0) / max(1, successful_transitions + error_count),
		"monitoring_enabled": monitoring_enabled
	}

func get_recent_transitions(count: int = 10) -> Array[Dictionary]:
	"""Get recent transition history"""
	var recent = transition_history.slice(-count) if transition_history.size() > count else transition_history
	return recent

func enable_monitoring():
	"""Enable transition monitoring"""
	monitoring_enabled = true
	print("✅ TransitionMonitor: Monitoring enabled")

func disable_monitoring():
	"""Disable transition monitoring"""
	monitoring_enabled = false
	print("🔇 TransitionMonitor: Monitoring disabled")

func clear_history():
	"""Clear transition history"""
	transition_history.clear()
	print("🗑️ TransitionMonitor: History cleared")

func generate_report() -> String:
	"""Generate a transition monitoring report"""
	var stats = get_transition_stats()
	var recent = get_recent_transitions(5)

	var report = "📊 TRANSITION MONITORING REPORT\n"
	report += "=".repeat(40) + "\n"
	report += "📈 Statistics:\n"
	report += "  • Total transitions: %d\n" % stats.total_transitions
	report += "  • Successful: %d\n" % stats.successful_transitions
	report += "  • Failed: %d\n" % stats.failed_transitions
	report += "  • Success rate: %.1f%%\n" % stats.success_rate

	if recent.size() > 0:
		report += "\n🕒 Recent transitions:\n"
		for transition in recent:
			var status = "✅" if transition.get("success", false) else "❌"
			report += "  %s %s → %s (%d ms)\n" % [
				status,
				transition.get("from_scene", "unknown").get_file(),
				transition.get("to_scene", "unknown").get_file(),
				transition.get("transition_time_ms", 0)
			]

	report += "=".repeat(40)
	return report

# Autoload integration helper
static func add_to_scene_as_autoload():
    """Helper to add this monitor to the scene tree"""
    var monitor = load("res://tools/TransitionMonitor.gd").new()
    monitor.name = "TransitionMonitor"

    # Add to root to persist across scenes
    var tree = Engine.get_main_loop() as SceneTree
    if tree:
        tree.root.add_child(monitor)
        return monitor
    return null