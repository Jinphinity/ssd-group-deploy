extends Node
class_name UIIntegrationManager

## UI Integration Manager for seamless access to all game systems
## Provides unified access to inventory, crafting, market, and other UI systems

# UI System References
var inventory_ui: CanvasLayer = null
var crafting_ui: CraftingUI = null
var market_ui: CanvasLayer = null
var hud: CanvasLayer = null

# Controller References
var inventory: Inventory = null
var crafting_controller: CraftingController = null
var market_controller: MarketController = null

# State Management
var current_open_ui: String = ""
var is_any_ui_open: bool = false
var ui_systems_connected: bool = false

# Configuration
var enable_ui_sounds: bool = true
var auto_pause_on_ui: bool = true

# Signals
signal ui_opened(ui_name: String)
signal ui_closed(ui_name: String)
signal ui_integration_ready()

func _ready() -> void:
	# Add to integration manager group
	add_to_group("ui_integration_manager")

	# Set process mode to handle input when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Initialize after a short delay to ensure all systems are loaded
	call_deferred("_initialize_ui_integration")

	print("🎮 UI Integration Manager initialized")

func _initialize_ui_integration() -> void:
	"""Initialize connections to all UI systems and controllers"""
	print("🔧 UI Integration Manager: Starting initialization...")

	_find_ui_systems()
	_find_controllers()
	_setup_input_mappings()
	_connect_ui_signals()

	ui_systems_connected = _validate_connections()

	if ui_systems_connected:
		print("✅ UI Integration Manager: All systems connected successfully")
		ui_integration_ready.emit()
	else:
		print("⚠️ UI Integration Manager: Some systems not available - will retry in 1 second")
		print("🔍 Current status: %s" % get_integration_status())
		# Retry after 1 second for late-loading systems
		get_tree().create_timer(1.0).timeout.connect(_initialize_ui_integration)

func _find_ui_systems() -> void:
	"""Locate all UI system references"""
	# Find HUD
	hud = get_tree().get_first_node_in_group("hud")
	if not hud:
		var stage = get_tree().current_scene
		if stage:
			hud = stage.get_node_or_null("UI/HUD")

	# Find Inventory UI
	inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if not inventory_ui:
		var stage = get_tree().current_scene
		if stage:
			inventory_ui = stage.get_node_or_null("UI/InventoryUI")

	# Find Crafting UI
	crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
	if not crafting_ui:
		var stage = get_tree().current_scene
		if stage:
			crafting_ui = stage.get_node_or_null("UI/CraftingUI")

	# Find Market UI
	market_ui = get_tree().get_first_node_in_group("market_ui")
	if not market_ui:
		var stage = get_tree().current_scene
		if stage:
			market_ui = stage.get_node_or_null("UI/MarketUI")

	print("🔍 UI Systems found - HUD: %s, Inventory: %s, Crafting: %s, Market: %s" % [
		"✓" if hud else "✗",
		"✓" if inventory_ui else "✗",
		"✓" if crafting_ui else "✗",
		"✓" if market_ui else "✗"
	])

func _find_controllers() -> void:
	"""Locate all controller references"""
	# Find player and inventory
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("player_sniper")

	if player and player.has_node("Inventory"):
		inventory = player.get_node("Inventory")

	# Find crafting controller
	crafting_controller = get_tree().get_first_node_in_group("crafting_controller")
	if not crafting_controller:
		var stage = get_tree().current_scene
		if stage:
			crafting_controller = stage.get_node_or_null("CraftingController")

	# Find market controller
	market_controller = get_tree().get_first_node_in_group("market_controller")
	if not market_controller:
		var stage = get_tree().current_scene
		if stage:
			market_controller = stage.get_node_or_null("MarketController")

	print("🎛️ Controllers found - Inventory: %s, Crafting: %s, Market: %s" % [
		"✓" if inventory else "✗",
		"✓" if crafting_controller else "✗",
		"✓" if market_controller else "✗"
	])

func _setup_input_mappings() -> void:
	"""Setup input action mappings for UI access"""
	# Ensure input actions exist - add them if missing
	_ensure_input_action("inventory", KEY_I)
	_ensure_input_action("crafting", KEY_C)
	_ensure_input_action("market", KEY_M)
	_ensure_input_action("ui_cancel", KEY_ESCAPE)

	print("⌨️ Input mappings configured")

