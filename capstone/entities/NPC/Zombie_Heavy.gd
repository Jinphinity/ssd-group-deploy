extends CharacterBody3D

@export var speed: float = 2.2
@export var vision: Vision
@export var damage_reduction: float = 0.5 # resistant to blades

var target: Node3D = null
var health: float = 120.0

# Enhanced Heavy AI (Phase 4 Academic Compliance)
var behavior_state: String = "advancing"  # advancing, charging, slamming, recovering, berserking
var alert_level: float = 0.0
var charge_cooldown: float = 5.0
var charge_distance: float = 15.0
var slam_damage: float = 30.0
var slam_radius: float = 4.0
var is_charging: bool = false
var charge_start_pos: Vector3
var charge_target_pos: Vector3
var berserk_threshold: float = 0.3  # Health percentage to trigger berserk
var is_berserking: bool = false
var stagger_timer: float = 0.0
var stagger_duration: float = 1.5
var behavior_update_timer: float = 0.0
var pack_members: Array = []

# Armor zones with different protection levels
var armor_zones := {
	"head": 0.2,      # 80% damage reduction on head
	"torso": 0.5,     # 50% damage reduction on torso
	"limbs": 0.3      # 70% damage reduction on limbs
}

# Difficulty scaling variables (integrated with DifficultyManager)
var difficulty_modifiers := {
	"health_multiplier": 1.0,
	"damage_multiplier": 1.0,
	"speed_multiplier": 1.0,
	"aggression_multiplier": 1.0,
	"armor_multiplier": 1.0
}

func _ready() -> void:
    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)

    # Apply difficulty scaling (integrated with DifficultyManager)
    _apply_difficulty_scaling()

    # Initialize pack behavior
    _find_pack_members()

    # Set initial charge cooldown
    charge_cooldown = randf_range(3.0, 7.0)

func _physics_process(delta: float) -> void:
    behavior_update_timer += delta

    if target == null:
        target = get_tree().get_first_node_in_group("player")

    # Update stagger
    if stagger_timer > 0.0:
        stagger_timer = max(0.0, stagger_timer - delta)
        velocity = Vector3.ZERO
        move_and_slide()
        return

    # Check for berserk mode
    var health_percentage = health / 120.0
    if health_percentage <= berserk_threshold and not is_berserking:
        behavior_state = "berserking"
        is_berserking = true

    # Enhanced behavior state machine
    match behavior_state:
        "advancing":
            _handle_advancing_state(delta)
        "charging":
            _handle_charging_state(delta)
        "slamming":
            _handle_slamming_state(delta)
        "recovering":
            _handle_recovering_state(delta)
        "berserking":
            _handle_berserking_state(delta)

    move_and_slide()

    # Periodic behavior updates
    if behavior_update_timer >= 0.2:
        _update_pack_coordination()
        behavior_update_timer = 0.0

func apply_damage(amount: float, body_part: String = "torso") -> void:
    # Apply armor zone protection
    var protection := armor_zones.get(body_part, damage_reduction)
    protection *= difficulty_modifiers.armor_multiplier

    var final := max(0.0, amount * (1.0 - protection))
    health = max(0.0, health - final)

    # Stagger from heavy damage
    if final > 15.0 and stagger_timer <= 0.0:
        stagger_timer = stagger_duration * randf_range(0.8, 1.2)
        if behavior_state == "charging":
            behavior_state = "recovering"

    # Alert nearby zombies
    alert_level = min(1.0, alert_level + 0.3)
    _alert_pack_members()

    if health == 0.0:
        queue_free()

# Enhanced Heavy AI Behavior States

func _handle_advancing_state(delta: float) -> void:
    if not target or not vision.sees(target):
        velocity = Vector3.ZERO
        return

    var distance = global_transform.origin.distance_to(target.global_transform.origin)
    var dir := (target.global_transform.origin - global_transform.origin)
    dir.y = 0

    # Check if should charge
    if distance <= charge_distance and charge_cooldown <= 0.0:
        behavior_state = "charging"
        is_charging = true
        charge_start_pos = global_transform.origin
        charge_target_pos = target.global_transform.origin
        charge_cooldown = randf_range(8.0, 12.0) * (2.0 - difficulty_modifiers.aggression_multiplier)
        return

    # Normal advance
    var move_speed = speed * difficulty_modifiers.speed_multiplier
    if is_berserking:
        move_speed *= 1.5

    velocity = dir.normalized() * move_speed
    charge_cooldown = max(0.0, charge_cooldown - delta)

