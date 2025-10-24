extends Node

## Item database loaded from JSON manifest with safe fallback defaults.

class_name ItemDatabase

const MANIFEST_PATH := "res://config/items/item_manifest.json"

const FALLBACK_ITEMS := {
	"weapon_lv1": {
		"id": "weapon_lv1",
		"name": "Makeshift Pistol",
		"type": "equipment",
		"slot": "weapon",
		"tier": 1,
		"base_damage_bonus": 5,
		"magazine_size": 8,
		"reserve_ammo": 32,
		"stat_mods": {
			"accuracy": 1,
			"dexterity": 1
		},
		"speed_multiplier": 1.0,
		"slot_size": 2,
		"weight": 2.5
	},
	"weapon_lv2": {
		"id": "weapon_lv2",
		"name": "Reliable Sidearm",
		"type": "equipment",
		"slot": "weapon",
		"tier": 2,
		"base_damage_bonus": 9,
		"magazine_size": 10,
		"reserve_ammo": 40,
		"stat_mods": {
			"accuracy": 2,
			"dexterity": 1
		},
		"speed_multiplier": 1.05,
		"slot_size": 2,
		"weight": 2.8
	},
	"weapon_lv3": {
		"id": "weapon_lv3",
		"name": "Tuned Carbine",
		"type": "equipment",
		"slot": "weapon",
		"tier": 3,
		"base_damage_bonus": 14,
		"magazine_size": 20,
		"reserve_ammo": 100,
		"stat_mods": {
			"accuracy": 3,
			"dexterity": 2
		},
		"speed_multiplier": 1.08,
		"slot_size": 3,
		"weight": 3.2
	},
	"weapon_lv4": {
		"id": "weapon_lv4",
		"name": "Elite Marksman Rifle",
		"type": "equipment",
		"slot": "weapon",
		"tier": 4,
		"base_damage_bonus": 20,
		"magazine_size": 5,
		"reserve_ammo": 50,
		"stat_mods": {
			"accuracy": 4,
			"dexterity": 3,
			"strength": 1
		},
		"speed_multiplier": 1.12,
		"slot_size": 3,
		"weight": 3.5
	},
	"armor_lv1": {
		"id": "armor_lv1",
		"name": "Padded Jacket",
		"type": "equipment",
		"slot": "armor",
		"tier": 1,
		"defense_bonus": 4,
		"stat_mods": {
			"endurance": 1,
			"strength": 1
		},
		"speed_multiplier": 0.98,
		"slot_size": 3,
		"weight": 4.0
	},
	"armor_lv2": {
		"id": "armor_lv2",
		"name": "Reinforced Vest",
		"type": "equipment",
		"slot": "armor",
		"tier": 2,
		"defense_bonus": 8,
		"stat_mods": {
			"endurance": 2,
			"strength": 1
		},
		"speed_multiplier": 0.96,
		"slot_size": 3,
		"weight": 4.5
	},
	"armor_lv3": {
		"id": "armor_lv3",
		"name": "Composite Armor",
		"type": "equipment",
		"slot": "armor",
		"tier": 3,
		"defense_bonus": 13,
		"stat_mods": {
			"endurance": 3,
			"strength": 2
		},
		"speed_multiplier": 0.94,
		"slot_size": 4,
		"weight": 5.0
	},
	"armor_lv4": {
		"id": "armor_lv4",
		"name": "Advanced Ballistic Suit",
		"type": "equipment",
		"slot": "armor",
		"tier": 4,
		"defense_bonus": 18,
		"stat_mods": {
			"endurance": 4,
			"strength": 3
		},
		"speed_multiplier": 0.92,
		"slot_size": 4,
		"weight": 5.5
	}
}

static var _items: Dictionary = {}
static var _items_by_category: Dictionary = {}
static var _items_by_slot: Dictionary = {}
static var _manifest_loaded := false
static var _manifest_load_warning := ""
const REQUIRED_FIELDS := ["id", "name", "type"]
const REQUIRED_EQUIPMENT_FIELDS := ["slot"]
const DEFAULT_STACKABLE_TYPES := ["consumable", "component"]

