extends Node

## ZoneManager: Centralized zone system management
## Handles zone transitions, AI behavior modifications, and zone-based gameplay effects

signal player_zone_changed(old_zone: Zone, new_zone: Zone)
signal zone_danger_level_changed(zone: Zone, new_level: float)

var current_player_zone: Zone = null
var zone_registry: Dictionary = {}
var base_spawn_rate: float = 1.0

func _ready() -> void:
    # Wait for scene to be ready, then register zones
    call_deferred("_register_all_zones")

    # Connect to existing zone signals
    _connect_zone_signals()

func _register_all_zones() -> void:
    """Register all zones in the scene"""
    var zones = get_tree().get_nodes_in_group("zones")
    for zone in zones:
        if zone is Zone:
            _register_zone(zone)

func _register_zone(zone: Zone) -> void:
    """Register a zone in the system"""
    if not zone_registry.has(zone.zone_name):
        zone_registry[zone.zone_name] = zone
        zone.zone_entered.connect(_on_zone_entered)
        zone.zone_exited.connect(_on_zone_exited)
        print("[ZoneManager] Registered zone: %s (%s)" % [zone.zone_name, Zone.ZoneType.keys()[zone.zone_type]])

func _connect_zone_signals() -> void:
    """Connect to zone-related signals from other systems"""
    # Connect to spawner signals
    var spawners = get_tree().get_nodes_in_group("wave_spawners")
    for spawner in spawners:
        if spawner.has_signal("spawn_rate_changed"):
            spawner.spawn_rate_changed.connect(_on_spawn_rate_changed)

func _on_zone_entered(body: Node3D, zone: Zone) -> void:
    """Handle entity entering a zone"""
    if body.is_in_group("player"):
        _handle_player_zone_change(zone)
    elif body.is_in_group("npc"):
        _handle_npc_zone_change(body, zone, true)

func _on_zone_exited(body: Node3D, zone: Zone) -> void:
    """Handle entity exiting a zone"""
    if body.is_in_group("player"):
        if current_player_zone == zone:
            _handle_player_zone_change(null)
    elif body.is_in_group("npc"):
        _handle_npc_zone_change(body, zone, false)

func _handle_player_zone_change(new_zone: Zone) -> void:
    """Handle player changing zones"""
    var old_zone = current_player_zone
    current_player_zone = new_zone

    if old_zone != new_zone:
        player_zone_changed.emit(old_zone, new_zone)
        _apply_player_zone_effects(old_zone, new_zone)

func _handle_npc_zone_change(npc: Node3D, zone: Zone, entering: bool) -> void:
    """Handle NPC zone changes and apply AI modifications"""
    if npc.has_method("apply_zone_behavior"):
        var zone_data := {
            "zone_type": zone.zone_type,
            "spawn_multiplier": zone.spawn_multiplier,
            "noise_penalty": zone.noise_penalty,
            "entering": entering
        }
        npc.apply_zone_behavior(zone_data)

func _apply_player_zone_effects(old_zone: Zone, new_zone: Zone) -> void:
    """Apply zone-specific effects when player changes zones"""
    # Remove old zone effects
    if old_zone:
        _remove_zone_effects(old_zone)

    # Apply new zone effects
    if new_zone:
        _apply_zone_effects(new_zone)

func _apply_zone_effects(zone: Zone) -> void:
    """Apply zone effects to game systems"""
    # Modify AI aggression based on zone type
    _modify_ai_aggression(zone)

    # Adjust spawn rates
    _modify_spawn_rates(zone.spawn_multiplier)

    # Update UI
    _update_zone_ui(zone)

func _remove_zone_effects(zone: Zone) -> void:
    """Remove zone effects from game systems"""
    # Reset AI aggression
    _reset_ai_aggression()

    # Reset spawn rates
    _modify_spawn_rates(1.0)

