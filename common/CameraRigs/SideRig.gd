extends ICameraRig

## Side-scroller camera rig for 2D gameplay
## Follows player horizontally with smooth movement and optional vertical tracking

@onready var camera_2d: Camera2D = $Camera2D
@onready var player_follow_target: Node2D = null

# Camera settings
var follow_speed: float = 5.0
var look_ahead_distance: float = 100.0
var vertical_offset: float = 0.0
var camera_bounds: Rect2 = Rect2()
var use_camera_bounds: bool = false

# Smoothing settings
var horizontal_smoothing: float = 0.1
var vertical_smoothing: float = 0.2
var zoom_level: float = 1.0

func _ready() -> void:
    super._ready()
    
    # Create Camera2D if not exists
    if not camera_2d:
        camera_2d = Camera2D.new()
        add_child(camera_2d)
    
    # Configure camera
    camera_2d.enabled = true
    camera_2d.zoom = Vector2(zoom_level, zoom_level)
    
    # Find player target
    _find_player_target()

func _find_player_target() -> void:
    # Look for PlayerSniper first (2D character)
    var player_sniper = get_tree().get_first_node_in_group("player_sniper")
    if player_sniper:
        player_follow_target = player_sniper
        return
    
    # Fall back to regular player if available
    var player = get_tree().get_first_node_in_group("player")
    if player:
        player_follow_target = player

func _process(delta: float) -> void:
    if not camera_2d or not player_follow_target:
        return
    
    _update_camera_position(delta)

func _update_camera_position(delta: float) -> void:
    var target_pos = player_follow_target.global_position
    
    # Add look-ahead based on player movement direction
    var look_ahead = Vector2.ZERO
    if player_follow_target.has_method("get_velocity"):
        var velocity = player_follow_target.get_velocity()
        if velocity.x != 0:
            look_ahead.x = sign(velocity.x) * look_ahead_distance
    
    # Calculate target camera position
    var camera_target = target_pos + look_ahead + Vector2(0, vertical_offset)
    
    # Apply camera bounds if enabled
    if use_camera_bounds:
        camera_target.x = clamp(camera_target.x, camera_bounds.position.x, camera_bounds.end.x)
        camera_target.y = clamp(camera_target.y, camera_bounds.position.y, camera_bounds.end.y)
    
    # Smooth movement
    var current_pos = camera_2d.global_position
    var new_pos = Vector2(
        lerp(current_pos.x, camera_target.x, horizontal_smoothing),
        lerp(current_pos.y, camera_target.y, vertical_smoothing)
    )
    
    camera_2d.global_position = new_pos

func aim_vector() -> Vector3:
    # In 2D side-scroller, aiming is horizontal along +X
    return Vector3.RIGHT

func screen_reticle_pos() -> Vector2:
    return get_viewport().get_visible_rect().size * 0.5

# Configuration methods
func set_follow_target(target: Node2D) -> void:
    player_follow_target = target

func set_camera_bounds(bounds: Rect2) -> void:
    camera_bounds = bounds
    use_camera_bounds = true

func clear_camera_bounds() -> void:
    use_camera_bounds = false

func set_zoom(zoom: float) -> void:
    zoom_level = zoom
    if camera_2d:
        camera_2d.zoom = Vector2(zoom, zoom)

func set_smoothing(horizontal: float, vertical: float) -> void:
    horizontal_smoothing = clamp(horizontal, 0.0, 1.0)
    vertical_smoothing = clamp(vertical, 0.0, 1.0)

func set_look_ahead(distance: float) -> void:
    look_ahead_distance = distance

func set_vertical_offset(offset: float) -> void:
    vertical_offset = offset

# Integration with perspective system
func activate() -> void:
    super.activate()
    if camera_2d:
        camera_2d.enabled = true
        camera_2d.make_current()

func deactivate() -> void:
    super.deactivate()
    if camera_2d:
        camera_2d.enabled = false