static func _ensure_loaded() -> void:
	if _manifest_loaded:
		return

	_manifest_loaded = true

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_use_fallback("Item manifest missing at %s" % MANIFEST_PATH)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(text)
	if parse_result != OK:
		_use_fallback("Failed to parse manifest: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		_use_fallback("Manifest root is not a dictionary.")
		return

	_items = _flatten_manifest(data)
	_build_indexes()
	if _items.is_empty():
		_use_fallback("Manifest produced zero items.")

static func _use_fallback(reason: String) -> void:
	_items.clear()
	_items_by_category.clear()
	_items_by_slot.clear()
	for key in FALLBACK_ITEMS.keys():
		_items[key] = FALLBACK_ITEMS[key].duplicate(true)
	_build_indexes()
	_manifest_load_warning = reason
	push_warning("ItemDatabase using fallback items: %s" % reason)

static func _flatten_manifest(manifest: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for section_key in manifest.keys():
		var section = manifest[section_key]
		if typeof(section) == TYPE_DICTIONARY:
			for sub_key in section.keys():
				_ingest_array(result, section[sub_key], section_key, sub_key)
		else:
			_ingest_array(result, section, section_key)
	return result

static func _ingest_array(result: Dictionary, value, section: String, subset: String = "") -> void:
	if typeof(value) != TYPE_ARRAY:
		return

	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if not item.has("id"):
			push_warning("Item manifest entry missing id in section %s/%s" % [section, subset])
			continue

		var item_id := String(item.get("id"))
		if item_id == "":
			push_warning("Item manifest entry has empty id in section %s/%s" % [section, subset])
			continue

		if result.has(item_id):
			push_warning("Duplicate item id '%s' encountered in manifest; keeping first definition." % item_id)
			continue

		var normalized: Dictionary = item.duplicate(true)
		normalized["section"] = section
		if subset != "":
			normalized["subcategory"] = subset
		if _validate_item(normalized, section, subset):
			_normalize_item_defaults(normalized)
			result[item_id] = normalized

static func get_item_definition(item_id: String) -> Dictionary:
	_ensure_loaded()
	return (_items.get(item_id, {}).duplicate(true))

static func create_item_instance(item_id: String, quantity: int = 1) -> Dictionary:
	var definition := get_item_definition(item_id)
	if definition.is_empty():
		return {}

	var instance: Dictionary = definition.duplicate(true)
	instance["item_id"] = item_id
	instance["quantity"] = max(1, quantity)
	instance["max_stack"] = definition.get("max_stack", 1)
	instance["slot_size"] = definition.get("slot_size", 1)
	instance["weight"] = definition.get("weight", 0.0)
	instance["equipped"] = false
	instance["is_stackable"] = bool(definition.get("stackable", quantity > 1 or instance.get("max_stack", 1) > 1))
	instance["category"] = definition.get("category", definition.get("type", ""))
	_normalize_weapon_fields(instance)
	return instance

static func _normalize_weapon_fields(instance: Dictionary) -> void:
	if String(instance.get("slot", "")).to_lower() != "weapon":
		return
	var accuracy := float(instance.get("accuracy", 1.0))
	accuracy = clamp(accuracy, 0.1, 1.5)
	instance["accuracy_multiplier"] = accuracy
	instance["spread_degrees"] = float(instance.get("spread", instance.get("spread_degrees", 0.0)))
	instance["recoil_per_shot"] = float(instance.get("recoil", instance.get("recoil_per_shot", 0.0)))
	instance["recoil_recovery"] = float(instance.get("recoil_recovery", 6.0))
	instance["falloff_start"] = float(instance.get("damage_falloff_start", 0.0))
	instance["falloff_end"] = float(instance.get("damage_falloff_end", 0.0))
	instance["falloff_min_multiplier"] = float(instance.get("falloff_min", 0.4))

static func get_all_items() -> Dictionary:
	_ensure_loaded()
	return _items.duplicate(true)

static func get_all_items_array() -> Array:
	_ensure_loaded()
	return _items.values().duplicate(true)

static func get_items_by_category(category: String) -> Array:
	_ensure_loaded()
	var key := category.to_lower()
	if _items_by_category.has(key):
		return _items_by_category[key].duplicate(true)
	return []

static func get_items_by_slot(slot: String) -> Array:
	_ensure_loaded()
	var key := slot.to_lower()
	if _items_by_slot.has(key):
		return _items_by_slot[key].duplicate(true)
	return []

static func has_item(item_id: String) -> bool:
	_ensure_loaded()
	return _items.has(item_id)

static func refresh_manifest() -> void:
	_items.clear()
	_items_by_category.clear()
	_items_by_slot.clear()
	_manifest_loaded = false
	_manifest_load_warning = ""
	_ensure_loaded()

static func get_manifest_warning() -> String:
	return _manifest_load_warning

static func _validate_item(item: Dictionary, section: String, subset: String) -> bool:
	for field in REQUIRED_FIELDS:
		if not item.has(field):
			push_warning("Item '%s' missing required field '%s' in section %s/%s" % [item.get("id", "<unknown>"), field, section, subset])
			return false

	var item_type := String(item.get("type", "")).to_lower()
	if item_type == "":
		push_warning("Item '%s' has empty type" % item.get("id", "<unknown>"))
		return false

	if item_type == "weapon" or item_type == "armor":
		for field in REQUIRED_EQUIPMENT_FIELDS:
			if not item.has(field):
				push_warning("Equipment item '%s' missing '%s' field" % [item.get("id", "<unknown>"), field])
				return false

	var slot_value := String(item.get("slot", "")).to_lower()
	if item_type == "weapon" and slot_value != "weapon":
		push_warning("Weapon item '%s' should have slot 'weapon'" % item.get("id", "<unknown>"))

	if item_type == "armor" and slot_value == "":
		push_warning("Armor item '%s' missing slot designation" % item.get("id", "<unknown>"))
		return false

	return true

static func _normalize_item_defaults(item: Dictionary) -> void:
	var item_type := String(item.get("type", "")).to_lower()
	if not item.has("slot_size"):
		item["slot_size"] = 1
	if not item.has("weight"):
		item["weight"] = 0.0
	if not item.has("value"):
		item["value"] = 0
	if not item.has("stackable") and DEFAULT_STACKABLE_TYPES.has(item_type):
		item["stackable"] = true
	if item.has("stat_mods") and typeof(item["stat_mods"]) != TYPE_DICTIONARY:
		push_warning("Item '%s' has invalid stat_mods format; resetting to empty dict" % item.get("id", "<unknown>"))
		item["stat_mods"] = {}

static func _build_indexes() -> void:
	_items_by_category.clear()
	_items_by_slot.clear()
	for item_id in _items.keys():
		var item: Dictionary = _items[item_id]
		var category := String(item.get("category", item.get("type", ""))).to_lower()
		var slot := String(item.get("slot", "")).to_lower()
		if category != "":
			if not _items_by_category.has(category):
				_items_by_category[category] = []
			_items_by_category[category].append(item.duplicate(true))
		if slot != "":
			if not _items_by_slot.has(slot):
				_items_by_slot[slot] = []
			_items_by_slot[slot].append(item.duplicate(true))
