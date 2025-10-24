extends Node

## Comprehensive UI System Diagnostic
## Add this script to a scene to diagnose UI system connection issues

func _ready():
	print("🔧 UI SYSTEM COMPREHENSIVE DIAGNOSTIC")
	print("=" * 60)

	# Wait for systems to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	test_input_actions()
	test_game_singleton()
	test_ui_integration_manager()
	test_scene_ui_components()
	test_ui_groups()

	print("\n🎯 DIAGNOSTIC COMPLETE")
	print("=" * 60)

func test_input_actions():
	print("\n📝 INPUT ACTION STATUS:")
	var actions = ["inventory", "crafting", "market", "save_game"]
	for action in actions:
		var exists = InputMap.has_action(action)
		var icon = "✅" if exists else "❌"
		print("  %s %s: %s" % [icon, action, "defined" if exists else "MISSING"])

		if exists:
			var events = InputMap.action_get_events(action)
			if events.size() > 0:
				var event = events[0] as InputEventKey
				if event:
					print("    🔧 Bound to keycode: %d" % event.physical_keycode)
			else:
				print("    ❌ No key bindings")

func test_game_singleton():
	print("\n🎮 GAME SINGLETON STATUS:")
	var game = get_node_or_null("/root/Game")
	if not game:
		print("  ❌ Game singleton NOT FOUND")
		return

	print("  ✅ Game singleton found")

	# Check UI Integration Manager reference
	if game.has_method("get_ui_integration_manager"):
		var ui_manager = game.get_ui_integration_manager()
		if ui_manager:
			print("  ✅ UIIntegrationManager reference: VALID")
			print("  🔧 Systems connected: %s" % ui_manager.ui_systems_connected)
		else:
			print("  ❌ UIIntegrationManager reference: NULL")
	else:
		print("  ❌ get_ui_integration_manager method: MISSING")

func test_ui_integration_manager():
	print("\n🔗 UI INTEGRATION MANAGER STATUS:")
	var ui_manager = get_tree().get_first_node_in_group("ui_integration_manager")
	if not ui_manager:
		print("  ❌ UIIntegrationManager NOT FOUND in scene tree")
		return

	print("  ✅ UIIntegrationManager found in scene tree")

	if ui_manager.has_method("get_integration_status"):
		var status = ui_manager.get_integration_status()
		print("  🔧 Integration Status: %s" % status)

		# Check individual components
		var components = status.get("components", {})
		print("  📋 Component Availability:")
		for component in components:
			var available = components[component]
			var icon = "✅" if available else "❌"
			print("    %s %s" % [icon, component])

	# Check current UI state
	if ui_manager.has_method("get_current_ui"):
		print("  🔧 Current open UI: '%s'" % ui_manager.get_current_ui())

func test_scene_ui_components():
	print("\n🖼️ SCENE UI COMPONENT STATUS:")
	var scene = get_tree().current_scene
	if not scene:
		print("  ❌ No current scene")
		return

	print("  ✅ Current scene: %s" % scene.name)

	# Test common UI paths
	var ui_paths = [
		"UI/InventoryUI",
		"UI/CraftingUI",
		"UI/MarketUI",
		"UI/HUD",
		"InventoryUI",
		"CraftingUI",
		"MarketUI"
	]

	print("  📂 UI Component Paths:")
	for path in ui_paths:
		var component = scene.get_node_or_null(path)
		var icon = "✅" if component else "❌"
		print("    %s %s" % [icon, path])

		if component:
			# Check important methods
			var methods = ["_open_inventory", "_close_inventory", "show_ui", "hide_ui", "toggle", "is_ui_open"]
			for method in methods:
				if component.has_method(method):
					print("      ✅ Method: %s" % method)

func test_ui_groups():
	print("\n👥 UI GROUP STATUS:")
	var groups = ["inventory_ui", "crafting_ui", "market_ui", "hud", "ui_integration_manager"]
	for group in groups:
		var nodes = get_tree().get_nodes_in_group(group)
		var icon = "✅" if nodes.size() > 0 else "❌"
		print("  %s Group '%s': %d nodes" % [icon, group, nodes.size()])

		if nodes.size() > 0:
			for i in range(min(3, nodes.size())):  # Show first 3 nodes
				print("    🔧 Node %d: %s" % [i+1, nodes[i].name])

func _input(event: InputEvent):
	# Real-time input monitoring
	if event.is_action_pressed("inventory"):
		print("🎯 REAL-TIME: Inventory key detected in diagnostic script!")
	elif event.is_action_pressed("crafting"):
		print("🎯 REAL-TIME: Crafting key detected in diagnostic script!")
	elif event.is_action_pressed("market"):
		print("🎯 REAL-TIME: Market key detected in diagnostic script!")