extends CharacterBody3D

@export var speed: float = 3.0
@export var attack_range: float = 1.4
@export var attack_damage: float = 10.0
@export var vision: Vision

var target: Node3D = null
var health: float = 50.0
var fsm: FSM

# Zone-aware behavior
var base_speed: float = 3.0
var base_attack_damage: float = 10.0
var base_health: float = 50.0
var aggression_multiplier: float = 1.0
var zone_noise_penalty: float = 1.0
var current_zone: Zone = null

# Enhanced AI Behaviors (Phase 4 Academic Compliance)
var behavior_state: String = "normal"  # normal, alerted, hunting, patrolling
var alert_level: float = 0.0  # 0.0 to 1.0, affects behavior intensity
var patrol_points: Array = []
var current_patrol_target: int = 0
var last_known_player_position: Vector3 = Vector3.ZERO
var investigation_time: float = 0.0
var group_leader: Node3D = null
var pack_members: Array = []
var formation_offset: Vector3 = Vector3.ZERO

# Difficulty scaling variables (integrated with DifficultyManager)
var difficulty_modifiers := {
    "health_multiplier": 1.0,
    "damage_multiplier": 1.0,
    "speed_multiplier": 1.0,
    "aggression_multiplier": 1.0,
    "detection_multiplier": 1.0
}

# Advanced behavior timers
var behavior_update_timer: float = 0.0
var group_coordination_timer: float = 0.0
var sound_investigation_timer: float = 0.0
var flanking_attempt_timer: float = 0.0

func _ready() -> void:
    # Store base values for zone modifications and difficulty scaling
    base_speed = speed
    base_attack_damage = attack_damage
    base_health = health

    # Add to groups for various systems
    add_to_group("npc")
    add_to_group("enemies")
    add_to_group("zombie_basic")

    # Initialize enhanced AI components
    _initialize_enhanced_ai()
    _setup_patrol_points()
    _register_with_pack_system()

    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)
    fsm = FSM.new()
    add_child(fsm)
    fsm.add_state("Idle", Callable(self, "_enter_idle"), Callable(self, "_update_idle"))
    fsm.add_state("Chase", Callable(self, "_enter_chase"), Callable(self, "_update_chase"))
    fsm.add_state("Attack", Callable(self, "_enter_attack"), Callable(self, "_update_attack"))
    fsm.set_state("Idle")

func _physics_process(delta: float) -> void:
    if target == null:
        target = get_tree().get_first_node_in_group("player")

    # Update enhanced AI systems
    _update_enhanced_behaviors(delta)
    _update_group_coordination(delta)
    _update_alert_system(delta)

    fsm.update(delta)
    move_and_slide()

    # Performance optimization: limit updates to reduce CPU usage
    behavior_update_timer += delta
    if behavior_update_timer >= 0.1:  # Update every 100ms
        _optimize_behavior_processing()
        behavior_update_timer = 0.0

func _enter_idle() -> void:
    velocity = Vector3.ZERO

func _update_idle(_dt: float) -> void:
    if target and vision.sees(target):
        fsm.set_state("Chase")

func _enter_chase() -> void:
    pass

func _update_chase(_dt: float) -> void:
    if not target:
        fsm.set_state("Idle")
        return
    var to := (target.global_transform.origin - global_transform.origin)
    var dist := to.length()
    if dist <= attack_range:
        fsm.set_state("Attack")
        return
    to.y = 0
    var dir := to.normalized()
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed

func _enter_attack() -> void:
    velocity = Vector3.ZERO

func _update_attack(_dt: float) -> void:
    if not target:
        fsm.set_state("Idle")
        return
    var to := (target.global_transform.origin - global_transform.origin)
    if to.length() > attack_range * 1.2:
        fsm.set_state("Chase")
        return
    if target and target.has_method("apply_damage"):
        target.apply_damage(attack_damage, "torso")

