extends CharacterBody2D

## Player Sniper Character for Sidescrolling Perspective
## Integrates with existing perspective-agnostic architecture

class_name PlayerSniper

const Ballistics = preload("res://common/Combat/Ballistics.gd")
const StatusEffectManager = preload("res://common/Combat/StatusEffectManager.gd")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var runtime_camera: Camera2D = get_node("RuntimeCamera") if has_node("RuntimeCamera") else null

@export var enable_runtime_camera: bool = false
@export_range(0.1, 3.0, 0.05) var character_scale: float = 0.35
@export_range(0.1, 3.0, 0.05) var animation_speed_scale: float = 1.0
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var auto_resize_collider: bool = true
@export var collider_size_override: Vector2 = Vector2.ZERO
@export var collider_offset: Vector2 = Vector2.ZERO
@export_range(10.0, 400.0, 5.0) var base_speed: float = 150.0
@export_range(1.0, 3.0, 0.1) var sprint_multiplier: float = 1.5
@export_range(0.1, 1.0, 0.05) var crouch_multiplier: float = 0.5
@export_range(0.0, 2.0, 0.1) var gravity_scale: float = 1.0
@export var default_magazine_size: int = 10
@export var default_reserve_ammo: int = 60
@export_range(0.5, 5.0, 0.1) var reload_duration: float = 2.0
@export var projectile_collision_layers: int = 1

# Movement and input
var speed: float = 120.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var magazine_size: int = default_magazine_size
var ammo_in_mag: int = default_magazine_size
var reserve_ammo: int = default_reserve_ammo
var _is_shooting: bool = false
var _reload_timer: float = 0.0
var _current_weapon_id: String = ""

# State management and recovery
var _animation_timeout_timer: float = 0.0
var _animation_timeout_limit: float = 5.0  # Max time for any animation
var _state_recovery_enabled: bool = true
var _input_debounce_timer: float = 0.0
var _input_debounce_duration: float = 0.1

# Animation states
enum AnimationState {
	IDLE,
	AIM_IDLE,
	WALK_FORWARD,
	WALK_BACKWARD,
	WALK_LOOP,
	SHOOT,
	RELOAD,
	TURN
}

var current_animation_state: AnimationState = AnimationState.IDLE
var is_aiming: bool = false
var is_facing_right: bool = true
var is_reloading: bool = false

# Movement intention system (Phase 1)
enum MovementMode {
	ALWAYS_FORWARD,    # Current behavior: movement direction = forward direction
	BIDIRECTIONAL      # Future: support backstrafe (face forward, move backward)
}

const MOVEMENT_THRESHOLD: float = 0.1  # Prevent input jitter affecting direction
var movement_mode: MovementMode = MovementMode.ALWAYS_FORWARD
var facing_direction: Vector2 = Vector2.RIGHT  # Absolute facing direction
var movement_intention: Vector2 = Vector2.ZERO  # Current movement intention from input

const HORIZONTAL_OFFSET_RATIO: float = 0.8
const ANIMATION_OFFSET_BASES := {
	&"idle": Vector2.ZERO,
	&"aim_idle": Vector2(126.0, 28.5),
	&"walk_forward": Vector2(68.5, 0.0),
	&"walk_backward": Vector2(44.5, 0.0),
	&"shoot": Vector2(108.0, 0.0),
	&"turn": Vector2(2.5, 0.0)
}

# Integration hooks
var _default_sprite_scale: Vector2 = Vector2.ONE
var _default_collider_size: Vector2 = Vector2.ZERO
var base_stats := {
	"strength": 1,
	"dexterity": 1,
	"agility": 1,
	"endurance": 1,
	"accuracy": 1
}
var effective_stats := {
	"strength": 1,
	"dexterity": 1,
	"agility": 1,
	"endurance": 1,
	"accuracy": 1
}
var equipment_damage_bonus: float = 0.0
var equipment_defense_bonus: float = 0.0
var equipment_speed_multiplier: float = 1.0
var equipment_damage_reduction: float = 0.0
var equipment_reload_bonus: float = 0.0
var inventory = null
var current_level: int = 1
var current_xp: int = 0
var xp_to_next: int = 100
var available_stat_points: int = 0
var nourishment_level: float = 100.0
var sleep_level: float = 100.0
var last_nourishment_time: float = 0.0
var last_sleep_time: float = 0.0
var max_health: float = 100.0
var current_health: float = 100.0

var melee_knives: int = 0
var melee_axes_clubs: int = 0
var firearm_handguns: int = 0
var firearm_rifles: int = 0
var firearm_shotguns: int = 0
var firearm_automatics: int = 0

var movement_speed_multiplier: float = 1.0
var reload_speed_multiplier: float = 1.0
var accuracy_multiplier: float = 1.0
var current_weapon_item: Dictionary = {}
var current_weapon_proficiency_key: String = "firearm_handguns"
var weapon_params: Dictionary = {}
var ballistics: Ballistics
var recoil_angle: float = 0.0
var _current_reload_duration: float = 2.0
var _current_aim_direction: Vector2 = Vector2.RIGHT
var active_status_effects: Dictionary = {}
var status_stat_bonuses: Dictionary = {}
var status_effect_callbacks: Dictionary = {}
var nourishment_decay_rate := 1.0
var sleep_decay_rate := 2.0
var last_survival_check_time: float = 0.0

signal stats_updated(stats: Dictionary)

