extends CharacterBody2D

## Juggernaut Boss Zombie for Sidescrolling Perspective
## Heavy boss enemy with multiple attack patterns

class_name ZombieJuggernaut

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea
@onready var vision: Vision2D = $Vision2D
@onready var hearing: Hearing2D = $Hearing2D

# Stats and properties
var max_health: float = 500.0
var current_health: float = 500.0
var move_speed: float = 60.0
var attack_damage: float = 75.0
var attack_range: float = 100.0
var detection_range: float = 300.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# AI States - Enhanced with zombie-like behaviors
enum AIState {
	IDLE,
	ROAMING,
	WANDERING,
	ALERTED,
	CHASE,
	ATTACK_3,
	ATTACK_4,
	ENRAGED,
	HIT_REACTION,
	DEATH
}

# Movement Tiers based on health percentage
enum MovementTier {
	INATTENTIVE,    # 100%-75% health: walk
	ALERT,          # 75%-25% health: walk_alt when player detected
	AGITATED,       # 25%-10% health: walk_side
	DESPERATE       # <10% health: run
}

var current_state: AIState = AIState.IDLE
var target_player: Node2D = null
var is_facing_right: bool = true
var is_enraged: bool = false
var is_attacking: bool = false
var is_dead: bool = false

# Attack patterns
var attack_cooldown: float = 2.0
var attack_timer: float = 0.0
var rage_threshold: float = 0.3 # 30% health

# Enhanced roaming behavior
var roaming_radius: float = 150.0
var idle_duration_range: Vector2 = Vector2(2.0, 8.0)
var wander_duration_range: Vector2 = Vector2(3.0, 12.0)
var direction_change_probability: float = 0.15
var idle_probability: float = 0.3
var current_movement_tier: MovementTier = MovementTier.INATTENTIVE

# Roaming state management
var roaming_timer: float = 0.0
var roaming_duration: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var roaming_origin: Vector2 = Vector2.ZERO

signal health_changed(new_health: float, max_health: float)
signal death()
signal attack_hit(damage: float)
signal rage_activated()

func _play_animation_safe(animation_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif animated_sprite.sprite_frames.get_animation_names().size() > 0:
		# Fallback to first available animation
		animated_sprite.play(animated_sprite.sprite_frames.get_animation_names()[0])

func _ready() -> void:
	current_health = max_health

	# Set up collision layers
	collision_layer = 4  # Enemy layer
	collision_mask = 1   # World layer

	# Connect area signals
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)

	# Set up animation connections
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.frame_changed.connect(_on_frame_changed)

	# Set up perception systems
	if vision:
		vision.owner_node = self
		vision.max_dist = detection_range
		vision.fov_deg = 120.0  # Wide FOV for boss enemy
		vision.vertical_fov_deg = 60.0  # Good vertical coverage

	if hearing:
		hearing.owner_node = self
		hearing.radius = detection_range * 0.8  # Slightly less than vision

	# Initialize patrol points if none set
	# Initialize roaming origin
	roaming_origin = global_position

	# Start with roaming behavior
	_change_state(AIState.ROAMING)
	_update_movement_tier()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Update timers
	attack_timer = max(0, attack_timer - delta)
	roaming_timer = max(0, roaming_timer - delta)

	# Check for player using vision system (performance optimized)
	if not target_player and _should_check_vision():
		_check_for_player_vision()

	# State machine
	_update_ai_state(delta)

	move_and_slide()

func _update_ai_state(delta: float) -> void:
	match current_state:
		AIState.IDLE:
			_handle_idle_state(delta)
		AIState.ROAMING:
			_handle_roaming_state(delta)
		AIState.WANDERING:
			_handle_wandering_state(delta)
		AIState.ALERTED:
			_handle_alerted_state(delta)
		AIState.CHASE:
			_handle_chase_state(delta)
		AIState.ATTACK_3, AIState.ATTACK_4:
			_handle_attack_state(delta)
		AIState.ENRAGED:
			_handle_enraged_state(delta)
		AIState.HIT_REACTION:
			_handle_hit_reaction_state(delta)

