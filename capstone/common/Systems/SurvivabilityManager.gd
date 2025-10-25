extends Node

## Centralized nourishment & sleep decay scheduler.
## Keeps offline snapshots and emits change events for UI/logging.

class_name SurvivabilityManager

signal survivability_changed(actor_id: int, snapshot: Dictionary)

const EVENT_SIGNAL := "SurvivabilityChanged"

var _survivors: Array[Node] = []
var _last_snapshots: Dictionary = {}
var _process_fallback := true

func _ready() -> void:
	_connect_game_time()
	set_process(true)

func register_survivor(actor: Node) -> void:
	if actor == null:
		return
	if _survivors.has(actor):
		return
	_survivors.append(actor)
	_update_snapshot(actor, true)

func unregister_survivor(actor: Node) -> void:
	if actor == null:
		return
	var actor_id := actor.get_instance_id()
	_survivors.erase(actor)
	_last_snapshots.erase(actor_id)

func notify_manual_update(actor: Node) -> void:
	_update_snapshot(actor, false)

func _process(delta: float) -> void:
	if not _process_fallback:
		return
	_step(delta)

func _on_tick(step: float) -> void:
	_step(step)

func _step(delta: float) -> void:
	if delta <= 0.0:
		return
	var to_remove: Array[Node] = []
	for actor in _survivors:
		if not is_instance_valid(actor) or not actor.is_inside_tree():
			to_remove.append(actor)
			continue
		if actor.has_method("apply_survivability_tick"):
			actor.apply_survivability_tick(delta)
		_update_snapshot(actor, false)
	for actor in to_remove:
		_survivors.erase(actor)
		_last_snapshots.erase(actor.get_instance_id())

func _update_snapshot(actor: Node, force_emit: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if not actor.has_method("get_survivability_snapshot"):
		return
	var snapshot: Dictionary = actor.get_survivability_snapshot()
	if typeof(snapshot) != TYPE_DICTIONARY:
		return
	var actor_id := actor.get_instance_id()
	var previous: Dictionary = _last_snapshots.get(actor_id, {})
	if force_emit or not _snapshots_equal(previous, snapshot):
		_last_snapshots[actor_id] = snapshot.duplicate(true)
		emit_signal("survivability_changed", actor_id, snapshot)
		_emit_event_bus(actor, snapshot)

func _snapshots_equal(prev: Dictionary, current: Dictionary) -> bool:
	if prev.size() != current.size():
		return false
	for key in current.keys():
		if not prev.has(key):
			return false
		if prev[key] != current[key]:
			if prev[key] is float and current[key] is float and is_equal_approx(prev[key], current[key]):
				continue
			return false
	return true

func _emit_event_bus(actor: Node, snapshot: Dictionary) -> void:
	var game := _get_game_root()
	if game and game.event_bus and game.event_bus.has_signal(EVENT_SIGNAL):
		game.event_bus.emit_signal(EVENT_SIGNAL, actor, snapshot.duplicate(true))

func _connect_game_time() -> void:
	var game_time := _get_game_time()
	if game_time:
		if not game_time.is_connected("tick", Callable(self, "_on_tick")):
			game_time.connect("tick", Callable(self, "_on_tick"))
		_process_fallback = false
	else:
		_process_fallback = true
		call_deferred("_connect_game_time")

func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTime")

func _get_game_root() -> Node:
	return get_node_or_null("/root/Game")