var difficulty_modifiers := {
	"xp_gain_multiplier": 1.0,
	"money_gain_multiplier": 1.0,
	"hunger_drain_multiplier": 1.0,
	"fatigue_drain_multiplier": 1.0,
	"healing_effectiveness_multiplier": 1.0,
	"item_durability_loss_multiplier": 1.0
}

signal animation_finished(animation_name: String)
signal shot_fired()
signal reload_complete()

func _ready() -> void:
	if animated_sprite:
		_default_sprite_scale = animated_sprite.scale
	if collision_shape and collision_shape.shape is RectangleShape2D:
		_default_collider_size = (collision_shape.shape as RectangleShape2D).size
	elif collision_shape and collision_shape.shape and collision_shape.shape.has_method("get_size"):
		_default_collider_size = collision_shape.shape.get_size()
	else:
		_default_collider_size = Vector2(32, 64)

	_apply_designer_settings()
	_setup_inventory_hooks()
	_initialize_character_profile()
	var game := _get_game_singleton()
	if game and game.survivability_manager:
		game.survivability_manager.register_survivor(self)

	ballistics = Ballistics.new()
	add_child(ballistics)
	last_nourishment_time = _get_current_time()
	last_sleep_time = last_nourishment_time
	_update_performance_multipliers()
	_emit_stats()

	# Set up animation connections
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_frame_changed)

	if runtime_camera:
		runtime_camera.enabled = enable_runtime_camera
		if enable_runtime_camera:
			runtime_camera.make_current()
	
	# Add to player groups
	add_to_group("player")
	add_to_group("player_sniper")
	
	# Start with idle animation
	play_animation("idle")
func _exit_tree() -> void:
	var game := _get_game_singleton()
	if game and game.survivability_manager:
		game.survivability_manager.unregister_survivor(self)


func _physics_process(delta: float) -> void:
	# Add gravity
	if gravity_scale != 0.0 and not is_on_floor():
		velocity.y += gravity * gravity_scale * delta
	elif is_on_floor():
		velocity.y = 0.0

	# State management and recovery
	_update_state_monitoring(delta)
	_update_recoil(delta)
	_update_status_effects(delta)
	_update_survivability(delta)

	# Handle input and movement
	_handle_input()
	_handle_movement()
	_update_animation_state()

	move_and_slide()

func _handle_input() -> void:
	# Aiming with right mouse button
	if Input.is_action_pressed("aim"):
		is_aiming = true
	elif Input.is_action_just_released("aim"):
		is_aiming = false

	# Shooting with spacebar (with input debouncing)
	if Input.is_action_just_pressed("fire") and not is_reloading and _input_debounce_timer <= 0:
		_fire_shot()
		_input_debounce_timer = _input_debounce_duration

	# Reload with R key
	if Input.is_action_just_pressed("reload") and not is_reloading:
		_start_reload()

	# Interact
	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _handle_movement() -> void:
	var direction = Input.get_axis("move_left", "move_right")
	
	# Calculate current speed with modifiers
	var is_sprinting = Input.is_action_pressed("sprint")
	var is_crouching = Input.is_action_pressed("crouch")
	speed = base_speed * movement_speed_multiplier * equipment_speed_multiplier
	var current_speed = speed
	
	if is_sprinting:
		current_speed *= sprint_multiplier
	if is_crouching:
		current_speed *= crouch_multiplier
	
	# Update movement intention from input
	movement_intention = Vector2(direction, 0)

	# Update facing direction based on movement intention (input-driven)
	if abs(direction) > MOVEMENT_THRESHOLD:
		var new_facing = Vector2.RIGHT if direction > 0 else Vector2.LEFT
		if new_facing != facing_direction:
			facing_direction = new_facing
			_update_sprite_direction()

	# Apply movement
	if direction != 0:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

func _update_animation_state() -> void:
	if _is_shooting:
		return
	if is_reloading:
		return # Don't interrupt reload animation
		
	var new_state: AnimationState
	
	if is_aiming:
		new_state = AnimationState.AIM_IDLE
	elif abs(movement_intention.x) > MOVEMENT_THRESHOLD:
		# Use input-driven animation with movement mode support
		match movement_mode:
			MovementMode.ALWAYS_FORWARD:
				new_state = AnimationState.WALK_FORWARD
			MovementMode.BIDIRECTIONAL:
				# Use bidirectional infrastructure to determine animation
				new_state = _get_bidirectional_animation()
	else:
		new_state = AnimationState.IDLE
	
	if new_state != current_animation_state:
		_change_animation_state(new_state)

func _change_animation_state(new_state: AnimationState) -> void:
	current_animation_state = new_state
	
	match new_state:
		AnimationState.IDLE:
			play_animation("idle")
		AnimationState.AIM_IDLE:
			play_animation("aim_idle")
		AnimationState.WALK_FORWARD:
			play_animation("walk_forward")
		AnimationState.WALK_BACKWARD:
			play_animation("walk_backward")
		AnimationState.WALK_LOOP:
			play_animation("walk_loop")
		AnimationState.SHOOT:
			play_animation("shoot")
		AnimationState.RELOAD:
			play_animation("reload")
		AnimationState.TURN:
			play_animation("turn")

func play_animation(animation_name: String, force_restart: bool = false) -> void:
	if not animated_sprite:
		return
		
	if force_restart or animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
	_apply_animation_offset(animation_name)

