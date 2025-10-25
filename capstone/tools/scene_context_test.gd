extends Node

## Scene Context Test - Add this to ANY scene to check UI component availability

func _ready():
	print("🔍 SCENE CONTEXT TEST")
	print("=" * 50)
	print("📍 Current Scene: %s" % get_tree().current_scene.name)
	print("📁 Scene File: %s" % get_tree().current_scene.scene_file_path)
	print("-" * 50)

	check_ui_components()
	check_input_actions()

	print("\n🎯 CONCLUSION:")
	var has_inventory = get_tree().get_first_node_in_group("inventory_ui") != null
	if has_inventory:
		print("✅ This scene HAS InventoryUI - 'I' key SHOULD work")
	else:
		print("❌ This scene has NO InventoryUI - 'I' key will NOT work")
		print("   → You need to load a gameplay stage scene!")

func check_ui_components():
	print("\n🎨 UI COMPONENTS IN THIS SCENE:")

	var ui_groups = ["inventory_ui", "crafting_ui", "market_ui", "hud"]
	for group in ui_groups:
		var nodes = get_tree().get_nodes_in_group(group)
		if nodes.size() > 0:
			for node in nodes:
				print("  ✅ %s: %s (path: %s)" % [group, node.name, node.get_path()])
		else:
			print("  ❌ %s: Not found" % group)

func check_input_actions():
	print("\n⌨️ INPUT ACTION STATUS:")
	var actions = ["inventory", "crafting", "market"]
	for action in actions:
		var exists = InputMap.has_action(action)
		print("  %s %s: %s" % ["✅" if exists else "❌", action, "Defined" if exists else "Missing"])

func _input(event: InputEvent):
	if event.is_action_just_pressed("inventory"):
		print("\n🎯 'I' KEY DETECTED!")
		var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
		if inventory_ui:
			print("  ✅ InventoryUI found - attempting toggle...")
			if inventory_ui.has_method("_toggle_inventory"):
				inventory_ui._toggle_inventory()
				print("  🎮 Toggle called successfully!")
			else:
				print("  ❌ No _toggle_inventory method")
		else:
			print("  ❌ NO InventoryUI in this scene - that's why it doesn't work!")