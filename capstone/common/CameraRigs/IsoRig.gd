extends ICameraRig

@onready var cam: Camera3D = $Camera3D
@export var height: float = 12.0
@export var tilt_deg: float = 60.0

func _ready() -> void:
    cam.transform.origin = Vector3(0, height, 0)
    cam.rotation_degrees.x = tilt_deg

func aim_vector() -> Vector3:
    return Vector3.DOWN

func screen_reticle_pos() -> Vector2:
    return get_viewport().get_visible_rect().size * 0.5