func _fire_shot() -> void:
	if _is_shooting or is_reloading:
		print("🔫 [PlayerSniper] Fire blocked - already shooting or reloading")
		return

	if ammo_in_mag <= 0:
		print("🔫 [PlayerSniper] Fire blocked - no ammo, starting reload")
		_start_reload()
		return

	if not animated_sprite or not is_instance_valid(animated_sprite):
		print("❌ [PlayerSniper] Fire blocked - invalid animation sprite")
		_force_state_recovery()
		return

	var weapon_item := current_weapon_item
	if weapon_item.is_empty():
		print("⚠️ [PlayerSniper] Firing with no equipped weapon - using default stats")
		weapon_item = {
			"id": "fallback_weapon",
			"name": "Sidearm",
			"base_damage": 12.0,
			"spread_degrees": 6.0,
			"recoil_per_shot": 0.3,
			"recoil_recovery": 6.0,
			"falloff_start": 0.0,
			"falloff_end": 0.0,
			"falloff_min": 0.4,
			"accuracy_multiplier": 1.0,
			"reload_time": reload_duration
		}

	ammo_in_mag = max(0, ammo_in_mag - 1)
	_is_shooting = true
	_animation_timeout_timer = 0.0
	current_animation_state = AnimationState.SHOOT
	play_animation("shoot", true)
	shot_fired.emit()
	_persist_ammo()

	var aim_direction := _get_aim_direction()
	_current_aim_direction = aim_direction
	var origin := global_position + Vector2(20.0 * facing_direction.x, -6.0)

	var proficiency_key: String = _determine_proficiency_key_from_item(weapon_item)
	var weapon_damage := float(weapon_item.get("base_damage", weapon_item.get("damage", 10.0)))
	var damage := get_modified_weapon_damage(weapon_damage, proficiency_key)
	var spread := float(weapon_item.get("spread_degrees", weapon_item.get("spread", 0.0)))
	var accuracy_mod := get_modified_accuracy()
	var final_spread: float = spread / max(0.1, accuracy_mod)
	var params := {
		"spread_degrees": final_spread,
		"falloff_start": float(weapon_item.get("falloff_start", weapon_item.get("damage_falloff_start", 0.0))),
		"falloff_end": float(weapon_item.get("falloff_end", weapon_item.get("damage_falloff_end", 0.0))),
		"falloff_min": float(weapon_item.get("falloff_min", weapon_item.get("falloff_min_multiplier", 0.4))),
		"max_distance": float(weapon_item.get("range", 600.0)),
		"hit_zone": "torso",
		"body_multipliers": weapon_item.get("body_part_multipliers", {}),
		"weapon_profile": weapon_item
	}

	var hit: Dictionary = {}
	if ballistics:
		hit = ballistics.fire(origin, aim_direction, damage, projectile_collision_layers, params)

	var recoil := float(weapon_item.get("recoil_per_shot", weapon_item.get("recoil", 0.0)))
	recoil_angle += deg_to_rad(recoil)
	recoil_angle = clamp(recoil_angle, -0.8, 0.8)

	gain_weapon_proficiency(proficiency_key, 1)
	_emit_stats()

	print("🔫 [PlayerSniper] Shot fired - ammo remaining: %d/%d" % [ammo_in_mag, reserve_ammo])
	if not hit.is_empty():
		print("🎯 [PlayerSniper] Hit target at %.1f units for %.1f damage" % [hit.get("distance", 0.0), hit.get("final_damage", damage)])

	if ammo_in_mag <= 0 and reserve_ammo > 0:
		print("🔫 [PlayerSniper] Magazine empty, auto-reload triggered")
		_start_reload()

func _start_reload() -> void:
	# Enhanced validation for reload action
	if is_reloading:
		print("🔄 [PlayerSniper] Reload blocked - already reloading")
		return

	if ammo_in_mag >= magazine_size:
		print("🔄 [PlayerSniper] Reload blocked - magazine full")
		return

	if reserve_ammo <= 0:
		print("🔄 [PlayerSniper] Reload blocked - no reserve ammo")
		return

	# Validate animation sprite before reloading
	if not animated_sprite or not is_instance_valid(animated_sprite):
		print("❌ [PlayerSniper] Reload blocked - invalid animation sprite")
		_force_state_recovery()
		return

	_is_shooting = false
	is_reloading = true
	_animation_timeout_timer = 0.0  # Reset timeout counter
	current_animation_state = AnimationState.RELOAD
	reload_duration = _current_reload_duration
	play_animation("reload", true)

	print("🔄 [PlayerSniper] Reload started - %d/%d ammo" % [ammo_in_mag, reserve_ammo])

func _update_sprite_direction() -> void:
	"""Update sprite direction based on facing_direction (input-driven)"""
	var should_face_right = facing_direction.x > 0

	# Update sprite flip: flip_h=true for right, flip_h=false for left
	# (assuming sprite naturally faces left)
	if animated_sprite:
		animated_sprite.flip_h = should_face_right
		_apply_animation_offset(_get_current_animation_name())

	is_facing_right = should_face_right

## Future-proof bidirectional movement infrastructure (Phase 4)

