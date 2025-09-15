extends ICameraRig

# Side-scroller style using 2D camera concepts with 3D disabled usage

func aim_vector() -> Vector3:
    # In 2D, aiming is horizontal along +X
    return Vector3.RIGHT

func screen_reticle_pos() -> Vector2:
    return get_viewport().get_visible_rect().size * 0.5

