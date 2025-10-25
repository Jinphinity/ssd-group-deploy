extends Node

## Test script to verify restored input handlers
## Add this to a scene with InventoryUI, CraftingUI, and MarketUI

func _ready():
	print("🧪 TESTING RESTORED INPUT SYSTEM")
	print("=" * 50)
	print("🔧 Re-enabled direct input handlers in UI components")
	print("📋 Test Instructions:")
	print("  • Press 'I' → Should toggle Inventory")
	print("  • Press 'C' → Should toggle Crafting")
	print("  • Press 'M' → Should toggle Market")
	print("  • Press ESC → Should close any open UI")
	print("=" * 50)

	# Wait for UI components to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	test_ui_component_presence()

func test_ui_component_presence():
	print("\n🔍 CHECKING UI COMPONENT PRESENCE:")

	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	var crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
	var market_ui = get_tree().get_first_node_in_group("market_ui")

	print("  %s InventoryUI: %s" % ["✅" if inventory_ui else "❌", "Found" if inventory_ui else "Missing"])
	print("  %s CraftingUI: %s" % ["✅" if crafting_ui else "❌", "Found" if crafting_ui else "Missing"])
	print("  %s MarketUI: %s" % ["✅" if market_ui else "❌", "Found" if market_ui else "Missing"])

	if inventory_ui:
		print("    🔧 InventoryUI has _unhandled_input: %s" % inventory_ui.has_method("_unhandled_input"))
		print("    🔧 InventoryUI has _toggle_inventory: %s" % inventory_ui.has_method("_toggle_inventory"))

	if crafting_ui:
		print("    🔧 CraftingUI has _unhandled_input: %s" % crafting_ui.has_method("_unhandled_input"))
		print("    🔧 CraftingUI has toggle: %s" % crafting_ui.has_method("toggle"))

	if market_ui:
		print("    🔧 MarketUI has _unhandled_input: %s" % market_ui.has_method("_unhandled_input"))

func _input(event: InputEvent):
	# Monitor input detection
	if event.is_action_just_pressed("inventory"):
		print("🎯 INPUT DETECTED: Inventory key (I) pressed - should trigger InventoryUI")
	elif event.is_action_just_pressed("crafting"):
		print("🎯 INPUT DETECTED: Crafting key (C) pressed - should trigger CraftingUI")
	elif event.is_action_just_pressed("market"):
		print("🎯 INPUT DETECTED: Market key (M) pressed - should trigger MarketUI")
	elif event.is_action_just_pressed("ui_cancel"):
		print("🎯 INPUT DETECTED: Cancel key (ESC) pressed - should close any open UI")