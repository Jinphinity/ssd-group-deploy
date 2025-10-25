extends CanvasLayer

## Enhanced Inventory UI with "I" key toggle and database synchronization for 2D gameplay

const EQUIPMENT_SLOT_DISPLAY := [
	{"id": "weapon", "label": "Weapon"},
	{"id": "head", "label": "Head"},
	{"id": "torso", "label": "Torso"},
	{"id": "legs", "label": "Legs"},
	{"id": "accessory", "label": "Accessory"}
]

@onready var list: ItemList = $Root/Panel/ItemList
@onready var info: Label = $Root/Panel/Info
@onready var close_button: Button = $Root/Panel/CloseButton
@onready var equip_button: Button = $Root/Panel/EquipButton
@onready var unequip_button: Button = $Root/Panel/UnequipButton
@onready var equipment_info: RichTextLabel = $Root/Panel/EquipmentInfo

var inv: Inventory = null
var is_syncing: bool = false
var last_sync_time: float = 0.0
var sync_interval: float = 5.0  # Sync every 5 seconds

signal inventory_opened()
signal inventory_closed()

func _ready() -> void:
	visible = false
	
	# Set process mode to handle input when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	_find_player_inventory()
	
	# Set up close button if it exists
	if close_button:
		close_button.pressed.connect(_close_inventory)
	if equip_button:
		equip_button.pressed.connect(_on_equip_button_pressed)
	if unequip_button:
		unequip_button.pressed.connect(_on_unequip_button_pressed)
	
	# Add to inventory UI group for easy access
	add_to_group("inventory_ui")

# Input handling re-enabled - UIIntegrationManager not working correctly
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_just_pressed("ui_cancel"):
		_close_inventory()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	# Auto-sync inventory with database periodically
	last_sync_time += delta
	if last_sync_time >= sync_interval and not is_syncing:
		_sync_with_database()
		last_sync_time = 0.0