func _ensure_input_action(action_name: String, default_key: Key) -> void:
	"""Ensure an input action exists with a default key binding"""
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var input_event = InputEventKey.new()
		input_event.keycode = default_key
		InputMap.action_add_event(action_name, input_event)
		print("➕ Added input action: %s → %s" % [action_name, OS.get_keycode_string(default_key)])

func _connect_ui_signals() -> void:
	"""Connect to UI system signals for state management"""
	# Connect to inventory UI signals if available
	if inventory_ui:
		if inventory_ui.has_signal("inventory_opened"):
			if not inventory_ui.inventory_opened.is_connected(_on_ui_opened):
				inventory_ui.inventory_opened.connect(func(): _on_ui_opened("inventory"))
		if inventory_ui.has_signal("inventory_closed"):
			if not inventory_ui.inventory_closed.is_connected(_on_ui_closed):
				inventory_ui.inventory_closed.connect(func(): _on_ui_closed("inventory"))

	print("🔗 UI signals connected")

func _validate_connections() -> bool:
	"""Validate that essential systems are connected"""
	var essential_systems = [
		inventory_ui != null,
		crafting_ui != null,
		inventory != null
	]

	return essential_systems.all(func(connected): return connected)

func _unhandled_input(event: InputEvent) -> void:
	"""Handle UI hotkeys and navigation"""
	if not ui_systems_connected:
		return

	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("crafting"):
		toggle_crafting()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("market"):
		toggle_market()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("ui_cancel") and is_any_ui_open:
		close_all_uis()
		get_viewport().set_input_as_handled()

# Public API for UI Management

func toggle_inventory() -> void:
	"""Toggle inventory UI - primary system access"""
	if current_open_ui == "inventory":
		close_inventory()
	else:
		open_inventory()

func toggle_crafting() -> void:
	"""Toggle crafting UI"""
	if current_open_ui == "crafting":
		close_crafting()
	else:
		open_crafting()

func toggle_market() -> void:
	"""Toggle market UI"""
	if current_open_ui == "market":
		close_market()
	else:
		open_market()

func open_inventory() -> void:
	"""Open inventory UI"""
	if not inventory_ui:
		_show_system_message("Inventory system not available", "error")
		return

	close_all_uis()

	if inventory_ui.has_method("_open_inventory"):
		inventory_ui._open_inventory()
	elif inventory_ui.has_method("toggle") and not inventory_ui.visible:
		inventory_ui.toggle()
	else:
		inventory_ui.visible = true

	_set_current_ui("inventory")
	_show_system_message("Inventory opened [I to close]", "info")

func close_inventory() -> void:
	"""Close inventory UI"""
	if not inventory_ui:
		return

	if inventory_ui.has_method("_close_inventory"):
		inventory_ui._close_inventory()
	elif inventory_ui.has_method("toggle") and inventory_ui.visible:
		inventory_ui.toggle()
	else:
		inventory_ui.visible = false

	_clear_current_ui("inventory")

func open_crafting() -> void:
	"""Open crafting UI"""
	if not crafting_ui:
		_show_system_message("Crafting system not available", "error")
		return

	if not crafting_controller:
		_show_system_message("Crafting controller not found", "error")
		return

	close_all_uis()

	# Connect crafting UI to controllers if needed
	if crafting_ui.controller == null and crafting_controller:
		crafting_ui.set_controller(crafting_controller)
	if crafting_ui.inventory == null and inventory:
		crafting_ui.set_inventory(inventory)

	if crafting_ui.has_method("show_ui"):
		crafting_ui.show_ui()
	elif crafting_ui.has_method("toggle"):
		if not crafting_ui.is_ui_open():
			crafting_ui.toggle()
	else:
		crafting_ui.visible = true

	_set_current_ui("crafting")
	_show_system_message("Crafting opened [C to close]", "info")

func close_crafting() -> void:
	"""Close crafting UI"""
	if not crafting_ui:
		return

	if crafting_ui.has_method("hide_ui"):
		crafting_ui.hide_ui()
	elif crafting_ui.has_method("toggle") and crafting_ui.is_ui_open():
		crafting_ui.toggle()
	else:
		crafting_ui.visible = false

	_clear_current_ui("crafting")