func apply_damage(amount: float, bodypart: String = "torso") -> void:
    # Apply difficulty-modified damage resistance
    var final_damage = amount

    # Headshot modifier
    if bodypart == "head":
        final_damage *= 1.5

    health = max(0.0, health - final_damage)

    # Enhanced AI response to damage
    _on_damage_received(amount, bodypart)

    # Alert nearby zombies
    _alert_nearby_zombies("damage_received", global_position)

    # Death handling with cleanup and rewards
    if health == 0.0:
        _on_death()

        # Notify player for XP reward
        if target and target.has_method("on_enemy_killed"):
            target.on_enemy_killed("Zombie_Basic")

        queue_free()

# Zone-aware behavior methods
func set_aggression_multiplier(multiplier: float) -> void:
    """Set aggression multiplier from zone system"""
    aggression_multiplier = multiplier
    _update_stats_from_zone()

func apply_zone_behavior(zone_data: Dictionary) -> void:
    """Apply zone-specific behavior modifications"""
    zone_noise_penalty = zone_data.get("noise_penalty", 1.0)

    # Modify detection based on zone
    if vision and vision.has_method("set_detection_multiplier"):
        var detection_multiplier := 1.0
        match zone_data.get("zone_type", 0):
            0:  # SAFE
                detection_multiplier = 0.5  # Reduced detection in safe zones
            1:  # HOSTILE
                detection_multiplier = 1.5  # Enhanced detection in hostile zones
            2:  # NEUTRAL
                detection_multiplier = 1.0

        vision.set_detection_multiplier(detection_multiplier)

func enter_zone(zone: Zone) -> void:
    """Called when entering a zone"""
    current_zone = zone
    print("🧟 %s entered %s zone" % [name, zone.zone_name])

func exit_zone(zone: Zone) -> void:
    """Called when exiting a zone"""
    if current_zone == zone:
        current_zone = null
        print("🧟 %s exited %s zone" % [name, zone.zone_name])

func _update_stats_from_zone() -> void:
    """Update speed and damage based on zone effects and difficulty"""
    var final_speed_multiplier = aggression_multiplier * difficulty_modifiers.get("speed_multiplier", 1.0)
    var final_damage_multiplier = aggression_multiplier * difficulty_modifiers.get("damage_multiplier", 1.0)

    speed = base_speed * final_speed_multiplier
    attack_damage = base_attack_damage * final_damage_multiplier

    # Update vision range based on difficulty
    if vision and vision.has_method("set_detection_multiplier"):
        var detection_multiplier = difficulty_modifiers.get("detection_multiplier", 1.0)
        vision.set_detection_multiplier(detection_multiplier)

func set_zone_effects(effects: Dictionary) -> void:
    """Set zone effects from Zone system"""
    var zone_type = effects.get("zone_type", 2)  # Default to NEUTRAL
    var entering = effects.get("entering", true)

    if entering:
        match zone_type:
            0:  # SAFE
                # Reduce aggression in safe zones
                set_aggression_multiplier(0.3)
            1:  # HOSTILE
                # Increase aggression in hostile zones
                var multiplier = effects.get("spawn_multiplier", 1.5)
                set_aggression_multiplier(multiplier)
            2:  # NEUTRAL
                set_aggression_multiplier(1.0)
    else:
        # Reset when leaving zone
        set_aggression_multiplier(1.0)

func get_current_zone() -> Zone:
    """Get the zone this NPC is currently in"""
    return current_zone

# Enhanced AI Behavior System (Phase 4 Academic Compliance)
func _initialize_enhanced_ai() -> void:
    """Initialize advanced AI components and behaviors"""
    # Set random formation offset for pack behavior
    formation_offset = Vector3(
        randf_range(-2.0, 2.0),
        0.0,
        randf_range(-2.0, 2.0)
    )

    # Initialize behavior state
    behavior_state = "patrolling"
    alert_level = 0.0