func _get_movement_type() -> String:
	"""Determine movement type for future bidirectional support"""
	if abs(movement_intention.x) <= MOVEMENT_THRESHOLD:
		return "idle"

	match movement_mode:
		MovementMode.ALWAYS_FORWARD:
			return "forward"
		MovementMode.BIDIRECTIONAL:
			# Future: Detect backstrafe (facing forward but moving backward)
			var moving_right = movement_intention.x > 0
			var facing_right = facing_direction.x > 0

			if moving_right == facing_right:
				return "forward"  # Moving in facing direction
			else:
				return "backstrafe"  # Moving opposite to facing direction
		_:
			return "forward"

func _get_bidirectional_animation() -> AnimationState:
	"""Get appropriate animation for bidirectional movement (future use)"""
	var movement_type = _get_movement_type()

	match movement_type:
		"idle":
			return AnimationState.IDLE
		"forward":
			return AnimationState.WALK_FORWARD
		"backstrafe":
			return AnimationState.WALK_BACKWARD
		_:
			return AnimationState.WALK_FORWARD

func set_movement_mode(mode: MovementMode) -> void:
	"""Allow runtime switching of movement modes (future API)"""
	movement_mode = mode

func _on_animation_finished() -> void:
	# Defensive validation for animation callback
	if not animated_sprite or not is_instance_valid(animated_sprite):
		print("⚠️ [PlayerSniper] Animation finished callback with invalid sprite")
		_force_state_recovery()
		return

	var anim_name = animated_sprite.animation
	if anim_name == "":
		print("⚠️ [PlayerSniper] Animation finished with empty name")
		_force_state_recovery()
		return

	# Reset animation timeout
	_animation_timeout_timer = 0.0

	animation_finished.emit(anim_name)
	print("🎬 [PlayerSniper] Animation finished: %s" % anim_name)
	
	match anim_name:
		"shoot":
			_is_shooting = false
			if is_aiming:
				_change_animation_state(AnimationState.AIM_IDLE)
			else:
				_change_animation_state(AnimationState.IDLE)
		
		"reload":
			is_reloading = false
			var needed: int = magazine_size - ammo_in_mag
			if needed > 0 and reserve_ammo > 0:
				var to_load: int = min(needed, reserve_ammo)
				ammo_in_mag += to_load
				reserve_ammo -= to_load
			reload_complete.emit()
			_persist_ammo()
			if is_aiming:
				_change_animation_state(AnimationState.AIM_IDLE)
			else:
				_change_animation_state(AnimationState.IDLE)

		"turn":
			# Turn animation complete - sprite direction already set by input system
			_change_animation_state(AnimationState.IDLE)

func _update_state_monitoring(delta: float) -> void:
	"""Monitor animation and state health, perform recovery if needed"""
	if not _state_recovery_enabled:
		return

	# Update input debounce timer
	if _input_debounce_timer > 0:
		_input_debounce_timer -= delta

	# Animation timeout monitoring
	if _is_shooting or is_reloading:
		_animation_timeout_timer += delta
		if _animation_timeout_timer > _animation_timeout_limit:
			print("⚠️ [PlayerSniper] Animation timeout detected, forcing recovery")
			_force_state_recovery()

	# Validate animation sprite health
	if not animated_sprite or not is_instance_valid(animated_sprite):
		print("❌ [PlayerSniper] AnimatedSprite2D became invalid, attempting recovery")
		_force_state_recovery()
		return

	# Check for stuck animation states
	if animated_sprite and not animated_sprite.is_playing() and (_is_shooting or is_reloading):
		print("⚠️ [PlayerSniper] Stuck animation state detected, forcing recovery")
		_force_state_recovery()

func _force_state_recovery() -> void:
	"""Force recovery from corrupted animation or input states"""
	print("🔧 [PlayerSniper] Forcing state recovery")

	# Reset all state flags
	_is_shooting = false
	is_reloading = false
	_animation_timeout_timer = 0.0

	# Reset to idle state
	current_animation_state = AnimationState.IDLE
	if animated_sprite and is_instance_valid(animated_sprite):
		play_animation("idle", true)

	# Clear input debounce
	_input_debounce_timer = 0.0

	print("✅ [PlayerSniper] State recovery completed")

func _on_frame_changed() -> void:
	# Handle frame-specific events (muzzle flash, shell ejection, etc.)
	var anim_name = animated_sprite.animation
	var frame = animated_sprite.frame
	
	match anim_name:
		"shoot":
			# Trigger muzzle flash on specific frame
			if frame == 3: # Adjust based on actual animation
				_create_muzzle_flash()

func _create_muzzle_flash() -> void:
	# Placeholder for muzzle flash effect
	# This would integrate with existing visual effects system
	pass

# Future work: Multi-perspective support
# func set_perspective_mode(mode: String) -> void:
# 	match mode:
# 		"side":
# 			show()
# 			set_physics_process(true)
# 		_:
# 			hide()
# 			set_physics_process(false)

# Integration with existing player controller
func _try_interact() -> void:
	# Cast interaction ray to detect interactable objects
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position, 
		global_position + Vector2(50 if is_facing_right else -50, 0)
	)
	query.collision_mask = 4  # Interaction layer
	
	var result = space_state.intersect_ray(query)
	if result and result.collider.has_method("interact"):
		result.collider.interact(self)

func _apply_designer_settings() -> void:
	speed = base_speed

	if animated_sprite:
		var final_scale := _default_sprite_scale * character_scale
		animated_sprite.scale = final_scale
		animated_sprite.position = sprite_offset
		animated_sprite.speed_scale = animation_speed_scale
		_apply_animation_offset(_get_current_animation_name())

	_apply_collider_settings()

