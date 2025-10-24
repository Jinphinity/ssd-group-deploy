extends Node2D

@export var zombie_scene: PackedScene = preload("res://entities/NPC/Zombie_Basic_2D.tscn")
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_weights: PackedFloat32Array = PackedFloat32Array()
@export var enemy_initial_counts: PackedInt32Array = PackedInt32Array()
@export var enemy_wave_counts: PackedInt32Array = PackedInt32Array()
@export var alert_spawn_bonus: int = 3
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

var _rng := RandomNumberGenerator.new()
var _spawn_timer: Timer
var _spawn_markers: Array[Node2D] = []
var _normalized_enemy_weights: Array[float] = []
var _normalized_initial_counts: Array[int] = []
var _normalized_wave_counts: Array[int] = []

func _ready() -> void:
	base_spawn_interval = spawn_interval
	current_spawn_interval = spawn_interval
	_rng.randomize()

	add_to_group("wave_spawners")
	add_to_group("enemy_spawners")

	if has_node("SpawnPoints"):
		for child in get_node("SpawnPoints").get_children():
			if child is Node2D:
				_spawn_markers.append(child)

	_initialize_enemy_profiles()
	_spawn_initial_wave()
	_setup_spawn_timer()
	_connect_event_bus()

func _initialize_enemy_profiles() -> void:
	if enemy_scenes.is_empty():
		if zombie_scene:
			enemy_scenes = [zombie_scene]
		else:
			return

	_normalized_enemy_weights.clear()
	_normalized_initial_counts.clear()
	_normalized_wave_counts.clear()

	for i in range(enemy_scenes.size()):
		var weight := 1.0
		if enemy_weights.size() > i:
			weight = float(enemy_weights[i])
		if weight <= 0.0:
			weight = 0.01
		_normalized_enemy_weights.append(weight)

		var init_count := initial_count
		if enemy_initial_counts.size() > i:
			init_count = int(enemy_initial_counts[i])
		elif enemy_scenes.size() > 0:
			init_count = int(round(float(initial_count) / float(enemy_scenes.size())))
		_normalized_initial_counts.append(max(init_count, 0))

		var wave_count := spawn_per_wave
		if enemy_wave_counts.size() > i:
			wave_count = int(enemy_wave_counts[i])
		elif enemy_scenes.size() > 0:
			wave_count = int(max(1, round(float(spawn_per_wave) / max(float(enemy_scenes.size()), 1.0))))
		_normalized_wave_counts.append(max(wave_count, 0))

func _setup_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = current_spawn_interval
	_spawn_timer.timeout.connect(_spawn_wave)
	_spawn_timer.autostart = true
	add_child.call_deferred(_spawn_timer)

func _connect_event_bus() -> void:
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game and game.has_method("get"):
			var bus = game.get("event_bus")
			if bus and bus.has_signal("WaveSpawnerAlert") and not bus.is_connected("WaveSpawnerAlert", Callable(self, "_on_wave_alert")):
				bus.connect("WaveSpawnerAlert", Callable(self, "_on_wave_alert"))

func _current_npc_count() -> int:
	return get_tree().get_nodes_in_group("npc").size()

func _spawn_initial_wave() -> void:
	if enemy_scenes.is_empty():
		return
	var spawned_this_pass := 0
	var capacity: int = max(0, max_count - _current_npc_count())
	for i in range(enemy_scenes.size()):
		var count: int = min(_normalized_initial_counts[i], max(0, capacity - spawned_this_pass))
		for _unused in range(count):
			_spawn_enemy(i)
			spawned_this_pass += 1
			if spawned_this_pass >= capacity:
				return

func _spawn_wave() -> void:
	var current_npcs := _current_npc_count()
	if current_npcs >= max_count:
		return

	var capacity: int = max_count - current_npcs
	var spawned_this_wave := 0

	for i in range(enemy_scenes.size()):
		var count: int = min(_normalized_wave_counts[i], capacity - spawned_this_wave)
		for _unused in range(count):
			_spawn_enemy(i)
			spawned_this_wave += 1
			if spawned_this_wave >= capacity:
				break
		if spawned_this_wave >= capacity:
			break

	while spawned_this_wave < capacity and capacity > 0:
		_spawn_enemy(_pick_enemy_index())
		spawned_this_wave += 1

	if spawned_this_wave > 0:
		print("🌊 Spawned %d enemies (total NPCs: %d)" % [spawned_this_wave, _current_npc_count()])

