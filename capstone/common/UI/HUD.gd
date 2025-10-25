extends CanvasLayer

# UI Element References
@onready var perspective_label: Label = $Root/TopBar/LeftPanel/PlayerInfo/PerspectiveLabel
@onready var level_label: Label = $Root/TopBar/LeftPanel/PlayerInfo/LevelLabel
@onready var health_bar: ProgressBar = $Root/TopBar/LeftPanel/StatusBars/HealthContainer/HealthBar
@onready var xp_bar: ProgressBar = $Root/TopBar/LeftPanel/StatusBars/XPContainer/XPBar
@onready var weapon_label: Label = $Root/TopBar/RightPanel/WeaponInfo/WeaponLabel
@onready var proficiency_label: Label = $Root/TopBar/RightPanel/WeaponInfo/ProficiencyLabel
@onready var nourishment_bar: ProgressBar = $Root/TopBar/RightPanel/SurvivalPanel/NourishmentContainer/NourishmentBar
@onready var sleep_bar: ProgressBar = $Root/TopBar/RightPanel/SurvivalPanel/SleepContainer/SleepBar
@onready var captions_label: Label = $Root/Captions

# Animation and effects
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var shake_duration: float = 0.0
var original_position: Vector2

func _ready() -> void:
	# Add to HUD group for easy finding
	add_to_group("hud")

	# Store original position for shake effect
	original_position = offset

	# Connect to game systems
	if has_node("/root/Game"):
		var g = get_node("/root/Game")
		if g.has_signal("perspective_changed"):
			if not g.is_connected("perspective_changed", Callable(self, "_on_perspective_changed")):
				g.connect("perspective_changed", Callable(self, "_on_perspective_changed"))
		var perspective_value = g.get("current_perspective")
		var perspective := "Side"
		if typeof(perspective_value) == TYPE_STRING and perspective_value != "":
			perspective = perspective_value
		_on_perspective_changed(perspective)
		if g.event_bus:
			if not g.event_bus.is_connected("WeaponFired", Callable(self, "_on_weapon_fired")):
				g.event_bus.connect("WeaponFired", Callable(self, "_on_weapon_fired"))
			if not g.event_bus.is_connected("PlayerLeveledUp", Callable(self, "_on_player_leveled_up")):
				g.event_bus.connect("PlayerLeveledUp", Callable(self, "_on_player_leveled_up"))

	# Find and connect to player
	var player := get_tree().get_first_node_in_group("player")
	if player:
		set_process(true)
		# Listen for player stat changes if available
		if player.has_signal("stats_updated"):
			player.connect("stats_updated", Callable(self, "_update_all_stats"))

	# Connect to accessibility system
	if has_node("/root/Accessibility"):
		var a = get_node("/root/Accessibility")
		a.connect("setting_changed", Callable(self, "_on_accessibility_changed"))
		_on_accessibility_changed()

	# Style the progress bars
	_setup_progress_bar_styles()

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_update_player_stats(player)

	# Handle UI shake effect
	if shake_timer > 0.0:
		shake_timer -= delta
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		offset = original_position + shake_offset

		# Reduce shake intensity over time
		shake_intensity = lerp(shake_intensity, 0.0, delta * 5.0)

		if shake_timer <= 0.0:
			offset = original_position
			shake_intensity = 0.0

func _update_player_stats(player: Node) -> void:
	# Update health
	if player.has_method("get_health"):
		var health = player.get_health()
		health_bar.value = health
		_animate_bar_color(health_bar, health, 100.0)

	# Update comprehensive stats if available
	if player.has_method("get_character_stats"):
		var stats = player.get_character_stats()

		# Update level and XP
		level_label.text = "Level: %d" % stats.level
		var xp_progress = float(stats.xp) / float(stats.xp_for_next_level) * 100.0
		xp_bar.value = xp_progress

		# Update weapon + proficiency information from inventory
		var weapon_name := "None"
		var proficiency_key := "firearm_handguns"
		var inventory := player.get_node_or_null("Inventory")
		if inventory:
			var summary: Dictionary = inventory.get_equipment_summary()
			var slots_dict: Dictionary = summary.get("slots", {})
			var weapon_item = slots_dict.get("weapon", null)
			if weapon_item:
				weapon_name = weapon_item.get("name", "Weapon")
				proficiency_key = _determine_proficiency_key(weapon_item)
		weapon_label.text = "Weapon: %s" % weapon_name
		var weapon_proficiencies: Dictionary = {}
		if typeof(stats) == TYPE_DICTIONARY:
			weapon_proficiencies = stats.get("weapon_proficiencies", {})
		else:
			weapon_proficiencies = stats.weapon_proficiencies
		var proficiency := int(weapon_proficiencies.get(proficiency_key, 0))
		proficiency_label.text = "Proficiency: %s %d%%" % [_format_proficiency_label(proficiency_key), proficiency]

		# Update survival stats
		nourishment_bar.value = stats.nourishment_level
		sleep_bar.value = stats.sleep_level

		# Color code survival bars based on levels
		_animate_bar_color(nourishment_bar, stats.nourishment_level, 100.0)
		_animate_bar_color(sleep_bar, stats.sleep_level, 100.0)