func open_market() -> void:
	"""Open market UI with offline support"""
	if not market_ui:
		_show_system_message("Market system not available", "error")
		return

	close_all_uis()

	# Ensure market controller exists (use fallback creation if needed)
	if not market_controller and market_ui.has_method("_create_fallback_market"):
		market_ui._create_fallback_market()
		market_controller = get_tree().get_first_node_in_group("market_controller")

	if market_ui.has_method("show_market_ui"):
		market_ui.show_market_ui()
	elif market_ui.has_method("toggle"):
		market_ui.toggle()
	else:
		market_ui.visible = true

	_set_current_ui("market")
	_show_system_message("Market opened [M to close]", "info")

func close_market() -> void:
	"""Close market UI"""
	if not market_ui:
		return

	if market_ui.has_method("hide_market_ui"):
		market_ui.hide_market_ui()
	elif market_ui.has_method("toggle") and market_ui.visible:
		market_ui.toggle()
	else:
		market_ui.visible = false

	_clear_current_ui("market")

func close_all_uis() -> void:
	"""Close all open UI systems"""
	close_inventory()
	close_crafting()
	close_market()
	current_open_ui = ""
	is_any_ui_open = false

# Internal State Management

func _set_current_ui(ui_name: String) -> void:
	"""Set the currently open UI"""
	current_open_ui = ui_name
	is_any_ui_open = true

	# Pause game if configured
	if auto_pause_on_ui and get_tree():
		get_tree().paused = true

	ui_opened.emit(ui_name)

func _clear_current_ui(ui_name: String) -> void:
	"""Clear the currently open UI if it matches"""
	if current_open_ui == ui_name:
		current_open_ui = ""
		is_any_ui_open = false

		# Unpause game if no UIs are open
		if auto_pause_on_ui and get_tree():
			get_tree().paused = false

		ui_closed.emit(ui_name)

func _on_ui_opened(ui_name: String) -> void:
	"""Handle UI opened event"""
	_set_current_ui(ui_name)

func _on_ui_closed(ui_name: String) -> void:
	"""Handle UI closed event"""
	_clear_current_ui(ui_name)

func _show_system_message(message: String, type: String) -> void:
	"""Show system message via HUD if available"""
	if hud and hud.has_method("show_event_notification"):
		hud.show_event_notification(message, type)
	else:
		print("🎮 %s: %s" % [type.to_upper(), message])

# Public API for external systems

func is_ui_open() -> bool:
	"""Check if any UI is currently open"""
	return is_any_ui_open

func get_current_ui() -> String:
	"""Get the name of the currently open UI"""
	return current_open_ui

func is_inventory_open() -> bool:
	"""Check if inventory is open"""
	return current_open_ui == "inventory"

func is_crafting_open() -> bool:
	"""Check if crafting is open"""
	return current_open_ui == "crafting"

func is_market_open() -> bool:
	"""Check if market is open"""
	return current_open_ui == "market"

func get_integration_status() -> Dictionary:
	"""Get detailed status of UI integration"""
	return {
		"systems_connected": ui_systems_connected,
		"current_ui": current_open_ui,
		"any_ui_open": is_any_ui_open,
		"components": {
			"hud": hud != null,
			"inventory_ui": inventory_ui != null,
			"crafting_ui": crafting_ui != null,
			"market_ui": market_ui != null,
			"inventory": inventory != null,
			"crafting_controller": crafting_controller != null,
			"market_controller": market_controller != null
		}
	}

# Configuration API

func set_auto_pause(enabled: bool) -> void:
	"""Configure whether UIs should auto-pause the game"""
	auto_pause_on_ui = enabled

func set_ui_sounds(enabled: bool) -> void:
	"""Configure whether UI interactions should play sounds"""
	enable_ui_sounds = enabled

# Integration with Game Scene

func notify_game_ready() -> void:
	"""Called by Game scene when fully initialized"""
	if not ui_systems_connected:
		_initialize_ui_integration()

func _exit_tree() -> void:
	"""Cleanup when manager is removed"""
	close_all_uis()
	print("🎮 UI Integration Manager shutdown")