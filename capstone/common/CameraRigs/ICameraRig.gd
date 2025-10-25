class_name ICameraRig
extends Node2D

func _ready() -> void:
    # Base implementation for camera rigs
    pass

func aim_vector() -> Vector3:
    return Vector3.ZERO

func screen_reticle_pos() -> Vector2:
    return Vector2.ZERO

func activate() -> void:
    # Base activation for camera rigs
    pass

func deactivate() -> void:
    # Base deactivation for camera rigs
    pass

