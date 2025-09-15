extends CharacterBody3D

@export var speed: float = 2.5
@export var preferred_range: float = 10.0
@export var cooldown: float = 2.0
@export var vision: Vision

var target: Node3D = null
var health: float = 40.0
var _cd: float = 0.0

func _ready() -> void:
    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)

func _physics_process(delta: float) -> void:
    _cd = max(0.0, _cd - delta)
    if target == null:
        target = get_tree().get_first_node_in_group("player")
    if target and vision.sees(target):
        var to := (target.global_transform.origin - global_transform.origin)
        var dist := to.length()
        to.y = 0
        var dir := to.normalized()
        if dist > preferred_range * 1.2:
            velocity = dir * speed
        elif dist < preferred_range * 0.8:
            velocity = -dir * speed
        else:
            velocity = Vector3.ZERO
            if _cd == 0.0:
                _spit_acid(dir)
                _cd = cooldown
    else:
        velocity = Vector3.ZERO
    move_and_slide()

func _spit_acid(dir: Vector3) -> void:
    var scene: PackedScene = preload("res://entities/Projectiles/AcidProjectile.tscn")
    var proj: Node3D = scene.instantiate()
    proj.global_transform.origin = global_transform.origin + Vector3(0, 1.2, 0)
    if proj.has_method("launch"):
        proj.launch(dir)
    get_tree().current_scene.add_child(proj)

func apply_damage(amount: float, _bodypart: String = "torso") -> void:
    health = max(0.0, health - amount)
    if health == 0.0:
        queue_free()