func _setup_patrol_points() -> void:
    """Set up patrol points around spawn location"""
    var spawn_pos = global_position
    var patrol_radius = 8.0

    for i in range(4):  # 4 patrol points in a square pattern
        var angle = (i * PI * 0.5) + randf_range(-0.3, 0.3)  # Add randomness
        var patrol_point = spawn_pos + Vector3(
            cos(angle) * patrol_radius,
            0.0,
            sin(angle) * patrol_radius
        )
        patrol_points.append(patrol_point)

func _register_with_pack_system() -> void:
    """Register with nearby zombies for pack behavior"""
    var nearby_zombies = get_tree().get_nodes_in_group("zombie_basic")

    for zombie in nearby_zombies:
        if zombie != self and zombie.global_position.distance_to(global_position) < 15.0:
            if pack_members.size() < 3:  # Maximum pack size of 4 (including self)
                pack_members.append(zombie)
                if zombie.has_method("join_pack"):
                    zombie.join_pack(self)

func join_pack(leader: Node3D) -> void:
    """Join a pack with the specified leader"""
    if pack_members.size() < 3:  # Only join if not already in a large pack
        group_leader = leader
        add_to_group("pack_member")

func _update_enhanced_behaviors(delta: float) -> void:
    """Update advanced AI behaviors based on current state"""
    match behavior_state:
        "patrolling":
            _update_patrol_behavior(delta)
        "investigating":
            _update_investigation_behavior(delta)
        "hunting":
            _update_hunting_behavior(delta)
        "flanking":
            _update_flanking_behavior(delta)
        "coordinated_attack":
            _update_coordinated_attack(delta)

func _update_patrol_behavior(delta: float) -> void:
    """Update patrol behavior when not alerted"""
    if not target or not vision.sees(target):
        if patrol_points.size() > 0:
            var target_point = patrol_points[current_patrol_target]
            var distance = global_position.distance_to(target_point)

            if distance < 2.0:  # Reached patrol point
                current_patrol_target = (current_patrol_target + 1) % patrol_points.size()
            else:
                # Move toward patrol point
                var direction = (target_point - global_position).normalized()
                direction.y = 0
                velocity = direction * (speed * 0.5)  # Patrol at half speed

func _update_investigation_behavior(delta: float) -> void:
    """Investigate last known player position or sounds"""
    investigation_time += delta

    if investigation_time > 10.0:  # Stop investigating after 10 seconds
        behavior_state = "patrolling"
        investigation_time = 0.0
        return

    # Move to last known position
    if last_known_player_position != Vector3.ZERO:
        var direction = (last_known_player_position - global_position).normalized()
        direction.y = 0
        velocity = direction * speed * 0.8  # Investigate at 80% speed

        # Check if reached investigation point
        if global_position.distance_to(last_known_player_position) < 3.0:
            behavior_state = "patrolling"
            investigation_time = 0.0

func _update_hunting_behavior(delta: float) -> void:
    """Enhanced hunting behavior with predictive movement"""
    if not target:
        behavior_state = "investigating"
        return

    if vision.sees(target):
        # Predictive targeting - aim ahead of moving targets
        var target_velocity = Vector3.ZERO
        if target.has_property("velocity"):
            target_velocity = target.velocity

        var prediction_time = global_position.distance_to(target.global_position) / speed
        var predicted_position = target.global_position + (target_velocity * prediction_time)

        var direction = (predicted_position - global_position).normalized()
        direction.y = 0

        # Consider flanking if player is stationary for too long
        flanking_attempt_timer += delta
        if flanking_attempt_timer > 3.0 and target_velocity.length() < 1.0:
            behavior_state = "flanking"
            flanking_attempt_timer = 0.0

        velocity = direction * speed
    else:
        last_known_player_position = target.global_position
        behavior_state = "investigating"

