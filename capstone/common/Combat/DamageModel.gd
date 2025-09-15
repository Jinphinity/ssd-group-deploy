extends RefCounted

class_name DamageModel

func compute_damage(weapon: Dictionary, armor: Dictionary, bodypart: String, diff: Dictionary) -> float:
    var base: float = weapon.get("damage", 10.0)
    var dr: float = armor.get("dr", 0.0)
    var mult := {"head": 1.5, "torso": 1.0, "limb": 0.7}.get(bodypart, 1.0)
    return max(0.0, base * mult * (1.0 - dr) * diff.get("damage_scale", 1.0))