func _on_perspective_changed(mode: String) -> void:
	perspective_label.text = "Perspective: %s" % mode

func _on_weapon_fired(_id, _params):
	# Show caption for accessibility
	if has_node("/root/Accessibility") and get_node("/root/Accessibility").show_captions:
		captions_label.text = "Bang!"
		captions_label.modulate = Color(1,1,1,1)
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if not is_inside_tree() or not captions_label or not is_instance_valid(captions_label):
				return
			captions_label.modulate = Color(1,1,1,0)
		)

	# Trigger UI shake effect
	trigger_ui_shake(8.0, 0.3)

func _on_player_leveled_up(new_level: int, stat_points: int):
	# Create level up effect
	captions_label.text = "LEVEL UP! (%d)" % new_level
	captions_label.modulate = Color(1, 1, 0, 1)  # Yellow

	# Trigger celebration shake
	trigger_ui_shake(15.0, 0.5)

	# Fade out level up text
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if not is_inside_tree() or not captions_label or not is_instance_valid(captions_label):
			return
		var tween = create_tween()
		tween.tween_property(captions_label, "modulate", Color(1,1,1,0), 0.5)
	)

func trigger_ui_shake(intensity: float, duration: float) -> void:
	"""Trigger UI shake effect with specified intensity and duration"""
	shake_intensity = intensity
	shake_timer = duration
	shake_duration = duration

func show_combo_text(combo_count: int) -> void:
	"""Show combo counter text"""
	captions_label.text = "COMBO x%d!" % combo_count
	captions_label.modulate = Color(1, 0.5, 0, 1)  # Orange

	# Fade out combo text
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if not is_inside_tree() or not captions_label or not is_instance_valid(captions_label):
			return
		var tween = create_tween()
		tween.tween_property(captions_label, "modulate", Color(1,1,1,0), 0.5)
	)

func show_crosshair_feedback() -> void:
	"""Show crosshair hit feedback"""
	# Create temporary crosshair flash
	captions_label.text = "◉"
	captions_label.modulate = Color(1, 1, 1, 1)

	# Quick flash effect
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if not is_inside_tree() or not captions_label or not is_instance_valid(captions_label):
			return
		captions_label.modulate = Color(1,1,1,0)
		captions_label.text = ""
	)

func show_event_notification(message: String, event_type: String) -> void:
	"""Show event notification with appropriate styling"""
	captions_label.text = message

	# Color based on event type
	match event_type:
		"OutpostAttacked", "Raider":
			captions_label.modulate = Color(1, 0.2, 0.2, 1)  # Red for danger
			trigger_ui_shake(12.0, 0.6)  # Strong shake for danger
		"ConvoyArrived", "Settlement":
			captions_label.modulate = Color(0.2, 1, 0.2, 1)  # Green for good news
			trigger_ui_shake(5.0, 0.3)  # Light shake for good news
		"Shortage":
			captions_label.modulate = Color(1, 1, 0.2, 1)  # Yellow for warnings
			trigger_ui_shake(8.0, 0.4)  # Medium shake for warnings
		_:
			captions_label.modulate = Color(0.7, 0.7, 1, 1)  # Blue for neutral
			trigger_ui_shake(6.0, 0.3)  # Light shake for neutral

	# Fade out notification
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not is_inside_tree() or not captions_label or not is_instance_valid(captions_label):
			return
		var tween = create_tween()
		tween.tween_property(captions_label, "modulate", Color(1,1,1,0), 1.0)
	)

