extends ICameraRig

@onready var cam: Camera3D = $Camera3D

func aim_vector() -> Vector3:
    return -cam.global_transform.basis.z.normalized()

func screen_reticle_pos() -> Vector2:
    return get_viewport().get_visible_rect().size * 0.5

