extends IMovementController

@export var owner_body: CharacterBody3D
@export var speed: float = 6.0
@export var accel: float = 12.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity");

var _vel: Vector3 = Vector3.ZERO

func move(input: Dictionary, delta: float) -> void:
    if owner_body == null:
        return
    var dir := Vector3.ZERO
    dir.z -= int(Input.is_action_pressed("move_forward"))
    dir.z += int(Input.is_action_pressed("move_back"))
    dir.x -= int(Input.is_action_pressed("move_left"))
    dir.x += int(Input.is_action_pressed("move_right"))
    if dir.length() > 0.001:
        dir = dir.normalized()
    # Transform to camera space if provided
    var basis := owner_body.global_transform.basis
    var move_vec := (basis.x * dir.x) + (basis.z * dir.z)
    move_vec.y = 0.0
    move_vec = move_vec.normalized() * speed

    _vel.x = lerp(_vel.x, move_vec.x, min(1.0, accel * delta))
    _vel.z = lerp(_vel.z, move_vec.z, min(1.0, accel * delta))
    _vel.y -= gravity * delta

    owner_body.velocity = _vel
    owner_body.move_and_slide()