func _apply_collider_settings() -> void:
	if not collision_shape:
		return

	collision_shape.position = collider_offset

	var shape := collision_shape.shape
	if shape is RectangleShape2D:
		var rect_shape := shape as RectangleShape2D
		if collider_size_override != Vector2.ZERO:
			rect_shape.size = collider_size_override
		elif auto_resize_collider and _default_collider_size != Vector2.ZERO:
			rect_shape.size = _default_collider_size * character_scale
		elif _default_collider_size != Vector2.ZERO:
			rect_shape.size = _default_collider_size

func refresh_designer_settings() -> void:
	_apply_designer_settings()
	_apply_equipment_summary()
	_apply_animation_offset(_get_current_animation_name())

func _apply_animation_offset(anim_name) -> void:
	if not animated_sprite:
		return

	var key: StringName
	if anim_name is StringName:
		key = anim_name
	else:
		key = StringName(anim_name)
	var base: Vector2 = ANIMATION_OFFSET_BASES.get(key, Vector2.ZERO)
	var offset := Vector2(-base.x * HORIZONTAL_OFFSET_RATIO, base.y)
	if animated_sprite.flip_h:
		offset.x = -offset.x

	animated_sprite.position = sprite_offset + offset

func _get_current_animation_name() -> StringName:
	if not animated_sprite:
		return StringName("")
	return animated_sprite.animation

func _initialize_character_profile() -> void:
	var character := {}
	if has_node("/root/CharacterService"):
		character = CharacterService.get_current_character()
	if character.is_empty():
		return
	hydrate_from_character_data(character)

func hydrate_from_character_data(character: Dictionary) -> void:
	if character.is_empty():
		return

	for stat in base_stats.keys():
		base_stats[stat] = int(character.get(stat, base_stats[stat]))
	_update_effective_stats()

	current_level = int(character.get("level", current_level))
	current_xp = int(character.get("experience", current_xp))
	available_stat_points = int(character.get("available_stat_points", available_stat_points))
	xp_to_next = _calculate_xp_to_next(current_level)

	ammo_in_mag = int(character.get("ammo_in_mag", ammo_in_mag))
	if ammo_in_mag <= 0:
		ammo_in_mag = default_magazine_size
	reserve_ammo = int(character.get("reserve_ammo", reserve_ammo))
	if reserve_ammo < 0:
		reserve_ammo = default_reserve_ammo

	max_health = float(character.get("max_health", max_health))
	current_health = clamp(float(character.get("current_health", max_health)), 0.0, max_health)
	nourishment_level = clamp(float(character.get("nourishment_level", nourishment_level)), 0.0, 100.0)
	sleep_level = clamp(float(character.get("sleep_level", sleep_level)), 0.0, 100.0)
	last_nourishment_time = _get_current_time()
	last_sleep_time = last_nourishment_time

	var profs: Dictionary = {}
	if character.has("weapon_proficiencies") and typeof(character["weapon_proficiencies"]) == TYPE_DICTIONARY:
		profs = character["weapon_proficiencies"]
	melee_knives = int(profs.get("melee_knives", character.get("melee_knives", melee_knives)))
	melee_axes_clubs = int(profs.get("melee_axes_clubs", character.get("melee_axes_clubs", melee_axes_clubs)))
	firearm_handguns = int(profs.get("firearm_handguns", character.get("firearm_handguns", firearm_handguns)))
	firearm_rifles = int(profs.get("firearm_rifles", character.get("firearm_rifles", firearm_rifles)))
	firearm_shotguns = int(profs.get("firearm_shotguns", character.get("firearm_shotguns", firearm_shotguns)))
	firearm_automatics = int(profs.get("firearm_automatics", character.get("firearm_automatics", firearm_automatics)))

	if inventory:
		inventory.hydrate_from_character_data(character)
		_apply_equipment_summary(inventory.get_equipment_summary())
	else:
		var equipment_summary := {
			"modifiers": character.get("equipment_modifiers", {}),
			"slots": character.get("equipment", {})
		}
		_apply_equipment_summary(equipment_summary)

	_update_performance_multipliers()
	_update_reload_duration()
	_emit_stats()

func _setup_inventory_hooks() -> void:
	inventory = get_node_or_null("Inventory")
	if inventory == null:
		return
	if inventory.has_signal("equipment_changed"):
		inventory.equipment_changed.connect(_on_equipment_changed)
	var character := {}
	if has_node("/root/CharacterService"):
		character = CharacterService.get_current_character()
	var has_saved_equipment := false
	if character is Dictionary and character.has("equipment") and character["equipment"] is Dictionary:
		has_saved_equipment = (character["equipment"] as Dictionary).size() > 0
	if inventory.items.is_empty() and not has_saved_equipment:
		var starter_ids := [
			{"primary": "pistol_makeshift", "fallback": "weapon_lv1"},
			{"primary": "helmet_basic"},
			{"primary": "armor_padded_jacket", "fallback": "armor_lv1"},
			{"primary": "pants_reinforced"},
			{"primary": "accessory_backpack"}
		]
		for entry in starter_ids:
			var primary_id := String(entry.get("primary", ""))
			var fallback_id := String(entry.get("fallback", ""))
			var equipped := false
			if primary_id != "":
				equipped = inventory.add_item_by_id(primary_id, 1, true)
			if (not equipped) and fallback_id != "":
				inventory.add_item_by_id(fallback_id, 1, true)
	_apply_equipment_summary()

