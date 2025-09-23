extends CharacterBody3D

@export var movement_controller_path: NodePath
@export var rig_scene: PackedScene
@export var weapon_damage: float = 20.0

var rig: Node = null
var ballistics: Ballistics
var health: float = 100.0
var movement_controller: Node = null
var slow_factor: float = 1.0
var dot_remaining: float = 0.0
var dot_rate: float = 0.0
var dot_timer: float = 0.0

# XP and Level System (§6.1.1, §6.1.2 Academic Compliance)
var level: int = 1
var xp: int = 0
var available_stat_points: int = 0

# Character Attributes (affect gameplay performance)
var strength: int = 1        # Carry capacity, melee damage, heavy weapon handling
var dexterity: int = 1       # Reload speed, item swap speed, looting speed
var agility: int = 1         # Movement speed, dodge window, acceleration
var endurance: int = 1       # Stamina, fatigue resistance, health recovery
var accuracy: int = 1        # Weapon sway, recoil recovery, aim spread

# Weapon Proficiencies (0-100 scale, XP-based progression)
var melee_knives: int = 0
var melee_axes_clubs: int = 0
var firearm_handguns: int = 0
var firearm_rifles: int = 0
var firearm_shotguns: int = 0
var firearm_automatics: int = 0

# Survivability Stats (decay over time, affect performance)
var nourishment_level: float = 100.0  # Affects health regen, stamina, accuracy
var sleep_level: float = 100.0        # Affects reaction time, weapon sway, perception
var last_rest_time: float = 0.0
var last_nourishment_time: float = 0.0

# Performance multipliers (calculated from stats)
var carry_capacity_multiplier: float = 1.0
var reload_speed_multiplier: float = 1.0
var movement_speed_multiplier: float = 1.0
var weapon_sway_multiplier: float = 1.0
var health_regen_rate: float = 0.0

func _ready() -> void:
    # Spawn rig
    if rig_scene:
        rig = rig_scene.instantiate()
        add_child(rig)
    ballistics = Ballistics.new()
    add_child(ballistics)
    # Listen for perspective changes
    if has_node("/root/Game"):
        var g = get_node("/root/Game")
        g.connect("perspective_changed", Callable(self, "_on_perspective_changed"))
    # Resolve controller
    if movement_controller_path != NodePath(""):
        var node = get_node(movement_controller_path)
        if node:
            movement_controller = node

    # Initialize survivability timers
    last_rest_time = Time.get_unix_time_from_system()
    last_nourishment_time = Time.get_unix_time_from_system()

    # Calculate initial performance multipliers
    _update_performance_multipliers()

func _physics_process(delta: float) -> void:
    if movement_controller and movement_controller.has_method("move"):
        movement_controller.owner_body = self
        var original_speed = movement_controller.get("speed")
        var has_speed_property := original_speed != null
        if has_speed_property:
            var final_multiplier = slow_factor * movement_speed_multiplier
            movement_controller.set("speed", float(original_speed) * final_multiplier)
        movement_controller.move({}, delta)
        if has_speed_property:
            movement_controller.set("speed", original_speed)
    if Input.is_action_just_pressed("fire"):
        _enhanced_attack_input()
    _update_dot(delta)
    _update_survivability(delta)
    _update_health_regeneration(delta)

func _fire_weapon() -> void:
    var origin := global_transform.origin + Vector3(0, 1.6, 0)
    var dir := Vector3.FORWARD
    if rig and rig.has_method("aim_vector"):
        dir = rig.aim_vector()

    # Apply stat and proficiency modifiers to weapon damage
    var modified_damage = get_modified_weapon_damage(weapon_damage, "firearm_handguns")  # Default to handgun
    var accuracy_modifier = get_modified_accuracy()

    # Enhanced firing with visual and audio feedback
    ballistics.fire(origin, dir, modified_damage, accuracy_modifier)

    # Grant weapon proficiency XP for firing
    gain_weapon_proficiency("firearm_handguns", 1)  # 1 XP per shot fired

    # Enhanced attack effects and feedback
    _trigger_attack_effects()

    # Emit game events
    if has_node("/root/Game"):
        var game = get_node("/root/Game")
        game.event_bus.emit_signal("NoiseEmitted", self, 50.0, 10.0)
        game.event_bus.emit_signal("WeaponFired", self, {
            "weapon_type": "handgun",
            "damage": modified_damage,
            "accuracy": accuracy_modifier,
            "position": origin
        })

