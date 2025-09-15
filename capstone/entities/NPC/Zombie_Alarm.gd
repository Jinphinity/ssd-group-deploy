extends CharacterBody3D

@export var speed: float = 2.8
@export var vision: Vision
@export var scream_radius: float = 25.0
@export var cooldown: float = 6.0

var target: Node3D = null
var health: float = 35.0
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
        if _cd == 0.0:
            _scream()
            _cd = cooldown
        var dir := (target.global_transform.origin - global_transform.origin)
        dir.y = 0
        velocity = dir.normalized() * speed
    else:
        velocity = Vector3.ZERO
    move_and_slide()

func _scream() -> void:
    if has_node("/root/Game"):
        get_node("/root/Game").event_bus.emit_signal("NoiseEmitted", self, 100.0, scream_radius)
    # Optional: spawn a couple of basics nearby
    var scene: PackedScene = preload("res://entities/NPC/Zombie_Basic.tscn")
    for i in 2:
        var z = scene.instantiate()
        z.global_transform.origin = global_transform.origin + Vector3(randf()*2.0-1.0, 0, randf()*2.0-1.0)
        get_tree().current_scene.add_child(z)

func apply_damage(amount: float, _body: String = "torso") -> void:
    health = max(0.0, health - amount)
    if health == 0.0:
        queue_free()

