extends Node

## Versatile ballistic system for 2D gameplay with optional falloff and spread.

class_name Ballistics

const DamageModel = preload("res://common/Combat/DamageModel.gd")

signal weapon_fired(params)

const DEFAULT_MAX_DISTANCE := 1200.0
const DEFAULT_LAYERS := 1

var max_distance: float = DEFAULT_MAX_DISTANCE
var collision_layers: int = DEFAULT_LAYERS
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func fire(origin: Vector2, direction: Vector2, damage: float, layers: int = DEFAULT_LAYERS, params: Dictionary = {}) -> Dictionary:
	var shot_params: Dictionary = params.duplicate(true)
	shot_params["origin"] = origin
	shot_params["base_direction"] = direction
	shot_params["base_damage"] = damage
	shot_params["layers"] = layers

	emit_signal("weapon_fired", shot_params)
	if has_node("/root/Game"):
		get_node("/root/Game").event_bus.emit_signal("WeaponFired", 0, shot_params)

	var final_direction := _apply_spread(direction, shot_params)
	var hit := _perform_raycast(origin, final_direction, layers, shot_params)
	if hit.is_empty():
		return hit

	var distance: float = origin.distance_to(hit.get("position", origin))
	var final_damage := _apply_damage_falloff(damage, distance, shot_params)
	var hit_zone := _resolve_hit_zone(hit, shot_params)
	final_damage = _apply_body_part_modifiers(hit.get("collider"), final_damage, hit_zone, shot_params)
	var target: Node = hit.get("collider")
	if target and target.has_method("apply_damage"):
		target.apply_damage(final_damage, hit_zone)

	hit["hit_zone"] = hit_zone
	hit["final_damage"] = final_damage
	hit["distance"] = distance
	hit["direction"] = final_direction
	return hit

func simulate_recoil(current_vector: Vector2, recoil: float, recovery: float, delta: float) -> Vector2:
	var target_vector: Vector2 = current_vector.normalized()
	var recoil_offset := Vector2(0.0, -recoil)
	var adjusted: Vector2 = (target_vector + recoil_offset).normalized()
	return target_vector.lerp(adjusted, clamp(recovery * delta, 0.0, 1.0)).normalized()

func _apply_spread(direction: Vector2, params: Dictionary) -> Vector2:
	var spread_deg := float(params.get("spread_degrees", 0.0))
	if spread_deg <= 0.0:
		return direction.normalized()
	var spread_rad: float = deg_to_rad(spread_deg)
	var angle: float = direction.angle()
	angle += _rng.randf_range(-spread_rad, spread_rad)
	return Vector2(cos(angle), sin(angle)).normalized()

func _resolve_hit_zone(hit_result: Dictionary, params: Dictionary) -> String:
	if hit_result.has("collider"):
		var collider: Variant = hit_result.get("collider")
		if collider and collider.has_method("get_hit_zone_from_hit"):
			return collider.get_hit_zone_from_hit(hit_result)
	return String(params.get("hit_zone", "torso"))

func _apply_body_part_modifiers(target: Node, base_damage: float, hit_zone: String, params: Dictionary) -> float:
	var damage := base_damage
	var body_multipliers: Dictionary = params.get("body_multipliers", {})
	if typeof(body_multipliers) == TYPE_DICTIONARY and body_multipliers.has(hit_zone):
		damage *= float(body_multipliers[hit_zone])
	elif DamageModel and body_multipliers == {}:
		var weapon_profile: Dictionary = params.get("weapon_profile", {})
		var armor_profile: Dictionary = params.get("armor_profile", {})
		damage = DamageModel.compute_damage(weapon_profile, armor_profile, hit_zone)
	return damage

func _apply_damage_falloff(base_damage: float, distance: float, params: Dictionary) -> float:
	var falloff_start := float(params.get("falloff_start", 0.0))
	var falloff_end := float(params.get("falloff_end", 0.0))
	if falloff_end <= falloff_start or falloff_start <= 0.0:
		return base_damage
	if distance <= falloff_start:
		return base_damage
	if distance >= falloff_end:
		return base_damage * float(params.get("falloff_min", 0.4))
	var t := (distance - falloff_start) / (falloff_end - falloff_start)
	var min_mul := float(params.get("falloff_min", 0.4))
	return max(0.0, lerp(base_damage, base_damage * min_mul, t))

func _perform_raycast(origin: Vector2, direction: Vector2, layers: int, params: Dictionary) -> Dictionary:
	var space := get_viewport().world_2d.direct_space_state if get_viewport() and get_viewport().world_2d else null
	if space == null:
		return {}
	var dir: Vector2 = direction.normalized()
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	var max_dist := float(params.get("max_distance", max_distance))
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, origin + dir * max_dist)
	query.collision_mask = layers
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {
		"position": hit.get("position", origin),
		"normal": hit.get("normal", Vector2.ZERO),
		"collider": hit.get("collider"),
		"rid": hit.get("rid"),
		"shape": hit.get("shape"),
		"type": "2d"
	}