func _on_equipment_changed(summary: Dictionary) -> void:
	_apply_equipment_summary(summary)

func _apply_equipment_summary(summary: Dictionary = {}) -> void:
	if summary.is_empty() and inventory:
		summary = inventory.get_equipment_summary()
	_update_effective_stats()
	var modifiers: Dictionary = summary.get("modifiers", {})
	var stat_mods: Dictionary = modifiers.get("stat_mods", {})
	for stat in stat_mods.keys():
		effective_stats[stat] = base_stats.get(stat, 1) + int(stat_mods[stat])
	equipment_damage_bonus = float(modifiers.get("damage_bonus", 0.0))
	equipment_defense_bonus = float(modifiers.get("defense_bonus", 0.0))
	equipment_speed_multiplier = float(modifiers.get("speed_multiplier", 1.0))
	equipment_damage_reduction = float(modifiers.get("damage_reduction", 0.0))
	equipment_reload_bonus = float(modifiers.get("reload_speed_bonus", 0.0))
	weapon_params = modifiers.get("weapon_params", {})

	var slots: Dictionary = summary.get("slots", {})
	var weapon_item = slots.get("weapon", null)
	if weapon_item:
		current_weapon_item = weapon_item.duplicate(true)
		var weapon_id = String(current_weapon_item.get("item_id", current_weapon_item.get("id", "")))
		var new_mag = int(current_weapon_item.get("magazine_size", default_magazine_size))
		if weapon_id != _current_weapon_id:
			_current_weapon_id = weapon_id
			magazine_size = max(1, new_mag)
			ammo_in_mag = magazine_size
			reserve_ammo = max(0, int(current_weapon_item.get("reserve_ammo", default_reserve_ammo)))
		else:
			magazine_size = max(1, new_mag)
			ammo_in_mag = clamp(ammo_in_mag, 0, magazine_size)
			reserve_ammo = max(0, int(current_weapon_item.get("reserve_ammo", reserve_ammo)))
		current_weapon_proficiency_key = _determine_proficiency_key_from_item(current_weapon_item)
	else:
		current_weapon_item = {}
		current_weapon_proficiency_key = "firearm_handguns"
		_current_weapon_id = ""
		magazine_size = default_magazine_size
		ammo_in_mag = clamp(ammo_in_mag, 0, magazine_size)
		reserve_ammo = max(0, reserve_ammo)

	_update_performance_multipliers()
	_update_reload_duration()
	_emit_stats()

func _persist_ammo() -> void:
	if not has_node("/root/CharacterService"):
		return
	var current = CharacterService.get_current_character()
	if current.is_empty():
		return
	current["ammo_in_mag"] = ammo_in_mag
	current["reserve_ammo"] = reserve_ammo
	CharacterService.set_current_character(current)
	var game := _get_game_singleton()
	if game and game.survivability_manager:
		game.survivability_manager.notify_manual_update(self)

func _update_effective_stats() -> void:
	for stat in base_stats.keys():
		effective_stats[stat] = base_stats[stat]

func _update_reload_duration() -> void:
	var base_time := float(weapon_params.get("reload_time", reload_duration))
	var speed_bonus := reload_speed_multiplier + equipment_reload_bonus
	if speed_bonus <= 0.1:
		speed_bonus = 0.1
	_current_reload_duration = clamp(base_time / speed_bonus, 0.25, 5.0)

func _get_aim_direction() -> Vector2:
	var target := get_global_mouse_position()
	var dir := target - global_position
	if dir.length() < 0.01:
		dir = facing_direction
	var adjusted: Vector2 = dir.normalized()
	if recoil_angle != 0.0:
		adjusted = adjusted.rotated(recoil_angle)
	return adjusted

func _update_recoil(delta: float) -> void:
	if recoil_angle == 0.0:
		return
	var recovery := float(weapon_params.get("recoil_recovery", 6.0))
	var step := recovery * delta
	if abs(recoil_angle) <= step:
		recoil_angle = 0.0
	else:
		recoil_angle = lerp(recoil_angle, 0.0, clamp(step, 0.0, 1.0))

func _update_status_effects(delta: float) -> void:
	if active_status_effects.is_empty():
		return
	var to_remove: Array = []
	for effect_id in active_status_effects.keys():
		var effect: Dictionary = active_status_effects[effect_id]
		effect["remaining"] = float(effect.get("remaining", 0.0)) - delta
		active_status_effects[effect_id] = effect
		match effect_id:
			"bleeding":
				var dps := float(effect.get("data", {}).get("damage_per_second", 2.0))
				_apply_status_damage(dps * delta)
			"acid":
				var dps := float(effect.get("data", {}).get("damage_per_second", 3.5))
				_apply_status_damage(dps * delta)
			"stat_buff":
				pass
		if effect.get("remaining", 0.0) <= 0.0:
			to_remove.append(effect_id)
	for effect_id in to_remove:
		clear_status_effect(effect_id)

func _update_survivability(delta: float) -> void:
	apply_survivability_tick(delta)

