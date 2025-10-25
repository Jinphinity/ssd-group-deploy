extends ZombieBasic2D

## Heavy zombie: slow, durable brute with knockback attacks.

class_name ZombieHeavy2D

@export var heavy_health: float = 140.0
@export var heavy_speed: float = 40.0
@export var heavy_attack_damage: float = 22.0
@export var knockback_force: float = 220.0
@export var knockback_vertical: float = 160.0

func _ready() -> void:
	speed = heavy_speed
	attack_damage = heavy_attack_damage
	health = heavy_health
	super._ready()

	if animated_sprite:
		animated_sprite.modulate = Color(0.35, 0.6, 0.4, 1.0)

	var rect := get_node_or_null("ZombieVisual")
	if rect and rect is ColorRect:
		rect.color = Color(0.25, 0.45, 0.3, 1.0)
	var label := get_node_or_null("ZombieVisual/ZombieLabel")
	if label:
		label.text = "HEAVY"
	var bar := get_node_or_null("HealthBar")
	if bar and bar is ProgressBar:
		bar.max_value = heavy_health
		bar.value = heavy_health

func _perform_attack() -> void:
	super._perform_attack()
	if target and is_instance_valid(target) and target is CharacterBody2D:
		var direction: float = sign(target.global_position.x - global_position.x)
		var body := target as CharacterBody2D
		body.velocity.x += knockback_force * direction
		body.velocity.y = min(body.velocity.y - knockback_vertical, -knockback_vertical)
