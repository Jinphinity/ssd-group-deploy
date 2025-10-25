extends CharacterBody2D

## Basic Zombie AI for 2D sidescroller gameplay
## Simplified version of Zombie_Basic.gd adapted for sidescrolling perspective

class_name ZombieBasic2D

@export var speed: float = 60.0
@export var attack_range: float = 40.0
@export var attack_damage: float = 10.0
@export var detection_range: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var detection_area: Area2D = $DetectionArea
@onready var vision: Vision2D = $Vision2D
@onready var hearing: Hearing2D = $Hearing2D

var target: Node2D = null
var health: float = 50.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Zone-aware behavior
var base_speed: float = 60.0
var base_attack_damage: float = 10.0
var base_health: float = 50.0
var aggression_multiplier: float = 1.0
var zone_noise_penalty: float = 1.0
var current_zone = null

# AI States
enum State {
	IDLE,
	PATROL,
	CHASE,
	ATTACK,
	DEAD
}

var current_state: State = State.IDLE
var is_facing_right: bool = true
var attack_cooldown: float = 0.0
var patrol_direction: int = 1
var last_direction_change: float = 0.0

signal zombie_died(zombie: ZombieBasic2D)
signal player_attacked(damage: float)

func _play_animation_safe(animation_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif animated_sprite.sprite_frames.get_animation_names().size() > 0:
		# Fallback to first available animation
		animated_sprite.play(animated_sprite.sprite_frames.get_animation_names()[0])

func _ready() -> void:
	# Store base values for zone modifications
	base_speed = speed
	base_attack_damage = attack_damage
	base_health = health

	# Set up detection and attack areas
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)

	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
		attack_area.body_exited.connect(_on_attack_area_exited)

	# Set up perception systems
	if vision:
		vision.owner_node = self
		vision.max_dist = detection_range
		vision.fov_deg = 90.0  # Standard FOV for basic enemy
		vision.vertical_fov_deg = 45.0  # Limited vertical coverage

	if hearing:
		hearing.owner_node = self
		hearing.radius = detection_range * 0.6  # Less sensitive than juggernaut

	# Set up animation
	_play_animation_safe("idle")

	# Add to groups
	add_to_group("npc")
	add_to_group("enemies")
	add_to_group("zombies")

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Update cooldowns
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Check for player using vision system (performance optimized)
	if not target and _should_check_vision():
		_check_for_player_vision()

	# State machine
	match current_state:
		State.IDLE:
			_handle_idle_state(delta)
		State.PATROL:
			_handle_patrol_state(delta)
		State.CHASE:
			_handle_chase_state(delta)
		State.ATTACK:
			_handle_attack_state(delta)

	move_and_slide()
	_update_facing_direction()
	_update_animation()

func _handle_idle_state(delta: float) -> void:
	velocity.x = 0
	# Transition to patrol after some time
	if randf() < 0.01:  # 1% chance per frame to start patrolling
		current_state = State.PATROL

func _handle_patrol_state(delta: float) -> void:
	# Simple patrol behavior - move back and forth
	velocity.x = patrol_direction * speed * 0.5
	
	# Change direction periodically or if hitting a wall
	last_direction_change += delta
	if last_direction_change > 3.0 or is_on_wall():
		patrol_direction *= -1
		last_direction_change = 0.0

func _handle_chase_state(delta: float) -> void:
	if not target or not is_instance_valid(target):
		current_state = State.IDLE
		target = null
		return
	
	# Move towards target
	var direction = sign(target.global_position.x - global_position.x)
	velocity.x = direction * speed * aggression_multiplier
	
	# Check if close enough to attack
	var distance = abs(target.global_position.x - global_position.x)
	if distance <= attack_range:
		current_state = State.ATTACK

func _handle_attack_state(delta: float) -> void:
	velocity.x = 0
	
	if attack_cooldown <= 0:
		_perform_attack()
		attack_cooldown = 1.5  # Attack every 1.5 seconds
	
	# Return to chase if target moves away
	if target and is_instance_valid(target):
		var distance = abs(target.global_position.x - global_position.x)
		if distance > attack_range * 1.2:
			current_state = State.CHASE

