extends Control

## Minimal Input Test - Add this as a scene to test input detection in isolation
## This will help identify if the issue is with input actions or UI components

var test_results := {}

func _ready():
	print("🧪 MINIMAL INPUT TEST - ISOLATED ENVIRONMENT")
	print("=" * 60)

	# Create a simple UI for visual feedback
	_setup_test_ui()

	print("📋 TEST INSTRUCTIONS:")
	print("  1. This scene tests ONLY input detection")
	print("  2. Press I, C, M, F5 keys")
	print("  3. Working keys will show messages and update the UI")
	print("  4. Silent keys indicate input action problems")
	print("=" * 60)

	# Test input actions immediately
	await get_tree().process_frame
	_test_input_action_definitions()

func _setup_test_ui():
	# Set up as fullscreen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Create title label
	var title = Label.new()
	title.text = "MINIMAL INPUT TEST - Press I, C, M, F5"
	title.position = Vector2(50, 50)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	# Create result display
	for i in range(4):
		var result_label = Label.new()
		result_label.name = "Result%d" % i
		result_label.text = "Waiting for input..."
		result_label.position = Vector2(50, 100 + i * 30)
		result_label.add_theme_font_size_override("font_size", 16)
		add_child(result_label)

func _test_input_action_definitions():
	print("\n🔍 TESTING INPUT ACTION DEFINITIONS:")

	var actions = [
		{"name": "inventory", "expected_key": "I"},
		{"name": "crafting", "expected_key": "C"},
		{"name": "market", "expected_key": "M"},
		{"name": "save_game", "expected_key": "F5"}
	]

	for i in range(actions.size()):
		var action = actions[i]
		var action_name = action["name"]
		var expected_key = action["expected_key"]

		var result_text = ""

		if InputMap.has_action(action_name):
			var events = InputMap.action_get_events(action_name)
			if events.size() > 0:
				var event = events[0] as InputEventKey
				if event:
					result_text = "✅ %s → Key %d (%s)" % [action_name, event.physical_keycode, expected_key]
					test_results[action_name] = {"status": "ok", "keycode": event.physical_keycode}
				else:
					result_text = "❌ %s → Non-key event" % action_name
					test_results[action_name] = {"status": "wrong_type"}
			else:
				result_text = "❌ %s → No events" % action_name
				test_results[action_name] = {"status": "no_events"}
		else:
			result_text = "❌ %s → Action missing" % action_name
			test_results[action_name] = {"status": "missing"}

		print("  %s" % result_text)

		# Update UI
		var result_label = get_node("Result%d" % i)
		result_label.text = result_text

		if "✅" in result_text:
			result_label.modulate = Color.GREEN
		else:
			result_label.modulate = Color.RED

# Test both _input and _unhandled_input to see which gets called
func _input(event: InputEvent):
	_handle_input_event(event, "_input")

func _unhandled_input(event: InputEvent):
	_handle_input_event(event, "_unhandled_input")

func _handle_input_event(event: InputEvent, handler_type: String):
	var actions_to_test = ["inventory", "crafting", "market", "save_game"]

	for action in actions_to_test:
		if event.is_action_just_pressed(action):
			var message = "🎯 %s DETECTED: '%s' action in %s handler!" % [Time.get_datetime_string_from_system(), action, handler_type]
			print(message)

			# Update test results
			if not test_results.has(action):
				test_results[action] = {}
			test_results[action]["detected"] = true
			test_results[action]["handler"] = handler_type

			# Visual feedback
			_show_input_feedback(action, handler_type)

			# Test specific functionality
			_test_action_functionality(action)

func _show_input_feedback(action: String, handler_type: String):
	# Create a temporary feedback label
	var feedback = Label.new()
	feedback.text = "DETECTED: %s (%s)" % [action, handler_type]
	feedback.position = Vector2(50, 300)
	feedback.modulate = Color.YELLOW
	feedback.add_theme_font_size_override("font_size", 20)
	add_child(feedback)

	# Animate and remove
	var tween = create_tween()
	tween.tween_property(feedback, "modulate", Color.TRANSPARENT, 2.0)
	tween.tween_callback(feedback.queue_free)

