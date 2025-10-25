extends Node

## Centralized configuration: economy, spawn rules
## Note: Difficulty system moved to DifficultyManager autoload

# DEPRECATED: Use DifficultyManager instead
var difficulty_presets := {
	"Story": {"damage_scale": 0.75, "npc_count": 8},
	"Normal": {"damage_scale": 1.0, "npc_count": 12},
	"Hard": {"damage_scale": 1.25, "npc_count": 16},
	"Nightmare": {"damage_scale": 1.5, "npc_count": 24}
}

var economy := {
	"base_price_multiplier": 1.0,
	"demand_multiplier": 1.0,
	"scarcity_multiplier": 1.0,
}

var spawn_curves := {
	"hostile_zones": [4, 6, 8, 12, 16],
}

# DEPRECATED: Use DifficultyManager.get_current_settings() instead
func get_difficulty(name: String) -> Dictionary:
	push_warning("Config.get_difficulty() is deprecated. Use DifficultyManager instead.")
	return difficulty_presets.get(name, difficulty_presets["Normal"])