func _trigger_attack_effects() -> void:
    """Enhanced attack effects for better player feedback"""
    # Screen shake for impact feel
    _trigger_screen_shake(5.0, 0.2)

    # Muzzle flash effect (if rig supports it)
    if rig and rig.has_method("play_muzzle_flash"):
        rig.play_muzzle_flash()

    # Camera recoil
    if rig and rig.has_method("apply_recoil"):
        var recoil_strength = 1.0 - (get_weapon_proficiency_multiplier("firearm_handguns") - 1.0) * 0.5
        rig.apply_recoil(recoil_strength)

    # Audio feedback with spatial audio
    _play_weapon_sound("handgun_fire")

    # Visual impact indicator
    _show_attack_indicator()

func _trigger_screen_shake(intensity: float, duration: float) -> void:
    """Trigger screen shake effect for attack feedback"""
    # Use global ScreenShake system
    if has_node("/root/ScreenShake"):
        var screen_shake = get_node("/root/ScreenShake")
        screen_shake.add_trauma(intensity * 0.05)  # Scale for screen shake

    # Also shake UI
    var hud = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("trigger_ui_shake"):
        hud.trigger_ui_shake(intensity, duration)

func _find_camera_in_children(node: Node) -> Camera3D:
    """Recursively find camera in node hierarchy"""
    if node is Camera3D:
        return node as Camera3D

    for child in node.get_children():
        var camera = _find_camera_in_children(child)
        if camera:
            return camera

    return null

func _play_weapon_sound(sound_name: String) -> void:
    """Play weapon sound with spatial audio"""
    if has_node("/root/Audio"):
        var audio_system = get_node("/root/Audio")
        if audio_system.has_method("play_3d_sound"):
            audio_system.play_3d_sound(sound_name, global_position)
        elif audio_system.has_method("play_sound"):
            audio_system.play_sound(sound_name)

func _show_attack_indicator() -> void:
    """Show visual attack indicator"""
    # Create crosshair feedback
    var hud = get_tree().get_first_node_in_group("hud")
    if hud and hud.has_method("show_crosshair_feedback"):
        hud.show_crosshair_feedback()

# Enhanced attack combo system
var last_attack_time: float = 0.0
var attack_combo_count: int = 0
var combo_window: float = 1.5  # Seconds for combo window

func _enhanced_attack_input() -> void:
    """Enhanced attack input handling with combo system"""
    var current_time = Time.get_time_dict_from_system()

    # Check for combo timing
    if current_time - last_attack_time <= combo_window:
        attack_combo_count += 1
    else:
        attack_combo_count = 1

    last_attack_time = current_time

    # Execute attack with combo multiplier
    var combo_multiplier = 1.0 + (attack_combo_count - 1) * 0.1  # 10% per combo
    weapon_damage *= combo_multiplier

    _fire_weapon()

    # Reset weapon damage
    weapon_damage /= combo_multiplier

    # Show combo feedback
    if attack_combo_count > 1:
        _show_combo_feedback(attack_combo_count)

func _show_combo_feedback(combo_count: int) -> void:
    """Show combo feedback to player"""
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        # Show combo text
        if hud.has_method("show_combo_text"):
            hud.show_combo_text(combo_count)

        # Extra shake for combos
        if hud.has_method("trigger_ui_shake"):
            var shake_intensity = 8.0 + (combo_count * 2.0)
            hud.trigger_ui_shake(shake_intensity, 0.4)

    # Grant extra XP for combos
    var bonus_xp = combo_count * 2
    gain_xp(bonus_xp)

    print("🔥 COMBO x%d! Bonus XP: +%d" % [combo_count, bonus_xp])

func apply_damage(amount: float, bodypart: String = "torso") -> void:
    health = max(0.0, health - amount)

    # Grant small amount of XP for surviving damage (encourages engagement)
    gain_xp(1)

    if health == 0.0:
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("PlayerDowned")

