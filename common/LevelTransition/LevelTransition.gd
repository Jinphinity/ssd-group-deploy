extends Area2D

## Level Transition Component for 2D side-scrolling game
## Reusable component for seamless level-to-level travel
## Based on Area2D interaction pattern from Trader_2D.gd

class_name LevelTransition

# Inspector-configurable properties (basic setup)
@export var target_scene_path: String = ""
@export var transition_name: String = "Next Area"
@export_enum("Any", "Authenticated", "Level Complete") var requirement_type: String = "Any"
@export var interaction_key: String = "interact"
@export var show_prompt: bool = true
@export var save_checkpoint: bool = true
@export var custom_prompt_text: String = ""

# Advanced configuration via resource
@export var advanced_config: TransitionZoneConfig = null

# Child node references
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var visual_indicator: Sprite2D = $VisualIndicator

# State variables
var is_player_nearby: bool = false
var current_player = null
var transition_available: bool = true

# Signals for coordination with other systems
signal transition_requested(transition: LevelTransition, target_scene: String)
signal transition_completed(transition: LevelTransition, target_scene: String)
signal transition_blocked(transition: LevelTransition, reason: String)
signal player_entered_zone(transition: LevelTransition)
signal player_exited_zone(transition: LevelTransition)

func _ready() -> void:
	# Apply advanced configuration if available
	_apply_advanced_config()

	# Set up Area2D signal connections
	body_entered.connect(_on_player_entered_transition_area)
	body_exited.connect(_on_player_exited_transition_area)

	# Hide interaction prompt initially
	if interaction_prompt:
		interaction_prompt.visible = false

	# Set up visual indicator if available
	if visual_indicator:
		visual_indicator.modulate = Color.WHITE

	# Add to transition group for easy access
	add_to_group("level_transitions")
	add_to_group("interactive_objects")

	# Connect to TransitionManager signals if available
	_connect_to_transition_manager()

	# Validate configuration
	_validate_configuration()

	print("🚪 Level transition initialized: %s → %s" % [_get_transition_name(), _get_target_scene_path()])

func _input(event: InputEvent) -> void:
	if is_player_nearby and transition_available and Input.is_action_just_pressed(interaction_key):
		_attempt_transition()

