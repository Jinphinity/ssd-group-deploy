extends ICameraRig

@onready var cam: Camera3D = $Camera3D
@export var shoulder_offset: Vector3 = Vector3(0.5, 1.6, -3.0)

func _ready() -> void:
    cam.transform.origin = shoulder_offset

func aim_vector() -> Vector3:
    return -cam.global_transform.basis.z.normalized()

func screen_reticle_pos() -> Vector2:
    return get_viewport().get_visible_rect().size * 0.5