func _handle_idle_state(delta: float) -> void:
	velocity.x = 0

	if target_player:
		_change_state(AIState.ALERTED)
	elif roaming_timer <= 0:
		# Randomly choose next behavior
		if randf() < idle_probability:
			_start_wandering()
		else:
			_change_state(AIState.ROAMING)

func _handle_roaming_state(delta: float) -> void:
	if target_player:
		_change_state(AIState.ALERTED)
		return

	# Move in a direction within roaming radius
	var distance_from_origin = global_position.distance_to(roaming_origin)

	if distance_from_origin > roaming_radius:
		# Return toward origin
		var direction = (roaming_origin - global_position).normalized()
		velocity.x = direction.x * _get_movement_speed() * 0.3
		_face_direction(direction.x)
	else:
		# Random roaming movement
		if wander_direction == Vector2.ZERO or randf() < direction_change_probability:
			wander_direction = Vector2(randf_range(-1.0, 1.0), 0).normalized()

		velocity.x = wander_direction.x * _get_movement_speed() * 0.4
		_face_direction(wander_direction.x)

	# Randomly transition to idle
	if roaming_timer <= 0 and randf() < 0.1:
		_start_idle_period()

func _handle_wandering_state(delta: float) -> void:
	if target_player:
		_change_state(AIState.ALERTED)
		return

	# Wandering with more purposeful movement
	if wander_direction == Vector2.ZERO:
		_start_wandering()

	velocity.x = wander_direction.x * _get_movement_speed() * 0.6
	_face_direction(wander_direction.x)

	# Check if wandering period is over
	if roaming_timer <= 0:
		_start_idle_period()

func _handle_alerted_state(delta: float) -> void:
	if not target_player:
		_change_state(AIState.ROAMING)
		return

	# Move toward player with alert behavior
	var direction: Vector2 = (target_player.global_position - global_position).normalized()
	var distance_to_player = global_position.distance_to(target_player.global_position)

	if distance_to_player <= attack_range and attack_timer <= 0:
		_choose_attack()
	elif distance_to_player > detection_range * 1.5:
		# Lost target
		target_player = null
		_change_state(AIState.ROAMING)
	else:
		# Chase with current movement tier speed
		velocity.x = direction.x * _get_movement_speed()
		_face_direction(direction.x)

		# Transition to full chase if very close
		if distance_to_player < attack_range * 2:
			_change_state(AIState.CHASE)

func _handle_chase_state(delta: float) -> void:
	if not target_player:
		_change_state(AIState.ROAMING)
		return

	var distance_to_player = global_position.distance_to(target_player.global_position)

	if distance_to_player > detection_range * 1.5:
		# Lost target
		target_player = null
		_change_state(AIState.ROAMING)
	elif distance_to_player <= attack_range and attack_timer <= 0:
		# Close enough to attack
		_choose_attack()
	else:
		# Move toward player with aggressive speed
		var direction = (target_player.global_position - global_position).normalized()
		velocity.x = direction.x * _get_movement_speed() * 1.2
		_face_direction(direction.x)

func _handle_attack_state(delta: float) -> void:
	velocity.x = 0  # Stop movement during attacks

func _handle_enraged_state(delta: float) -> void:
	# Enraged mode increases speed and aggression
	if target_player:
		_change_state(AIState.CHASE)
	else:
		# Look for targets more aggressively
		_change_state(AIState.WANDERING)

func _handle_hit_reaction_state(delta: float) -> void:
	velocity.x = 0

# Helper functions for new roaming system
func _start_idle_period() -> void:
	roaming_duration = randf_range(idle_duration_range.x, idle_duration_range.y)
	roaming_timer = roaming_duration
	_change_state(AIState.IDLE)

func _start_wandering() -> void:
	roaming_duration = randf_range(wander_duration_range.x, wander_duration_range.y)
	roaming_timer = roaming_duration
	wander_direction = Vector2(randf_range(-1.0, 1.0), 0).normalized()
	_change_state(AIState.WANDERING)

