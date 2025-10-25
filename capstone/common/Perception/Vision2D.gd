extends Node

## 2D Vision perception system for side-scrolling gameplay
## Converts 3D FOV and raycast system to 2D equivalent with side-scrolling optimizations

class_name Vision2D

@export var owner_node: Node2D
@export var fov_deg: float = 90.0
@export var max_dist: float = 200.0

# Side-scrolling specific settings
@export var vertical_fov_deg: float = 45.0  # Reduced vertical FOV for side-scroller
@export var prefer_horizontal: bool = true   # Prioritize horizontal detection

func sees(target: Node2D) -> bool:
	if owner_node == null or target == null:
		return false

	var to_target := target.global_position - owner_node.global_position
	var distance = to_target.length()

	# Distance check
	if distance > max_dist:
		return false

	# FOV check adapted for 2D side-scrolling
	if not _is_in_fov_2d(to_target):
		return false

	# Line of sight check using 2D physics
	return _has_line_of_sight_2d(target)

## 2D FOV calculation optimized for side-scrolling perspective
func _is_in_fov_2d(to_target: Vector2) -> bool:
	# Get owner's facing direction
	var forward = _get_forward_direction_2d()

	# Calculate angle between forward direction and target
	var angle = rad_to_deg(forward.angle_to(to_target.normalized()))

	# For side-scrolling, we want a more forgiving vertical FOV
	if prefer_horizontal:
		# Check horizontal FOV more strictly
		var horizontal_angle = rad_to_deg(Vector2(forward.x, 0).angle_to(Vector2(to_target.x, 0).normalized()))
		if abs(horizontal_angle) > fov_deg * 0.5:
			return false

		# Check vertical FOV more leniently
		var vertical_angle = rad_to_deg(Vector2(0, forward.y).angle_to(Vector2(0, to_target.y).normalized()))
		if abs(vertical_angle) > vertical_fov_deg * 0.5:
			return false

		return true
	else:
		# Standard circular FOV
		return abs(angle) <= fov_deg * 0.5

## Get 2D forward direction based on owner's orientation
func _get_forward_direction_2d() -> Vector2:
	# For CharacterBody2D, determine facing based on scale or a facing property
	if owner_node.has_method("get_facing_direction"):
		return owner_node.get_facing_direction()

	# For AnimatedSprite2D, check flip_h
	var sprite = owner_node.get_node_or_null("AnimatedSprite2D")
	if sprite and sprite is AnimatedSprite2D:
		return Vector2.RIGHT if not sprite.flip_h else Vector2.LEFT

	# Check if owner has a facing property or scale-based facing
	if owner_node.has_meta("facing_direction"):
		var facing = owner_node.get_meta("facing_direction")
		if facing is Vector2:
			return facing.normalized()
		elif facing is bool:
			return Vector2.RIGHT if facing else Vector2.LEFT

	# Check scale-based facing (common pattern)
	if owner_node.scale.x < 0:
		return Vector2.LEFT

	# Default to facing right
	return Vector2.RIGHT

## 2D line of sight check using PhysicsRayQueryParameters2D
func _has_line_of_sight_2d(target: Node2D) -> bool:
	var space = owner_node.get_world_2d().direct_space_state
	if space == null:
		return false

	# Create raycast from owner to target
	var query = PhysicsRayQueryParameters2D.create(
		owner_node.global_position,
		target.global_position
	)

	# Exclude the owner from the raycast
	query.exclude = [owner_node.get_rid()]

	# Set collision mask to check against walls/obstacles (layer 1 typically)
	query.collision_mask = 1  # World layer

	var result = space.intersect_ray(query)

	# If no collision, clear line of sight
	if result.is_empty():
		return true

	# If collision, check if it's the target we're looking for
	var collider = result.get("collider")
	return collider == target

## Get the facing direction as a normalized Vector2
func get_facing_direction() -> Vector2:
	return _get_forward_direction_2d()

## Set explicit facing direction (useful for manual control)
func set_facing_direction(direction: Vector2) -> void:
	if owner_node:
		owner_node.set_meta("facing_direction", direction.normalized())

## Debug visualization (useful for development)
func debug_draw_fov() -> void:
	if not owner_node:
		return

	# This would be implemented with a CanvasItem for visual debugging
	# Left as placeholder for development debugging needs
	pass

## Performance-optimized batch vision check for multiple targets
func sees_any(targets: Array[Node2D]) -> Node2D:
	if owner_node == null or targets.is_empty():
		return null

	var closest_target: Node2D = null
	var closest_distance: float = INF

	# Pre-calculate forward direction once
	var forward = _get_forward_direction_2d()

	for target in targets:
		if target == null:
			continue

		var to_target = target.global_position - owner_node.global_position
		var distance = to_target.length()

		# Skip if too far
		if distance > max_dist:
			continue

		# Skip if not in FOV
		if not _is_in_fov_2d(to_target):
			continue

		# Track closest valid target for final line of sight check
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target

	# Only do expensive raycast on the closest valid target
	if closest_target and _has_line_of_sight_2d(closest_target):
		return closest_target

	return null

## Get all visible targets (more expensive, use sparingly)
func get_visible_targets(targets: Array[Node2D]) -> Array[Node2D]:
	var visible: Array[Node2D] = []

	for target in targets:
		if sees(target):
			visible.append(target)

	return visible