func _update_flanking_behavior(delta: float) -> void:
    """Attempt to flank the player by moving around obstacles"""
    if not target:
        behavior_state = "patrolling"
        return

    flanking_attempt_timer += delta
    if flanking_attempt_timer > 5.0:  # Stop flanking after 5 seconds
        behavior_state = "hunting"
        flanking_attempt_timer = 0.0
        return

    # Calculate flanking position (90 degrees from direct approach)
    var to_target = target.global_position - global_position
    var flank_direction = Vector3(-to_target.z, 0, to_target.x).normalized()
    var flank_position = target.global_position + flank_direction * 5.0

    var direction = (flank_position - global_position).normalized()
    direction.y = 0
    velocity = direction * speed

func _update_coordinated_attack(delta: float) -> void:
    """Coordinate attack with pack members"""
    if not target or pack_members.is_empty():
        behavior_state = "hunting"
        return

    # Move to formation position relative to pack leader
    if group_leader and group_leader != self:
        var formation_position = group_leader.global_position + formation_offset
        var direction = (formation_position - global_position).normalized()
        direction.y = 0
        velocity = direction * speed
    else:
        # Act as pack leader
        _update_hunting_behavior(delta)

func _update_group_coordination(delta: float) -> void:
    """Update group coordination and communication"""
    group_coordination_timer += delta

    if group_coordination_timer >= 0.5:  # Update every 500ms
        _sync_with_pack_members()
        _coordinate_pack_tactics()
        group_coordination_timer = 0.0

func _sync_with_pack_members() -> void:
    """Synchronize information with pack members"""
    for member in pack_members:
        if not is_instance_valid(member):
            pack_members.erase(member)
            continue

        # Share target information
        if target and member.has_method("receive_target_info"):
            member.receive_target_info(target, last_known_player_position)

        # Share alert level
        if member.has_method("sync_alert_level"):
            member.sync_alert_level(alert_level)

func _coordinate_pack_tactics() -> void:
    """Coordinate tactical decisions with pack"""
    if pack_members.size() >= 2 and target:
        # Switch to coordinated attack if enough pack members
        if behavior_state in ["hunting", "patrolling"]:
            behavior_state = "coordinated_attack"

            # Assign roles to pack members
            for i in range(pack_members.size()):
                var member = pack_members[i]
                if member.has_method("assign_pack_role"):
                    var roles = ["flanker_left", "flanker_right", "direct_assault"]
                    member.assign_pack_role(roles[i % roles.size()])

func receive_target_info(shared_target: Node3D, shared_position: Vector3) -> void:
    """Receive target information from pack members"""
    if not target and shared_target:
        target = shared_target
        last_known_player_position = shared_position
        behavior_state = "investigating"

func sync_alert_level(shared_alert: float) -> void:
    """Synchronize alert level with pack members"""
    alert_level = max(alert_level, shared_alert)

func assign_pack_role(role: String) -> void:
    """Assign specific role in pack tactics"""
    match role:
        "flanker_left":
            formation_offset = Vector3(-3.0, 0.0, -1.0)
        "flanker_right":
            formation_offset = Vector3(3.0, 0.0, -1.0)
        "direct_assault":
            formation_offset = Vector3(0.0, 0.0, 1.0)

func _update_alert_system(delta: float) -> void:
    """Update alert level and behavioral responses"""
    if target and vision.sees(target):
        alert_level = min(1.0, alert_level + delta * 2.0)  # Increase alert quickly
        behavior_state = "hunting"
    else:
        alert_level = max(0.0, alert_level - delta * 0.5)  # Decrease alert slowly

        if alert_level < 0.1 and behavior_state == "hunting":
            behavior_state = "investigating"

func _alert_nearby_zombies(alert_type: String, alert_position: Vector3) -> void:
    """Alert nearby zombies to events"""
    var nearby_zombies = get_tree().get_nodes_in_group("enemies")

    for zombie in nearby_zombies:
        if zombie != self and zombie.global_position.distance_to(alert_position) < 20.0:
            if zombie.has_method("receive_alert"):
                zombie.receive_alert(alert_type, alert_position, alert_level)

