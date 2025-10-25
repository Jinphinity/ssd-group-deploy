extends Area2D
class_name Zone2D

## Zone system for Safe/Hostile area designation (2D version)
## Affects AI behavior, spawn rates, and risk/reward mechanics

enum ZoneType {
	SAFE,
	HOSTILE,
	NEUTRAL
}

@export var zone_type: ZoneType = ZoneType.NEUTRAL
@export var zone_name: String = "Unknown Zone"
@export var spawn_multiplier: float = 1.0
@export var xp_multiplier: float = 1.0
@export var loot_multiplier: float = 1.0
@export var noise_penalty: float = 1.0  # Multiplier for noise detection in this zone

signal zone_entered(body: Node2D, zone: Zone2D)
signal zone_exited(body: Node2D, zone: Zone2D)

var entities_in_zone: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Add to zone group for easy access
	add_to_group("zones")
	match zone_type:
		ZoneType.SAFE:
			add_to_group("safe_zones")
		ZoneType.HOSTILE:
			add_to_group("hostile_zones")
		ZoneType.NEUTRAL:
			add_to_group("neutral_zones")

func _on_body_entered(body: Node2D) -> void:
	entities_in_zone.append(body)
	zone_entered.emit(body, self)

	# Apply zone effects to entities
	_apply_zone_effects(body, true)

	# Notify relevant systems
	if body.is_in_group("player"):
		_on_player_entered()
	elif body.is_in_group("npc"):
		_on_npc_entered(body)

func _on_body_exited(body: Node2D) -> void:
	entities_in_zone.erase(body)
	zone_exited.emit(body, self)

	# Remove zone effects from entities
	_apply_zone_effects(body, false)

	# Notify relevant systems
	if body.is_in_group("player"):
		_on_player_exited()
	elif body.is_in_group("npc"):
		_on_npc_exited(body)

func _apply_zone_effects(body: Node2D, entering: bool) -> void:
	"""Apply or remove zone-specific effects to entities"""
	if body.has_method("set_zone_effects"):
		var effects := {
			"zone_type": zone_type,
			"zone_name": zone_name,
			"spawn_multiplier": spawn_multiplier,
			"xp_multiplier": xp_multiplier,
			"loot_multiplier": loot_multiplier,
			"noise_penalty": noise_penalty,
			"entering": entering
		}
		body.set_zone_effects(effects)

func _on_player_entered() -> void:
	"""Handle player entering this zone"""
	var message := ""
	var color := "white"

	match zone_type:
		ZoneType.SAFE:
			message = "Entered Safe Zone: %s" % zone_name
			color = "green"
			# Reduce spawn rates in safe zones
			_modify_spawn_rates(0.1)
		ZoneType.HOSTILE:
			message = "Entered Hostile Zone: %s" % zone_name
			color = "red"
			# Increase spawn rates in hostile zones
			_modify_spawn_rates(spawn_multiplier)
		ZoneType.NEUTRAL:
			message = "Entered: %s" % zone_name
			color = "yellow"

	# Send message to HUD if available
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_zone_message"):
		hud.show_zone_message(message, color)

	print("🏃 Player entered %s zone: %s" % [ZoneType.keys()[zone_type].to_lower(), zone_name])

func _on_player_exited() -> void:
	"""Handle player exiting this zone"""
	# Reset spawn rates when leaving zone
	_modify_spawn_rates(1.0)
	print("🏃 Player exited %s zone: %s" % [ZoneType.keys()[zone_type].to_lower(), zone_name])

func _on_npc_entered(npc: Node2D) -> void:
	"""Handle NPC entering this zone"""
	if npc.has_method("enter_zone"):
		npc.enter_zone(self)

func _on_npc_exited(npc: Node2D) -> void:
	"""Handle NPC exiting this zone"""
	if npc.has_method("exit_zone"):
		npc.exit_zone()

func _modify_spawn_rates(multiplier: float) -> void:
	"""Modify spawn rates in this zone"""
	var wave_spawners = get_tree().get_nodes_in_group("wave_spawners")
	for spawner in wave_spawners:
		if spawner.has_method("set_zone_multiplier"):
			spawner.set_zone_multiplier(multiplier)

func get_zone_info() -> Dictionary:
	"""Get comprehensive zone information"""
	return {
		"type": zone_type,
		"name": zone_name,
		"entities_count": entities_in_zone.size(),
		"spawn_multiplier": spawn_multiplier,
		"xp_multiplier": xp_multiplier,
		"loot_multiplier": loot_multiplier,
		"noise_penalty": noise_penalty,
		"entities_in_zone": entities_in_zone.map(func(e): return e.name if e != null else "null")
	}

func is_safe_zone() -> bool:
	return zone_type == ZoneType.SAFE

func is_hostile_zone() -> bool:
	return zone_type == ZoneType.HOSTILE

func is_neutral_zone() -> bool:
	return zone_type == ZoneType.NEUTRAL

func get_danger_level() -> float:
	"""Get relative danger level of this zone (0.0 = safest, 1.0+ = dangerous)"""
	match zone_type:
		ZoneType.SAFE:
			return 0.0
		ZoneType.NEUTRAL:
			return 0.5
		ZoneType.HOSTILE:
			return spawn_multiplier
		_:
			return 0.5

# Compatibility methods for ZoneManager duck typing
func zone_entered_signal() -> Signal:
	return zone_entered

func zone_exited_signal() -> Signal:
	return zone_exited
