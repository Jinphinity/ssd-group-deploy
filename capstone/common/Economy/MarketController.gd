extends Node
class_name MarketController

signal price_updated(item_id: String, old_price: float, new_price: float)
signal event_processed(event_type: String, effects: Dictionary)
signal stock_changed()

const ItemDatabaseClass = preload("res://common/Data/ItemDatabase.gd")

# Pricing and stock state
var base_prices: Dictionary = {}              # item_id -> base price
var current_prices: Dictionary = {}           # item_id -> current price
var price_history: Dictionary = {}            # item_id -> Array[float]
var market_events: Array = []                 # Array of event dictionaries

# Catalog & stock
var manifest_items: Dictionary = {}           # item_id -> definition
var current_stock: Dictionary = {}            # item_id -> stock data dictionary
var stock_size_min: int = 8
var stock_size_max: int = 12
var stock_quantity_by_tier := {
	1: 6,
	2: 4,
	3: 3,
	4: 1,
	5: 1
}
var tier_weights := {
	1: 6.0,
	2: 4.0,
	3: 2.0,
	4: 0.75,
	5: 0.25
}
var sell_ratio := 0.5  # Player sell-back ratio; buy-side markup handled via events later

var _rng := RandomNumberGenerator.new()
var last_refresh_time: float = 0.0
var rotation_interval_seconds: float = 240.0
var _rotation_timer: float = 0.0

var event_effects := {
	"OutpostAttacked": {
		"weapons": 1.30,
		"handgun": 1.35,
		"rifle": 1.40,
		"ammo": 1.50,
		"medical": 1.25,
		"default": 1.15
	},
	"Shortage": {
		"ammo": 2.00,
		"consumable": 1.80,
		"medical": 1.70,
		"default": 1.25
	},
	"ConvoyArrived": {
		"weapons": 0.90,
		"ammo": 0.75,
		"consumable": 0.80,
		"default": 0.85
	},
	"TradeRouteClear": {
		"weapons": 0.95,
		"armor": 0.90,
		"default": 0.92
	},
	"Raider": {
		"weapons": 1.35,
		"armor": 1.20,
		"ammo": 1.45,
		"default": 1.25
	},
	"Settlement": {
		"consumable": 0.85,
		"medical": 0.80,
		"default": 0.90
	}
}

func _ready() -> void:
	_rng.randomize()
	add_to_group("markets")
	_initialize_catalog()
	_initialize_stock()
	_initialize_price_history()

	if DifficultyManager:
		var price_multiplier = DifficultyManager.get_modifier("market_price_multiplier")
		_apply_price_multiplier(price_multiplier)

	if Api and Api.jwt != "":
		_sync_prices_with_server()

	# Connect to auth state changes for online/offline transitions
	if AuthController:
		if not AuthController.user_logged_in.is_connected(_on_user_logged_in):
			AuthController.user_logged_in.connect(_on_user_logged_in)
		if not AuthController.user_logged_out.is_connected(_on_user_logged_out):
			AuthController.user_logged_out.connect(_on_user_logged_out)
		print("✅ [MARKET] Connected to AuthController state change signals")
	else:
		print("⚠️ [MARKET] AuthController not available during initialization")

func _initialize_catalog() -> void:
	manifest_items = ItemDatabaseClass.get_all_items()
	if manifest_items.is_empty():
		push_warning("MarketController: manifest items unavailable; using fallback catalog")
	base_prices.clear()
	for item_id in manifest_items.keys():
		var definition: Dictionary = manifest_items[item_id]
		base_prices[item_id] = float(definition.get("value", 100.0))

func _initialize_stock() -> void:
	current_stock.clear()
	current_prices.clear()
	_rotation_timer = 0.0
	if manifest_items.is_empty():
		return

	var desired_stock: int = clamp(stock_size_min + _rng.randi_range(0, max(0, stock_size_max - stock_size_min)), stock_size_min, stock_size_max)
	var selected_ids := _select_stock_items(desired_stock)

	for item_id in selected_ids:
		var definition: Dictionary = manifest_items.get(item_id, {})
		var base_price: float = base_prices.get(item_id, float(definition.get("value", 100.0)))
		var quantity: int = _initial_quantity_for_tier(int(definition.get("tier", 1)))

		current_prices[item_id] = base_price
		current_stock[item_id] = {
			"definition": definition.duplicate(true),
			"quantity": quantity,
			"base_price": base_price,
			"last_refresh": GameTime.get_unix_time_from_system()
		}

	last_refresh_time = GameTime.get_unix_time_from_system()
	stock_changed.emit()

