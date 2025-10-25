extends Node

## Game singleton: high-level game state, scene loads, transitions

signal perspective_changed(mode: String)

var current_stage: Node = null
var event_bus: Node = null
var status_effects: StatusEffectManager = null
var survivability_manager: SurvivabilityManager = null
var ui_integration_manager: UIIntegrationManager = null
var current_perspective: String = "Side"  # Default to side-scrolling
var hud: CanvasLayer = null
var market_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null
var crafting_ui: CraftingUI = null
var crafting_controller: CraftingController = null
var market_controller: MarketController = null
var settlement_controller: SettlementController = null

# Auto-save system
var auto_save_timer: Timer = null
var auto_save_interval: float = 300.0  # Save every 5 minutes

func _ready() -> void:
	_ensure_input_map()
	# Create a lightweight EventBus node for global signals
	event_bus = preload("res://common/Util/EventBus.gd").new()
	event_bus.name = "EventBus"
	add_child(event_bus)
	status_effects = preload("res://common/Combat/StatusEffectManager.gd").new()
	status_effects.name = "StatusEffectManager"
	add_child(status_effects)
	survivability_manager = preload("res://common/Systems/SurvivabilityManager.gd").new()
	survivability_manager.name = "SurvivabilityManager"
	add_child(survivability_manager)

	# Create UI Integration Manager for unified UI access
	ui_integration_manager = preload("res://common/UI/UIIntegrationManager.gd").new()
	ui_integration_manager.name = "UIIntegrationManager"
	add_child(ui_integration_manager)

	# Setup auto-save system
	_setup_auto_save()

	# Saved stages are now restored after authentication via menu/continue
	# UI toggles routed here
	set_process_input(true)
	emit_signal("perspective_changed", current_perspective)

func load_stage(packed_path: String) -> void:
	if current_stage and current_stage.is_inside_tree():
		current_stage.queue_free()
	var p := load(packed_path)
	if p:
		current_stage = p.instantiate()
		get_tree().root.add_child(current_stage)
		get_tree().current_scene = current_stage
		# Grab UIs if present
		hud = current_stage.get_node_or_null("UI/HUD")
		if hud == null:
			hud = current_stage.get_node_or_null("HUD")

		market_ui = current_stage.get_node_or_null("UI/MarketUI")
		if market_ui == null:
			market_ui = current_stage.get_node_or_null("MarketUI")

		inventory_ui = current_stage.get_node_or_null("UI/InventoryUI")
		if inventory_ui == null:
			inventory_ui = current_stage.get_node_or_null("InventoryUI")
		crafting_ui = current_stage.get_node_or_null("UI/CraftingUI")
		if crafting_ui == null:
			crafting_ui = current_stage.get_node_or_null("CraftingUI")
		crafting_controller = current_stage.get_node_or_null("CraftingController")
		# Restore inventory if present in save
		var data = Save.load_local()
		if data.has("inventory"):
			var player := current_stage.get_node_or_null("Player")
			if player == null:
				player = current_stage.get_node_or_null("PlayerSniper")
			if player and player.has_node("Inventory"):
				for it in data["inventory"]:
					player.get_node("Inventory").add_item(it)

		# Always use side-scrolling perspective for 2D gameplay
		_set_perspective_internal("Side", true)

		# Notify UI Integration Manager that game systems are ready
		if ui_integration_manager:
			ui_integration_manager.notify_game_ready()

		# Start auto-save when stage loads
		start_auto_save()

func set_perspective(mode: String) -> void:
	_set_perspective_internal(mode, false)

func _set_perspective_internal(mode: String, force_emit: bool) -> void:
	if not force_emit and current_perspective == mode:
		return
	current_perspective = mode
	emit_signal("perspective_changed", mode)