func on_enemy_killed(enemy_type: String) -> void:
    """Called when player kills an enemy - grants XP with difficulty scaling"""
    var base_xp_reward = 0
    match enemy_type:
        "Zombie_Basic":
            base_xp_reward = 10
        "Zombie_Ranger":
            base_xp_reward = 15
        "Zombie_Alarm":
            base_xp_reward = 12
        "Zombie_Heavy":
            base_xp_reward = 20
        "Zombie_Big":
            base_xp_reward = 25
        _:
            base_xp_reward = 8  # Default XP for unknown enemy types

    gain_xp_with_difficulty(base_xp_reward)
    print("💀 Enemy killed! +%d XP" % base_xp_reward)

func get_health() -> float:
    return health

func apply_biominetrap(slow_amount: float, dot: float, duration: float) -> void:
    slow_factor = max(0.3, 1.0 - slow_amount)
    dot_remaining = duration
    dot_rate = dot
    dot_timer = 0.0

func _update_dot(delta: float) -> void:
    if dot_remaining > 0.0:
        dot_timer += delta
        if dot_timer >= 1.0:
            dot_timer = 0.0
            apply_damage(dot_rate, "torso")
            dot_remaining = max(0.0, dot_remaining - 1.0)
    else:
        slow_factor = 1.0

# XP and Level System Implementation
func gain_xp(amount: int) -> void:
    """Gain XP and check for level up"""
    xp += amount
    _check_level_up()

func _check_level_up() -> void:
    """Check if player should level up and grant stat points"""
    var xp_needed = _calculate_xp_for_level(level + 1)
    if xp >= xp_needed:
        level += 1
        available_stat_points += 2  # 2 stat points per level
        print("🎉 Level up! Now level %d. Available stat points: %d" % [level, available_stat_points])

        # Notify UI system of level up
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("PlayerLeveledUp", level, available_stat_points)

func _calculate_xp_for_level(target_level: int) -> int:
    """Calculate XP needed for a specific level (exponential curve)"""
    return int(100 * pow(target_level - 1, 1.5))

func allocate_stat_point(stat_name: String) -> bool:
    """Allocate an available stat point to a specific attribute"""
    if available_stat_points <= 0:
        return false

    match stat_name:
        "strength":
            if strength < 10:  # Cap at 10
                strength += 1
                available_stat_points -= 1
                _update_performance_multipliers()
                return true
        "dexterity":
            if dexterity < 10:
                dexterity += 1
                available_stat_points -= 1
                _update_performance_multipliers()
                return true
        "agility":
            if agility < 10:
                agility += 1
                available_stat_points -= 1
                _update_performance_multipliers()
                return true
        "endurance":
            if endurance < 10:
                endurance += 1
                available_stat_points -= 1
                _update_performance_multipliers()
                return true
        "accuracy":
            if accuracy < 10:
                accuracy += 1
                available_stat_points -= 1
                _update_performance_multipliers()
                return true

    return false

# Weapon Proficiency System
func gain_weapon_proficiency(weapon_type: String, xp_amount: int) -> void:
    """Gain proficiency XP for a specific weapon type"""
    match weapon_type:
        "melee_knives":
            melee_knives = min(100, melee_knives + xp_amount)
        "melee_axes_clubs":
            melee_axes_clubs = min(100, melee_axes_clubs + xp_amount)
        "firearm_handguns":
            firearm_handguns = min(100, firearm_handguns + xp_amount)
        "firearm_rifles":
            firearm_rifles = min(100, firearm_rifles + xp_amount)
        "firearm_shotguns":
            firearm_shotguns = min(100, firearm_shotguns + xp_amount)
        "firearm_automatics":
            firearm_automatics = min(100, firearm_automatics + xp_amount)

func get_weapon_proficiency_multiplier(weapon_type: String) -> float:
    """Get performance multiplier based on weapon proficiency (reduces penalties)"""
    var proficiency = 0
    match weapon_type:
        "melee_knives":
            proficiency = melee_knives
        "melee_axes_clubs":
            proficiency = melee_axes_clubs
        "firearm_handguns":
            proficiency = firearm_handguns
        "firearm_rifles":
            proficiency = firearm_rifles
        "firearm_shotguns":
            proficiency = firearm_shotguns
        "firearm_automatics":
            proficiency = firearm_automatics

    # Each 10 levels reduces weapon-specific penalties by 5%
    return 1.0 + (proficiency / 10.0) * 0.05

