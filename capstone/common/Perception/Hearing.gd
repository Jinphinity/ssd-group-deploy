extends Node

## Hearing model: respond to NoiseEmitted via EventBus

class_name Hearing

@export var owner_node: Node3D
@export var radius: float = 15.0

func _ready() -> void:
    if has_node("/root/Game"):
        var bus = get_node("/root/Game").event_bus
        bus.connect("NoiseEmitted", Callable(self, "_on_noise"))

func _on_noise(source: Node, intensity: float, r: float) -> void:
    if owner_node == null or source == null:
        return
    var dist := owner_node.global_transform.origin.distance_to(source.global_transform.origin)
    if dist <= max(radius, r):
        if owner_node.has_method("on_heard_noise"):
            owner_node.on_heard_noise(source, intensity)