func _on_player_entered_transition_area(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		current_player = body
		_show_interaction_prompt()
		player_entered_zone.emit(self)
		print("🚪 Player entered transition zone: %s" % transition_name)

func _on_player_exited_transition_area(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		current_player = null
		_hide_interaction_prompt()
		player_exited_zone.emit(self)
		print("🚪 Player exited transition zone: %s" % transition_name)

func _show_interaction_prompt() -> void:
	"""Display interaction prompt to player"""
	if not show_prompt or not interaction_prompt:
		return

	# Check if transition is available
	if not _check_requirements():
		transition_available = false
		interaction_prompt.text = _get_blocked_message()
		interaction_prompt.modulate = Color.ORANGE
	else:
		transition_available = true
		var prompt_text = _get_custom_prompt_text() if _get_custom_prompt_text() != "" else "Press E to enter %s" % _get_transition_name()
		interaction_prompt.text = prompt_text
		interaction_prompt.modulate = Color.WHITE

	interaction_prompt.visible = true

	# Update visual indicator
	if visual_indicator:
		visual_indicator.modulate = Color.GREEN if transition_available else Color.RED

func _hide_interaction_prompt() -> void:
	"""Hide interaction prompt"""
	if interaction_prompt:
		interaction_prompt.visible = false

	# Reset visual indicator
	if visual_indicator:
		visual_indicator.modulate = Color.WHITE

func _attempt_transition() -> void:
	"""Attempt to execute the transition"""
	if not transition_available:
		var reason = _get_blocked_reason()
		transition_blocked.emit(self, reason)
		_show_message("Cannot transition: %s" % reason)
		return

	# Final requirement check
	if not _check_requirements():
		var reason = _get_blocked_reason()
		transition_blocked.emit(self, reason)
		_show_message("Cannot transition: %s" % reason)
		return

	# Validate target scene exists
	if not _validate_target_scene():
		transition_blocked.emit(self, "Target scene not found")
		_show_message("Error: Target scene not found")
		return

	# Signal transition request
	transition_requested.emit(self, _get_target_scene_path())

	# Execute transition through TransitionManager
	if has_node("/root/TransitionManager"):
		TransitionManager.transition_to_scene(_get_target_scene_path(), _get_save_checkpoint())
	else:
		# Fallback to direct scene transition
		_execute_direct_transition()

func _execute_direct_transition() -> void:
	"""Fallback direct scene transition"""
	var target_path = _get_target_scene_path()
	print("🚪 Executing direct transition to: %s" % target_path)

	# Save checkpoint if requested
	if _get_save_checkpoint():
		_save_checkpoint_before_transition()

	# Execute scene change
	get_tree().change_scene_to_file(target_path)

	# Signal completion
	transition_completed.emit(self, target_path)

func _check_requirements() -> bool:
	"""Check if player meets transition requirements"""
	var req_type = _get_requirement_type()
	match req_type:
		"Any":
			return true
		"Authenticated":
			return _check_auth_requirement()
		"Level Complete":
			return _check_level_complete_requirement()
		"Custom":
			return _check_custom_requirements()
		_:
			return true

func _check_custom_requirements() -> bool:
	"""Check custom requirements using advanced config"""
	if advanced_config:
		return advanced_config.check_custom_requirements(current_player)
	return true

func _check_auth_requirement() -> bool:
	"""Check authentication requirement"""
	if AuthController:
		return AuthController.is_authenticated
	return true  # Fallback if AuthController not available

func _check_level_complete_requirement() -> bool:
	"""Check level completion requirement"""
	# TODO: Implement level completion checking
	# This would integrate with a progression tracking system
	return true  # Placeholder implementation

func _get_blocked_reason() -> String:
	"""Get reason why transition is blocked"""
	match requirement_type:
		"Authenticated":
			return "Authentication required"
		"Level Complete":
			return "Complete current level first"
		_:
			return "Requirements not met"

func _get_blocked_message() -> String:
	"""Get user-friendly blocked message"""
	match requirement_type:
		"Authenticated":
			return "Login required to access %s" % transition_name
		"Level Complete":
			return "Complete current level to access %s" % transition_name
		_:
			return "Cannot access %s" % transition_name

func _validate_target_scene() -> bool:
	"""Validate that target scene exists"""
	if target_scene_path == "":
		return false
	return ResourceLoader.exists(target_scene_path)

func _validate_configuration() -> void:
	"""Validate component configuration"""
	if target_scene_path == "":
		push_warning("LevelTransition: target_scene_path is empty")

	if transition_name == "":
		transition_name = "Next Area"

	if not ResourceLoader.exists(target_scene_path) and target_scene_path != "":
		push_warning("LevelTransition: target scene does not exist: %s" % target_scene_path)

func _save_checkpoint_before_transition() -> void:
	"""Save checkpoint before transition"""
	if Save and Save.has_method("save_local"):
		var checkpoint_data = {
			"scene": get_tree().current_scene.scene_file_path,
			"position": _get_player_position(),
			"timestamp": Time.get_ticks_msec(),
			"transition_source": transition_name
		}
		Save.save_local(checkpoint_data)
		print("💾 Checkpoint saved before transition")

func _get_player_position() -> Vector2:
	"""Get current player position"""
	if current_player and current_player.has_method("get_global_position"):
		return current_player.global_position
	return Vector2.ZERO

func _show_message(text: String) -> void:
	"""Show message to player (follows Trader_2D pattern)"""
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(text)
	else:
		print("🚪 Transition: %s" % text)

# Public API methods for external configuration
func set_target_scene(scene_path: String) -> void:
	"""Set target scene path programmatically"""
	target_scene_path = scene_path
	_validate_configuration()

func set_transition_name(name: String) -> void:
	"""Set transition name programmatically"""
	transition_name = name

func set_requirement_type(req_type: String) -> void:
	"""Set requirement type programmatically"""
	requirement_type = req_type

func get_transition_info() -> Dictionary:
	"""Get transition information for debugging/UI"""
	return {
		"name": _get_transition_name(),
		"target_scene": _get_target_scene_path(),
		"requirement_type": _get_requirement_type(),
		"available": transition_available,
		"player_nearby": is_player_nearby,
		"has_advanced_config": advanced_config != null
	}

# Advanced configuration integration methods
func _apply_advanced_config() -> void:
	"""Apply advanced configuration if available"""
	if not advanced_config:
		return

	# Override basic properties with advanced config
	target_scene_path = advanced_config.target_scene
	transition_name = advanced_config.transition_name
	requirement_type = advanced_config.requirement_type
	interaction_key = advanced_config.interaction_key
	show_prompt = advanced_config.show_prompt
	save_checkpoint = advanced_config.save_checkpoint
	custom_prompt_text = advanced_config.custom_prompt_text

	print("🔧 Applied advanced configuration: %s" % advanced_config.resource_path)

func _connect_to_transition_manager() -> void:
	"""Connect to TransitionManager signals for coordination"""
	if not has_node("/root/TransitionManager"):
		return

	# Connect our signals to TransitionManager if the methods exist
	if TransitionManager.has_method("_on_transition_requested"):
		if not transition_requested.is_connected(TransitionManager._on_transition_requested):
			transition_requested.connect(TransitionManager._on_transition_requested)

	if TransitionManager.has_method("_on_transition_completed"):
		if not transition_completed.is_connected(TransitionManager._on_transition_completed):
			transition_completed.connect(TransitionManager._on_transition_completed)

	print("🔗 Connected to TransitionManager signals")

# Getter methods that respect advanced configuration
func _get_transition_name() -> String:
	"""Get transition name from config or fallback"""
	if advanced_config:
		return advanced_config.transition_name
	return transition_name

func _get_target_scene_path() -> String:
	"""Get target scene path from config or fallback"""
	if advanced_config:
		return advanced_config.target_scene
	return target_scene_path

func _get_requirement_type() -> String:
	"""Get requirement type from config or fallback"""
	if advanced_config:
		return advanced_config.requirement_type
	return requirement_type

func _get_custom_prompt_text() -> String:
	"""Get custom prompt text from config or fallback"""
	if advanced_config:
		return advanced_config.custom_prompt_text
	return custom_prompt_text

func _get_save_checkpoint() -> bool:
	"""Get save checkpoint setting from config or fallback"""
	if advanced_config:
		return advanced_config.save_checkpoint
	return save_checkpoint