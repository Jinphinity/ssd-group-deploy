extends Node

## Enhanced Inventory system with database integration and character linking
## Tailored for 2D player characters

class_name Inventory

const ItemDatabaseClass = preload("res://common/Data/ItemDatabase.gd")
const EQUIPMENT_SLOT_ORDER := [
	"weapon",
	"head",
	"torso",
	"legs",
	"accessory"
]

signal item_added(item)
signal item_removed(item)
signal item_updated(item)
signal inventory_changed()
signal equipment_changed(equipment_summary)

@export var capacity_slots: int = 12
@export var carry_weight_max: float = 25.0

var items: Array = [] # array of Dictionaries
var character_id: int = -1
var is_dirty: bool = false  # Track if inventory needs syncing
var last_save_time: float = 0.0
var equipment_slots := {
	"weapon": null,
	"head": null,
	"torso": null,
	"legs": null,
	"accessory": null
}
var _equipment_summary := {
	"stat_mods": {},
	"damage_bonus": 0.0,
	"defense_bonus": 0.0,
	"damage_reduction": 0.0,
	"speed_multiplier": 1.0,
	"magazine_size": 0,
	"reserve_ammo": 0,
	"capacity_bonus_slots": 0,
	"carry_weight_bonus": 0.0,
	"reload_speed_bonus": 0.0,
	"weapon_item": null,
	"weapon_params": {}
}
var _base_capacity_slots: int = -1
var _base_carry_weight_max: float = -1.0

func _ready() -> void:
	if _base_capacity_slots < 0:
		_base_capacity_slots = capacity_slots
	if _base_carry_weight_max < 0.0:
		_base_carry_weight_max = carry_weight_max
	_normalize_equipment_state()
	_recalculate_equipment_modifiers()

	# Connect to character service to get character ID
	if has_node("/root/CharacterService"):
		var character_data = CharacterService.get_current_character()
		if character_data and character_data.has("id"):
			character_id = int(character_data.id)
			load_from_database()

	# Connect to auth state changes for online/offline transitions
	if AuthController:
		if not AuthController.user_logged_in.is_connected(_on_user_logged_in):
			AuthController.user_logged_in.connect(_on_user_logged_in)
		if not AuthController.user_logged_out.is_connected(_on_user_logged_out):
			AuthController.user_logged_out.connect(_on_user_logged_out)
		print("✅ [INVENTORY] Connected to AuthController state change signals")
	else:
		print("⚠️ [INVENTORY] AuthController not available during initialization")

func hydrate_from_character_data(character_data: Dictionary) -> void:
	"""Apply persisted equipment and inventory data from character storage."""
	if character_data.is_empty():
		return

	# Restore inventory items (if present)
	if character_data.has("inventory_items") and typeof(character_data["inventory_items"]) == TYPE_ARRAY:
		items.clear()
		for raw_item in character_data["inventory_items"]:
			if typeof(raw_item) == TYPE_DICTIONARY:
				items.append(raw_item.duplicate(true))

	# Restore equipment slots
	if character_data.has("equipment") and typeof(character_data["equipment"]) == TYPE_DICTIONARY:
		var stored_equipment: Dictionary = character_data["equipment"]
		for slot in EQUIPMENT_SLOT_ORDER:
			var stored_item = stored_equipment.get(slot, null)
			if typeof(stored_item) == TYPE_DICTIONARY:
				var item_copy: Dictionary = stored_item.duplicate(true)
				item_copy["equipped"] = true
				equipment_slots[slot] = item_copy
				# Ensure equipped item exists in inventory list
				var found := false
				for inv_item in items:
					if typeof(inv_item) == TYPE_DICTIONARY and inv_item.get("id", "") == item_copy.get("id", ""):
						inv_item["equipped"] = true
						found = true
						break
				if not found:
					items.append(item_copy.duplicate(true))
			else:
				equipment_slots[slot] = null

	# Restore inventory limits
	if character_data.has("inventory_capacity_slots"):
		var capacity := int(character_data["inventory_capacity_slots"])
		capacity_slots = max(capacity, 0)
		_base_capacity_slots = capacity_slots
	if character_data.has("inventory_carry_weight_max"):
		var carry_limit := float(character_data["inventory_carry_weight_max"])
		carry_weight_max = max(carry_limit, 0.0)
		_base_carry_weight_max = carry_weight_max

	_normalize_equipment_state()
	_recalculate_equipment_modifiers()

	if character_data.has("equipment_modifiers") and typeof(character_data["equipment_modifiers"]) == TYPE_DICTIONARY:
		_equipment_summary = character_data["equipment_modifiers"].duplicate(true)

	is_dirty = false
	inventory_changed.emit()
	equipment_changed.emit(get_equipment_summary())