func apply_survivability_tick(delta: float) -> void:
	var current_time := _get_current_time()
	if last_survival_check_time == 0.0:
		last_survival_check_time = current_time
	if last_nourishment_time <= 0.0:
		last_nourishment_time = current_time
	if last_sleep_time <= 0.0:
		last_sleep_time = current_time
	var changed := false
	var hunger_multiplier: float = difficulty_modifiers.get("hunger_drain_multiplier", 1.0)
	var fatigue_multiplier: float = difficulty_modifiers.get("fatigue_drain_multiplier", 1.0)
	var nourishment_decay: float = ((current_time - last_nourishment_time) / 3600.0) * hunger_multiplier * nourishment_decay_rate
	if nourishment_decay > 0.1:
		nourishment_level = clamp(nourishment_level - nourishment_decay, 0.0, 100.0)
		last_nourishment_time = current_time
		changed = true
	var sleep_decay: float = ((current_time - last_sleep_time) / 1800.0) * fatigue_multiplier * sleep_decay_rate
	if sleep_decay > 0.1:
		sleep_level = clamp(sleep_level - sleep_decay, 0.0, 100.0)
		last_sleep_time = current_time
		changed = true
	if changed:
		_update_performance_multipliers()
		_persist_character_stats()
		_emit_stats()

func _apply_status_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	apply_damage(amount, "torso")

func _calculate_xp_to_next(level: int) -> int:
	return 100 + int(pow(level, 1.5) * 50)

func add_experience(amount: int) -> void:
	current_xp += amount
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		current_level += 1
		available_stat_points += 3
		xp_to_next = _calculate_xp_to_next(current_level)
		print("🎉 Level up! Level %d" % current_level)
		if has_node("/root/CharacterService"):
			var updated = CharacterService.get_current_character()
			updated["level"] = current_level
			updated["experience"] = current_xp
			updated["available_stat_points"] = available_stat_points
			CharacterService.set_current_character(updated)
	_emit_stats()

func _emit_stats() -> void:
	stats_updated.emit(get_character_stats())

func _persist_character_stats() -> void:
	if not has_node("/root/CharacterService"):
		return
	var current := CharacterService.get_current_character()
	if current.is_empty():
		return
	current["nourishment_level"] = nourishment_level
	current["sleep_level"] = sleep_level
	current["current_health"] = current_health
	current["max_health"] = max_health
	current["melee_knives"] = melee_knives
	current["melee_axes_clubs"] = melee_axes_clubs
	current["firearm_handguns"] = firearm_handguns
	current["firearm_rifles"] = firearm_rifles
	current["firearm_shotguns"] = firearm_shotguns
	current["firearm_automatics"] = firearm_automatics
	current["weapon_proficiencies"] = {
		"melee_knives": melee_knives,
		"melee_axes_clubs": melee_axes_clubs,
		"firearm_handguns": firearm_handguns,
		"firearm_rifles": firearm_rifles,
		"firearm_shotguns": firearm_shotguns,
		"firearm_automatics": firearm_automatics
	}
	current["ammo_in_mag"] = ammo_in_mag
	current["reserve_ammo"] = reserve_ammo
	CharacterService.set_current_character(current)
	var game := _get_game_singleton()
	if game and game.survivability_manager:
		game.survivability_manager.notify_manual_update(self)

func _get_current_time() -> float:
	if GameTime:
		return GameTime.get_unix_time_from_system()
	return Time.get_unix_time_from_system()

func gain_weapon_proficiency(weapon_type: String, xp_amount: int) -> void:
	match weapon_type:
		"melee_knives":
			melee_knives = clamp(melee_knives + xp_amount, 0, 100)
		"melee_axes_clubs":
			melee_axes_clubs = clamp(melee_axes_clubs + xp_amount, 0, 100)
		"firearm_handguns":
			firearm_handguns = clamp(firearm_handguns + xp_amount, 0, 100)
		"firearm_rifles":
			firearm_rifles = clamp(firearm_rifles + xp_amount, 0, 100)
		"firearm_shotguns":
			firearm_shotguns = clamp(firearm_shotguns + xp_amount, 0, 100)
		"firearm_automatics":
			firearm_automatics = clamp(firearm_automatics + xp_amount, 0, 100)
	_emit_stats()
	_persist_character_stats()

func get_weapon_proficiency_multiplier(weapon_type: String) -> float:
	var proficiency := 0
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
	return 1.0 + (proficiency / 10.0) * 0.05

func get_modified_weapon_damage(base_damage: float, weapon_type: String) -> float:
	var damage := base_damage + equipment_damage_bonus
	var strength: int = effective_stats.get("strength", 1)
	if weapon_type.begins_with("melee"):
		damage *= 1.0 + (strength - 1) * 0.15
	damage *= get_weapon_proficiency_multiplier(weapon_type)
	if nourishment_level < 25.0:
		damage *= 0.85
	return max(0.0, damage)

func get_modified_accuracy() -> float:
	var accuracy: float = 1.0 + (effective_stats.get("accuracy", 1) - 1) * 0.1
	accuracy *= accuracy_multiplier
	if current_weapon_item.has("accuracy_multiplier"):
		accuracy *= float(current_weapon_item.get("accuracy_multiplier"))
	if sleep_level < 25.0:
		accuracy *= 0.85
	if nourishment_level < 25.0:
		accuracy *= 0.85
	return max(0.1, accuracy)