func _modify_ai_aggression(zone: Zone) -> void:
    """Modify NPC aggression based on zone type"""
    var npcs = get_tree().get_nodes_in_group("npc")
    var aggression_multiplier := 1.0

    match zone.zone_type:
        Zone.ZoneType.SAFE:
            aggression_multiplier = 0.3  # NPCs less aggressive in safe zones
        Zone.ZoneType.HOSTILE:
            aggression_multiplier = zone.spawn_multiplier  # More aggressive in hostile zones
        Zone.ZoneType.NEUTRAL:
            aggression_multiplier = 1.0

    for npc in npcs:
        if npc.has_method("set_aggression_multiplier"):
            npc.set_aggression_multiplier(aggression_multiplier)

func _reset_ai_aggression() -> void:
    """Reset AI aggression to default values"""
    var npcs = get_tree().get_nodes_in_group("npc")
    for npc in npcs:
        if npc.has_method("set_aggression_multiplier"):
            npc.set_aggression_multiplier(1.0)

func _modify_spawn_rates(multiplier: float) -> void:
    """Modify spawn rates across all spawners"""
    var spawners = get_tree().get_nodes_in_group("wave_spawners")
    for spawner in spawners:
        if spawner.has_method("set_zone_multiplier"):
            spawner.set_zone_multiplier(multiplier)

func _update_zone_ui(zone: Zone) -> void:
    """Update UI to reflect current zone"""
    var hud = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("update_zone_display"):
        hud.update_zone_display(zone.zone_name, zone.zone_type)

func _on_spawn_rate_changed(spawner: Node, new_rate: float) -> void:
    """Handle spawn rate changes from spawners"""
    # Could trigger zone danger level updates
    if current_player_zone:
        var danger_level = _calculate_zone_danger_level(current_player_zone)
        zone_danger_level_changed.emit(current_player_zone, danger_level)

func _calculate_zone_danger_level(zone: Zone) -> float:
    """Calculate current danger level of a zone"""
    var base_danger = zone.get_danger_level()
    var npc_count = get_tree().get_nodes_in_group("npc").size()
    var npc_factor = min(npc_count / 10.0, 2.0)  # Cap at 2x danger

    return base_danger * npc_factor

func get_current_zone() -> Zone:
    """Get the zone the player is currently in"""
    return current_player_zone

func get_zone_by_name(zone_name: String) -> Zone:
    """Get a zone by its name"""
    return zone_registry.get(zone_name, null)

func get_all_zones() -> Array[Zone]:
    """Get all registered zones"""
    var zones: Array[Zone] = []
    for zone in zone_registry.values():
        zones.append(zone)
    return zones

func get_zones_by_type(zone_type: Zone.ZoneType) -> Array[Zone]:
    """Get all zones of a specific type"""
    var filtered_zones: Array[Zone] = []
    for zone in zone_registry.values():
        if zone.zone_type == zone_type:
            filtered_zones.append(zone)
    return filtered_zones

func is_player_in_safe_zone() -> bool:
    """Check if player is currently in a safe zone"""
    return current_player_zone != null and current_player_zone.is_safe_zone()

func is_player_in_hostile_zone() -> bool:
    """Check if player is currently in a hostile zone"""
    return current_player_zone != null and current_player_zone.is_hostile_zone()

func get_zone_stats() -> Dictionary:
    """Get comprehensive zone statistics"""
    var stats := {
        "total_zones": zone_registry.size(),
        "safe_zones": get_zones_by_type(Zone.ZoneType.SAFE).size(),
        "hostile_zones": get_zones_by_type(Zone.ZoneType.HOSTILE).size(),
        "neutral_zones": get_zones_by_type(Zone.ZoneType.NEUTRAL).size(),
        "current_zone": current_player_zone != null ? current_player_zone.zone_name : "None",
        "current_danger_level": current_player_zone != null ? _calculate_zone_danger_level(current_player_zone) : 0.0
    }
    return stats
