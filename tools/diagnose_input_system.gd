extends Node

## Runtime diagnostic for input system issues
## This script will check the actual state of all input handling components

func _ready():
	print("🔧 DIAGNOSING INPUT SYSTEM RUNTIME STATE")
	print("=" * 60)

	# Wait for all systems to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	test_game_singleton_state()
	test_ui_integration_manager_state()
	test_input_action_availability()
	test_scene_ui_components()

	print("\n🎯 DIAGNOSIS COMPLETE")
	print("=" * 60)

func test_game_singleton_state():
	print("\n🔍 TESTING: Game Singleton State")

	var game = get_node_or_null("/root/Game")
	if not game:
		print("❌ Game singleton not found")
		return

	print("✅ Game singleton found")

	# Check UIIntegrationManager reference
	if game.has_method("get_ui_integration_manager"):
		var ui_manager = game.get_ui_integration_manager()
		if ui_manager:
			print("✅ Game has UIIntegrationManager reference")
			print("🔧 UIIntegrationManager systems_connected: %s" % ui_manager.ui_systems_connected)
		else:
			print("❌ Game UIIntegrationManager is null")
	else:
		print("❌ Game missing get_ui_integration_manager method")

	# Check direct UI references in Game
	print("🔧 Game direct UI references:")
	print("  - inventory_ui: %s" % (game.inventory_ui != null))
	print("  - crafting_ui: %s" % (game.crafting_ui != null))
	print("  - market_ui: %s" % (game.market_ui != null))
	print("  - current_stage: %s" % (game.current_stage != null))

func test_ui_integration_manager_state():
	print("\n🔍 TESTING: UIIntegrationManager State")

	var ui_manager = get_tree().get_first_node_in_group("ui_integration_manager")
	if not ui_manager:
		print("❌ UIIntegrationManager not found in scene tree")
		return

	print("✅ UIIntegrationManager found in scene tree")

	if ui_manager.has_method("get_integration_status"):
		var status = ui_manager.get_integration_status()
		print("🔧 Integration Status: %s" % status)

		# Break down what's missing
		var components = status.get("components", {})
		print("🔧 Component Status:")
		for component in components:
			var available = components[component]
			var icon = "✅" if available else "❌"
			print("  %s %s: %s" % [icon, component, available])

	# Test input handling capability
	if ui_manager.has_method("is_ui_open"):
		print("🔧 Any UI currently open: %s" % ui_manager.is_ui_open())

func test_input_action_availability():
	print("\n🔍 TESTING: Input Action Availability")

	var actions = ["inventory", "crafting", "market", "save_game"]
	for action in actions:
		if InputMap.has_action(action):
			print("✅ Action '%s' exists" % action)
			var events = InputMap.action_get_events(action)
			if events.size() > 0:
				print("  🔧 Has %d key binding(s)" % events.size())
			else:
				print("  ❌ No key bindings")
		else:
			print("❌ Action '%s' missing" % action)

func test_scene_ui_components():
	print("\n🔍 TESTING: Scene UI Components")

	var current_scene = get_tree().current_scene
	if not current_scene:
		print("❌ No current scene")
		return

	print("✅ Current scene: %s" % current_scene.name)

	# Test UI component paths
	var ui_paths = [
		"UI/InventoryUI",
		"UI/CraftingUI",
		"UI/MarketUI",
		"UI/HUD",
		"InventoryUI",
		"CraftingUI",
		"MarketUI",
		"HUD"
	]

	print("🔧 UI Component Detection:")
	for path in ui_paths:
		var component = current_scene.get_node_or_null(path)
		var icon = "✅" if component else "❌"
		print("  %s %s: %s" % [icon, path, component != null])

		if component and component.has_method("has_method"):
			# Check for key methods
			var methods = ["_open_inventory", "_close_inventory", "show_ui", "hide_ui", "toggle"]
			for method in methods:
				if component.has_method(method):
					print("    ✅ Has method: %s" % method)

	# Test groups
	print("🔧 UI Groups:")
	var groups = ["inventory_ui", "crafting_ui", "market_ui", "hud"]
	for group in groups:
		var nodes = get_tree().get_nodes_in_group(group)
		print("  %s Group '%s': %d nodes" % ["✅" if nodes.size() > 0 else "❌", group, nodes.size()])

func _input(event: InputEvent):
	# Test direct input detection
	if event.is_action_pressed("inventory"):
		print("🎯 DETECTED: 'inventory' action pressed!")
	elif event.is_action_pressed("crafting"):
		print("🎯 DETECTED: 'crafting' action pressed!")
	elif event.is_action_pressed("market"):
		print("🎯 DETECTED: 'market' action pressed!")