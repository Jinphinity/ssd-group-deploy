extends Node

## TransitionManager Autoload - Global coordinator for level transitions
## Manages scene transitions, loading screens, and state persistence
## Integrates with existing Save system and AuthController

# Transition state management
var current_transition: LevelTransition = null
var transition_history: Array[Dictionary] = []
var is_transitioning: bool = false
var loading_screen_scene: PackedScene = null

# Configuration
var max_history_size: int = 10
var transition_timeout: float = 5.0
var enable_loading_screen: bool = true

# Signals for system coordination
signal transition_started(target_scene: String, source_transition: LevelTransition)
signal transition_completed(target_scene: String, source_transition: LevelTransition)
signal transition_failed(target_scene: String, source_transition: LevelTransition, error: String)
signal checkpoint_saved(scene_path: String, position: Vector2)

func _ready() -> void:
	# Connect to existing autoload systems
	_initialize_integration()
	print("🔄 TransitionManager initialized")

func _initialize_integration() -> void:
	"""Initialize integration with existing systems"""
	# Connect to AuthController if available
	if AuthController and AuthController.has_signal("authentication_changed"):
		AuthController.authentication_changed.connect(_on_auth_state_changed)

	# Load transition history from Save system
	_load_transition_history()

	# Set up loading screen if available
	_setup_loading_screen()

func transition_to_scene(scene_path: String, checkpoint: bool = true, source_transition: LevelTransition = null) -> bool:
	"""Main transition method - orchestrates scene change with full coordination"""
	if is_transitioning:
		push_warning("TransitionManager: Already transitioning, ignoring request")
		return false

	if not _validate_scene_path(scene_path):
		transition_failed.emit(scene_path, source_transition, "Invalid scene path")
		return false

	print("🔄 Starting transition to: %s" % scene_path)
	is_transitioning = true
	current_transition = source_transition

	# Signal transition start
	transition_started.emit(scene_path, source_transition)

	# Save checkpoint if requested
	if checkpoint:
		save_transition_checkpoint(scene_path)

	# Add to history
	_add_to_history(scene_path, source_transition)

	# Show loading screen if enabled
	if enable_loading_screen:
		_show_loading_screen()

	# Execute transition with error handling
	var success = await _execute_scene_transition(scene_path)

	# Hide loading screen
	if enable_loading_screen:
		_hide_loading_screen()

	# Update state
	is_transitioning = false
	current_transition = null

	if success:
		transition_completed.emit(scene_path, source_transition)
		print("✅ Transition completed successfully: %s" % scene_path)
	else:
		transition_failed.emit(scene_path, source_transition, "Scene transition failed")
		print("❌ Transition failed: %s" % scene_path)

	return success

func can_transition_to(scene_path: String) -> bool:
	"""Check if transition to scene is possible"""
	if is_transitioning:
		return false

	if not _validate_scene_path(scene_path):
		return false

	# Additional validation can be added here
	return true

func save_transition_checkpoint(target_scene: String = "") -> void:
	"""Save checkpoint before transition"""
	if not Save:
		print("⚠️ Save system not available for checkpoint")
		return

	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	var player_position = _get_current_player_position()
	var checkpoint_data = {
		"scene": current_scene.scene_file_path,
		"target_scene": target_scene,
		"position": player_position,
		"timestamp": Time.get_ticks_msec(),
		"transition_id": _generate_transition_id()
	}

	Save.save_local(checkpoint_data)
	checkpoint_saved.emit(current_scene.scene_file_path, player_position)
	print("💾 Transition checkpoint saved: %s → %s" % [current_scene.scene_file_path, target_scene])

func get_transition_history() -> Array:
	"""Get transition history for debugging/analytics"""
	return transition_history.duplicate()

func clear_transition_history() -> void:
	"""Clear transition history"""
	transition_history.clear()
	_save_transition_history()

func get_last_transition() -> Dictionary:
	"""Get last transition info"""
	if transition_history.is_empty():
		return {}
	return transition_history.back()

func _execute_scene_transition(scene_path: String) -> bool:
	"""Execute the actual scene transition with timeout protection"""
	var timeout_timer = get_tree().create_timer(transition_timeout)
	var transition_completed = false

	# Create a one-shot callable for the timeout
	var timeout_callback = func():
		if not transition_completed:
			push_error("TransitionManager: Scene transition timed out")

	timeout_timer.timeout.connect(timeout_callback, CONNECT_ONE_SHOT)

	# Execute scene change
	var error = get_tree().change_scene_to_file(scene_path)
	if error == OK:
		transition_completed = true
		return true
	else:
		push_error("TransitionManager: Failed to change scene to %s (Error code: %d)" % [scene_path, error])
		transition_completed = true
		return false