func process_tick(delta: float) -> void:
	_rotation_timer += delta
	if rotation_interval_seconds > 0.0 and _rotation_timer >= rotation_interval_seconds:
		_rotation_timer = 0.0
		_rotate_stock()

func _initialize_price_history() -> void:
	price_history.clear()
	for item_id in current_prices.keys():
		price_history[item_id] = [current_prices[item_id]]

func _select_stock_items(count: int) -> Array:
	var available_ids: Array = manifest_items.keys()
	if available_ids.is_empty():
		return []

	var selected: Array = []
	var attempts := 0

	while selected.size() < count and attempts < available_ids.size() * 3:
		var candidate := _weighted_random_item(available_ids)
		attempts += 1
		if selected.has(candidate):
			continue
		selected.append(candidate)
	return selected

func _weighted_random_item(ids: Array) -> String:
	if ids.is_empty():
		return ""

	var total_weight := 0.0
	for item_id in ids:
		total_weight += _get_weight_for_item(manifest_items.get(item_id, {}))

	if total_weight <= 0.0:
		return ids[_rng.randi_range(0, ids.size() - 1)]

	var pick := _rng.randf_range(0.0, total_weight)
	var cumulative := 0.0
	for item_id in ids:
		cumulative += _get_weight_for_item(manifest_items.get(item_id, {}))
		if pick <= cumulative:
			return item_id
	return ids.back()

func _get_weight_for_item(definition: Dictionary) -> float:
	var tier := int(definition.get("tier", 1))
	return float(tier_weights.get(tier, 1.0))

func _initial_quantity_for_tier(tier: int) -> int:
	return max(1, int(stock_quantity_by_tier.get(tier, 2)))

func adjust_for_event(event_type: String, payload: Dictionary) -> void:
	if current_prices.is_empty():
		return

	var effects_map: Dictionary = event_effects.get(event_type, {})
	var price_changes: Dictionary = {}

	print("[Market] Processing event:", event_type)

	for item_id in current_prices.keys():
		var definition: Dictionary = manifest_items.get(item_id, {})
		var old_price: float = current_prices[item_id]
		var base_price: float = base_prices.get(item_id, old_price)
		var multiplier := _resolve_event_multiplier(effects_map, definition)
		var random_factor := _rng.randf_range(0.9, 1.1)
		var new_price: float = clamp(base_price * multiplier * random_factor, base_price * 0.3, base_price * 3.0)

		current_prices[item_id] = new_price
		price_changes[item_id] = {
			"old": old_price,
			"new": new_price,
			"change": new_price - old_price
		}

		var history: Array = price_history.get(item_id, [])
		history.append(new_price)
		if history.size() > 10:
			history.pop_front()
		price_history[item_id] = history

		price_updated.emit(item_id, old_price, new_price)

		var direction := "increase" if new_price > old_price else "decrease"
		var percent_change: float = 0.0
		if old_price != 0.0:
			percent_change = abs(new_price - old_price) / old_price * 100.0
		print("  [Market] %s: $%.1f -> $%.1f (%.1f%% %s)" % [
			definition.get("name", item_id),
			old_price,
			new_price,
			percent_change,
			direction
		])

	var event_data := {
		"type": event_type,
		"timestamp": GameTime.get_unix_time_from_system(),
		"payload": payload,
		"price_changes": price_changes
	}
	market_events.append(event_data)

	_send_event_to_server(event_data)
	event_processed.emit(event_type, price_changes)

func _resolve_event_multiplier(effects_map: Dictionary, definition: Dictionary) -> float:
	if effects_map.is_empty():
		return 1.0

	var tags := _collect_item_tags(definition)
	for tag in tags:
		if effects_map.has(tag):
			return float(effects_map[tag])
	return float(effects_map.get("default", 1.0))

