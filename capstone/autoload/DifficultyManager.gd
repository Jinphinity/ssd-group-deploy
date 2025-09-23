extends Node

## Difficulty Presets System - Academic Compliance Phase 4
## Affects multiple gameplay systems with configurable parameters

enum DifficultyLevel {
	STORY,      # Narrative focus, minimal challenge
	EASY,       # Beginner-friendly, reduced challenge
	NORMAL,     # Balanced default experience
	HARD,       # Increased challenge for experienced players
	NIGHTMARE,  # Maximum challenge, scarce resources
	CUSTOM      # User-defined parameters
}

# Current difficulty settings
var current_difficulty: DifficultyLevel = DifficultyLevel.NORMAL
var custom_settings: Dictionary = {}

# Difficulty configuration presets
var difficulty_presets := {
	DifficultyLevel.STORY: {
		"name": "Story Mode",
		"description": "Focus on narrative with minimal combat challenge",
		"enemy_health_multiplier": 0.5,
		"enemy_damage_multiplier": 0.6,
		"enemy_spawn_rate_multiplier": 0.4,
		"enemy_aggression_multiplier": 0.5,
		"resource_scarcity_multiplier": 0.3,
		"xp_gain_multiplier": 1.5,
		"money_gain_multiplier": 1.3,
		"item_durability_loss_multiplier": 0.5,
		"hunger_drain_multiplier": 0.5,
		"fatigue_drain_multiplier": 0.5,
		"healing_effectiveness_multiplier": 1.5,
		"crafting_success_rate_bonus": 0.2,
		"market_price_multiplier": 0.8,
		"npc_friendliness_bonus": 0.3
	},
	DifficultyLevel.EASY: {
		"name": "Easy",
		"description": "Reduced challenge for new players",
		"enemy_health_multiplier": 0.7,
		"enemy_damage_multiplier": 0.8,
		"enemy_spawn_rate_multiplier": 0.7,
		"enemy_aggression_multiplier": 0.7,
		"resource_scarcity_multiplier": 0.6,
		"xp_gain_multiplier": 1.2,
		"money_gain_multiplier": 1.1,
		"item_durability_loss_multiplier": 0.7,
		"hunger_drain_multiplier": 0.7,
		"fatigue_drain_multiplier": 0.7,
		"healing_effectiveness_multiplier": 1.2,
		"crafting_success_rate_bonus": 0.1,
		"market_price_multiplier": 0.9,
		"npc_friendliness_bonus": 0.15
	},
	DifficultyLevel.NORMAL: {
		"name": "Normal",
		"description": "Balanced default experience",
		"enemy_health_multiplier": 1.0,
		"enemy_damage_multiplier": 1.0,
		"enemy_spawn_rate_multiplier": 1.0,
		"enemy_aggression_multiplier": 1.0,
		"resource_scarcity_multiplier": 1.0,
		"xp_gain_multiplier": 1.0,
		"money_gain_multiplier": 1.0,
		"item_durability_loss_multiplier": 1.0,
		"hunger_drain_multiplier": 1.0,
		"fatigue_drain_multiplier": 1.0,
		"healing_effectiveness_multiplier": 1.0,
		"crafting_success_rate_bonus": 0.0,
		"market_price_multiplier": 1.0,
		"npc_friendliness_bonus": 0.0
	},
	DifficultyLevel.HARD: {
		"name": "Hard",
		"description": "Increased challenge for experienced players",
		"enemy_health_multiplier": 1.3,
		"enemy_damage_multiplier": 1.2,
		"enemy_spawn_rate_multiplier": 1.3,
		"enemy_aggression_multiplier": 1.3,
		"resource_scarcity_multiplier": 1.4,
		"xp_gain_multiplier": 0.9,
		"money_gain_multiplier": 0.85,
		"item_durability_loss_multiplier": 1.3,
		"hunger_drain_multiplier": 1.3,
		"fatigue_drain_multiplier": 1.3,
		"healing_effectiveness_multiplier": 0.8,
		"crafting_success_rate_bonus": -0.1,
		"market_price_multiplier": 1.2,
		"npc_friendliness_bonus": -0.2
	},
	DifficultyLevel.NIGHTMARE: {
		"name": "Nightmare",
		"description": "Maximum challenge with scarce resources",
		"enemy_health_multiplier": 1.6,
		"enemy_damage_multiplier": 1.5,
		"enemy_spawn_rate_multiplier": 1.6,
		"enemy_aggression_multiplier": 1.5,
		"resource_scarcity_multiplier": 2.0,
		"xp_gain_multiplier": 0.8,
		"money_gain_multiplier": 0.7,
		"item_durability_loss_multiplier": 1.5,
		"hunger_drain_multiplier": 1.5,
		"fatigue_drain_multiplier": 1.5,
		"healing_effectiveness_multiplier": 0.6,
		"crafting_success_rate_bonus": -0.2,
		"market_price_multiplier": 1.5,
		"npc_friendliness_bonus": -0.3
	}
}

