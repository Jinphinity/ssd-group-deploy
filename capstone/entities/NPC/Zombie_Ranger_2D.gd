extends CharacterBody2D

## Ranger zombie: ranged acid attacks with status effects.

class_name ZombieRanger2D

@export var move_speed: float = 70.0
@export var detection_range: float = 320.0
@export var attack_cooldown: float = 2.5
@export var projectile_scene: PackedScene = preload("res://entities/Projectiles/AcidProjectile.tscn")
@export var projectile_speed: float = 300.0
@export var projectile_damage: float = 6.0
@export var projectile_spread_deg: float = 6.0
@export var status_duration: float = 6.0
@export var status_damage_per_second: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var target: Node2D = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var _attack_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _play_animation_safe(animation_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif animated_sprite.sprite_frames.get_animation_names().size() > 0:
		# Fallback to first available animation
		animated_sprite.play(animated_sprite.sprite_frames.get_animation_names()[0])

func _ready() -> void:
	_rng.randomize()
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	add_to_group("npc")
	_play_animation_safe("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if target and is_instance_valid(target):
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * move_speed
		if animated_sprite:
			animated_sprite.flip_h = dir < 0
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_perform_ranged_attack()
	else:
		velocity.x = 0.0
	move_and_slide()

func _on_detection_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body

func _on_detection_exited(body: Node) -> void:
	if body == target:
		target = null

func _perform_ranged_attack() -> void:
	if projectile_scene == null or target == null or not is_instance_valid(target):
		return
	var projectile = projectile_scene.instantiate()
	var direction: Vector2 = (target.global_position - global_position).normalized()
	direction = direction.rotated(deg_to_rad(_rng.randf_range(-projectile_spread_deg, projectile_spread_deg)))
	projectile.global_position = global_position + direction * 24.0
	if projectile.has_method("configure"):
		projectile.configure(direction * projectile_speed, projectile_damage, {
			"effect_id": "acid",
			"duration": status_duration,
			"damage_per_second": status_damage_per_second
		})
	get_tree().current_scene.add_child(projectile)
	_attack_timer = attack_cooldown
	_play_animation_safe("attack")

func apply_damage(amount: float, bodypart: String = "torso") -> void:
	queue_free()