func _collect_item_tags(definition: Dictionary) -> Array:
	var tags: Array = []
	var section := String(definition.get("section", "")).to_lower()
	var subcategory := String(definition.get("subcategory", "")).to_lower()
	var category := String(definition.get("category", "")).to_lower()

	if section != "":
		tags.append(section)
	if subcategory != "":
		tags.append(subcategory)
	if category != "":
		tags.append(category)

	# Generic category aliasing
	if section == "weapons" or category.contains("handgun") or category.contains("rifle") or category.contains("shotgun"):
		tags.append("weapons")
	if section == "consumables":
		tags.append("consumable")
	if section == "components":
		tags.append("component")
	if section == "armor":
		tags.append("armor")
	if category.contains("ammo"):
		tags.append("ammo")
	if category.contains("medical") or category.contains("med"):
		tags.append("medical")

	return tags

func purchase_item(item_id: String) -> Dictionary:
	if not current_stock.has(item_id):
		return {"success": false, "reason": "not_stocked"}

	var stock: Dictionary = current_stock[item_id]
	var quantity: int = int(stock.get("quantity", 0))
	if quantity <= 0:
		return {"success": false, "reason": "out_of_stock"}

	quantity -= 1
	stock["quantity"] = quantity
	current_stock[item_id] = stock

	var price := float(current_prices.get(item_id, stock.get("base_price", 0.0)))
	var item_instance := ItemDatabaseClass.create_item_instance(item_id, 1)
	if item_instance.is_empty():
		# Fallback to definition data
		var definition: Dictionary = stock.get("definition", {})
		item_instance = definition.duplicate(true)
		item_instance["item_id"] = item_id
		item_instance["quantity"] = 1
		item_instance["equipped"] = false

	stock_changed.emit()

	return {
		"success": true,
		"item": item_instance,
		"price": price,
		"quantity_remaining": quantity,
		"definition": stock.get("definition", {})
	}

func revert_purchase(item_id: String) -> void:
	if not current_stock.has(item_id):
		return
	var stock: Dictionary = current_stock[item_id]
	stock["quantity"] = int(stock.get("quantity", 0)) + 1
	current_stock[item_id] = stock
	stock_changed.emit()

func receive_sellback(item: Dictionary) -> void:
	var item_id := String(item.get("item_id", ""))
	if item_id == "":
		return

	if manifest_items.has(item_id):
		# Use canonical definition
		var definition: Dictionary = manifest_items[item_id]
		base_prices[item_id] = float(definition.get("value", base_prices.get(item_id, 100.0)))
	else:
		# Adopt item's definition into catalog for completeness
		manifest_items[item_id] = item.duplicate(true)
		base_prices[item_id] = float(item.get("value", base_prices.get(item_id, 100.0)))

	if current_stock.has(item_id):
		var stock: Dictionary = current_stock[item_id]
		stock["quantity"] = int(stock.get("quantity", 0)) + 1
		current_stock[item_id] = stock
	else:
		var definition: Dictionary = manifest_items.get(item_id, item.duplicate(true))
		var base_price: float = base_prices.get(item_id, float(definition.get("value", 100.0)))
		current_stock[item_id] = {
			"definition": definition.duplicate(true),
			"quantity": 1,
			"base_price": base_price,
			"last_refresh": GameTime.get_unix_time_from_system()
		}
		current_prices[item_id] = base_price
		price_history[item_id] = [base_price]
	stock_changed.emit()

func get_buyback_price(item: Dictionary) -> float:
	var item_id := String(item.get("item_id", ""))
	if item_id != "" and base_prices.has(item_id):
		return round(base_prices[item_id] * sell_ratio)

	var name := String(item.get("name", ""))
	for key in base_prices.keys():
		var definition: Dictionary = manifest_items.get(key, {})
		if definition.get("name", "") == name:
			return round(base_prices[key] * sell_ratio)
	if item_id != "":
		return round(float(item.get("value", base_prices.get(item_id, 20.0))) * sell_ratio)
	return 10.0

func get_stock_entries() -> Array:
	var entries: Array = []
	for item_id in current_stock.keys():
		var stock: Dictionary = current_stock[item_id]
		var definition: Dictionary = stock.get("definition", {})
		var price := int(round(current_prices.get(item_id, stock.get("base_price", 0.0))))
		entries.append({
			"item_id": item_id,
			"name": definition.get("name", item_id),
			"price": price,
			"quantity": int(stock.get("quantity", 0)),
			"tier": int(definition.get("tier", 1)),
			"category": String(definition.get("category", "")),
		"definition": definition.duplicate(true)
	})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _sort_stock_entries(a, b))
	return entries