# Achievement tracking for difficulty-based progression
var difficulty_achievements := {
	"story_completion": false,
	"easy_completion": false,
	"normal_completion": false,
	"hard_completion": false,
	"nightmare_completion": false,
	"difficulty_master": false  # Complete on all difficulties
}

# Settings that can be modified at runtime
var runtime_modifiers := {
	"enemy_scaling_enabled": true,
	"resource_scaling_enabled": true,
	"progression_scaling_enabled": true,
	"economy_scaling_enabled": true,
	"survival_scaling_enabled": true
}

signal difficulty_changed(new_difficulty: DifficultyLevel)
signal difficulty_modifier_updated(modifier_name: String, new_value: float)

func _ready() -> void:
	# Load saved difficulty preference
	_load_difficulty_settings()

	# Apply current difficulty on startup
	_apply_difficulty_settings()

	print("🎮 Difficulty Manager initialized - Current: %s" % get_difficulty_name(current_difficulty))

func set_difficulty(new_difficulty: DifficultyLevel) -> void:
	"""Set new difficulty level and apply all related modifications"""
	if new_difficulty == current_difficulty:
		return

	var old_difficulty = current_difficulty
	current_difficulty = new_difficulty

	_apply_difficulty_settings()
	_save_difficulty_settings()

	difficulty_changed.emit(new_difficulty)

	print("⚡ Difficulty changed from %s to %s" % [
		get_difficulty_name(old_difficulty),
		get_difficulty_name(new_difficulty)
	])

func get_difficulty_name(difficulty: DifficultyLevel) -> String:
	"""Get human-readable name for difficulty level"""
	if difficulty == DifficultyLevel.CUSTOM:
		return "Custom"
	return difficulty_presets[difficulty]["name"]

func get_difficulty_description(difficulty: DifficultyLevel) -> String:
	"""Get description for difficulty level"""
	if difficulty == DifficultyLevel.CUSTOM:
		return "User-defined difficulty settings"
	return difficulty_presets[difficulty]["description"]

func get_current_settings() -> Dictionary:
	"""Get current difficulty settings (either preset or custom)"""
	if current_difficulty == DifficultyLevel.CUSTOM:
		return custom_settings
	else:
		return difficulty_presets[current_difficulty]

func get_modifier(modifier_name: String) -> float:
	"""Get specific difficulty modifier value"""
	var settings = get_current_settings()
	return settings.get(modifier_name, 1.0)

func set_custom_modifier(modifier_name: String, value: float) -> void:
	"""Set custom difficulty modifier (switches to CUSTOM difficulty)"""
	if current_difficulty != DifficultyLevel.CUSTOM:
		# Copy current preset as base for custom settings
		custom_settings = difficulty_presets[current_difficulty].duplicate()
		current_difficulty = DifficultyLevel.CUSTOM

	custom_settings[modifier_name] = value
	_apply_single_modifier(modifier_name, value)
	_save_difficulty_settings()

	difficulty_modifier_updated.emit(modifier_name, value)
	print("🔧 Custom modifier set: %s = %.2f" % [modifier_name, value])