func _handle_charging_state(delta: float) -> void:
    var charge_direction = (charge_target_pos - charge_start_pos).normalized()
    var charge_speed = speed * 3.0 * difficulty_modifiers.speed_multiplier

    if is_berserking:
        charge_speed *= 1.3

    velocity = charge_direction * charge_speed

    var distance_to_target = global_transform.origin.distance_to(charge_target_pos)
    if distance_to_target < 2.0:
        behavior_state = "slamming"

func _handle_slamming_state(delta: float) -> void:
    velocity = Vector3.ZERO

    # Deal slam damage to nearby entities
    var slam_damage_final = slam_damage * difficulty_modifiers.damage_multiplier
    if target and global_transform.origin.distance_to(target.global_transform.origin) <= slam_radius:
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("DamageDealt", target, slam_damage_final)

    behavior_state = "recovering"

func _handle_recovering_state(delta: float) -> void:
    velocity = Vector3.ZERO

    # Recovery time after slam
    await get_tree().create_timer(randf_range(2.0, 3.0)).timeout
    behavior_state = "advancing"
    is_charging = false

func _handle_berserking_state(delta: float) -> void:
    if not target or not vision.sees(target):
        velocity = Vector3.ZERO
        return

    var dir := (target.global_transform.origin - global_transform.origin)
    dir.y = 0

    # Faster, more aggressive movement in berserk
    var berserk_speed = speed * 2.0 * difficulty_modifiers.speed_multiplier
    velocity = dir.normalized() * berserk_speed

    # Attempt charge more frequently
    if charge_cooldown <= 0.0:
        var distance = global_transform.origin.distance_to(target.global_transform.origin)
        if distance <= charge_distance * 1.5:
            behavior_state = "charging"
            is_charging = true
            charge_start_pos = global_transform.origin
            charge_target_pos = target.global_transform.origin
            charge_cooldown = randf_range(4.0, 6.0)

    charge_cooldown = max(0.0, charge_cooldown - delta)

# Helper Functions

func _apply_difficulty_scaling() -> void:
    if has_node("/root/DifficultyManager"):
        var diff_manager = get_node("/root/DifficultyManager")
        var preset = diff_manager.get_current_preset()

        difficulty_modifiers.health_multiplier = preset.enemy_health
        difficulty_modifiers.damage_multiplier = preset.enemy_damage
        difficulty_modifiers.speed_multiplier = preset.enemy_speed
        difficulty_modifiers.aggression_multiplier = preset.ai_aggressiveness
        difficulty_modifiers.armor_multiplier = preset.enemy_health * 0.8  # Armor scales with health

        # Apply health scaling
        health *= difficulty_modifiers.health_multiplier

func _find_pack_members() -> void:
    pack_members.clear()
    var zombies = get_tree().get_nodes_in_group("zombies")
    for zombie in zombies:
        if zombie != self and global_transform.origin.distance_to(zombie.global_transform.origin) < 20.0:
            pack_members.append(zombie)

func _update_pack_coordination() -> void:
    if pack_members.size() == 0:
        return

    # Clean up dead pack members
    pack_members = pack_members.filter(func(z): return is_instance_valid(z))

    # Coordinate with pack for flanking
    if behavior_state == "advancing" and target:
        var pack_positions = []
        for member in pack_members:
            if member.has_method("get_behavior_state") and member.get_behavior_state() == "advancing":
                pack_positions.append(member.global_transform.origin)

func _alert_pack_members() -> void:
    for member in pack_members:
        if is_instance_valid(member) and member.has_method("receive_alert"):
            member.receive_alert(global_transform.origin, alert_level)

func receive_alert(source_pos: Vector3, level: float) -> void:
    alert_level = max(alert_level, level * 0.8)
    if behavior_state == "advancing":
        # Become more aggressive when alerted
        charge_cooldown = max(0.0, charge_cooldown - 2.0)

func get_behavior_state() -> String:
    return behavior_state

