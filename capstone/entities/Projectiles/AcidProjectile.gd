extends Area2D

## Simple acid projectile for Ranger zombies.

class_name AcidProjectile

@export var lifespan_seconds: float = 6.0
@export var default_speed: float = 320.0
@export var default_damage: float = 5.0

var velocity: Vector2 = Vector2.ZERO
var damage: float = 5.0
var effect_payload: Dictionary = {}
var _life_timer: float = 0.0

func _ready() -> void:
	_life_timer = lifespan_seconds
	damage = default_damage
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func configure(direction: Vector2, projectile_damage: float, effect: Dictionary = {}) -> void:
	velocity = direction
	damage = projectile_damage
	effect_payload = effect.duplicate(true)

func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	global_position += velocity * delta
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	_apply_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("terrain"):
		queue_free()

func _apply_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("apply_damage"):
		target.apply_damage(damage, "torso")
	elif target.has_method("take_damage"):
		target.take_damage(damage)

	if effect_payload.get("effect_id", "") != "":
		var manager := StatusEffectManager.get_singleton()
		if manager:
			manager.apply_effect(target, effect_payload.get("effect_id", ""), effect_payload)

	queue_free()