func _sort_stock_entries(a: Dictionary, b: Dictionary) -> bool:
	var tier_a := int(a.get("tier", 1))
	var tier_b := int(b.get("tier", 1))
	if tier_a == tier_b:
		return String(a.get("name", "")).naturalnocasecmp_to(String(b.get("name", ""))) < 0
	return tier_a < tier_b

func get_price(item_id: String) -> float:
	return float(current_prices.get(item_id, base_prices.get(item_id, 0.0)))

func force_price_update(item_id: String, new_price: float) -> void:
	if not current_prices.has(item_id):
		return
	var old_price = current_prices[item_id]
	current_prices[item_id] = new_price
	price_updated.emit(item_id, old_price, new_price)


func get_state_snapshot() -> Dictionary:
	var stock_copy: Dictionary = {}
	for item_id in current_stock.keys():
		var original: Dictionary = current_stock[item_id]
		stock_copy[item_id] = {
			"definition": (original.get("definition", {}) as Dictionary).duplicate(true),
			"quantity": int(original.get("quantity", 0)),
			"base_price": float(original.get("base_price", 0.0)),
			"last_refresh": float(original.get("last_refresh", GameTime.get_unix_time_from_system()))
		}
	return {
		"current_stock": stock_copy,
		"current_prices": current_prices.duplicate(true),
		"base_prices": base_prices.duplicate(true),
		"rotation_timer": _rotation_timer,
		"last_refresh_time": last_refresh_time,
		"price_history": price_history.duplicate(true)
	}

func hydrate_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var stock: Dictionary = state.get("current_stock", {})
	current_stock.clear()
	for item_id in stock.keys():
		var entry: Dictionary = stock[item_id]
		var definition: Dictionary = (entry.get("definition", {}) as Dictionary).duplicate(true)
		manifest_items[item_id] = definition.duplicate(true)
		current_stock[item_id] = {
			"definition": definition,
			"quantity": int(entry.get("quantity", 0)),
			"base_price": float(entry.get("base_price", base_prices.get(item_id, 0.0))),
			"last_refresh": float(entry.get("last_refresh", GameTime.get_unix_time_from_system()))
		}
	if state.has("current_prices"):
		current_prices = (state.get("current_prices") as Dictionary).duplicate(true)
	if state.has("base_prices"):
		base_prices = (state.get("base_prices") as Dictionary).duplicate(true)
	_rotation_timer = float(state.get("rotation_timer", _rotation_timer))
	last_refresh_time = float(state.get("last_refresh_time", last_refresh_time))
	_initialize_price_history()
	stock_changed.emit()
func reset_prices() -> void:
	_initialize_stock()
	_initialize_price_history()

	if DifficultyManager:
		var price_multiplier = DifficultyManager.get_modifier("market_price_multiplier")
		_apply_price_multiplier(price_multiplier)

func get_price_trend(item_id: String) -> String:
	var history: Array = price_history.get(item_id, [])
	if history.size() < 2:
		return "stable"
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

	return {
		"current_prices": current_prices.duplicate(true),
		"base_prices": base_prices.duplicate(true),
		"recent_events": recent_events,
		"price_trends": _build_price_trends(),
		"stock": get_stock_entries(),
		"total_events": market_events.size()
	}

func _build_price_trends() -> Dictionary:
	var trends: Dictionary = {}
	for item_id in current_prices.keys():
		trends[item_id] = get_price_trend(item_id)
	return trends

# Difficulty scaling integration
func _apply_difficulty_scaling(modifiers: Dictionary) -> void:
	var price_multiplier = modifiers.get("price_multiplier", 1.0)
	_apply_price_multiplier(price_multiplier)
	print("💰 MarketController difficulty scaling applied: %.2fx price multiplier" % price_multiplier)

func _apply_price_multiplier(multiplier: float) -> void:
	for item_id in current_prices.keys():
		var base_price = base_prices.get(item_id, current_prices[item_id])
		var new_price = base_price * multiplier
		var old_price = current_prices[item_id]
		current_prices[item_id] = new_price
		price_updated.emit(item_id, old_price, new_price)

