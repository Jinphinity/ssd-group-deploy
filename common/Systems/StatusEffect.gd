extends RefCounted

## Base class for status effects processed by StatusEffectManager.
## Subclasses should override _on_start, _on_tick, and _on_finish as needed.

class_name StatusEffect

var effect_id: String = ""
var target: Node = null
var params: Dictionary = {}
var duration: float = 0.0
var elapsed: float = 0.0
var manager: Node = null

func configure(effect_id_in: String, target_in: Node, params_in: Dictionary, manager_in: Node) -> void:
	effect_id = effect_id_in
	target = target_in
	params = params_in.duplicate(true)
	manager = manager_in
	duration = float(params.get("duration", 0.0))
	elapsed = 0.0
	_register_summary()
	_on_start()
	_update_summary()

func refresh(params_in: Dictionary) -> void:
	params = params_in.duplicate(true)
	duration = float(params.get("duration", duration))
	elapsed = 0.0
	_on_refresh()
	_update_summary()

func tick(delta: float) -> bool:
	if not _is_target_valid():
		return true
	elapsed += delta
	_on_tick(delta)
	_update_summary()
	return duration > 0.0 and elapsed >= duration or _should_finish()

func finish() -> void:
	_on_finish()
	_unregister_summary()

func _on_start() -> void:
	pass

func _on_refresh() -> void:
	pass

func _on_tick(_delta: float) -> void:
	pass

func _on_finish() -> void:
	pass

func _should_finish() -> bool:
	return false

func get_remaining_time() -> float:
	if duration <= 0.0:
		return -1.0
	return max(duration - elapsed, 0.0)

func get_display_name() -> String:
	return String(params.get("name", effect_id.capitalize()))

func _is_target_valid() -> bool:
	return target != null and is_instance_valid(target)

func _register_summary() -> void:
	if _is_target_valid() and target.has_method("register_status_effect"):
		target.register_status_effect(effect_id, {
			"id": effect_id,
			"name": get_display_name(),
			"remaining": get_remaining_time()
		})

func _update_summary() -> void:
	if _is_target_valid() and target.has_method("update_status_effect_summary"):
		target.update_status_effect_summary(effect_id, {
			"id": effect_id,
			"name": get_display_name(),
			"remaining": get_remaining_time()
		})

func _unregister_summary() -> void:
	if _is_target_valid() and target.has_method("unregister_status_effect"):
		target.unregister_status_effect(effect_id)