func _setup_progress_bar_styles() -> void:
	"""Setup visual styling for progress bars"""
	# Health bar - red theme
	var health_style = StyleBoxFlat.new()
	health_style.bg_color = Color(0.8, 0.2, 0.2, 0.8)
	health_style.border_width_left = 1
	health_style.border_width_right = 1
	health_style.border_width_top = 1
	health_style.border_width_bottom = 1
	health_style.border_color = Color(0.4, 0.1, 0.1, 1.0)
	health_bar.add_theme_stylebox_override("fill", health_style)

	# XP bar - blue theme
	var xp_style = StyleBoxFlat.new()
	xp_style.bg_color = Color(0.2, 0.6, 0.8, 0.8)
	xp_style.border_width_left = 1
	xp_style.border_width_right = 1
	xp_style.border_width_top = 1
	xp_style.border_width_bottom = 1
	xp_style.border_color = Color(0.1, 0.3, 0.4, 1.0)
	xp_bar.add_theme_stylebox_override("fill", xp_style)

	# Nourishment bar - green theme
	var food_style = StyleBoxFlat.new()
	food_style.bg_color = Color(0.4, 0.8, 0.2, 0.8)
	food_style.border_width_left = 1
	food_style.border_width_right = 1
	food_style.border_width_top = 1
	food_style.border_width_bottom = 1
	food_style.border_color = Color(0.2, 0.4, 0.1, 1.0)
	nourishment_bar.add_theme_stylebox_override("fill", food_style)

	# Sleep bar - purple theme
	var sleep_style = StyleBoxFlat.new()
	sleep_style.bg_color = Color(0.6, 0.3, 0.8, 0.8)
	sleep_style.border_width_left = 1
	sleep_style.border_width_right = 1
	sleep_style.border_width_top = 1
	sleep_style.border_width_bottom = 1
	sleep_style.border_color = Color(0.3, 0.15, 0.4, 1.0)
	sleep_bar.add_theme_stylebox_override("fill", sleep_style)

func _determine_proficiency_key(weapon_item: Dictionary) -> String:
	var category := String(weapon_item.get("category", "")).to_lower()
	match category:
		"handgun":
			return "firearm_handguns"
		"rifle":
			return "firearm_rifles"
		"smg":
			return "firearm_automatics"
		"shotgun":
			return "firearm_shotguns"
		"melee_knife":
			return "melee_knives"
		"melee_club", "melee_axe":
			return "melee_axes_clubs"
		_:
			return "firearm_handguns"

func _format_proficiency_label(key: String) -> String:
	match key:
		"firearm_handguns":
			return "Handguns"
		"firearm_rifles":
			return "Rifles"
		"firearm_shotguns":
			return "Shotguns"
		"firearm_automatics":
			return "Automatics"
		"melee_knives":
			return "Melee (Knives)"
		"melee_axes_clubs":
			return "Melee (Axes/Clubs)"
		_:
			return key.capitalize()

func _animate_bar_color(bar: ProgressBar, current_value: float, max_value: float) -> void:
	"""Animate progress bar colors based on value percentage"""
	var percentage = current_value / max_value
	var color: Color

	# Color coding: Green > Yellow > Red
	if percentage > 0.6:
		color = Color.GREEN.lerp(Color.YELLOW, (1.0 - percentage) * 2.5)
	elif percentage > 0.3:
		color = Color.YELLOW.lerp(Color.RED, (0.6 - percentage) * 3.33)
	else:
		color = Color.RED

	# Apply color to the bar
	if bar.has_theme_stylebox_override("fill"):
		var style = bar.get_theme_stylebox("fill") as StyleBoxFlat
		if style:
			style.bg_color = Color(color.r, color.g, color.b, 0.8)

func _on_accessibility_changed():
	var acc := get_node_or_null("/root/Accessibility")
	var high: bool = acc != null and acc.high_contrast
	var col := Color(1,1,1) if high else Color(1,1,1,0.85)

	# Update label colors
	perspective_label.modulate = col
	level_label.modulate = col
	weapon_label.modulate = col
	proficiency_label.modulate = col
	captions_label.modulate = Color(1,1,0,1) if high else Color(1,1,1,1)

	# High contrast mode adjustments
	if high:
		# Make progress bars more visible in high contrast
		for bar in [health_bar, xp_bar, nourishment_bar, sleep_bar]:
			bar.modulate = Color(1.2, 1.2, 1.2, 1.0)