func _send_event_to_server(event_data: Dictionary) -> void:
	if not Api or Api.jwt == "":
		print("⚠️ [MARKET] Cannot send event - API not available or not authenticated")
		return

	# Check if we're in offline mode
	if AuthController and AuthController.is_offline_mode():
		print("⚠️ [MARKET] Cannot send event - in offline mode")
		return

	var payload = {
		"event_type": event_data.get("type", ""),
		"settlement_id": 1,
		"price_changes": event_data.get("price_changes", {}),
		"timestamp": event_data.get("timestamp", GameTime.get_unix_time_from_system()),
		"payload": event_data.get("payload", {})
	}

	var req = Api.post("market/events", payload)
	if req:
		req.request_completed.connect(_on_event_sync_completed)
		print("📡 [MARKET] Sending event to server: %s" % event_data.get("type", "unknown"))
	else:
		print("❌ [MARKET] Failed to create event sync request")

func _on_event_sync_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code == 200:
		print("[Market] Event synced with server")
	else:
		print("[Market] Failed to sync market event:", response_code)

func _sync_prices_with_server() -> void:
	var req = Api.get_json("market/prices?settlement_id=1")
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

	for item_id in server_prices.keys():
		var server_price = float(server_prices[item_id])
		if current_prices.has(item_id):
			var previous_price = current_prices[item_id]
			current_prices[item_id] = server_price
			price_updated.emit(item_id, previous_price, server_price)

	print("[Market] Prices synchronized with server")

func _get_connection_safe_price(item_id: String) -> float:
	return float(current_prices.get(item_id, base_prices.get(item_id, 0.0)))

func _rotate_stock() -> void:
	if manifest_items.is_empty():
		return
	var current_ids: Array = current_stock.keys()
	var desired_count := current_ids.size()
	var drop_count := int(ceil(desired_count * 0.35))
	var ids_array: Array = current_ids.duplicate(true)
	ids_array.shuffle()
	for i in range(min(drop_count, ids_array.size())):
		var remove_id: Variant = ids_array[i]
		current_stock.erase(remove_id)
		current_prices.erase(remove_id)
		price_history.erase(remove_id)
	var missing: int = max(stock_size_min, desired_count) - current_stock.size()
	if missing > 0:
		var new_ids := _select_stock_items(missing)
		for item_id in new_ids:
			if current_stock.has(item_id):
				continue
			var definition: Dictionary = manifest_items.get(item_id, {})
			var base_price: float = base_prices.get(item_id, float(definition.get("value", 100.0)))
			var quantity: int = _initial_quantity_for_tier(int(definition.get("tier", 1)))
			current_prices[item_id] = base_price
			current_stock[item_id] = {
				"definition": definition.duplicate(true),
				"quantity": quantity,
				"base_price": base_price,
				"last_refresh": GameTime.get_unix_time_from_system()
			}
	_initialize_price_history()
	print("🔄 [Market] Stock rotated (%d items)" % current_stock.size())
	stock_changed.emit()

## Online/Offline Mode Handlers

func _on_user_logged_in(user_data: Dictionary) -> void:
	"""Handle user login - sync market data with server"""
	print("📡 [MARKET] User logged in - syncing market data with server")

	# Sync prices with server
	_sync_prices_with_server()

	# Send any pending market events to server
	if market_events.size() > 0:
		print("📡 [MARKET] Syncing %d pending market events" % market_events.size())
		for event in market_events:
			_send_event_to_server(event)

func _on_user_logged_out() -> void:
	"""Handle user logout - stop server sync"""
	print("💾 [MARKET] User logged out - switching to offline mode")

	# Keep local market data but stop server sync
	print("📦 [MARKET] Market data preserved locally")

func get_sync_status() -> Dictionary:
	"""Get current sync status for debugging"""
	var auth_status: Dictionary = AuthController.get_auth_status() if AuthController else {}
	var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])
	var is_offline: bool = AuthController.is_offline_mode() if AuthController else true
	var api_available: bool = Api != null and Api.jwt != ""

	return {
		"is_authenticated": is_authenticated,
		"is_offline_mode": is_offline,
		"api_available": api_available,
		"can_sync": is_authenticated and not is_offline and api_available,
		"last_refresh_time": last_refresh_time,
		"total_events": market_events.size(),
		"stock_items": current_stock.size(),
		"sync_enabled": AuthController != null and Api != null
	}

func sync_all_to_server() -> void:
	"""Manually trigger full sync to server if online"""
	var status = get_sync_status()

	if status.can_sync:
		print("📡 [MARKET] Manual full sync to server triggered")
		_sync_prices_with_server()

		# Send all market events
		for event in market_events:
			_send_event_to_server(event)
	else:
		print("⚠️ [MARKET] Cannot sync - not authenticated or in offline mode")
		print("  Status: %s" % status)
