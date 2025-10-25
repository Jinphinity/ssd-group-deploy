extends Resource

## TransitionZoneConfig - Advanced configuration resource for level transitions
## Provides complex setup options beyond basic Inspector properties

class_name TransitionZoneConfig

# Core transition properties
@export var target_scene: String = ""
@export var transition_name: String = "Next Area"
@export_enum("Any", "Authenticated", "Level Complete", "Custom") var requirement_type: String = "Any"

# Advanced interaction configuration
@export var custom_prompt_text: String = ""
@export var interaction_key: String = "interact"
@export var show_prompt: bool = true
@export var auto_transition: bool = false
@export var transition_delay: float = 0.0

# Audio configuration
@export var audio_cue_enter: AudioStream = null
@export var audio_cue_transition: AudioStream = null
@export var audio_cue_blocked: AudioStream = null
@export var audio_volume: float = 1.0
@export var audio_spatial: bool = true

# Visual effects configuration
@export var visual_effect_enter: PackedScene = null
@export var visual_effect_transition: PackedScene = null
@export var visual_effect_blocked: PackedScene = null
@export var effect_duration: float = 1.0

# Custom requirement configuration
@export var requires_item: String = ""
@export var minimum_level: int = 0
@export var required_achievement: String = ""
@export var custom_requirement_script: Script = null

# Save and checkpoint configuration
@export var save_checkpoint: bool = true
@export var checkpoint_name: String = ""
@export var preserve_player_state: bool = true

# Visual appearance configuration
@export var zone_color: Color = Color.WHITE
@export var zone_opacity: float = 0.5
@export var highlight_color: Color = Color.GREEN
@export var blocked_color: Color = Color.RED
@export var pulse_animation: bool = true

# Performance and behavior settings
@export var detection_frequency: float = 10.0  # FPS for Area2D monitoring
@export var exit_delay: float = 0.5  # Delay before hiding prompt on exit
@export var debug_mode: bool = false

# Validation and error handling
@export var validate_target_on_ready: bool = true
@export var fallback_scene: String = ""
@export var error_message: String = "Transition unavailable"

func _init() -> void:
	# Set default values
	resource_name = "TransitionZoneConfig"

func validate_configuration() -> Dictionary:
	"""Validate the configuration and return validation results"""
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}

	# Validate target scene
	if target_scene == "":
		result.errors.append("Target scene path is empty")
		result.valid = false
	elif not ResourceLoader.exists(target_scene):
		result.errors.append("Target scene does not exist: %s" % target_scene)
		result.valid = false

	# Validate fallback scene if specified
	if fallback_scene != "" and not ResourceLoader.exists(fallback_scene):
		result.warnings.append("Fallback scene does not exist: %s" % fallback_scene)

	# Validate audio resources
	if audio_cue_enter and not audio_cue_enter is AudioStream:
		result.errors.append("Invalid audio_cue_enter resource")
		result.valid = false

	if audio_cue_transition and not audio_cue_transition is AudioStream:
		result.errors.append("Invalid audio_cue_transition resource")
		result.valid = false

	if audio_cue_blocked and not audio_cue_blocked is AudioStream:
		result.errors.append("Invalid audio_cue_blocked resource")
		result.valid = false

	# Validate visual effects
	if visual_effect_enter and not _is_valid_scene_resource(visual_effect_enter):
		result.warnings.append("Invalid visual_effect_enter scene")

	if visual_effect_transition and not _is_valid_scene_resource(visual_effect_transition):
		result.warnings.append("Invalid visual_effect_transition scene")

	if visual_effect_blocked and not _is_valid_scene_resource(visual_effect_blocked):
		result.warnings.append("Invalid visual_effect_blocked scene")

	# Validate numeric ranges
	if audio_volume < 0.0 or audio_volume > 2.0:
		result.warnings.append("Audio volume outside recommended range (0.0-2.0)")

	if detection_frequency < 1.0 or detection_frequency > 60.0:
		result.warnings.append("Detection frequency outside recommended range (1-60 FPS)")

	if transition_delay < 0.0:
		result.errors.append("Transition delay cannot be negative")
		result.valid = false

	if effect_duration < 0.0:
		result.errors.append("Effect duration cannot be negative")
		result.valid = false

	return result

