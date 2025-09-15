extends Node

## Price curves and marketplace logic (stub)

class_name MarketController

@export var base_prices := {}
var current_prices := {}

func _ready() -> void:
    current_prices = base_prices.duplicate(true)

func adjust_for_event(event_type: String, payload: Dictionary) -> void:
    # Placeholder dynamic pricing
    for k in current_prices.keys():
        var p: float = current_prices[k]
        if event_type == "OutpostAttacked":
            current_prices[k] = p * 1.1
        elif event_type == "Shortage":
            current_prices[k] = p * 1.25
        else:
            current_prices[k] = p
    if has_node("/root/Game"):
        for item_id in current_prices.keys():
            get_node("/root/Game").event_bus.emit_signal("PriceChanged", item_id, current_prices[item_id])

