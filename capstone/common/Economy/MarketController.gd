extends Node
class_name MarketController

signal price_updated(item_name: String, old_price: float, new_price: float)
signal event_processed(event_type: String, effects: Dictionary)

@export var base_prices := {"Pistol": 100.0, "Ammo": 5.0, "Medkit": 25.0}
var current_prices: Dictionary = {}
var price_history: Dictionary = {}
var market_events: Array = []

var event_effects := {
    "OutpostAttacked": {"Pistol": 1.3, "Ammo": 1.5, "Medkit": 1.2},
    "Shortage": {"Pistol": 1.1, "Ammo": 2.0, "Medkit": 1.8},
    "ConvoyArrived": {"Pistol": 0.9, "Ammo": 0.7, "Medkit": 0.8},
    "TradeRouteClear": {"Pistol": 0.95, "Ammo": 0.85, "Medkit": 0.9},
    "Raider": {"Pistol": 1.4, "Ammo": 1.8, "Medkit": 1.3},
    "Settlement": {"Pistol": 0.8, "Ammo": 0.75, "Medkit": 0.85}
}

func _ready() -> void:
    current_prices = base_prices.duplicate(true)
    _initialize_price_history()

    if Api and Api.jwt != "":
        _sync_prices_with_server()

func _initialize_price_history() -> void:
    for item_name in base_prices.keys():
        price_history[item_name] = [base_prices[item_name]]

func adjust_for_event(event_type: String, payload: Dictionary) -> void:
    var effects := event_effects.get(event_type, {})
    var price_changes := {}

    print("[Market] Processing event:", event_type)

    for item_name in current_prices.keys():
        var old_price: float = current_prices[item_name]
        var multiplier: float = effects.get(item_name, 1.0)
        var random_factor := randf_range(0.9, 1.1)
        var new_price := old_price * multiplier * random_factor
        var base_price := base_prices.get(item_name, old_price)

        new_price = clamp(new_price, base_price * 0.3, base_price * 3.0)

        current_prices[item_name] = new_price
        price_changes[item_name] = {
            "old": old_price,
            "new": new_price,
            "change": new_price - old_price
        }

        if price_history.has(item_name):
            price_history[item_name].append(new_price)
            if price_history[item_name].size() > 10:
                price_history[item_name].pop_front()

        price_updated.emit(item_name, old_price, new_price)

        var direction := new_price > old_price ? "increase" : "decrease"
        var percent_change := old_price != 0.0 ? abs(new_price - old_price) / old_price * 100.0 : 0.0
        print("  [Market] %s: $%.1f -> $%.1f (%.1f%% %s)" % [
            item_name,
            old_price,
            new_price,
            percent_change,
            direction
        ])

    var event_data := {
        "type": event_type,
        "timestamp": Time.get_unix_time_from_system(),
        "payload": payload,
        "price_changes": price_changes
    }
    market_events.append(event_data)

    _send_event_to_server(event_data)
    event_processed.emit(event_type, price_changes)

func _send_event_to_server(event_data: Dictionary) -> void:
    if not Api or Api.jwt == "":
        return

    var req := Api.post("market/events", {
        "event_type": event_data.get("type", ""),
        "settlement_id": 1,
        "price_changes": event_data.get("price_changes", {}),
        "timestamp": event_data.get("timestamp", Time.get_unix_time_from_system())
    })
    req.request_completed.connect(_on_event_sync_completed)

func _on_event_sync_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if response_code == 200:
        print("[Market] Event synced with server")
    else:
        print("[Market] Failed to sync market event:", response_code)

func _sync_prices_with_server() -> void:
    var req := Api.get_json("market/prices?settlement_id=1")
    req.request_completed.connect(_on_prices_synced)

func _on_prices_synced(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code != 200:
        return

    var json := JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK:
        return

    var response = json.data
    if typeof(response) != TYPE_DICTIONARY:
        return

    var server_prices = response.get("prices", {})
    if typeof(server_prices) != TYPE_DICTIONARY:
        return

    for item_name in server_prices.keys():
        var server_price = float(server_prices[item_name])
        if current_prices.has(item_name):
            var previous_price = current_prices[item_name]
            current_prices[item_name] = server_price
            price_updated.emit(item_name, previous_price, server_price)

    print("[Market] Prices synchronized with server")

func get_price_trend(item_name: String) -> String:
    if not price_history.has(item_name) or price_history[item_name].size() < 2:
        return "stable"

    var history: Array = price_history[item_name]
    var recent: float = history[-1]
    var previous: float = history[-2]
    if previous == 0.0:
        return "stable"

    var change_percent := (recent - previous) / previous * 100.0
    if change_percent > 5.0:
        return "rising"
    if change_percent < -5.0:
        return "falling"
    return "stable"

func get_market_summary() -> Dictionary:
    var recent_events: Array = []
    if market_events.size() > 5:
        recent_events = market_events.slice(market_events.size() - 5, market_events.size())
    else:
        recent_events = market_events.duplicate(true)

    var summary := {
        "current_prices": current_prices.duplicate(true),
        "base_prices": base_prices.duplicate(true),
        "recent_events": recent_events,
        "price_trends": {},
        "total_events": market_events.size()
    }

    for item_name in current_prices.keys():
        summary.price_trends[item_name] = get_price_trend(item_name)

    return summary

func get_price(item_name: String) -> float:
    return float(current_prices.get(item_name, base_prices.get(item_name, 0.0)))

func force_price_update(item_name: String, new_price: float) -> void:
    if not current_prices.has(item_name):
        return
    var old_price = current_prices[item_name]
    current_prices[item_name] = new_price
    price_updated.emit(item_name, old_price, new_price)

func reset_prices() -> void:
    for item_name in base_prices.keys():
        var old_price = current_prices.get(item_name, base_prices[item_name])
        current_prices[item_name] = base_prices[item_name]
        price_updated.emit(item_name, old_price, base_prices[item_name])

    market_events.clear()
    _initialize_price_history()