func add_item(item: Dictionary) -> bool:
	# Check if we can add the item
	if get_slots_used() + int(item.get("slot_size", 1)) > capacity_slots:
		print("❌ Inventory full - cannot add %s" % item.get("name", "item"))
		return false
	if get_weight() + float(item.get("weight", 0.0)) > carry_weight_max:
		print("❌ Too heavy - cannot add %s" % item.get("name", "item"))
		return false
	
	# Try to stack with existing items
	var stacked = _try_stack_item(item)
	if not stacked:
		# Add as new item
		item["slot"] = _normalize_slot(item.get("slot", ""))
		item["id"] = _generate_item_id()
		item["acquired_at"] = Time.get_unix_time_from_system()
		item["equipped"] = item.get("equipped", false)
		items.append(item)
	
	item_added.emit(item)
	inventory_changed.emit()
	_mark_dirty()
	print("📦 Added %s to inventory" % item.get("name", "item"))
	return true

func remove_item(idx: int) -> Dictionary:
	if idx < 0 or idx >= items.size():
		return {}
	var item = items.pop_at(idx)

	# Unequip if the removed item was equipped
	var slot = _normalize_slot(item.get("slot", ""))
	if slot != "" and equipment_slots.has(slot) and equipment_slots[slot] and equipment_slots[slot].get("id", "") == item.get("id", ""):
		equipment_slots[slot] = null
		_recalculate_equipment_modifiers()

	item_removed.emit(item)
	inventory_changed.emit()
	_mark_dirty()
	print("📦 Removed %s from inventory" % item.get("name", "item"))
	return item

func remove_item_by_name(item_name: String, quantity: int = 1) -> bool:
	"""Remove items by name and quantity"""
	var removed_count = 0
	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if item.get("name", "") == item_name:
			var item_quantity = item.get("quantity", 1)
			if item_quantity <= quantity - removed_count:
				# Remove entire stack
				removed_count += item_quantity
				remove_item(i)
			else:
				# Reduce quantity
				item["quantity"] = item_quantity - (quantity - removed_count)
				removed_count = quantity
				item_updated.emit(item)
				inventory_changed.emit()
				_mark_dirty()
			
			if removed_count >= quantity:
				return true
	
	return removed_count > 0

func get_slots_used() -> int:
	var s := 0
	for it in items:
		s += int(it.get("slot_size", 1))
	return s

func get_weight() -> float:
	var w := 0.0
	for it in items:
		var item_weight = float(it.get("weight", 0.0))
		var quantity = int(it.get("quantity", 1))
		w += item_weight * quantity
	return w

func add_item_by_id(item_id: String, quantity: int = 1, auto_equip: bool = false) -> bool:
	var item_instance = ItemDatabaseClass.create_item_instance(item_id, quantity)
	if item_instance.is_empty():
		print("❌ Unknown item id: %s" % item_id)
		return false
	if add_item(item_instance):
		if auto_equip and item_instance.has("slot"):
			equip_item_by_internal_id(item_instance.get("id", ""))
		return true
	return false