# Survivability Stats System
func _update_survivability(delta: float) -> void:
    """Update nourishment and sleep levels with decay over time (affected by difficulty)"""
    var current_time = Time.get_unix_time_from_system()

    # Apply difficulty modifiers to decay rates
    var hunger_multiplier = difficulty_modifiers.get("hunger_drain_multiplier", 1.0)
    var fatigue_multiplier = difficulty_modifiers.get("fatigue_drain_multiplier", 1.0)

    # Nourishment decays 1 point per hour of gameplay (base rate)
    var nourishment_decay = ((current_time - last_nourishment_time) / 3600.0) * hunger_multiplier
    if nourishment_decay > 0.1:  # Update every 6 minutes real time
        nourishment_level = max(0.0, nourishment_level - nourishment_decay)
        last_nourishment_time = current_time

    # Sleep decays 2 points per hour of gameplay (base rate)
    var sleep_decay = ((current_time - last_rest_time) / 1800.0) * fatigue_multiplier  # 2 per hour
    if sleep_decay > 0.1:
        sleep_level = max(0.0, sleep_level - sleep_decay)
        last_rest_time = current_time

    # Update performance multipliers when survivability changes significantly
    if nourishment_decay > 0.1 or sleep_decay > 0.1:
        _update_performance_multipliers()

func consume_food(nourishment_value: float) -> void:
    """Restore nourishment level through food consumption"""
    nourishment_level = min(100.0, nourishment_level + nourishment_value)
    _update_performance_multipliers()

func rest_in_safe_zone(duration: float) -> void:
    """Restore sleep level through resting in safe zones"""
    var sleep_restored = duration * 0.5  # 30 minutes rest = 15 sleep points
    sleep_level = min(100.0, sleep_level + sleep_restored)
    _update_performance_multipliers()

# Performance Multiplier Calculation
func _update_performance_multipliers() -> void:
    """Calculate performance multipliers based on stats and survivability"""

    # Carry capacity (strength-based)
    carry_capacity_multiplier = 1.0 + (strength - 1) * 0.2

    # Reload speed (dexterity-based)
    reload_speed_multiplier = 1.0 + (dexterity - 1) * 0.15

    # Movement speed (agility-based)
    movement_speed_multiplier = 1.0 + (agility - 1) * 0.1

    # Weapon sway (accuracy-based, plus survivability penalties)
    var base_sway_reduction = (accuracy - 1) * 0.1
    var sleep_penalty = 0.0
    if sleep_level < 25.0:
        sleep_penalty = 0.2  # 20% more weapon sway when very tired
    weapon_sway_multiplier = max(0.5, 1.0 - base_sway_reduction + sleep_penalty)

    # Health regeneration (endurance + nourishment)
    var base_regen = (endurance - 1) * 0.1
    var nourishment_bonus = 0.0
    if nourishment_level > 75.0:
        nourishment_bonus = 0.15
    elif nourishment_level < 25.0:
        base_regen *= 0.5  # Half regen when malnourished
    health_regen_rate = base_regen + nourishment_bonus

func _update_health_regeneration(delta: float) -> void:
    """Apply health regeneration based on endurance and nourishment (affected by difficulty)"""
    if health < 100.0 and health_regen_rate > 0.0:
        var healing_multiplier = difficulty_modifiers.get("healing_effectiveness_multiplier", 1.0)
        var regen_amount = health_regen_rate * delta * healing_multiplier
        health = min(100.0, health + regen_amount)

# Gameplay Integration Methods
func get_modified_weapon_damage(base_damage: float, weapon_type: String) -> float:
    """Calculate final weapon damage with stat and proficiency modifiers"""
    var damage = base_damage

    # Strength bonus for melee weapons
    if weapon_type.begins_with("melee"):
        damage *= 1.0 + (strength - 1) * 0.15

    # Proficiency bonus
    damage *= get_weapon_proficiency_multiplier(weapon_type)

    # Nourishment penalty
    if nourishment_level < 25.0:
        damage *= 0.85  # 15% damage penalty when malnourished

    return damage

