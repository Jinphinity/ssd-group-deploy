extends Node3D

@export var zombie_scene: PackedScene = preload("res://entities/NPC/Zombie_Basic.tscn")
@export var count: int = 20
@export var radius: float = 20.0

func _ready() -> void:
    for i in count:
        var z: Node3D = zombie_scene.instantiate()
        var ang := randf() * TAU
        var r := randf() * radius
        z.global_transform.origin = global_transform.origin + Vector3(cos(ang)*r, 0, sin(ang)*r)
        get_tree().current_scene.add_child(z)

