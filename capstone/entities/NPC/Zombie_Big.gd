extends CharacterBody3D

@export var speed: float = 1.8
@export var vision: Vision
@export var vulnerability: float = 1.2 # extra damage from AoE/shotgun (approx)

var target: Node3D = null
var health: float = 200.0
var max_health: float = 200.0

# Enhanced Big AI (Phase 4 Academic Compliance)
var behavior_state: String = "patrolling"  # patrolling, guarding, pursuing, stomping, regenerating
var alert_level: float = 0.0
var territorial_center: Vector3
var territorial_radius: float = 15.0
var stomp_cooldown: float = 8.0
var stomp_damage: float = 40.0
var stomp_radius: float = 6.0
var intimidation_radius: float = 12.0
var regeneration_rate: float = 2.0  # HP per second
var regeneration_cooldown: float = 0.0
var last_damage_time: float = 0.0
var behavior_update_timer: float = 0.0
var patrol_points: Array = []
var current_patrol_target: int = 0
var pack_members: Array = []
var is_blocking_path: bool = false

# Big zombie abilities
var ground_slam_charging: bool = false
var intimidation_aura_active: bool = false
var crowd_control_active: bool = false

# Difficulty scaling variables (integrated with DifficultyManager)
var difficulty_modifiers := {
	"health_multiplier": 1.0,
	"damage_multiplier": 1.0,
	"speed_multiplier": 1.0,
	"regeneration_multiplier": 1.0,
	"intimidation_multiplier": 1.0
}

func _ready() -> void:
    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)

    # Apply difficulty scaling (integrated with DifficultyManager)
    _apply_difficulty_scaling()

    # Set territorial center
    territorial_center = global_transform.origin

    # Initialize patrol points around territory
    _generate_patrol_points()

    # Find pack members
    _find_pack_members()

    # Set initial cooldowns
    stomp_cooldown = randf_range(5.0, 10.0)
    regeneration_cooldown = randf_range(8.0, 15.0)

func _physics_process(delta: float) -> void:
    behavior_update_timer += delta
    last_damage_time += delta

    if target == null:
        target = get_tree().get_first_node_in_group("player")

    # Handle regeneration
    _handle_regeneration(delta)

    # Update cooldowns
    stomp_cooldown = max(0.0, stomp_cooldown - delta)
    regeneration_cooldown = max(0.0, regeneration_cooldown - delta)

    # Handle intimidation aura
    _handle_intimidation_aura()

    # Enhanced behavior state machine
    match behavior_state:
        "patrolling":
            _handle_patrolling_state(delta)
        "guarding":
            _handle_guarding_state(delta)
        "pursuing":
            _handle_pursuing_state(delta)
        "stomping":
            _handle_stomping_state(delta)
        "regenerating":
            _handle_regenerating_state(delta)

    move_and_slide()

    # Periodic behavior updates
    if behavior_update_timer >= 0.3:
        _update_territorial_behavior()
        _update_pack_coordination()
        behavior_update_timer = 0.0

func apply_damage(amount: float, _body: String = "torso") -> void:
    var final := amount * vulnerability
    health = max(0.0, health - final)
    last_damage_time = 0.0  # Reset regeneration timer

    # Interrupt regeneration if active
    if behavior_state == "regenerating":
        behavior_state = "pursuing"

    # Territorial response - become more aggressive when damaged in territory
    var distance_from_center = global_transform.origin.distance_to(territorial_center)
    if distance_from_center <= territorial_radius:
        alert_level = min(1.0, alert_level + 0.4)
        if behavior_state == "patrolling":
            behavior_state = "guarding"

    # Alert pack members
    _alert_pack_members()

    # Consider stomp attack if enemy is close
    if target and global_transform.origin.distance_to(target.global_transform.origin) <= stomp_radius * 1.5:
        if stomp_cooldown <= 0.0 and behavior_state != "stomping":
            behavior_state = "stomping"

    if health == 0.0:
        queue_free()

# Enhanced Big AI Behavior States