func equip_item(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	return equip_item_dictionary(items[index])

func equip_item_by_internal_id(item_internal_id: String) -> bool:
	for item in items:
		if item.get("id", "") == item_internal_id:
			return equip_item_dictionary(item)
	return false

func equip_item_dictionary(item: Dictionary) -> bool:
	var slot = _normalize_slot(item.get("slot", ""))
	if slot == "" or not equipment_slots.has(slot):
		print("⚠️ Item %s cannot be equipped (slot missing)" % item.get("name", ""))
		return false

	# Unequip existing item in that slot
	if equipment_slots[slot]:
		equipment_slots[slot]["equipped"] = false

	item["equipped"] = true
	item["slot"] = slot
	equipment_slots[slot] = item
	_recalculate_equipment_modifiers()
	inventory_changed.emit()
	_mark_dirty()
	_update_character_persistence()
	print("🛡️ Equipped %s into slot %s" % [item.get("name", ""), slot])
	return true

func unequip_slot(slot: String) -> void:
	slot = _normalize_slot(slot)
	if not equipment_slots.has(slot):
		return
	var equipped_item = equipment_slots[slot]
	if equipped_item:
		equipped_item["equipped"] = false
	equipment_slots[slot] = null
	_recalculate_equipment_modifiers()
	inventory_changed.emit()
	_mark_dirty()
	_update_character_persistence()

func get_equipment_summary() -> Dictionary:
	return {
		"slots": _duplicate_equipment_slots(),
		"modifiers": _equipment_summary.duplicate(true)
	}

func get_item_count(item_name: String) -> int:
	"""Get total quantity of specific item"""
	var count = 0
	for item in items:
		if item.get("name", "") == item_name:
			count += item.get("quantity", 1)
	return count

func has_item(item_name: String, required_quantity: int = 1) -> bool:
	"""Check if inventory contains enough of specific item"""
	return get_item_count(item_name) >= required_quantity

func get_items_by_type(item_type: String) -> Array:
	"""Get all items of specific type"""
	var filtered_items: Array[Dictionary] = []
	for item in items:
		if item.get("type", "") == item_type:
			filtered_items.append(item)
	return filtered_items

func _try_stack_item(new_item: Dictionary) -> bool:
	"""Try to stack new item with existing items"""
	var item_name = new_item.get("name", "")
	var new_quantity = new_item.get("quantity", 1)
	var max_stack = new_item.get("max_stack", 1)
	
	if max_stack <= 1:
		return false  # Item doesn't stack
	
	for item in items:
		if item.get("name", "") == item_name:
			var current_quantity = item.get("quantity", 1)
			var space_available = max_stack - current_quantity
			
			if space_available > 0:
				var add_amount = min(space_available, new_quantity)
				item["quantity"] = current_quantity + add_amount
				new_quantity -= add_amount
				item_updated.emit(item)
				
				if new_quantity <= 0:
					return true  # Fully stacked
	
	# If there's remaining quantity, modify the new item
	if new_quantity < new_item.get("quantity", 1):
		new_item["quantity"] = new_quantity
		return false  # Partially stacked, still need to add as new item
	
	return false

func _generate_item_id() -> String:
	"""Generate unique item ID"""
	return "item_%d_%d" % [character_id, Time.get_unix_time_from_system()]

func _normalize_slot(slot_value) -> String:
	if typeof(slot_value) != TYPE_STRING:
		return ""
	var slot := String(slot_value).strip_edges().to_lower()
	match slot:
		"armor":
			return "torso"
		"helmet":
			return "head"
		"pants":
			return "legs"
		_:
			return slot

func _create_empty_equipment_dict() -> Dictionary:
	var dict: Dictionary = {}
	for slot in EQUIPMENT_SLOT_ORDER:
		dict[slot] = null
	return dict

func _normalize_equipment_state() -> void:
	var normalized := _create_empty_equipment_dict()
	for slot in equipment_slots.keys():
		var item = equipment_slots[slot]
		if item == null:
			continue
		var normalized_slot := _normalize_slot(slot)
		if not normalized.has(normalized_slot):
			continue
		if item.has("slot"):
			item["slot"] = normalized_slot
		normalized[normalized_slot] = item
	equipment_slots = normalized

func _duplicate_equipment_slots() -> Dictionary:
	var dup: Dictionary = {}
	for slot in EQUIPMENT_SLOT_ORDER:
		var item = equipment_slots.get(slot, null)
		dup[slot] = item if item == null else item.duplicate(true)
	return dup

func _duplicate_inventory_items() -> Array:
	var result: Array = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item.duplicate(true))
		else:
			result.append(item)
	return result