func _validate_scene_path(scene_path: String) -> bool:
	"""Validate that scene path is valid and exists"""
	if scene_path == "":
		return false

	if not scene_path.ends_with(".tscn"):
		return false

	if not ResourceLoader.exists(scene_path):
		push_warning("TransitionManager: Scene does not exist: %s" % scene_path)
		return false

	return true

func _add_to_history(scene_path: String, source_transition: LevelTransition) -> void:
	"""Add transition to history with size management"""
	var history_entry = {
		"target_scene": scene_path,
		"source_scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"transition_name": source_transition.transition_name if source_transition else "Direct",
		"timestamp": Time.get_ticks_msec(),
		"transition_id": _generate_transition_id()
	}

	transition_history.append(history_entry)

	# Maintain history size limit
	while transition_history.size() > max_history_size:
		transition_history.remove_at(0)

	_save_transition_history()

func _generate_transition_id() -> String:
	"""Generate unique transition ID"""
	return "trans_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]

func _get_current_player_position() -> Vector2:
	"""Get current player position for checkpoint saving"""
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("get_global_position"):
		return player.global_position
	return Vector2.ZERO

func _load_transition_history() -> void:
	"""Load transition history from Save system"""
	if not Save:
		return

	var save_data = Save.load_local()
	if save_data.has("transition_history"):
		var loaded_history = save_data.get("transition_history", [])
		if typeof(loaded_history) == TYPE_ARRAY:
			transition_history = loaded_history

func _save_transition_history() -> void:
	"""Save transition history to Save system"""
	if not Save:
		return

	var save_data = Save.load_local()
	save_data["transition_history"] = transition_history
	Save.save_local(save_data)

func _setup_loading_screen() -> void:
	"""Set up loading screen if available"""
	# TODO: Create a dedicated loading screen scene
	# For now, this is a placeholder for future implementation
	var loading_screen_path = "res://common/UI/LoadingScreen.tscn"
	if ResourceLoader.exists(loading_screen_path):
		loading_screen_scene = load(loading_screen_path)

func _show_loading_screen() -> void:
	"""Show loading screen during transition"""
	# TODO: Implement loading screen display
	# This would add a loading screen overlay during transitions
	print("🔄 Loading screen shown")

func _hide_loading_screen() -> void:
	"""Hide loading screen after transition"""
	# TODO: Implement loading screen hiding
	# This would remove the loading screen overlay
	print("🔄 Loading screen hidden")

func _on_auth_state_changed(is_authenticated: bool) -> void:
	"""Handle authentication state changes"""
	print("🔄 TransitionManager: Auth state changed to %s" % is_authenticated)
	# This can be used to update transition availability based on auth state

# Debug and utility methods
func get_current_transition_info() -> Dictionary:
	"""Get current transition state for debugging"""
	return {
		"is_transitioning": is_transitioning,
		"current_transition": current_transition.get_transition_info() if current_transition else {},
		"history_size": transition_history.size(),
		"last_transition": get_last_transition()
	}

func force_stop_transition() -> void:
	"""Emergency method to stop stuck transitions"""
	is_transitioning = false
	current_transition = null
	_hide_loading_screen()
	print("🚨 Transition force stopped")

# Signal handlers for LevelTransition coordination
func _on_transition_requested(source_transition: LevelTransition, target_scene: String) -> void:
	"""Handle transition request from LevelTransition component"""
	print("🔄 TransitionManager received transition request: %s → %s" % [source_transition.name, target_scene])

	# Validate the request
	if not can_transition_to(target_scene):
		transition_failed.emit(target_scene, source_transition, "Transition not available")
		return

	# Execute the transition
	transition_to_scene(target_scene, true, source_transition)

func _on_transition_completed(source_transition: LevelTransition, target_scene: String) -> void:
	"""Handle transition completion from LevelTransition component"""
	print("✅ TransitionManager transition completed: %s → %s" % [source_transition.name if source_transition else "Direct", target_scene])

	# Additional cleanup or state management can be added here

# Public API for external configuration
func set_loading_screen_enabled(enabled: bool) -> void:
	"""Enable/disable loading screen"""
	enable_loading_screen = enabled

func set_transition_timeout(timeout: float) -> void:
	"""Set transition timeout duration"""
	transition_timeout = timeout

func set_max_history_size(size: int) -> void:
	"""Set maximum history size"""
	max_history_size = size