func _test_action_functionality(action: String):
	print("  🔧 Testing %s functionality..." % action)

	match action:
		"inventory":
			_test_inventory_functionality()
		"crafting":
			_test_crafting_functionality()
		"market":
			_test_market_functionality()
		"save_game":
			_test_save_functionality()

func _test_inventory_functionality():
	# Try to find InventoryUI component
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")

	if inventory_ui:
		print("    ✅ InventoryUI component found: %s" % inventory_ui.name)
		print("    🔧 Path: %s" % inventory_ui.get_path())
		print("    🔧 Visible: %s" % inventory_ui.visible)
		print("    🔧 Has toggle method: %s" % inventory_ui.has_method("_toggle_inventory"))

		# Try to call the toggle method
		if inventory_ui.has_method("_toggle_inventory"):
			print("    🎯 Attempting to call _toggle_inventory()...")
			inventory_ui._toggle_inventory()

			# Check if it worked
			await get_tree().process_frame
			print("    📊 Inventory visible after toggle: %s" % inventory_ui.visible)
		else:
			print("    ❌ _toggle_inventory method not available")
	else:
		print("    ❌ InventoryUI component NOT FOUND")

		# Check scene structure
		print("    🔍 Searching current scene for UI components...")
		_search_scene_for_ui_components()

func _search_scene_for_ui_components():
	var current_scene = get_tree().current_scene
	if current_scene:
		print("      🏗️ Current scene: %s" % current_scene.name)
		_print_node_tree(current_scene, 0, 3)
	else:
		print("      ❌ No current scene")

func _print_node_tree(node: Node, depth: int, max_depth: int):
	var indent = "  ".repeat(depth + 2)
	print("%s- %s (%s)" % [indent, node.name, node.get_class()])

	# Check if this looks like a UI component
	if "UI" in node.name or "Inventory" in node.name or "Crafting" in node.name or "Market" in node.name:
		print("%s  🎯 POTENTIAL UI COMPONENT!" % indent)
		if node.is_in_group("inventory_ui"):
			print("%s  ✅ In inventory_ui group" % indent)
		else:
			print("%s  ❌ Not in inventory_ui group" % indent)

	if depth < max_depth:
		for child in node.get_children():
			_print_node_tree(child, depth + 1, max_depth)

func _test_crafting_functionality():
	var crafting_ui = get_tree().get_first_node_in_group("crafting_ui")
	print("    %s CraftingUI: %s" % ["✅" if crafting_ui else "❌", "Found" if crafting_ui else "Not found"])

func _test_market_functionality():
	var market_ui = get_tree().get_first_node_in_group("market_ui")
	print("    %s MarketUI: %s" % ["✅" if market_ui else "❌", "Found" if market_ui else "Not found"])

func _test_save_functionality():
	var game = get_node_or_null("/root/Game")
	if game and game.has_method("manual_save_game"):
		print("    ✅ Game.manual_save_game available")
		# Don't actually call it to avoid unwanted saves
	else:
		print("    ❌ Game.manual_save_game not available")

# Generate a summary after some testing
func _on_timer_timeout():
	print("\n📊 TEST SUMMARY:")
	print("=" * 40)

	var total_actions = test_results.size()
	var working_actions = 0

	for action in test_results:
		var data = test_results[action]
		var status = data.get("status", "unknown")
		var detected = data.get("detected", false)

		print("🔧 %s:" % action)
		print("  Definition: %s" % status)
		print("  Detection: %s" % ("✅" if detected else "❌"))

		if status == "ok" and detected:
			working_actions += 1

	print("\n🎯 WORKING ACTIONS: %d/%d" % [working_actions, total_actions])

	if working_actions == 0:
		print("🚨 CRITICAL: NO INPUT ACTIONS WORKING")
		print("   Possible causes:")
		print("   - Input actions not properly defined")
		print("   - Script compilation errors")
		print("   - Godot engine issues")
	elif working_actions < total_actions:
		print("⚠️ PARTIAL: Some input actions not working")
	else:
		print("✅ SUCCESS: All input actions working")
		print("   If inventory still doesn't open, the issue is in UI components")

# Set up a timer to generate summary
func _enter_tree():
	var timer = Timer.new()
	timer.wait_time = 10.0  # Generate summary after 10 seconds
	timer.timeout.connect(_on_timer_timeout)
	timer.autostart = true
	add_child(timer)