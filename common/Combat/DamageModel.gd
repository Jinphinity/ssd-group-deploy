extends RefCounted

class_name DamageModel

static func compute_damage(weapon: Dictionary, armor: Dictionary, bodypart: String) -> float:
	"""Compute damage with automatic difficulty scaling from DifficultyManager"""
	var base: float = weapon.get("damage", 10.0)
	var dr: float = armor.get("dr", 0.0)
	var mult: float = {"head": 1.5, "torso": 1.0, "limb": 0.7}.get(bodypart, 1.0)
	
	# Get difficulty scaling from DifficultyManager
	var damage_multiplier: float = 1.0
	if DifficultyManager:
		damage_multiplier = DifficultyManager.get_modifier("enemy_damage_multiplier")
	
	return max(0.0, base * mult * (1.0 - dr) * damage_multiplier)

# Legacy method for backward compatibility
static func compute_damage_legacy(weapon: Dictionary, armor: Dictionary, bodypart: String, diff: Dictionary) -> float:
	"""Legacy method for backward compatibility"""
	var base: float = weapon.get("damage", 10.0)
	var dr: float = armor.get("dr", 0.0)
	var mult: float = {"head": 1.5, "torso": 1.0, "limb": 0.7}.get(bodypart, 1.0)
	return max(0.0, base * mult * (1.0 - dr) * diff.get("damage_scale", 1.0))
