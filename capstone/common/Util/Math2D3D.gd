extends Node

class_name Math2D3D

static func clamp01(v: float) -> float:
    return clamp(v, 0.0, 1.0)

static func lerp_angle_wrap(a: float, b: float, t: float) -> float:
    return lerp_angle(a, b, t)
