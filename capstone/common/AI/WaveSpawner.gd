extends Node3D

@export var zombie_scene: PackedScene = preload("res://entities/NPC/Zombie_Basic.tscn")
@export var initial_count: int = 20
@export var max_count: int = 40
@export var radius: float = 20.0
@export var spawn_interval: float = 30.0  # Seconds between spawn waves
@export var spawn_per_wave: int = 3

signal spawn_rate_changed(spawner: Node, new_rate: float)

var base_spawn_interval: float = 30.0
var zone_multiplier: float = 1.0
var current_spawn_interval: float = 30.0
var spawned_count: int = 0

func _ready() -> void:
    # Store base values
    base_spawn_interval = spawn_interval
    current_spawn_interval = spawn_interval

    # Add to spawner group for zone system
    add_to_group("wave_spawners")

    # Spawn initial wave
    _spawn_initial_wave()

    # Set up continuous spawning timer
    var spawn_timer := Timer.new()
    spawn_timer.wait_time = current_spawn_interval
    spawn_timer.timeout.connect(_spawn_wave)
    spawn_timer.autostart = true
    add_child(spawn_timer)

func _spawn_initial_wave() -> void:
    """Spawn initial zombie wave"""
    for i in initial_count:
        _spawn_zombie()

func _spawn_wave() -> void:
    """Spawn a wave of zombies"""
    var current_npc_count = get_tree().get_nodes_in_group("npc").size()

    # Don't spawn if we're at max capacity
    if current_npc_count >= max_count:
        return

    # Spawn new wave
    var spawn_count = min(spawn_per_wave, max_count - current_npc_count)
    for i in spawn_count:
        _spawn_zombie()

    print("🌊 Spawned %d zombies (total NPCs: %d)" % [spawn_count, current_npc_count + spawn_count])

func _spawn_zombie() -> void:
    """Spawn a single zombie at a random position"""
    if not zombie_scene:
        print("❌ No zombie scene configured for spawner")
        return

    var z: Node3D = zombie_scene.instantiate()
    var ang := randf() * TAU
    var r := randf() * radius
    z.global_transform.origin = global_transform.origin + Vector3(cos(ang)*r, 0, sin(ang)*r)

    # Add to scene
    get_tree().current_scene.add_child(z)
    spawned_count += 1

func set_zone_multiplier(multiplier: float) -> void:
    """Set spawn rate multiplier from zone system"""
    zone_multiplier = multiplier
    _update_spawn_rate()

func _update_spawn_rate() -> void:
    """Update spawn rate based on zone multiplier"""
    var old_interval = current_spawn_interval
    current_spawn_interval = base_spawn_interval / zone_multiplier

    # Clamp to reasonable values
    current_spawn_interval = clamp(current_spawn_interval, 5.0, 120.0)

    # Update timer if interval changed significantly
    if abs(current_spawn_interval - old_interval) > 1.0:
        var timer = get_children().filter(func(child): return child is Timer)
        if timer.size() > 0:
            timer[0].wait_time = current_spawn_interval

        spawn_rate_changed.emit(self, 1.0 / current_spawn_interval)
        print("⏱️ Spawn rate updated: %.1fs interval (zone multiplier: %.1fx)" % [current_spawn_interval, zone_multiplier])

func get_spawn_stats() -> Dictionary:
    """Get spawner statistics"""
    var current_npc_count = get_tree().get_nodes_in_group("npc").size()
    return {
        "spawned_total": spawned_count,
        "current_npcs": current_npc_count,
        "max_count": max_count,
        "spawn_interval": current_spawn_interval,
        "zone_multiplier": zone_multiplier,
        "can_spawn": current_npc_count < max_count
    }

func force_spawn_wave() -> void:
    """Force spawn a wave immediately"""
    _spawn_wave()

func set_max_count(new_max: int) -> void:
    """Set maximum NPC count"""
    max_count = new_max

func clear_all_npcs() -> void:
    """Clear all spawned NPCs"""
    var npcs = get_tree().get_nodes_in_group("npc")
    for npc in npcs:
        if npc and is_instance_valid(npc):
            npc.queue_free()
    spawned_count = 0