func _recalculate_equipment_modifiers() -> void:
	_normalize_equipment_state()
	var stat_totals: Dictionary = {}
	var damage_bonus := 0.0
	var defense_bonus := 0.0
	var damage_reduction := 0.0
	var speed_multiplier := 1.0
	var magazine_size := 0
	var reserve_ammo := 0
	var capacity_bonus_slots := 0
	var carry_weight_bonus := 0.0
	var reload_speed_bonus := 0.0

	for slot in equipment_slots.keys():
		var item = equipment_slots[slot]
		if item == null:
			continue

		var item_stat_mods: Dictionary = item.get("stat_mods", {})
		for stat_name in item_stat_mods.keys():
			stat_totals[stat_name] = stat_totals.get(stat_name, 0) + int(item_stat_mods[stat_name])

		var base_damage := float(item.get("base_damage_bonus", item.get("damage_bonus", 0.0)))
		damage_bonus += base_damage
		defense_bonus += float(item.get("defense_bonus", 0.0))
		damage_reduction += float(item.get("damage_reduction", 0.0))
		var item_speed := float(item.get("speed_multiplier", 1.0))
		if item_speed <= 0.0:
			item_speed = 0.01
		speed_multiplier *= item_speed
		capacity_bonus_slots += int(item.get("capacity_bonus", 0))
		carry_weight_bonus += float(item.get("carry_weight_bonus", 0.0))
		reload_speed_bonus += float(item.get("reload_speed_bonus", 0.0))

		if slot == "weapon":
			if item.has("magazine_size"):
				magazine_size = int(item.get("magazine_size"))
			if item.has("reserve_ammo"):
				reserve_ammo = int(item.get("reserve_ammo"))

	damage_reduction = clamp(damage_reduction, 0.0, 0.9)
	if speed_multiplier <= 0.0:
		speed_multiplier = 0.01

	var weapon_item: Variant = equipment_slots.get("weapon", null)
	var weapon_summary: Dictionary = {}
	var weapon_copy = null
	if weapon_item:
		weapon_copy = weapon_item.duplicate(true)
		weapon_summary = {
			"spread_degrees": weapon_copy.get("spread_degrees", weapon_copy.get("spread", 0.0)),
			"recoil_per_shot": weapon_copy.get("recoil_per_shot", weapon_copy.get("recoil", 0.0)),
			"recoil_recovery": weapon_copy.get("recoil_recovery", 6.0),
			"falloff_start": weapon_copy.get("falloff_start", weapon_copy.get("damage_falloff_start", 0.0)),
			"falloff_end": weapon_copy.get("falloff_end", weapon_copy.get("damage_falloff_end", 0.0)),
			"falloff_min": weapon_copy.get("falloff_min_multiplier", weapon_copy.get("falloff_min", 0.4)),
			"accuracy_multiplier": weapon_copy.get("accuracy_multiplier", weapon_copy.get("accuracy", 1.0)),
			"base_damage": weapon_copy.get("base_damage", weapon_copy.get("damage", 10.0)),
			"reload_time": weapon_copy.get("reload_time", 2.0),
			"fire_rate": weapon_copy.get("fire_rate", 0.5)
		}

	_equipment_summary = {
		"stat_mods": stat_totals,
		"damage_bonus": damage_bonus,
		"defense_bonus": defense_bonus,
		"damage_reduction": damage_reduction,
		"speed_multiplier": speed_multiplier,
		"magazine_size": magazine_size,
		"reserve_ammo": reserve_ammo,
		"capacity_bonus_slots": capacity_bonus_slots,
		"carry_weight_bonus": carry_weight_bonus,
		"reload_speed_bonus": reload_speed_bonus,
		"weapon_item": weapon_copy,
		"weapon_params": weapon_summary
	}

	if _base_capacity_slots >= 0:
		capacity_slots = max(0, _base_capacity_slots + capacity_bonus_slots)
		capacity_slots = max(capacity_slots, get_slots_used())
	if _base_carry_weight_max >= 0.0:
		carry_weight_max = max(0.0, _base_carry_weight_max + carry_weight_bonus)

	equipment_changed.emit(get_equipment_summary())