func _update_performance_multipliers() -> void:
	var agility: int = effective_stats.get("agility", 1)
	var dexterity: int = effective_stats.get("dexterity", 1)
	var accuracy_stat: int = effective_stats.get("accuracy", 1)
	movement_speed_multiplier = 1.0 + (agility - 1) * 0.05
	reload_speed_multiplier = 1.0 + (dexterity - 1) * 0.05
	accuracy_multiplier = 1.0 + (accuracy_stat - 1) * 0.05
	if sleep_level < 25.0:
		movement_speed_multiplier *= 0.9
		reload_speed_multiplier *= 0.9
		accuracy_multiplier *= 0.85
	if nourishment_level < 25.0:
		movement_speed_multiplier *= 0.9
		reload_speed_multiplier *= 0.95
	_update_reload_duration()

func _determine_proficiency_key_from_item(item: Dictionary) -> String:
	var category := String(item.get("category", "")).to_lower()
	match category:
		"handgun":
			return "firearm_handguns"
		"rifle":
			return "firearm_rifles"
		"smg":
			return "firearm_automatics"
		"shotgun":
			return "firearm_shotguns"
		"melee_knife":
			return "melee_knives"
		"melee_club", "melee_axe":
			return "melee_axes_clubs"
		_:
			return "firearm_handguns"

func apply_status_effect(effect_id: String, params: Dictionary = {}) -> void:
	var duration := float(params.get("duration", 5.0))
	active_status_effects[effect_id] = {
		"remaining": duration,
		"data": params
	}
	if effect_id == "stat_buff":
		var stat_mods: Dictionary = params.get("stat_buffs", params.get("stat_mods", {}))
		for stat in stat_mods.keys():
			status_stat_bonuses[stat] = status_stat_bonuses.get(stat, 0) + int(stat_mods[stat])
			base_stats[stat] = base_stats.get(stat, 1) + int(stat_mods[stat])
		_update_effective_stats()
		_update_performance_multipliers()
	_emit_stats()

func clear_status_effect(effect_id: String = "") -> void:
	if effect_id == "":
		for key in active_status_effects.keys():
			clear_status_effect(key)
		return
	var effect: Dictionary = active_status_effects.get(effect_id, {})
	if effect == null:
		return
	if effect_id == "stat_buff":
		var stat_mods: Dictionary = effect.get("data", {}).get("stat_buffs", effect.get("data", {}).get("stat_mods", {}))
		for stat in stat_mods.keys():
			status_stat_bonuses[stat] = status_stat_bonuses.get(stat, 0) - int(stat_mods[stat])
			base_stats[stat] = max(1, base_stats.get(stat, 1) - int(stat_mods[stat]))
		_update_effective_stats()
		_update_performance_multipliers()
	active_status_effects.erase(effect_id)
	_emit_stats()

func consume_item(item: Dictionary) -> void:
	if item.is_empty():
		return
	var nourishment_restore := float(item.get("nourishment_restore", 0.0))
	var sleep_restore := float(item.get("sleep_restore", 0.0))
	if nourishment_restore > 0.0:
		nourishment_level = clamp(nourishment_level + nourishment_restore, 0.0, 100.0)
		last_nourishment_time = _get_current_time()
	if sleep_restore > 0.0:
		sleep_level = clamp(sleep_level + sleep_restore, 0.0, 100.0)
		last_sleep_time = _get_current_time()
	var stat_buffs: Dictionary = item.get("stat_buffs", {})
	if not stat_buffs.is_empty():
		apply_status_effect("stat_buff", {
			"duration": float(item.get("duration", 30.0)),
			"stat_buffs": stat_buffs
		})
	_update_performance_multipliers()
	_persist_character_stats()
	_emit_stats()

func apply_damage(amount: float, bodypart: String = "torso") -> void:
	var mitigated: float = max(0.0, amount - equipment_defense_bonus)
	mitigated *= (1.0 - clamp(equipment_damage_reduction, 0.0, 0.9))
	current_health = clamp(current_health - mitigated, 0.0, max_health)
	_emit_stats()
	_persist_character_stats()

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	current_health = clamp(current_health + amount, 0.0, max_health)
	_emit_stats()
	_persist_character_stats()

func get_health() -> float:
	return current_health

func get_character_stats() -> Dictionary:
	return {
		"level": current_level,
		"xp": current_xp,
		"xp_for_next_level": xp_to_next,
		"available_stat_points": available_stat_points,
		"strength": effective_stats.get("strength", 1),
		"dexterity": effective_stats.get("dexterity", 1),
		"agility": effective_stats.get("agility", 1),
		"endurance": effective_stats.get("endurance", 1),
		"accuracy": effective_stats.get("accuracy", 1),
		"nourishment_level": nourishment_level,
		"sleep_level": sleep_level,
		"health": current_health,
		"max_health": max_health,
		"weapon_proficiencies": {
			"melee_knives": melee_knives,
			"melee_axes_clubs": melee_axes_clubs,
			"firearm_handguns": firearm_handguns,
			"firearm_rifles": firearm_rifles,
			"firearm_shotguns": firearm_shotguns,
			"firearm_automatics": firearm_automatics
		},
		"equipment": {
			"weapon": current_weapon_item.duplicate(true) if not current_weapon_item.is_empty() else {}
		}
	}

func get_survivability_snapshot() -> Dictionary:
	return {
		"nourishment_level": nourishment_level,
		"sleep_level": sleep_level,
		"timestamp": _get_current_time()
	}

func _get_game_singleton() -> Node:
	return get_node_or_null("/root/Game")
