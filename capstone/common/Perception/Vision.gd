extends Node

## Simple FOV check with rough occlusion

class_name Vision

@export var owner_node: Node3D
@export var fov_deg: float = 90.0
@export var max_dist: float = 20.0

func sees(target: Node3D) -> bool:
    if owner_node == null or target == null:
        return false
    var to_target := (target.global_transform.origin - owner_node.global_transform.origin)
    if to_target.length() > max_dist:
        return false
    # Forward in Godot 3D is -Z
    var forward := -owner_node.global_transform.basis.z.normalized()
    var angle := rad_to_deg(forward.angle_to(to_target.normalized()))
    if angle > fov_deg * 0.5:
        return false
    var space := owner_node.get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(owner_node.global_transform.origin, target.global_transform.origin)
    var result := space.intersect_ray(query)
    if result.size() == 0:
        return true
    return result.get("collider") == target