func _update_character_persistence() -> void:
	if not has_node("/root/CharacterService"):
		return
	var current = CharacterService.get_current_character()
	if current.is_empty():
		return
	current["equipment"] = _duplicate_equipment_slots()
	current["equipment_modifiers"] = _equipment_summary.duplicate(true)
	current["inventory_items"] = _duplicate_inventory_items()
	current["inventory_capacity_slots"] = capacity_slots
	current["inventory_carry_weight_max"] = carry_weight_max
	CharacterService.set_current_character(current)

func load_from_database() -> void:
	"""Load inventory from database"""
	if character_id <= 0:
		return

	var auth_status: Dictionary = AuthController.get_auth_status()
	var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])
	if not is_authenticated:
		return

	Api.get_json("inventory/%d" % character_id, "inventory_load_%d" % character_id)
	print("📦 Loading inventory from database for character %d" % character_id)

func save_to_database() -> void:
	"""Save inventory to database"""
	if character_id <= 0:
		print("⚠️ [INVENTORY] Cannot save - no character ID")
		return

	if not is_dirty:
		print("📦 [INVENTORY] Inventory already synced - no save needed")
		return

	var auth_status: Dictionary = AuthController.get_auth_status()
	var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])
	if not is_authenticated:
		print("⚠️ [INVENTORY] Cannot save - not authenticated")
		return

	if AuthController.is_offline_mode():
		print("⚠️ [INVENTORY] Cannot save - in offline mode")
		return

	var inventory_data = {
		"character_id": character_id,
		"items": items,
		"equipment": _duplicate_equipment_slots(),
		"capacity_slots": capacity_slots,
		"carry_weight_max": carry_weight_max,
		"slots_used": get_slots_used(),
		"current_weight": get_weight(),
		"last_modified": Time.get_unix_time_from_system(),
		"sync_version": 1
	}

	var request = Api.post("inventory/save", inventory_data, "inventory_save_%d" % character_id)
	if request:
		is_dirty = false
		last_save_time = Time.get_ticks_msec()
		print("📡 [INVENTORY] Saving inventory to server for character %d" % character_id)
	else:
		print("❌ [INVENTORY] Failed to initiate save request")

func _mark_dirty() -> void:
	"""Mark inventory as needing sync"""
	is_dirty = true
	last_save_time = Time.get_ticks_msec()

	# Auto-save to server after a short delay if online
	if character_id > 0:
		call_deferred("_auto_sync_check")

func _auto_sync_check() -> void:
	"""Check if we should auto-sync to server"""
	var auth_status: Dictionary = AuthController.get_auth_status() if AuthController else {}
	var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])

	if is_authenticated and not AuthController.is_offline_mode() and is_dirty:
		# Wait a bit to batch multiple changes, then sync
		await get_tree().create_timer(2.0).timeout
		if is_dirty:  # Check again in case it was synced in the meantime
			save_to_database()

