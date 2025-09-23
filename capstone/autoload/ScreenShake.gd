extends Node

# ScreenShake autoload for system-wide screen shake effects
# Demonstrates GODOT-AEGIS pattern for reusable game systems

signal shake_requested(intensity: float, duration: float)

# Current shake state
var trauma: float = 0.0
var trauma_power: float = 2.0
var decay_rate: float = 1.3
var max_offset: float = 50.0
var max_roll: float = 0.1

# Noise for shake variation
var noise: FastNoiseLite
var noise_speed: float = 150.0
var time: float = 0.0

func _ready() -> void:
    # Initialize noise for varied shake patterns
    noise = FastNoiseLite.new()
    noise.seed = randi()
    noise.frequency = 4.0

    print("=== SCREENSHAKE SYSTEM INITIALIZED ===")

func _process(delta: float) -> void:
    # Decay trauma over time
    if trauma > 0.0:
        trauma = max(trauma - decay_rate * delta, 0.0)

    # Update time for noise sampling
    time += delta

func add_trauma(amount: float) -> void:
    """Add trauma to trigger screen shake"""
    trauma = min(trauma + amount, 1.0)
    print("🌪️ Screen shake trauma added: %.2f (total: %.2f)" % [amount, trauma])

func get_shake_offset() -> Vector2:
    """Get current shake offset for cameras"""
    if trauma == 0.0:
        return Vector2.ZERO

    var amount = pow(trauma, trauma_power)

    # Use noise for varied shake
    var shake_x = noise.get_noise_1d(time * noise_speed) * max_offset * amount
    var shake_y = noise.get_noise_1d(time * noise_speed + 100) * max_offset * amount

    return Vector2(shake_x, shake_y)

func get_shake_rotation() -> float:
    """Get current shake rotation for cameras"""
    if trauma == 0.0:
        return 0.0

    var amount = pow(trauma, trauma_power)
    return noise.get_noise_1d(time * noise_speed + 200) * max_roll * amount

func apply_shake_to_camera(camera: Camera3D) -> void:
    """Apply shake effects to a 3D camera"""
    if not camera:
        return

    var offset = get_shake_offset()
    var rotation = get_shake_rotation()

    # Apply translation shake
    camera.position += Vector3(offset.x * 0.01, offset.y * 0.01, 0)

    # Apply rotation shake
    camera.rotation_degrees += Vector3(rotation * 57.3, 0, 0)

func apply_shake_to_ui(ui_node: CanvasLayer) -> void:
    """Apply shake effects to UI elements"""
    if not ui_node:
        return

    var offset = get_shake_offset()
    ui_node.offset = offset

# Public interface for triggering shakes
func shake_weak(duration: float = 0.3) -> void:
    """Light screen shake for minor events"""
    add_trauma(0.2)

func shake_medium(duration: float = 0.5) -> void:
    """Medium screen shake for standard attacks"""
    add_trauma(0.4)

func shake_strong(duration: float = 0.8) -> void:
    """Strong screen shake for powerful events"""
    add_trauma(0.6)

func shake_explosion(duration: float = 1.0) -> void:
    """Intense screen shake for explosions"""
    add_trauma(1.0)

func shake_custom(intensity: float, duration: float = 0.5) -> void:
    """Custom screen shake with specified intensity"""
    add_trauma(intensity)
    emit_signal("shake_requested", intensity, duration)

# Utility methods
func is_shaking() -> bool:
    """Check if screen is currently shaking"""
    return trauma > 0.0

func get_trauma_level() -> float:
    """Get current trauma level (0.0 - 1.0)"""
    return trauma

func stop_shake() -> void:
    """Immediately stop all screen shake"""
    trauma = 0.0
    print("🛑 Screen shake stopped")

# Integration with existing game events
func _on_weapon_fired(_player, _params) -> void:
    """React to weapon fire events"""
    shake_weak(0.2)

func _on_explosion_triggered(_position, _intensity) -> void:
    """React to explosion events"""
    shake_explosion(1.0)

func _on_player_leveled_up(_level, _stat_points) -> void:
    """React to level up events"""
    shake_medium(0.5)