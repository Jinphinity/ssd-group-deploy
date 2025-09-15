extends Node

## Track population/resources and emit events (stub)

class_name SettlementController

@export var population: int = 20
@export var resource_food: int = 100
@export var resource_ammo: int = 120
@export var resource_med: int = 30

func apply_event(event_type: String, payload: Dictionary = {}) -> void:
    match event_type:
        "OutpostAttacked":
            population = max(0, population - 2)
        "ConvoyArrived":
            resource_food += 20
            resource_ammo += 30
            resource_med += 10
        _:
            pass
    if has_node("/root/Game"):
        get_node("/root/Game").event_bus.emit_signal("PopulationChanged", population)

