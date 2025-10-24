extends IMovementController

@export var owner_body: CharacterBody2D
@export var speed: float = 200.0
@export var accel: float = 12.0

var _vel: Vector2 = Vector2.ZERO

func move(input: Dictionary, delta: float) -> void:
    if owner_body == null:
        return
    var dir := Vector2.ZERO
    dir.y -= int(Input.is_action_pressed("move_forward"))
    dir.y += int(Input.is_action_pressed("move_back"))
    dir.x -= int(Input.is_action_pressed("move_left"))
    dir.x += int(Input.is_action_pressed("move_right"))
    if dir.length() > 0.001:
        dir = dir.normalized()
    var target := dir * speed
    _vel.x = lerp(_vel.x, target.x, min(1.0, accel * delta))
    _vel.y = lerp(_vel.y, target.y, min(1.0, accel * delta))
    owner_body.velocity = _vel
    owner_body.move_and_slide()

