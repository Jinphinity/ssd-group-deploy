extends Control

## TransitionPrompt UI Component
## Provides visual feedback for level transition interactions
## Designed to be embedded in LevelTransition scenes

class_name TransitionPrompt

@onready var background_panel: Panel = $BackgroundPanel
@onready var prompt_label: Label = $BackgroundPanel/VBoxContainer/PromptLabel
@onready var requirement_label: Label = $BackgroundPanel/VBoxContainer/RequirementLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Configuration
@export var fade_duration: float = 0.3
@export var pulse_enabled: bool = true
@export var auto_size: bool = true

# State
var is_visible_to_player: bool = false
var current_transition: LevelTransition = null

# Signals
signal prompt_animation_finished()

func _ready() -> void:
	# Initially hidden
	modulate = Color.TRANSPARENT
	visible = false

	# Configure auto-sizing
	if auto_size:
		set_anchors_and_offsets_preset(Control.PRESET_CENTER)

	# Set up animation if available
	if animation_player:
		_setup_animations()

func show_prompt(text: String, requirement_text: String = "", available: bool = true) -> void:
	"""Show transition prompt with animation"""
	if prompt_label:
		prompt_label.text = text

	if requirement_label:
		requirement_label.text = requirement_text
		requirement_label.visible = requirement_text != ""

	# Update visual state based on availability
	_update_visual_state(available)

	# Show with animation
	visible = true
	is_visible_to_player = true

	# Animate in
	if animation_player and animation_player.has_animation("fade_in"):
		animation_player.play("fade_in")
	else:
		_fade_in()

func hide_prompt() -> void:
	"""Hide transition prompt with animation"""
	if not is_visible_to_player:
		return

	is_visible_to_player = false

	# Animate out
	if animation_player and animation_player.has_animation("fade_out"):
		animation_player.play("fade_out")
	else:
		_fade_out()

func update_prompt_state(available: bool, reason: String = "") -> void:
	"""Update prompt visual state and requirement text"""
	_update_visual_state(available)

	if requirement_label:
		if available:
			requirement_label.text = ""
			requirement_label.visible = false
		else:
			requirement_label.text = reason
			requirement_label.visible = true

func _update_visual_state(available: bool) -> void:
	"""Update visual appearance based on availability"""
	if not background_panel:
		return

	if available:
		# Available state - green tint
		background_panel.modulate = Color(0.8, 1.0, 0.8, 0.9)
		if prompt_label:
			prompt_label.modulate = Color.WHITE
	else:
		# Blocked state - red tint
		background_panel.modulate = Color(1.0, 0.8, 0.8, 0.9)
		if prompt_label:
			prompt_label.modulate = Color(1.0, 0.8, 0.8)

func _fade_in() -> void:
	"""Manual fade in animation"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, fade_duration)
	tween.tween_callback(_on_fade_in_complete)

func _fade_out() -> void:
	"""Manual fade out animation"""
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_duration)
	tween.tween_callback(_on_fade_out_complete)

func _on_fade_in_complete() -> void:
	"""Called when fade in animation completes"""
	if pulse_enabled and animation_player and animation_player.has_animation("pulse"):
		animation_player.play("pulse")
	prompt_animation_finished.emit()

func _on_fade_out_complete() -> void:
	"""Called when fade out animation completes"""
	visible = false
	if animation_player:
		animation_player.stop()
	prompt_animation_finished.emit()

func _setup_animations() -> void:
	"""Set up AnimationPlayer animations programmatically"""
	if not animation_player:
		return

	# Create fade_in animation
	var fade_in_anim = Animation.new()
	fade_in_anim.length = fade_duration

	var modulate_track = fade_in_anim.add_track(Animation.TYPE_VALUE)
	fade_in_anim.track_set_path(modulate_track, NodePath("..:modulate"))
	fade_in_anim.track_insert_key(modulate_track, 0.0, Color.TRANSPARENT)
	fade_in_anim.track_insert_key(modulate_track, fade_duration, Color.WHITE)

	animation_player.add_animation_library("default", AnimationLibrary.new())
	animation_player.get_animation_library("default").add_animation("fade_in", fade_in_anim)

	# Create fade_out animation
	var fade_out_anim = Animation.new()
	fade_out_anim.length = fade_duration

	var modulate_track_out = fade_out_anim.add_track(Animation.TYPE_VALUE)
	fade_out_anim.track_set_path(modulate_track_out, NodePath("..:modulate"))
	fade_out_anim.track_insert_key(modulate_track_out, 0.0, Color.WHITE)
	fade_out_anim.track_insert_key(modulate_track_out, fade_duration, Color.TRANSPARENT)

	animation_player.get_animation_library("default").add_animation("fade_out", fade_out_anim)

	# Create pulse animation if enabled
	if pulse_enabled:
		var pulse_anim = Animation.new()
		pulse_anim.length = 2.0
		pulse_anim.loop_mode = Animation.LOOP_LINEAR

		var scale_track = pulse_anim.add_track(Animation.TYPE_VALUE)
		pulse_anim.track_set_path(scale_track, NodePath("..:scale"))
		pulse_anim.track_insert_key(scale_track, 0.0, Vector2.ONE)
		pulse_anim.track_insert_key(scale_track, 1.0, Vector2(1.1, 1.1))
		pulse_anim.track_insert_key(scale_track, 2.0, Vector2.ONE)

		animation_player.get_animation_library("default").add_animation("pulse", pulse_anim)

# Public API methods
func set_transition_reference(transition: LevelTransition) -> void:
	"""Set reference to the parent transition"""
	current_transition = transition

func get_prompt_info() -> Dictionary:
	"""Get prompt information for debugging"""
	return {
		"visible": is_visible_to_player,
		"prompt_text": prompt_label.text if prompt_label else "",
		"requirement_text": requirement_label.text if requirement_label else "",
		"has_animation": animation_player != null
	}