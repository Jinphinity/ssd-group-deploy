extends Node

## Unified hitscan/projectile adapter

class_name Ballistics

signal weapon_fired(params)

var max_distance := 200.0

func fire(origin: Vector3, direction: Vector3, damage: float, layers: int = 1) -> Dictionary:
    var params = {"origin": origin, "dir": direction}
    emit_signal("weapon_fired", params)
    if has_node("/root/Game"):
        get_node("/root/Game").event_bus.emit_signal("WeaponFired", 0, params)
    var space := get_world_3d().direct_space_state
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * max_distance)
    query.collision_mask = layers
    var hit := space.intersect_ray(query)
    if hit.size() > 0:
        var target := hit.get("collider")
        if target and target.has_method("apply_damage"):
            target.apply_damage(damage, "torso")
    return hit
