extends Area3D

@export var speed: float = 12.0
@export var dot: float = 2.0
@export var duration: float = 4.0

var _dir := Vector3.ZERO

func launch(dir: Vector3) -> void:
    _dir = dir.normalized()

func _process(delta: float) -> void:
    translate(_dir * speed * delta)

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    get_tree().create_timer(6.0).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
    if body and body.has_method("apply_biominetrap"):
        body.apply_biominetrap(0.5, dot, duration)
    elif body and body.has_method("apply_damage"):
        body.apply_damage(dot * 2.0, "torso")
    queue_free()