func _get_movement_speed() -> float:
	var base_speed = move_speed

	# Apply movement tier modifiers
	match current_movement_tier:
		MovementTier.INATTENTIVE:
			return base_speed * 0.5
		MovementTier.ALERT:
			return base_speed * 0.7
		MovementTier.AGITATED:
			return base_speed * 0.9
		MovementTier.DESPERATE:
			return base_speed * 1.3

	return base_speed

func _update_movement_tier() -> void:
	var health_percent = current_health / max_health

	if health_percent <= 0.1:
		current_movement_tier = MovementTier.DESPERATE
	elif health_percent <= 0.25:
		current_movement_tier = MovementTier.AGITATED
	elif health_percent <= 0.75 and target_player:
		current_movement_tier = MovementTier.ALERT
	else:
		current_movement_tier = MovementTier.INATTENTIVE

func _change_state(new_state: AIState) -> void:
	if new_state == current_state:
		return
	
	current_state = new_state
	_play_state_animation()

func _play_state_animation() -> void:
	if not animated_sprite:
		return

	match current_state:
		AIState.IDLE:
			_play_animation_safe("idle")
		AIState.ROAMING, AIState.WANDERING:
			_play_movement_animation()
		AIState.ALERTED:
			_play_movement_animation()
		AIState.CHASE:
			_play_movement_animation()
		AIState.ATTACK_3:
			animated_sprite.play("attack_3")
			is_attacking = true
		AIState.ATTACK_4:
			animated_sprite.play("attack_4")
			is_attacking = true
		AIState.ENRAGED:
			animated_sprite.play("rage")
		AIState.HIT_REACTION:
			animated_sprite.play(_get_random_hit_reaction())
		AIState.DEATH:
			animated_sprite.play(_get_random_death_animation())

func _play_movement_animation() -> void:
	# Play animation based on current movement tier
	match current_movement_tier:
		MovementTier.INATTENTIVE:
			animated_sprite.play("walk")
		MovementTier.ALERT:
			animated_sprite.play("walk_alt")
		MovementTier.AGITATED:
			animated_sprite.play("walk_side")
		MovementTier.DESPERATE:
			animated_sprite.play("run")

func _get_random_hit_reaction() -> String:
	return "hit_reaction_1" if randf() < 0.5 else "hit_reaction_2"

func _get_random_death_animation() -> String:
	return "death_1" if randf() < 0.5 else "death_2"

func _choose_attack() -> void:
	if is_attacking:
		return

	# Enhanced attack selection based on rage state
	var attack_weights: Array[float] = []
	if is_enraged:
		attack_weights = [0.3, 0.7]  # Favor attack_4 when enraged
	else:
		attack_weights = [0.7, 0.3]  # Favor attack_3 normally

	var selected = 0 if randf() < attack_weights[0] else 1

	if selected == 1:
		_change_state(AIState.ATTACK_4)
	else:
		_change_state(AIState.ATTACK_3)

	# Apply rage mode attack cooldown reduction
	var cooldown_modifier = 0.7 if is_enraged else 1.0
	attack_timer = attack_cooldown * cooldown_modifier