func get_inventory_summary() -> Dictionary:
	"""Get inventory summary for display or API"""
	return {
		"character_id": character_id,
		"total_items": items.size(),
		"slots_used": get_slots_used(),
		"capacity_slots": capacity_slots,
		"current_weight": get_weight(),
		"carry_weight_max": carry_weight_max,
		"is_dirty": is_dirty,
		"item_types": _get_item_type_counts()
	}

func _get_item_type_counts() -> Dictionary:
	"""Get count of items by type"""
	var type_counts: Dictionary = {}
	for item in items:
		var item_type := "misc"
		if item.has("type"):
			item_type = String(item["type"])

		var current_count := 0
		if type_counts.has(item_type):
			current_count = int(type_counts[item_type])

		var quantity := 1
		if item.has("quantity"):
			quantity = int(item["quantity"])

		type_counts[item_type] = current_count + quantity
	return type_counts

# Add some starting items for testing
func add_starting_items() -> void:
	"""Add starting items for new characters"""
	var starting_items = [
		{
			"name": "Survival Knife",
			"type": "weapon",
			"rarity": "common",
			"damage": 15,
			"durability": 100,
			"weight": 0.5,
			"slot_size": 1,
			"quantity": 1,
			"max_stack": 1
		},
		{
			"name": "Bandage",
			"type": "medical",
			"rarity": "common",
			"heal_amount": 25,
			"weight": 0.1,
			"slot_size": 1,
			"quantity": 3,
			"max_stack": 10
		},
		{
			"name": "Energy Bar",
			"type": "consumable",
			"rarity": "common",
			"energy_restore": 50,
			"weight": 0.2,
			"slot_size": 1,
			"quantity": 2,
			"max_stack": 5
		}
	]

	for item in starting_items:
		add_item(item)

## Online/Offline Mode Handlers

func _on_user_logged_in(user_data: Dictionary) -> void:
	"""Handle user login - sync inventory to server"""
	print("📡 [INVENTORY] User logged in - syncing inventory to server")

	# Get character ID from current character
	if has_node("/root/CharacterService"):
		var character_data = CharacterService.get_current_character()
		if character_data and character_data.has("id"):
			character_id = int(character_data.id)
			print("📦 [INVENTORY] Character ID updated: %d" % character_id)

			# Load inventory from server for this character
			load_from_database()

			# Save any pending local changes to server
			if is_dirty:
				save_to_database()
		else:
			print("⚠️ [INVENTORY] No current character found for server sync")
	else:
		print("❌ [INVENTORY] CharacterService not available for sync")

func _on_user_logged_out() -> void:
	"""Handle user logout - stop server sync"""
	print("💾 [INVENTORY] User logged out - switching to offline mode")

	# Clear any server-specific state
	character_id = -1
	is_dirty = false

	# Keep local inventory data but stop server sync
	print("📦 [INVENTORY] Inventory data preserved locally")

func sync_to_server() -> void:
	"""Manually trigger sync to server if online"""
	if character_id > 0:
		var auth_status: Dictionary = AuthController.get_auth_status()
		var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])

		if is_authenticated and not AuthController.is_offline_mode():
			save_to_database()
			print("📡 [INVENTORY] Manual sync to server triggered")
		else:
			print("⚠️ [INVENTORY] Cannot sync - not authenticated or in offline mode")
	else:
		print("⚠️ [INVENTORY] Cannot sync - no character ID set")

func get_sync_status() -> Dictionary:
	"""Get current sync status for debugging"""
	var auth_status: Dictionary = AuthController.get_auth_status() if AuthController else {}
	var is_authenticated: bool = auth_status.has("is_authenticated") and bool(auth_status["is_authenticated"])
	var is_offline: bool = AuthController.is_offline_mode() if AuthController else true

	return {
		"character_id": character_id,
		"is_dirty": is_dirty,
		"is_authenticated": is_authenticated,
		"is_offline_mode": is_offline,
		"can_sync": character_id > 0 and is_authenticated and not is_offline,
		"last_save_time": last_save_time,
		"total_items": items.size(),
		"sync_enabled": AuthController != null and Api != null
	}