func receive_alert(alert_type: String, alert_position: Vector3, source_alert_level: float) -> void:
    """Receive alert from another zombie"""
    alert_level = max(alert_level, source_alert_level * 0.7)  # Reduce intensity

    match alert_type:
        "damage_received":
            last_known_player_position = alert_position
            behavior_state = "investigating"
        "player_spotted":
            last_known_player_position = alert_position
            behavior_state = "hunting"
        "noise_heard":
            last_known_player_position = alert_position
            behavior_state = "investigating"

func _on_damage_received(amount: float, bodypart: String) -> void:
    """Enhanced response to receiving damage"""
    # Increase alert level significantly
    alert_level = min(1.0, alert_level + 0.5)

    # Switch to hunting behavior
    behavior_state = "hunting"

    # Remember approximate player position
    if target:
        last_known_player_position = target.global_position

    # Call for help from pack members
    _call_for_help()

func _call_for_help() -> void:
    """Call for help from nearby zombies"""
    _alert_nearby_zombies("damage_received", global_position)

    # Increase urgency for pack members
    for member in pack_members:
        if is_instance_valid(member) and member.has_method("respond_to_help_call"):
            member.respond_to_help_call(self)

func respond_to_help_call(caller: Node3D) -> void:
    """Respond to help call from pack member"""
    if caller in pack_members or caller == group_leader:
        alert_level = min(1.0, alert_level + 0.3)
        behavior_state = "coordinated_attack"

        if caller.target:
            target = caller.target
            last_known_player_position = caller.last_known_player_position

func _on_death() -> void:
    """Handle death with pack coordination"""
    # Alert pack members of death
    for member in pack_members:
        if is_instance_valid(member) and member.has_method("on_pack_member_death"):
            member.on_pack_member_death(self)

    # Notify pack leader
    if group_leader and is_instance_valid(group_leader) and group_leader.has_method("on_pack_member_death"):
        group_leader.on_pack_member_death(self)

func on_pack_member_death(dead_member: Node3D) -> void:
    """Handle pack member death"""
    pack_members.erase(dead_member)

    # Increase alert and aggression
    alert_level = min(1.0, alert_level + 0.4)
    aggression_multiplier = min(2.0, aggression_multiplier + 0.3)
    _update_stats_from_zone()

func _optimize_behavior_processing() -> void:
    """Optimize AI processing to maintain performance"""
    # Skip complex behaviors if too far from player
    if target and global_position.distance_to(target.global_position) > 50.0:
        behavior_state = "patrolling"
        alert_level = max(0.0, alert_level - 0.1)

    # Clean up invalid pack members
    for i in range(pack_members.size() - 1, -1, -1):
        if not is_instance_valid(pack_members[i]):
            pack_members.remove_at(i)

# Difficulty Scaling Integration (Phase 4 Academic Compliance)
func _apply_difficulty_scaling(modifiers: Dictionary) -> void:
    """Apply difficulty scaling to enemy stats and behavior"""
    for modifier_name in modifiers:
        if modifier_name in difficulty_modifiers:
            difficulty_modifiers[modifier_name] = modifiers[modifier_name]

    # Apply health scaling
    if "health_multiplier" in modifiers:
    var health_ratio = base_health > 0.0 ? health / base_health : 1.0
        health = base_health * modifiers["health_multiplier"]
        health *= health_ratio  # Maintain current health percentage

    # Update other stats
    _update_stats_from_zone()

    print("🧟 Zombie_Basic difficulty scaling applied: %s" % str(modifiers))

# Public API for external systems
func get_ai_debug_info() -> Dictionary:
    """Get current AI state for debugging"""
    return {
        "behavior_state": behavior_state,
        "alert_level": alert_level,
        "pack_size": pack_members.size(),
        "has_target": target != null,
        "health_percentage": (health / base_health) * 100.0,
        "current_zone": current_zone != null ? current_zone.zone_name : "none",
        "difficulty_modifiers": difficulty_modifiers
    }