func get_prompt_text() -> String:
	"""Get the prompt text to display to the player"""
	if custom_prompt_text != "":
		return custom_prompt_text

	match requirement_type:
		"Authenticated":
			return "Press E to enter %s (Login required)" % transition_name
		"Level Complete":
			return "Press E to enter %s (Complete level first)" % transition_name
		"Custom":
			return "Press E to enter %s" % transition_name
		_:
			return "Press E to enter %s" % transition_name

func get_blocked_message() -> String:
	"""Get the message to show when transition is blocked"""
	if error_message != "":
		return error_message

	match requirement_type:
		"Authenticated":
			return "Login required to access %s" % transition_name
		"Level Complete":
			return "Complete current level to access %s" % transition_name
		"Custom":
			if requires_item != "":
				return "Requires %s to access %s" % [requires_item, transition_name]
			elif minimum_level > 0:
				return "Requires level %d to access %s" % [minimum_level, transition_name]
			else:
				return "Cannot access %s" % transition_name
		_:
			return "Cannot access %s" % transition_name

func check_custom_requirements(player: Node = null) -> bool:
	"""Check custom requirements - can be overridden"""
	if requirement_type != "Custom":
		return true

	# Check item requirement
	if requires_item != "":
		if player and player.has_method("has_item"):
			return player.has_item(requires_item)
		return false

	# Check level requirement
	if minimum_level > 0:
		if player and player.has_method("get_level"):
			return player.get_level() >= minimum_level
		return false

	# Check achievement requirement
	if required_achievement != "":
		if player and player.has_method("has_achievement"):
			return player.has_achievement(required_achievement)
		return false

	# If custom script is provided, delegate to it
	if custom_requirement_script:
		# TODO: Implement custom script execution
		# This would need to be implemented based on the game's scripting system
		pass

	return true

func get_checkpoint_data(current_scene: String, player_position: Vector2) -> Dictionary:
	"""Get checkpoint data for saving"""
	var checkpoint_data = {
		"scene": current_scene,
		"target_scene": target_scene,
		"position": player_position,
		"timestamp": Time.get_ticks_msec(),
		"transition_name": transition_name,
		"config_resource": resource_path
	}

	if checkpoint_name != "":
		checkpoint_data["checkpoint_name"] = checkpoint_name

	return checkpoint_data

func _is_valid_scene_resource(scene: PackedScene) -> bool:
	"""Validate that a PackedScene resource is valid"""
	if not scene:
		return false

	# Try to get the scene state to validate it
	var state = scene.get_state()
	return state != null

# Static helper methods for creating common configurations
static func create_simple_transition(target: String, name: String) -> TransitionZoneConfig:
	"""Create a simple transition configuration"""
	var config = TransitionZoneConfig.new()
	config.target_scene = target
	config.transition_name = name
	config.requirement_type = "Any"
	return config

static func create_auth_transition(target: String, name: String) -> TransitionZoneConfig:
	"""Create an authentication-required transition"""
	var config = TransitionZoneConfig.new()
	config.target_scene = target
	config.transition_name = name
	config.requirement_type = "Authenticated"
	return config

static func create_level_complete_transition(target: String, name: String) -> TransitionZoneConfig:
	"""Create a level completion-required transition"""
	var config = TransitionZoneConfig.new()
	config.target_scene = target
	config.transition_name = name
	config.requirement_type = "Level Complete"
	return config

static func create_item_required_transition(target: String, name: String, item: String) -> TransitionZoneConfig:
	"""Create an item-required transition"""
	var config = TransitionZoneConfig.new()
	config.target_scene = target
	config.transition_name = name
	config.requirement_type = "Custom"
	config.requires_item = item
	return config