func _handle_patrolling_state(delta: float) -> void:
    if target and vision.sees(target):
        var distance_to_target = global_transform.origin.distance_to(target.global_transform.origin)
        if distance_to_target <= territorial_radius:
            behavior_state = "guarding"
            return
        elif distance_to_target <= intimidation_radius:
            behavior_state = "pursuing"
            return

    # Patrol around territory
    if patrol_points.size() > 0:
        var target_point = patrol_points[current_patrol_target]
        var distance_to_patrol = global_transform.origin.distance_to(target_point)

        if distance_to_patrol < 3.0:
            current_patrol_target = (current_patrol_target + 1) % patrol_points.size()

        var dir = (target_point - global_transform.origin)
        dir.y = 0
        velocity = dir.normalized() * (speed * 0.7 * difficulty_modifiers.speed_multiplier)
    else:
        velocity = Vector3.ZERO

func _handle_guarding_state(delta: float) -> void:
    if not target or not vision.sees(target):
        behavior_state = "patrolling"
        return

    var distance_to_target = global_transform.origin.distance_to(target.global_transform.origin)
    var distance_from_center = global_transform.origin.distance_to(territorial_center)

    # Stay within territory while guarding
    if distance_from_center > territorial_radius * 1.2:
        var dir_to_center = (territorial_center - global_transform.origin)
        dir_to_center.y = 0
        velocity = dir_to_center.normalized() * speed * difficulty_modifiers.speed_multiplier
        return

    # Block player's path or position strategically
    if distance_to_target > 8.0:
        var dir = (target.global_transform.origin - global_transform.origin)
        dir.y = 0
        velocity = dir.normalized() * (speed * 0.8 * difficulty_modifiers.speed_multiplier)
    else:
        velocity = Vector3.ZERO
        is_blocking_path = true

        # Consider stomp attack
        if stomp_cooldown <= 0.0:
            behavior_state = "stomping"

func _handle_pursuing_state(delta: float) -> void:
    if not target or not vision.sees(target):
        behavior_state = "patrolling"
        return

    var distance_to_target = global_transform.origin.distance_to(target.global_transform.origin)
    var dir = (target.global_transform.origin - global_transform.origin)
    dir.y = 0

    # Pursue with full speed
    velocity = dir.normalized() * speed * difficulty_modifiers.speed_multiplier

    # Check for stomp opportunity
    if distance_to_target <= stomp_radius and stomp_cooldown <= 0.0:
        behavior_state = "stomping"

    # If player escapes territory, return to guarding
    var distance_from_center = global_transform.origin.distance_to(territorial_center)
    if distance_from_center > territorial_radius * 1.5:
        behavior_state = "guarding"

func _handle_stomping_state(delta: float) -> void:
    velocity = Vector3.ZERO
    ground_slam_charging = true

    # Charge stomp attack
    await get_tree().create_timer(1.0).timeout

    # Execute stomp
    _execute_ground_stomp()
    stomp_cooldown = randf_range(8.0, 12.0) * (2.0 - alert_level)
    ground_slam_charging = false

    # Return to appropriate behavior
    if target and vision.sees(target):
        var distance = global_transform.origin.distance_to(target.global_transform.origin)
        if distance <= territorial_radius:
            behavior_state = "guarding"
        else:
            behavior_state = "pursuing"
    else:
        behavior_state = "patrolling"

func _handle_regenerating_state(delta: float) -> void:
    velocity = Vector3.ZERO

    # Regenerate health
    var regen_amount = regeneration_rate * difficulty_modifiers.regeneration_multiplier * delta
    health = min(max_health, health + regen_amount)

    # Check if should exit regeneration
    if target and vision.sees(target):
        var distance = global_transform.origin.distance_to(target.global_transform.origin)
        if distance <= intimidation_radius:
            behavior_state = "pursuing"
    elif health >= max_health * 0.8:
        behavior_state = "patrolling"

# Ability Functions

func _handle_regeneration(delta: float) -> void:
    # Start regeneration if not damaged recently and low health
    if last_damage_time > 8.0 and health < max_health * 0.6:
        if regeneration_cooldown <= 0.0 and behavior_state != "regenerating":
            behavior_state = "regenerating"
            regeneration_cooldown = 20.0

