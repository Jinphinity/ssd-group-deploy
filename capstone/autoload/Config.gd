extends Node

## Centralized configuration: difficulty, economy, spawn rules

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

func get_difficulty(name: String) -> Dictionary:
    return difficulty_presets.get(name, difficulty_presets["Normal"])