func _find_player_inventory() -> void:
	"""Find player inventory from the active 2D player"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		# Try finding specific player types
		player = get_tree().get_first_node_in_group("player_sniper")
	
	if player and player.has_node("Inventory"):
		inv = player.get_node("Inventory")
		_refresh()
		inv.item_added.connect(_refresh)
		inv.item_removed.connect(_refresh)
		inv.item_updated.connect(_refresh)
		if not inv.inventory_changed.is_connected(_refresh):
			inv.inventory_changed.connect(_refresh)
		if inv.has_signal("equipment_changed") and not inv.equipment_changed.is_connected(_on_equipment_changed):
			inv.equipment_changed.connect(_on_equipment_changed)
		print("📦 Inventory UI connected to player inventory")
	else:
		print("❌ No player inventory found")

func _toggle_inventory() -> void:
	"""Toggle inventory visibility with I key"""
	if visible:
		_close_inventory()
	else:
		_open_inventory()

func _open_inventory() -> void:
	"""Open inventory UI"""
	# Close other UIs first via Game singleton
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game.has_method("_close_all_uis_except"):
			game._close_all_uis_except("inventory")
	
	visible = true
	_refresh()
	_sync_with_database()
	_update_equipment_info()
	inventory_opened.emit()
	print("📦 Inventory opened")
	
	# Pause game while inventory is open
	if get_tree():
		get_tree().paused = true

func _close_inventory() -> void:
	"""Close inventory UI"""
	visible = false
	inventory_closed.emit()
	print("📦 Inventory closed")
	
	# Unpause game
	if get_tree():
		get_tree().paused = false

func _refresh(_a = null) -> void:
	"""Refresh inventory display"""
	if inv == null:
		return
		
	list.clear()
	for i in range(inv.items.size()):
		var item = inv.items[i]
		var name: String = item.get("name", "Item")
		var quantity: int = item.get("quantity", 1)
		var durability: int = item.get("durability", 100)
		var rarity: String = item.get("rarity", "common")
		var equipped_prefix := ""
		if item.get("equipped", false):
			equipped_prefix = "[E] "
		
		var item_text = "%s%s x%d" % [equipped_prefix, name, quantity]
		if durability < 100:
			item_text += " (%d%%)" % durability
			
		list.add_item(item_text)
		
		# Color code by rarity
		match rarity:
			"rare":
				list.set_item_custom_bg_color(i, Color.BLUE * 0.3)
			"epic":
				list.set_item_custom_bg_color(i, Color.PURPLE * 0.3)
			"legendary":
				list.set_item_custom_bg_color(i, Color.GOLD * 0.3)
	
	# Update info display
	info.text = "Slots: %d/%d  Weight: %.1f/%.1f kg" % [
		inv.get_slots_used(), 
		inv.capacity_slots, 
		inv.get_weight(), 
		inv.carry_weight_max
	]
	_update_equipment_info()

func _update_equipment_info(summary: Dictionary = {}) -> void:
	if summary.is_empty() and inv:
		summary = inv.get_equipment_summary()
	var modifiers: Dictionary = summary.get("modifiers", {})
	var stat_mods: Dictionary = modifiers.get("stat_mods", {})
	var slots: Dictionary = summary.get("slots", {})
	var player := get_tree().get_first_node_in_group("player_sniper")
	var lines: Array[String] = []
	if player and player is PlayerSniper:
		var ps: PlayerSniper = player
		lines.append("[b]Survivor[/b]")
		lines.append("Level %d" % ps.current_level)
		lines.append("XP %d / %d" % [ps.current_xp, ps.xp_to_next])
		lines.append("Ammo %d / %d" % [ps.ammo_in_mag, ps.magazine_size])
		lines.append("Reserve %d" % ps.reserve_ammo)
		lines.append("")

	lines.append("[b]Equipped[/b]")
	for slot_entry in EQUIPMENT_SLOT_DISPLAY:
		var slot_id: String = slot_entry["id"]
		var slot_label: String = slot_entry["label"]
		var item = slots.get(slot_id, null)
		if item:
			var tier: Variant = item.get("tier", "-")
			lines.append("%s: %s (Tier %s)" % [slot_label, item.get("name", "?"), tier])
		else:
			lines.append("%s: None" % slot_label)
	lines.append("\n[b]Modifiers[/b]")
	for stat in stat_mods.keys():
		lines.append("%s %+d" % [stat.capitalize(), stat_mods[stat]])
	lines.append("Damage %+0.1f" % modifiers.get("damage_bonus", 0.0))
	lines.append("Defense %+0.1f" % modifiers.get("defense_bonus", 0.0))
	var dmg_reduction := float(modifiers.get("damage_reduction", 0.0))
	if abs(dmg_reduction) > 0.001:
		lines.append("Damage Reduction %+0.1f%%" % (dmg_reduction * 100.0))
	lines.append("Speed x%.2f" % modifiers.get("speed_multiplier", 1.0))
	var capacity_bonus := int(modifiers.get("capacity_bonus_slots", 0))
	if capacity_bonus != 0:
		lines.append("Capacity %+d slots" % capacity_bonus)
	var carry_bonus := float(modifiers.get("carry_weight_bonus", 0.0))
	if abs(carry_bonus) > 0.001:
		lines.append("Carry Weight %+0.1f kg" % carry_bonus)
	var reload_bonus := float(modifiers.get("reload_speed_bonus", 0.0))
	if abs(reload_bonus) > 0.001:
		lines.append("Reload %+0.1f%%" % (reload_bonus * 100.0))
	if equipment_info:
		equipment_info.bbcode_text = "\n".join(lines)

func _on_equipment_changed(summary: Dictionary) -> void:
	_update_equipment_info(summary)
	_refresh()

func _on_equip_button_pressed() -> void:
	if inv == null:
		return
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var index := int(selected[0])
	if inv.equip_item(index):
		_update_equipment_info()

func _on_unequip_button_pressed() -> void:
	if inv == null:
		return
	var selected := list.get_selected_items()
	if selected.is_empty():
		return
	var item: Dictionary = inv.items[int(selected[0])]
	var slot: String = _normalize_slot(item.get("slot", ""))
	if slot != "":
		inv.unequip_slot(slot)
		_update_equipment_info()

func _sync_with_database() -> void:
	"""Synchronize inventory with database"""
	if not inv or is_syncing or not (has_node("/root/AuthController") and AuthController.get_auth_status().is_authenticated):
		return
	
	is_syncing = true
	
	# Get current character
	var character_data = CharacterService.get_current_character()
	if not character_data or not character_data.has("id"):
		is_syncing = false
		return
	
	var character_id = character_data.id
	
	# Prepare inventory data for sync
	var inventory_data = {
		"character_id": character_id,
		"items": inv.items,
		"capacity_slots": inv.capacity_slots,
		"carry_weight_max": inv.carry_weight_max,
		"slots_used": inv.get_slots_used(),
		"current_weight": inv.get_weight()
	}
	
	# Send to API
	Api.post("inventory/sync", inventory_data, "inventory_sync")
	print("📦 Syncing inventory with database...")

func _on_api_response(response_data: Dictionary, request_id: String) -> void:
	"""Handle API responses for inventory operations"""
	if request_id == "inventory_sync":
		is_syncing = false
		if response_data.get("success", false):
			print("📦 Inventory synced successfully")
		else:
			print("❌ Inventory sync failed: %s" % response_data.get("error", "Unknown error"))
	elif request_id == "inventory_load":
		_handle_inventory_load(response_data)

func _normalize_slot(slot_value: String) -> String:
	var slot := slot_value.strip_edges().to_lower()
	match slot:
		"armor":
			return "torso"
		"helmet":
			return "head"
		"pants":
			return "legs"
		_:
			return slot

func _handle_inventory_load(response_data: Dictionary) -> void:
	"""Handle loaded inventory data from database"""
	if not response_data.get("success", false) or not inv:
		return
		
	var inventory_data = response_data.get("data", {})
	var items = inventory_data.get("items", [])
	
	# Clear current inventory and load from database
	inv.items.clear()
	for item in items:
		inv.items.append(item)
	
	# Update capacity if provided
	if inventory_data.has("capacity_slots"):
		inv.capacity_slots = inventory_data.capacity_slots
	if inventory_data.has("carry_weight_max"):
		inv.carry_weight_max = inventory_data.carry_weight_max
	
	_refresh()
	print("📦 Inventory loaded from database")

func load_inventory_from_database() -> void:
	"""Load inventory from database"""
	var character_data = CharacterService.get_current_character()
	if not character_data or not character_data.has("id"):
		return
	
	var character_id = character_data.id
	Api.get_json("inventory/%d" % character_id, "inventory_load")

# Connect to API responses
func _enter_tree() -> void:
	if Api:
		Api.response_received.connect(_on_api_response)