func _handle_intimidation_aura() -> void:
    if not target:
        return

    var distance_to_target = global_transform.origin.distance_to(target.global_transform.origin)
    if distance_to_target <= intimidation_radius:
        intimidation_aura_active = true
        # Slow down nearby player (would need game event system)
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("IntimidationEffect", target, alert_level * difficulty_modifiers.intimidation_multiplier)
    else:
        intimidation_aura_active = false

func _execute_ground_stomp() -> void:
    # Deal damage to nearby entities
    var stomp_damage_final = stomp_damage * difficulty_modifiers.damage_multiplier

    if target and global_transform.origin.distance_to(target.global_transform.origin) <= stomp_radius:
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("DamageDealt", target, stomp_damage_final)
            get_node("/root/Game").event_bus.emit_signal("GroundStomp", global_transform.origin, stomp_radius)

    # Alert all nearby zombies
    var zombies = get_tree().get_nodes_in_group("zombies")
    for zombie in zombies:
        if zombie != self and global_transform.origin.distance_to(zombie.global_transform.origin) < 25.0:
            if zombie.has_method("receive_alert"):
                zombie.receive_alert(global_transform.origin, 0.8)

# Helper Functions

func _apply_difficulty_scaling() -> void:
    if has_node("/root/DifficultyManager"):
        var diff_manager = get_node("/root/DifficultyManager")
        var preset = diff_manager.get_current_preset()

        difficulty_modifiers.health_multiplier = preset.enemy_health
        difficulty_modifiers.damage_multiplier = preset.enemy_damage
        difficulty_modifiers.speed_multiplier = preset.enemy_speed
        difficulty_modifiers.regeneration_multiplier = preset.enemy_health * 0.7  # Regen scales with health
        difficulty_modifiers.intimidation_multiplier = preset.ai_aggressiveness

        # Apply health scaling
        health *= difficulty_modifiers.health_multiplier
        max_health *= difficulty_modifiers.health_multiplier

func _generate_patrol_points() -> void:
    patrol_points.clear()
    var num_points = 6
    var angle_step = 2 * PI / num_points

    for i in num_points:
        var angle = i * angle_step
        var radius = territorial_radius * 0.8
        var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
        patrol_points.append(territorial_center + offset)

func _find_pack_members() -> void:
    pack_members.clear()
    var zombies = get_tree().get_nodes_in_group("zombies")
    for zombie in zombies:
        if zombie != self and global_transform.origin.distance_to(zombie.global_transform.origin) < territorial_radius * 2:
            pack_members.append(zombie)

func _update_territorial_behavior() -> void:
    # Adjust behavior based on territorial control
    var distance_from_center = global_transform.origin.distance_to(territorial_center)
    if distance_from_center > territorial_radius * 1.5 and behavior_state == "patrolling":
        # Return to territory center
        behavior_state = "guarding"

func _update_pack_coordination() -> void:
    # Clean up dead pack members
    pack_members = pack_members.filter(func(z): return is_instance_valid(z))

    # Coordinate with pack for area denial
    if behavior_state == "guarding" and pack_members.size() > 0:
        for member in pack_members:
            if member.has_method("set_formation_position"):
                var formation_pos = _calculate_formation_position(member)
                member.set_formation_position(formation_pos)

func _calculate_formation_position(member: Node3D) -> Vector3:
    # Calculate strategic position for pack member
    var member_index = pack_members.find(member)
    var angle = (member_index * 2 * PI) / pack_members.size()
    var radius = 8.0
    var offset = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
    return territorial_center + offset

func _alert_pack_members() -> void:
    for member in pack_members:
        if is_instance_valid(member) and member.has_method("receive_alert"):
            member.receive_alert(global_transform.origin, alert_level)

func receive_alert(source_pos: Vector3, level: float) -> void:
    alert_level = max(alert_level, level * 0.9)
    if behavior_state == "patrolling":
        behavior_state = "guarding"

func get_behavior_state() -> String:
    return behavior_state

func set_formation_position(position: Vector3) -> void:
    # Called by other Big zombies for coordination
    if behavior_state == "patrolling":
        patrol_points[0] = position  # Override first patrol point