func reset_to_preset(difficulty: DifficultyLevel) -> void:
	"""Reset custom settings and apply preset difficulty"""
	if difficulty == DifficultyLevel.CUSTOM:
		push_warning("Cannot reset to CUSTOM difficulty - choose a preset")
		return

	custom_settings.clear()
	set_difficulty(difficulty)

# Core difficulty application system
func _apply_difficulty_settings() -> void:
	"""Apply all difficulty settings to game systems"""
	var settings = get_current_settings()

	if runtime_modifiers.enemy_scaling_enabled:
		_apply_enemy_scaling(settings)

	if runtime_modifiers.resource_scaling_enabled:
		_apply_resource_scaling(settings)

	if runtime_modifiers.progression_scaling_enabled:
		_apply_progression_scaling(settings)

	if runtime_modifiers.economy_scaling_enabled:
		_apply_economy_scaling(settings)

	if runtime_modifiers.survival_scaling_enabled:
		_apply_survival_scaling(settings)

func _apply_single_modifier(modifier_name: String, value: float) -> void:
	"""Apply a single modifier change immediately"""
	var settings = {modifier_name: value}

	# Apply to relevant system based on modifier name
	if modifier_name.begins_with("enemy_"):
		_apply_enemy_scaling(settings)
	elif modifier_name.begins_with("resource_"):
		_apply_resource_scaling(settings)
	elif modifier_name.ends_with("_gain_multiplier"):
		_apply_progression_scaling(settings)
	elif modifier_name.begins_with("market_") or modifier_name.ends_with("_multiplier"):
		_apply_economy_scaling(settings)
	elif modifier_name.begins_with("hunger_") or modifier_name.begins_with("fatigue_") or modifier_name.begins_with("healing_"):
		_apply_survival_scaling(settings)

func _apply_enemy_scaling(settings: Dictionary) -> void:
	"""Apply enemy-related difficulty modifiers"""
	# Broadcast enemy scaling to all enemy spawners and controllers
	get_tree().call_group("enemies", "_apply_difficulty_scaling", {
		"health_multiplier": settings.get("enemy_health_multiplier", 1.0),
		"damage_multiplier": settings.get("enemy_damage_multiplier", 1.0),
		"aggression_multiplier": settings.get("enemy_aggression_multiplier", 1.0)
	})

	get_tree().call_group("enemy_spawners", "_apply_difficulty_scaling", {
		"spawn_rate_multiplier": settings.get("enemy_spawn_rate_multiplier", 1.0)
	})

func _apply_resource_scaling(settings: Dictionary) -> void:
	"""Apply resource scarcity and availability scaling"""
	# Apply to resource spawners and loot systems
	get_tree().call_group("resource_spawners", "_apply_difficulty_scaling", {
		"scarcity_multiplier": settings.get("resource_scarcity_multiplier", 1.0)
	})

	get_tree().call_group("loot_systems", "_apply_difficulty_scaling", {
		"scarcity_multiplier": settings.get("resource_scarcity_multiplier", 1.0)
	})

func _apply_progression_scaling(settings: Dictionary) -> void:
	"""Apply XP and progression scaling"""
	# Apply to player progression systems
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_apply_difficulty_scaling"):
		player._apply_difficulty_scaling({
			"xp_gain_multiplier": settings.get("xp_gain_multiplier", 1.0),
			"money_gain_multiplier": settings.get("money_gain_multiplier", 1.0)
		})

func _apply_economy_scaling(settings: Dictionary) -> void:
	"""Apply market and economy scaling"""
	# Apply to market systems
	get_tree().call_group("markets", "_apply_difficulty_scaling", {
		"price_multiplier": settings.get("market_price_multiplier", 1.0)
	})

