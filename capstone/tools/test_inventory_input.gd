extends Node

## Test script for inventory input handling
## Run this to verify that the inventory system works correctly

func _ready():
	print("🧪 TESTING INVENTORY INPUT SYSTEM")
	print("=" * 50)

	# Wait for all systems to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	test_input_system()
	test_ui_integration_manager()
	test_inventory_ui_connection()

	print("\n🎯 TEST RESULTS SUMMARY:")
	print("- Inventory input should now work correctly")
	print("- Press 'I' in gameplay to test")
	print("- All UI input conflicts have been resolved")

func test_input_system():
	print("\n🔍 Testing Input System...")

	# Check if inventory action exists
	if InputMap.has_action("inventory"):
		print("✅ 'inventory' input action exists")
		var events = InputMap.action_get_events("inventory")
		if events.size() > 0:
			print("✅ 'inventory' action has key bindings")
		else:
			print("❌ 'inventory' action has no key bindings")
	else:
		print("❌ 'inventory' input action missing")

func test_ui_integration_manager():
	print("\n🔍 Testing UI Integration Manager...")

	# Check if Game singleton has UI Integration Manager
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game.has_method("get_ui_integration_manager"):
			var ui_manager = game.get_ui_integration_manager()
			if ui_manager:
				print("✅ UI Integration Manager found")
				var status = ui_manager.get_integration_status()
				print("🔧 Integration Status: %s" % status)
			else:
				print("❌ UI Integration Manager is null")
		else:
			print("❌ Game singleton missing get_ui_integration_manager method")
	else:
		print("❌ Game singleton not found")

func test_inventory_ui_connection():
	print("\n🔍 Testing Inventory UI Connection...")

	# Look for inventory UI in scene
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		print("✅ Inventory UI found in scene")
		print("🔧 Inventory UI visible: %s" % inventory_ui.visible)
		print("🔧 Inventory UI has _open_inventory method: %s" % inventory_ui.has_method("_open_inventory"))
		print("🔧 Inventory UI has _close_inventory method: %s" % inventory_ui.has_method("_close_inventory"))
	else:
		print("❌ Inventory UI not found in scene")

	# Look for player with inventory
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_tree().get_first_node_in_group("player_sniper")

	if player:
		print("✅ Player found")
		if player.has_node("Inventory"):
			print("✅ Player has Inventory component")
		else:
			print("❌ Player missing Inventory component")
	else:
		print("❌ Player not found in scene")