extends CharacterBody3D

@export var speed: float = 1.8
@export var vision: Vision
@export var vulnerability: float = 1.2 # extra damage from AoE/shotgun (approx)

var target: Node3D = null
var health: float = 200.0

func _ready() -> void:
    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)

func _physics_process(_dt: float) -> void:
    if target == null:
        target = get_tree().get_first_node_in_group("player")
    if target and vision.sees(target):
        var dir := (target.global_transform.origin - global_transform.origin)
        dir.y = 0
        velocity = dir.normalized() * speed
    else:
        velocity = Vector3.ZERO
    move_and_slide()

func apply_damage(amount: float, _body: String = "torso") -> void:
    var final := amount * vulnerability
    health = max(0.0, health - final)
    if health == 0.0:
        queue_free()

