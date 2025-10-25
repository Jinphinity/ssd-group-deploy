extends Node

## Lightweight status effect routing for gameplay systems.

class_name StatusEffectManager

signal effect_applied(target: Node, effect_id: String, params: Dictionary)
signal effect_cleared(target: Node, effect_id: String)

static var _instance: StatusEffectManager = null

func _ready() -> void:
	_instance = self

static func get_singleton() -> StatusEffectManager:
	return _instance

func apply_effect(target: Node, effect_id: String, params: Dictionary = {}) -> void:
	if target == null:
		return
	if target.has_method("apply_status_effect"):
		target.apply_status_effect(effect_id, params)
		effect_applied.emit(target, effect_id, params)

func clear_effect(target: Node, effect_id: String = "") -> void:
	if target == null:
		return
	if target.has_method("clear_status_effect"):
		target.clear_status_effect(effect_id)
		effect_cleared.emit(target, effect_id)