func _apply_survival_scaling(settings: Dictionary) -> void:
	"""Apply survival mechanics scaling"""
	# Apply to survival systems (hunger, fatigue, health)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("_apply_survival_difficulty_scaling"):
		player._apply_survival_difficulty_scaling({
			"hunger_drain_multiplier": settings.get("hunger_drain_multiplier", 1.0),
			"fatigue_drain_multiplier": settings.get("fatigue_drain_multiplier", 1.0),
			"healing_effectiveness_multiplier": settings.get("healing_effectiveness_multiplier", 1.0),
			"item_durability_loss_multiplier": settings.get("item_durability_loss_multiplier", 1.0)
		})

# Achievement and progression tracking
func mark_difficulty_completed(difficulty: DifficultyLevel) -> void:
	"""Mark a difficulty level as completed for achievements"""
	match difficulty:
		DifficultyLevel.STORY:
			difficulty_achievements.story_completion = true
		DifficultyLevel.EASY:
			difficulty_achievements.easy_completion = true
		DifficultyLevel.NORMAL:
			difficulty_achievements.normal_completion = true
		DifficultyLevel.HARD:
			difficulty_achievements.hard_completion = true
		DifficultyLevel.NIGHTMARE:
			difficulty_achievements.nightmare_completion = true

	# Check for difficulty master achievement
	if (difficulty_achievements.story_completion and
		difficulty_achievements.easy_completion and
		difficulty_achievements.normal_completion and
		difficulty_achievements.hard_completion and
		difficulty_achievements.nightmare_completion):
		difficulty_achievements.difficulty_master = true
		print("🏆 Achievement Unlocked: Difficulty Master!")

	_save_difficulty_settings()
	print("🎯 Difficulty completed: %s" % get_difficulty_name(difficulty))

func get_difficulty_progress() -> Dictionary:
	"""Get completion status for all difficulties"""
	return difficulty_achievements.duplicate()

func can_unlock_difficulty(difficulty: DifficultyLevel) -> bool:
	"""Check if difficulty level is unlocked"""
	match difficulty:
		DifficultyLevel.STORY, DifficultyLevel.EASY, DifficultyLevel.NORMAL:
			return true  # Always available
		DifficultyLevel.HARD:
			return difficulty_achievements.normal_completion
		DifficultyLevel.NIGHTMARE:
			return difficulty_achievements.hard_completion
		DifficultyLevel.CUSTOM:
			return difficulty_achievements.easy_completion  # Unlock after completing easy

	return false

