extends Node

## World time & scheduler

signal tick(dt)

var time_scale := 1.0
var accumulator := 0.0
var step := 0.2 # economic/AI tick

func _process(delta: float) -> void:
    accumulator += delta * time_scale
    if accumulator >= step:
        accumulator -= step
        emit_signal("tick", step)

