extends Node

## 2D Hearing perception system for side-scrolling gameplay
## Responds to NoiseEmitted events via EventBus with 2D distance calculations

class_name Hearing2D

@export var owner_node: Node2D
@export var radius: float = 150.0

# Side-scrolling specific settings
@export var horizontal_multiplier: float = 1.0  # Hearing sensitivity multiplier for horizontal sounds
@export var vertical_multiplier: float = 0.7    # Reduced sensitivity for vertical sounds in side-scroller

func _ready() -> void:
	if has_node("/root/Game"):
		var game_node = get_node("/root/Game")
		if game_node.has_signal("NoiseEmitted"):
			game_node.NoiseEmitted.connect(_on_noise)
		elif "event_bus" in game_node and game_node.event_bus:
			var bus = game_node.event_bus
			if bus.has_signal("NoiseEmitted"):
				bus.NoiseEmitted.connect(_on_noise)

func _on_noise(source: Node, intensity: float, noise_radius: float) -> void:
	if owner_node == null or source == null:
		return

	# Calculate 2D distance
	var source_pos: Vector2
	if source is Node2D:
		source_pos = source.global_position
	elif source.has_method("get_global_position"):
		var pos = source.get_global_position()
		source_pos = Vector2(pos.x, pos.y) if pos is Vector3 else pos
	else:
		return

	var dist = owner_node.global_position.distance_to(source_pos)
	var effective_radius = max(radius, noise_radius)

	# Apply side-scrolling distance modifiers
	var direction = source_pos - owner_node.global_position
	var horizontal_dist = abs(direction.x)
	var vertical_dist = abs(direction.y)

	# Calculate weighted distance for side-scrolling perspective
	var weighted_dist = sqrt(
		pow(horizontal_dist / horizontal_multiplier, 2) +
		pow(vertical_dist / vertical_multiplier, 2)
	)

	if weighted_dist <= effective_radius:
		if owner_node.has_method("on_heard_noise"):
			# Pass the actual intensity modified by distance
			var distance_factor = 1.0 - (weighted_dist / effective_radius)
			var effective_intensity = intensity * distance_factor
			owner_node.on_heard_noise(source, effective_intensity)

## Get effective hearing range in a given direction
func get_effective_range(direction: Vector2) -> float:
	direction = direction.normalized()
	var horizontal_component = abs(direction.x) * horizontal_multiplier
	var vertical_component = abs(direction.y) * vertical_multiplier
	return radius * max(horizontal_component, vertical_component)

## Check if a position would be audible
func can_hear_at_position(pos: Vector2, noise_intensity: float = 1.0) -> bool:
	if owner_node == null:
		return false

	var direction = pos - owner_node.global_position
	var horizontal_dist = abs(direction.x)
	var vertical_dist = abs(direction.y)

	var weighted_dist = sqrt(
		pow(horizontal_dist / horizontal_multiplier, 2) +
		pow(vertical_dist / vertical_multiplier, 2)
	)

	return weighted_dist <= radius * noise_intensity