# Difficulty comparison and recommendations
func get_recommended_difficulty() -> DifficultyLevel:
	"""Get recommended difficulty based on player progress"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return DifficultyLevel.NORMAL

	var player_level := 1
	var total_playtime := 0.0

	if player.has_method("get_character_stats"):
		var stats = player.get_character_stats()
		if typeof(stats) == TYPE_DICTIONARY:
			player_level = int(stats.get("level", 1))
			total_playtime = float(stats.get("total_playtime", 0.0))
	else:
		if player.has_method("get"):
			var level_value = player.get("level")
			if typeof(level_value) in [TYPE_INT, TYPE_FLOAT]:
				player_level = int(level_value)

	if player_level < 5 or total_playtime < 3600.0:
		return DifficultyLevel.EASY
	elif player_level < 15 or total_playtime < 18000.0:
		return DifficultyLevel.NORMAL
	elif player_level < 25:
		return DifficultyLevel.HARD
	else:
		return DifficultyLevel.NIGHTMARE

func get_difficulty_comparison(difficulty1: DifficultyLevel, difficulty2: DifficultyLevel) -> Dictionary:
	"""Compare two difficulty levels and return key differences"""
	var settings1 = difficulty_presets.get(difficulty1, {})
	var settings2 = difficulty_presets.get(difficulty2, {})

	var comparison = {}
	var key_metrics = [
		"enemy_health_multiplier",
		"enemy_damage_multiplier",
		"resource_scarcity_multiplier",
		"xp_gain_multiplier"
	]

	for metric in key_metrics:
		var value1 = settings1.get(metric, 1.0)
		var value2 = settings2.get(metric, 1.0)
		comparison[metric] = {
			"difference": value2 - value1,
			"percent_change": value1 != 0.0 ? ((value2 - value1) / value1) * 100.0 : 0.0
		}

	return comparison

# Save/Load system
func _save_difficulty_settings() -> void:
	"""Save current difficulty settings to file"""
	var save_data = {
		"current_difficulty": current_difficulty,
		"custom_settings": custom_settings,
		"achievements": difficulty_achievements,
		"runtime_modifiers": runtime_modifiers
	}

	var file = FileAccess.open("user://difficulty_settings.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()

func _load_difficulty_settings() -> void:
	"""Load difficulty settings from file"""
	if not FileAccess.file_exists("user://difficulty_settings.save"):
		return

	var file = FileAccess.open("user://difficulty_settings.save", FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()

		if save_data:
			current_difficulty = save_data.get("current_difficulty", DifficultyLevel.NORMAL)
			custom_settings = save_data.get("custom_settings", {})
			difficulty_achievements = save_data.get("achievements", difficulty_achievements)
			runtime_modifiers = save_data.get("runtime_modifiers", runtime_modifiers)

# Public API for UI and external systems
func get_all_difficulty_info() -> Array:
	"""Get complete information about all difficulty levels"""
	var info = []

	for difficulty_level in DifficultyLevel.values():
		if difficulty_level == DifficultyLevel.CUSTOM:
			continue

		var difficulty_info = {
			"level": difficulty_level,
			"name": get_difficulty_name(difficulty_level),
			"description": get_difficulty_description(difficulty_level),
			"unlocked": can_unlock_difficulty(difficulty_level),
			"completed": _is_difficulty_completed(difficulty_level),
			"recommended": difficulty_level == get_recommended_difficulty(),
			"settings": difficulty_presets[difficulty_level]
		}
		info.append(difficulty_info)

	return info

func _is_difficulty_completed(difficulty: DifficultyLevel) -> bool:
	"""Check if specific difficulty has been completed"""
	match difficulty:
		DifficultyLevel.STORY:
			return difficulty_achievements.story_completion
		DifficultyLevel.EASY:
			return difficulty_achievements.easy_completion
		DifficultyLevel.NORMAL:
			return difficulty_achievements.normal_completion
		DifficultyLevel.HARD:
			return difficulty_achievements.hard_completion
		DifficultyLevel.NIGHTMARE:
			return difficulty_achievements.nightmare_completion
	return false

func toggle_runtime_modifier(modifier_name: String, enabled: bool) -> void:
	"""Enable/disable runtime difficulty modifiers"""
	if modifier_name in runtime_modifiers:
		runtime_modifiers[modifier_name] = enabled
		_save_difficulty_settings()

		# Reapply difficulty if modifier was enabled
		if enabled:
			_apply_difficulty_settings()

	print("[Difficulty] Runtime modifier '%s' %s" % [modifier_name, enabled ? "enabled" : "disabled"])

# Debug and testing functions
func debug_print_current_settings() -> void:
	"""Print current difficulty settings for debugging"""
	print("=== Current Difficulty Settings ===")
	print("Level: %s" % get_difficulty_name(current_difficulty))
	print("Description: %s" % get_difficulty_description(current_difficulty))

	var settings = get_current_settings()
	for key in settings:
		print("  %s: %.2f" % [key, settings[key]])

	print("Runtime Modifiers:")
	for key in runtime_modifiers:
		print("  %s: %s" % [key, runtime_modifiers[key]])

func simulate_difficulty_impact(target_difficulty: DifficultyLevel) -> Dictionary:
	"""Simulate the impact of switching to a different difficulty"""
	var current_settings = get_current_settings()
	var target_settings = difficulty_presets.get(target_difficulty, {})

	return get_difficulty_comparison(current_difficulty, target_difficulty)
