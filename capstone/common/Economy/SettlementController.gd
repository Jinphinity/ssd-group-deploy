extends Node

## Settlement controller tracks population, morale, and resources for offline gameplay.

class_name SettlementController

signal population_changed(new_population: int)
signal resources_changed(resources: Dictionary)
signal settlement_won()
signal settlement_lost()

@export var population: int = 40
@export var population_target: int = 100
@export var minimum_population: int = 5

@export var resource_food: int = 120
@export var resource_ammo: int = 150
@export var resource_med: int = 40

@export var morale: float = 0.6
@export var morale_decay_rate: float = 0.01
@export var morale_boost_events: float = 0.05

@export var food_consumption_per_survivor: float = 0.5  # per hour
@export var med_consumption_base: float = 0.1
@export var ammo_consumption_patrol: float = 0.05

var _time_accumulator: float = 0.0
var tick_interval_hours: float = 1.0

func process_tick(delta_seconds: float) -> void:
	_time_accumulator += delta_seconds / 3600.0
	if _time_accumulator >= tick_interval_hours:
		var hours: float = float(floor(_time_accumulator / tick_interval_hours))
		_time_accumulator -= hours * tick_interval_hours
		_simulate_hours(hours)

func _simulate_hours(hours: float) -> void:
	if hours <= 0:
		return
	var food_needed := int(ceil(population * food_consumption_per_survivor * hours))
	resource_food = max(0, resource_food - food_needed)
	var med_needed := int(ceil(population * med_consumption_base * hours * (1.0 - morale)))
	resource_med = max(0, resource_med - med_needed)
	var ammo_needed := int(ceil(population * ammo_consumption_patrol * hours * morale))
	resource_ammo = max(0, resource_ammo - ammo_needed)
	if resource_food <= 0:
		population = max(minimum_population, population - int(ceil(population * 0.05 * hours)))
		morale = max(0.0, morale - 0.05)
	if resource_med <= 0:
		population = max(minimum_population, population - int(ceil(population * 0.03 * hours)))
		morale = max(0.0, morale - 0.03)
	if resource_ammo <= 0:
		morale = max(0.0, morale - 0.02)
	else:
		morale = clamp(morale - morale_decay_rate * hours, 0.0, 1.0)

	_resources_changed()
	_population_changed()
	_check_win_conditions()

func apply_event(event_type: String, payload: Dictionary = {}) -> void:
	match event_type:
		"OutpostAttacked":
			var severity := int(payload.get("severity", 1))
			population = max(minimum_population, population - severity * 2)
			resource_med = max(0, resource_med - severity * 2)
			morale = max(0.0, morale - 0.05 * severity)
		"ConvoyArrived":
			resource_food += int(payload.get("cargo_size", 80))
			resource_ammo += int(payload.get("cargo_size", 80) * 0.6)
			resource_med += int(payload.get("cargo_size", 80) * 0.2)
			morale = min(1.0, morale + morale_boost_events)
		"Settlement":
			population = min(population_target, population + int(payload.get("population_change", 8)))
			morale = min(1.0, morale + morale_boost_events)
		"Shortage":
			var amount := int(payload.get("severity", 1.0) * 15)
			var affected := String(payload.get("affected_item", "Ammo")).to_lower()
			match affected:
				"ammo":
					resource_ammo = max(0, resource_ammo - amount)
				"medkit", "medical":
					resource_med = max(0, resource_med - amount)
				"food", "supplies":
					resource_food = max(0, resource_food - amount)
			morale = max(0.0, morale - 0.04)
		"Raider":
			population = max(minimum_population, population - int(payload.get("raider_count", 3)))
			resource_ammo = max(0, resource_ammo - 15)
			morale = max(0.0, morale - 0.06)
		_:
			pass
	_resources_changed()
	_population_changed()
	_check_win_conditions()

func donate_resources(food: int, ammo: int, med: int) -> void:
	resource_food = max(0, resource_food + food)
	resource_ammo = max(0, resource_ammo + ammo)
	resource_med = max(0, resource_med + med)
	if food > 0 or ammo > 0 or med > 0:
		morale = min(1.0, morale + 0.02)
	_resources_changed()

func _resources_changed() -> void:
	var summary := {
		"food": resource_food,
		"ammo": resource_ammo,
		"med": resource_med,
		"morale": morale
	}
	resources_changed.emit(summary)
	if has_node("/root/Game"):
		var game_node = get_node("/root/Game")
		if game_node.event_bus and game_node.event_bus.has_signal("resources_changed"):
			game_node.event_bus.emit_signal("resources_changed", summary)

func _population_changed() -> void:
	population_changed.emit(population)
	if has_node("/root/Game"):
		var game_node = get_node("/root/Game")
		if game_node.event_bus and game_node.event_bus.has_signal("PopulationChanged"):
			game_node.event_bus.emit_signal("PopulationChanged", population)

func _check_win_conditions() -> void:
	if population >= population_target:
		settlement_won.emit()
	if population <= minimum_population and (resource_food <= 0 or morale <= 0.05):
		settlement_lost.emit()


func get_state_snapshot() -> Dictionary:
	return {
		"population": population,
		"population_target": population_target,
		"minimum_population": minimum_population,
		"resource_food": resource_food,
		"resource_ammo": resource_ammo,
		"resource_med": resource_med,
		"morale": morale,
		"_time_accumulator": _time_accumulator
	}

func hydrate_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	population = int(state.get("population", population))
	population_target = int(state.get("population_target", population_target))
	minimum_population = int(state.get("minimum_population", minimum_population))
	resource_food = int(state.get("resource_food", resource_food))
	resource_ammo = int(state.get("resource_ammo", resource_ammo))
	resource_med = int(state.get("resource_med", resource_med))
	morale = float(state.get("morale", morale))
	_time_accumulator = float(state.get("_time_accumulator", _time_accumulator))
	_resources_changed()
	_population_changed()
func get_summary() -> Dictionary:
	return {
		"population": population,
		"target": population_target,
		"morale": morale,
		"food": resource_food,
		"ammo": resource_ammo,
		"med": resource_med
	}