func take_damage(damage: float, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	
	current_health = max(0, current_health - damage)
	health_changed.emit(current_health, max_health)
	
	# Apply knockback
	if knockback_force != Vector2.ZERO:
		velocity += knockback_force
	
	# Update movement tier based on health
	_update_movement_tier()

	# Check for rage mode (health threshold only, player detection handled separately)
	if not is_enraged and current_health <= max_health * rage_threshold:
		is_enraged = true
		rage_activated.emit()
		_change_state(AIState.ENRAGED)
	elif not is_attacking:
		_change_state(AIState.HIT_REACTION)
	
	# Check for death
	if current_health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	
	is_dead = true
	collision_layer = 0  # Disable collision
	_change_state(AIState.DEATH)
	death.emit()

func _face_direction(direction_x: float) -> void:
	if direction_x > 0 and not is_facing_right:
		is_facing_right = true
		animated_sprite.flip_h = false
	elif direction_x < 0 and is_facing_right:
		is_facing_right = false
		animated_sprite.flip_h = true

func _on_animation_finished() -> void:
	var anim_name = animated_sprite.animation

	match anim_name:
		"attack_3", "attack_4":
			is_attacking = false
			if target_player:
				_change_state(AIState.CHASE)
			else:
				_change_state(AIState.ROAMING)

		"hit_reaction_1", "hit_reaction_2":
			if target_player:
				_change_state(AIState.ALERTED)
			else:
				_change_state(AIState.ROAMING)

		"rage":
			# After rage animation, return to appropriate state
			if target_player:
				_change_state(AIState.CHASE)
			else:
				_change_state(AIState.WANDERING)

		"death_1", "death_2":
			queue_free()

func _on_frame_changed() -> void:
	# Handle frame-specific events (damage frames, effects, etc.)
	var anim_name = animated_sprite.animation
	var frame = animated_sprite.frame

	match anim_name:
		"attack_3":
			if frame == 12:  # Damage frame for heavy attack
				_deal_attack_damage(attack_damage * 1.5)

		"attack_4":
			if frame == 16:  # Damage frame for special attack
				var damage_multiplier = 2.5 if is_enraged else 2.0
				_deal_attack_damage(attack_damage * damage_multiplier)

func _deal_attack_damage(damage: float) -> void:
	# Find players in attack range and deal damage
	if not attack_area:
		return
	
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage"):
			body.take_damage(damage)
			attack_hit.emit(damage)

func _on_detection_area_entered(body: Node2D) -> void:
	if body.has_method("take_damage") and not is_dead:
		target_player = body
		# NEW: Immediate rage on player detection (dual trigger system)
		if not is_enraged:
			is_enraged = true
			rage_activated.emit()
			_update_movement_tier()
			_change_state(AIState.ALERTED)

func _on_detection_area_exited(body: Node2D) -> void:
	if body == target_player:
		# Don't immediately lose target, wait for chase state to handle it
		pass

# Vision and hearing perception methods
var vision_check_timer: float = 0.0
var vision_check_interval: float = 0.2  # Check vision 5 times per second

func _should_check_vision() -> bool:
	vision_check_timer += get_physics_process_delta_time()
	if vision_check_timer >= vision_check_interval:
		vision_check_timer = 0.0
		return true
	return false

func _check_for_player_vision() -> void:
	if not vision:
		return

	# Get all potential targets (players)
	var players_nodes = get_tree().get_nodes_in_group("player")
	if players_nodes.is_empty():
		return

	# Convert to Array[Node2D] for vision system compatibility
	var players: Array[Node2D] = []
	for player in players_nodes:
		if player is Node2D:
			players.append(player as Node2D)

	if players.is_empty():
		return

	# Use optimized batch vision check
	var spotted_player = vision.sees_any(players)
	if spotted_player:
		target_player = spotted_player
		_on_player_detected("vision")

func on_heard_noise(source: Node, intensity: float) -> void:
	# Hearing callback from Hearing2D component
	if is_dead or target_player:
		return

	# Check if the noise source is a player
	if source.is_in_group("player"):
		target_player = source
		_on_player_detected("hearing")
	elif intensity > 0.7:  # High intensity noise attracts attention
		# Move toward the noise source for investigation
		var noise_direction = (source.global_position - global_position).normalized()
		wander_direction = noise_direction
		if current_state == AIState.IDLE:
			_change_state(AIState.WANDERING)

func _on_player_detected(detection_type: String) -> void:
	if not target_player or is_dead:
		return

	# Enhanced detection with rage activation
	if not is_enraged:
		is_enraged = true
		rage_activated.emit()
		_update_movement_tier()

	# Set appropriate state based on distance
	var distance_to_player = global_position.distance_to(target_player.global_position)
	if distance_to_player <= attack_range * 2:
		_change_state(AIState.CHASE)
	else:
		_change_state(AIState.ALERTED)

	print("🧟 Juggernaut detected player via ", detection_type)

func get_facing_direction() -> Vector2:
	# Required by Vision2D to determine facing direction
	return Vector2.RIGHT if is_facing_right else Vector2.LEFT

func _on_attack_area_entered(body: Node2D) -> void:
	# Area is mainly for damage dealing, handled in frame events
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