func _pick_enemy_index() -> int:
	if _normalized_enemy_weights.is_empty():
		return 0
	var total_weight := 0.0
	for weight in _normalized_enemy_weights:
		total_weight += weight
	if total_weight <= 0.0:
		return 0
	var pick := _rng.randf_range(0.0, total_weight)
	var accumulator := 0.0
	for i in range(_normalized_enemy_weights.size()):
		accumulator += _normalized_enemy_weights[i]
		if pick <= accumulator:
			return i
	return _normalized_enemy_weights.size() - 1

func _spawn_enemy(index: int) -> void:
	if index < 0 or index >= enemy_scenes.size():
		return
	var scene := enemy_scenes[index]
	if scene == null:
		return

	var enemy_instance = scene.instantiate()
	if enemy_instance == null:
		return

	var spawn_position := global_position
	if _spawn_markers.size() > 0:
		var marker: Node2D = _spawn_markers[_rng.randi_range(0, _spawn_markers.size() - 1)]
		var jitter := Vector2(_rng.randf_range(-radius, radius), _rng.randf_range(-radius, radius))
		spawn_position = marker.global_position + jitter
	else:
		var ang := _rng.randf() * TAU
		var r := _rng.randf() * radius
		spawn_position += Vector2(cos(ang) * r, sin(ang) * r)

	if enemy_instance is Node2D:
		var enemy_node := enemy_instance as Node2D
		enemy_node.global_position = spawn_position
		get_tree().current_scene.add_child.call_deferred(enemy_node)
		spawned_count += 1

func set_zone_multiplier(multiplier: float) -> void:
	zone_multiplier = multiplier
	_update_spawn_rate()

func _update_spawn_rate() -> void:
	var old_interval = current_spawn_interval
	current_spawn_interval = base_spawn_interval / max(zone_multiplier, 0.01)
	current_spawn_interval = clamp(current_spawn_interval, 5.0, 120.0)

	if abs(current_spawn_interval - old_interval) > 0.1 and _spawn_timer:
		_spawn_timer.wait_time = current_spawn_interval
		spawn_rate_changed.emit(self, 1.0 / current_spawn_interval)
		print("⏱️ Spawn rate updated: %.1fs interval (zone multiplier: %.1fx)" % [current_spawn_interval, zone_multiplier])

func get_spawn_stats() -> Dictionary:
	return {
		"spawned_total": spawned_count,
		"current_npcs": _current_npc_count(),
		"max_count": max_count,
		"spawn_interval": current_spawn_interval,
		"zone_multiplier": zone_multiplier,
		"can_spawn": _current_npc_count() < max_count,
		"profiles": enemy_scenes.size()
	}

func force_spawn_wave() -> void:
	_spawn_wave()

func set_max_count(new_max: int) -> void:
	max_count = new_max

func _apply_difficulty_scaling(modifiers: Dictionary) -> void:
	var spawn_rate_multiplier = modifiers.get("spawn_rate_multiplier", 1.0)
	current_spawn_interval = base_spawn_interval / max(spawn_rate_multiplier, 0.01)
	current_spawn_interval = clamp(current_spawn_interval, 5.0, 120.0)
	if _spawn_timer:
		_spawn_timer.wait_time = current_spawn_interval
	print("🌊 WaveSpawner difficulty scaling applied: %.1fx spawn rate (%.1fs interval)" % [spawn_rate_multiplier, current_spawn_interval])

func clear_all_npcs() -> void:
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc and is_instance_valid(npc):
			npc.queue_free()
	spawned_count = 0

func _on_wave_alert(payload: Dictionary) -> void:
	var extra := int(payload.get("count", alert_spawn_bonus))
	extra = max(extra, 0)
	if extra == 0:
		return
	var capacity: int = max(0, max_count - _current_npc_count())
	var to_spawn: int = min(extra, capacity)
	for _unused in range(to_spawn):
		_spawn_enemy(_pick_enemy_index())
	if to_spawn > 0:
		print("🚨 Alarm triggered additional spawn: %d enemies" % to_spawn)
