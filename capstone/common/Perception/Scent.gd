extends Node

## Simple scent tracker with time decay

class_name Scent

var trail: Array = [] # [{pos:Vector3, t:float}]
@export var decay_time: float = 10.0

func add_mark(pos: Vector3) -> void:
    trail.append({"pos": pos, "t": Time.get_ticks_msec() / 1000.0})
    _prune()

func get_recent_positions(window: float = 3.0) -> Array:
    var now := Time.get_ticks_msec() / 1000.0
    var out := []
    for m in trail:
        if now - m.t <= window:
            out.append(m.pos)
    return out

func _prune() -> void:
    var now := Time.get_ticks_msec() / 1000.0
    trail = trail.filter(func(m): return now - m.t <= decay_time)