func _ensure_input_map() -> void:
	var actions := [
		"move_forward", "move_back", "move_left", "move_right",
		"fire", "aim", "interact", "reload", "inventory", "market", "crafting", "pause", "save_game",
		"acc_toggle_high_contrast", "acc_toggle_captions"
	]
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	# Default bindings (safe duplicates are ignored by Godot)
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_mouse_button("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse_button("aim", MOUSE_BUTTON_RIGHT)
	_bind_key("interact", KEY_E)
	_bind_key("reload", KEY_R)
	_bind_key("inventory", KEY_I)
	_bind_key("market", KEY_M)
	_bind_key("crafting", KEY_C)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("save_game", KEY_F5)
	_bind_key("acc_toggle_high_contrast", KEY_H)
	_bind_key("acc_toggle_captions", KEY_CTRL + KEY_C)

func _bind_key(action: StringName, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _bind_mouse_button(action: StringName, button: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func _input(event: InputEvent) -> void:
	# Handle save game input (always available)
	if event.is_action_pressed("save_game"):
		manual_save_game()
		return

	# Let UI Integration Manager handle UI toggles
	if ui_integration_manager and ui_integration_manager.ui_systems_connected:
		# UI Integration Manager handles inventory, market, and crafting inputs
		# Only handle accessibility inputs here
		if event.is_action_pressed("acc_toggle_high_contrast") and has_node("/root/Accessibility"):
			get_node("/root/Accessibility").toggle_high_contrast()
		elif event.is_action_pressed("acc_toggle_captions") and has_node("/root/Accessibility"):
			get_node("/root/Accessibility").toggle_captions()
	else:
		# Fallback to manual UI handling if integration manager not ready
		if event.is_action_pressed("inventory"):
			if inventory_ui == null:
				inventory_ui = _find_inventory_ui()
			if inventory_ui:
				if inventory_ui.visible:
					inventory_ui.call_deferred("_close_inventory")
				else:
					inventory_ui.call_deferred("_open_inventory")
		elif event.is_action_pressed("market"):
			if market_ui == null:
				market_ui = _find_market_ui()
			if market_ui:
				if market_ui.visible:
					market_ui.visible = false
				else:
					_close_all_uis_except("market")
					market_ui.visible = true
		elif event.is_action_pressed("crafting"):
			if crafting_ui == null:
				crafting_ui = _find_crafting_ui()
			if crafting_ui:
				if crafting_ui.is_ui_open():
					crafting_ui.hide_ui()
				else:
					_close_all_uis_except("crafting")
					crafting_ui.show_ui()
		elif event.is_action_pressed("acc_toggle_high_contrast") and has_node("/root/Accessibility"):
			get_node("/root/Accessibility").toggle_high_contrast()
		elif event.is_action_pressed("acc_toggle_captions") and has_node("/root/Accessibility"):
			get_node("/root/Accessibility").toggle_captions()

# Manual save game function
func manual_save_game() -> void:
	"""Save the game manually with user feedback"""
	var save_data = Save.snapshot()
	Save.save_local(save_data)

	# Show save confirmation message
	if hud and hud.has_method("show_event_notification"):
		hud.show_event_notification("Game Saved", "info")
	else:
		print("💾 Game saved successfully!")

	print("💾 [Game] Manual save completed - timestamp: %s" % save_data.get("timestamp", "unknown"))

# Auto-save system
func _setup_auto_save() -> void:
	"""Setup the auto-save timer"""
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_auto_save)
	auto_save_timer.autostart = false  # Start when gameplay begins
	add_child(auto_save_timer)
	print("⏰ Auto-save system initialized (interval: %.0f seconds)" % auto_save_interval)

func _auto_save() -> void:
	"""Perform automatic save"""
	if current_stage:  # Only auto-save during gameplay
		var save_data = Save.snapshot()
		Save.save_local(save_data)

		# Show subtle auto-save notification
		if hud and hud.has_method("show_event_notification"):
			hud.show_event_notification("Auto-saved", "info")

		print("⏰ [Game] Auto-save completed - timestamp: %s" % save_data.get("timestamp", "unknown"))

func start_auto_save() -> void:
	"""Start the auto-save timer when gameplay begins"""
	if auto_save_timer and not auto_save_timer.is_stopped():
		auto_save_timer.start()
		print("⏰ Auto-save started")

func stop_auto_save() -> void:
	"""Stop the auto-save timer"""
	if auto_save_timer:
		auto_save_timer.stop()
		print("⏰ Auto-save stopped")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.save_local(Save.snapshot())
		get_tree().quit()

func _find_inventory_ui():
	var stage_inventory = current_stage.get_node_or_null("UI/InventoryUI") if current_stage else null
	if stage_inventory:
		return stage_inventory
	var by_group = get_tree().get_first_node_in_group("inventory_ui")
	if by_group:
		return by_group
	return null

func _find_market_ui():
	var stage_market = current_stage.get_node_or_null("UI/MarketUI") if current_stage else null
	if stage_market:
		return stage_market
	var by_group = get_tree().get_first_node_in_group("market_ui")
	if by_group:
		return by_group
	return null

func _find_crafting_ui():
	var stage_crafting = current_stage.get_node_or_null("UI/CraftingUI") if current_stage else null
	if stage_crafting:
		return stage_crafting
	var by_group = get_tree().get_first_node_in_group("crafting_ui")
	if by_group:
		return by_group
	return null

func _close_all_uis_except(keep_open: String = "") -> void:
	"""Close all UIs except the one specified"""
	# Use UI Integration Manager if available
	if ui_integration_manager and ui_integration_manager.ui_systems_connected:
		if keep_open == "":
			ui_integration_manager.close_all_uis()
		else:
			# Close individual UIs except the one to keep open
			if keep_open != "inventory":
				ui_integration_manager.close_inventory()
			if keep_open != "market":
				ui_integration_manager.close_market()
			if keep_open != "crafting":
				ui_integration_manager.close_crafting()
	else:
		# Fallback to manual UI closing
		if keep_open != "inventory":
			if inventory_ui == null:
				inventory_ui = _find_inventory_ui()
			if inventory_ui and inventory_ui.visible:
				inventory_ui.call_deferred("_close_inventory")

		if keep_open != "market":
			if market_ui == null:
				market_ui = _find_market_ui()
			if market_ui and market_ui.visible:
				market_ui.visible = false

		if keep_open != "crafting":
			if crafting_ui == null:
				crafting_ui = _find_crafting_ui()
			if crafting_ui and crafting_ui.is_ui_open():
				crafting_ui.hide_ui()

func register_economy_controllers(market: MarketController, settlement: SettlementController) -> void:
	market_controller = market
	settlement_controller = settlement

func clear_economy_controllers() -> void:
	market_controller = null
	settlement_controller = null
func register_crafting_interface(controller: CraftingController, ui: CraftingUI) -> void:
	crafting_controller = controller
	crafting_ui = ui

# UI Integration Manager API

func get_ui_integration_manager() -> UIIntegrationManager:
	"""Get reference to the UI Integration Manager"""
	return ui_integration_manager

func is_any_ui_open() -> bool:
	"""Check if any UI is currently open"""
	if ui_integration_manager:
		return ui_integration_manager.is_ui_open()
	return false

func get_ui_integration_status() -> Dictionary:
	"""Get detailed status of UI integration for debugging"""
	if ui_integration_manager:
		return ui_integration_manager.get_integration_status()
	return {"error": "UI Integration Manager not available"}