func _perform_attack() -> void:
	if animated_sprite:
		animated_sprite.play("attack")
	
	# Deal damage to player if in range
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var distance = abs(target.global_position.x - global_position.x)
		if distance <= attack_range:
			target.take_damage(attack_damage * aggression_multiplier)
			player_attacked.emit(attack_damage * aggression_multiplier)

func _update_facing_direction() -> void:
	if abs(velocity.x) > 0.1:
		is_facing_right = velocity.x > 0
		if animated_sprite:
			animated_sprite.flip_h = not is_facing_right

func _update_animation() -> void:
	if not animated_sprite:
		return

	match current_state:
		State.IDLE:
			_play_animation_safe("idle")
		State.PATROL:
			_play_animation_safe("walk")
		State.CHASE:
			_play_animation_safe("run")
		State.ATTACK:
			if not animated_sprite.is_playing() or animated_sprite.animation != "attack":
				_play_animation_safe("attack")
		State.DEAD:
			_play_animation_safe("death")

func _on_detection_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		current_state = State.CHASE
		print("🧟 Zombie detected player")

func _on_detection_area_exited(body: Node2D) -> void:
	if body == target:
		# Don't immediately lose target, give some chase time
		if is_inside_tree():
			await get_tree().create_timer(2.0).timeout
		if target == body:  # Still the same target after delay
			target = null
			current_state = State.PATROL

func _on_attack_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and current_state == State.CHASE:
		current_state = State.ATTACK

func _on_attack_area_exited(body: Node2D) -> void:
	if body == target and current_state == State.ATTACK:
		current_state = State.CHASE

func take_damage(damage: float) -> void:
	health -= damage
	if health <= 0:
		_die()
	else:
		# Take damage reaction
		if animated_sprite:
			var original_modulate = animated_sprite.modulate
			animated_sprite.modulate = Color.RED
			await get_tree().create_timer(0.1).timeout
			if animated_sprite:
				animated_sprite.modulate = original_modulate

func _die() -> void:
	current_state = State.DEAD
	set_collision_layer_value(1, false)  # Disable collision
	zombie_died.emit(self)
	
	if animated_sprite:
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	
	queue_free()

# Zone integration methods
func apply_zone_behavior(zone_data: Dictionary) -> void:
	if zone_data.entering:
		enter_zone(zone_data)
	else:
		exit_zone()

func enter_zone(zone_data) -> void:
	current_zone = zone_data
	if zone_data is Zone2D:
		aggression_multiplier = zone_data.spawn_multiplier
		zone_noise_penalty = zone_data.noise_penalty
	elif zone_data is Dictionary:
		aggression_multiplier = zone_data.get("spawn_multiplier", 1.0)
		zone_noise_penalty = zone_data.get("noise_penalty", 1.0)
	else:
		aggression_multiplier = 1.0
		zone_noise_penalty = 1.0

func exit_zone() -> void:
	current_zone = null
	aggression_multiplier = 1.0
	zone_noise_penalty = 1.0

func set_aggression_multiplier(multiplier: float) -> void:
	aggression_multiplier = multiplier

func set_zone_effects(effects: Dictionary) -> void:
	if effects.entering:
		aggression_multiplier = effects.get("spawn_multiplier", 1.0)
		zone_noise_penalty = effects.get("noise_penalty", 1.0)
	else:
		aggression_multiplier = 1.0
		zone_noise_penalty = 1.0

# Vision and hearing perception methods
var vision_check_timer: float = 0.0
var vision_check_interval: float = 0.3  # Basic zombies check less frequently than juggernaut

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
		target = spotted_player
		current_state = State.CHASE
		print("🧟 Basic zombie detected player via vision")

func on_heard_noise(source: Node, intensity: float) -> void:
	# Hearing callback from Hearing2D component
	if current_state == State.DEAD or target:
		return

	# Check if the noise source is a player
	if source.is_in_group("player"):
		target = source
		current_state = State.CHASE
		print("🧟 Basic zombie detected player via hearing")
	elif intensity > 0.5:  # Medium intensity noise attracts basic zombies
		# Move toward the noise source for investigation
		var noise_direction = (source.global_position - global_position).normalized()
		patrol_direction = 1 if noise_direction.x > 0 else -1
		if current_state == State.IDLE:
			current_state = State.PATROL

func get_facing_direction() -> Vector2:
	# Required by Vision2D to determine facing direction
	return Vector2.RIGHT if is_facing_right else Vector2.LEFT