func get_modified_accuracy() -> float:
    """Get current accuracy modifier for weapon firing"""
    var base_accuracy = 1.0 + (accuracy - 1) * 0.1

    # Sleep penalty
    if sleep_level < 25.0:
        base_accuracy *= 0.85  # 15% accuracy penalty when exhausted

    # Nourishment penalty
    if nourishment_level < 25.0:
        base_accuracy *= 0.85  # 15% accuracy penalty when malnourished

    return base_accuracy

# Character Information Methods
func get_character_stats() -> Dictionary:
    """Get all character stats for UI display"""
    return {
        "level": level,
        "xp": xp,
        "xp_for_next_level": _calculate_xp_for_level(level + 1),
        "available_stat_points": available_stat_points,
        "strength": strength,
        "dexterity": dexterity,
        "agility": agility,
        "endurance": endurance,
        "accuracy": accuracy,
        "nourishment_level": nourishment_level,
        "sleep_level": sleep_level,
        "weapon_proficiencies": {
            "melee_knives": melee_knives,
            "melee_axes_clubs": melee_axes_clubs,
            "firearm_handguns": firearm_handguns,
            "firearm_rifles": firearm_rifles,
            "firearm_shotguns": firearm_shotguns,
            "firearm_automatics": firearm_automatics
        }
    }

# Difficulty Scaling Integration (Phase 4 Academic Compliance)
var difficulty_modifiers := {
    "xp_gain_multiplier": 1.0,
    "money_gain_multiplier": 1.0,
    "hunger_drain_multiplier": 1.0,
    "fatigue_drain_multiplier": 1.0,
    "healing_effectiveness_multiplier": 1.0,
    "item_durability_loss_multiplier": 1.0
}

func _apply_difficulty_scaling(modifiers: Dictionary) -> void:
    """Apply difficulty-based modifiers to player progression systems"""
    for modifier_name in modifiers:
        if modifier_name in difficulty_modifiers:
            difficulty_modifiers[modifier_name] = modifiers[modifier_name]
            print("🎮 Player difficulty modifier applied: %s = %.2f" % [modifier_name, modifiers[modifier_name]])

func _apply_survival_difficulty_scaling(modifiers: Dictionary) -> void:
    """Apply difficulty-based modifiers to survival mechanics"""
    for modifier_name in modifiers:
        if modifier_name in difficulty_modifiers:
            difficulty_modifiers[modifier_name] = modifiers[modifier_name]
            print("💊 Survival difficulty modifier applied: %s = %.2f" % [modifier_name, modifiers[modifier_name]])

    # Immediately update performance multipliers to reflect difficulty changes
    _update_performance_multipliers()

func gain_xp_with_difficulty(base_amount: int) -> void:
    """Gain XP with difficulty scaling applied"""
    var modified_amount = int(base_amount * difficulty_modifiers.get("xp_gain_multiplier", 1.0))
    gain_xp(modified_amount)

    if modified_amount != base_amount:
        print("📈 XP gained with difficulty scaling: %d (base: %d, multiplier: %.2f)" % [
            modified_amount, base_amount, difficulty_modifiers.get("xp_gain_multiplier", 1.0)
        ])

func gain_money_with_difficulty(base_amount: int) -> void:
    """Gain money with difficulty scaling applied"""
    var modified_amount = int(base_amount * difficulty_modifiers.get("money_gain_multiplier", 1.0))
    # Apply to Save system or player money tracking
    if has_node("/root/Save"):
        var save_system = get_node("/root/Save")
        if save_system.has_method("add_money"):
            save_system.add_money(modified_amount)

    print("💰 Money gained with difficulty scaling: %d (base: %d, multiplier: %.2f)" % [
        modified_amount, base_amount, difficulty_modifiers.get("money_gain_multiplier", 1.0)
    ])

func _on_perspective_changed(mode: String) -> void:
    var map := {
        "FPS": preload("res://common/CameraRigs/FPSRig.tscn"),
        "TPS": preload("res://common/CameraRigs/TPSRig.tscn"),
        "Iso": preload("res://common/CameraRigs/IsoRig.tscn"),
        "Side": preload("res://common/CameraRigs/FPSRig.tscn") # placeholder
    }
    if rig:
        rig.queue_free()
    if map.has(mode):
        rig = map[mode].instantiate()
        add_child(rig)
