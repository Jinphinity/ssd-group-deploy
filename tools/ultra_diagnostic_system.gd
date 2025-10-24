extends Node

## Ultra-Comprehensive Input System Diagnostic
## This will trace EVERY step of input handling to find the exact failure point

var diagnostic_data := {}
var input_trace := []
var frame_count := 0

signal diagnostic_complete(results: Dictionary)

func _ready():
	print("🔬 ULTRA-COMPREHENSIVE INPUT SYSTEM DIAGNOSTIC")
	print("=" * 80)
	print("🎯 This will trace EVERY step from key press to UI response")
	print("⚠️ Press 'I' key after initialization completes to begin trace")
	print("=" * 80)

	# Set high priority input processing
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Wait for all systems to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	perform_comprehensive_system_analysis()

func perform_comprehensive_system_analysis():
	print("\n🔍 PHASE 1: SYSTEM STATE ANALYSIS")
	print("-" * 50)

	diagnostic_data["phase1"] = {}

	# 1. Engine and Project Analysis
	await analyze_engine_state()

	# 2. Input Action System Analysis
	await analyze_input_actions()

	# 3. Scene Hierarchy Analysis
	await analyze_scene_structure()

	# 4. UI Component Analysis
	await analyze_ui_components()

	# 5. Game Singleton Analysis
	await analyze_game_singleton()

	# 6. Potential Conflicts Analysis
	await analyze_potential_conflicts()

	print("\n✅ SYSTEM ANALYSIS COMPLETE")
	print("🎯 Now press 'I' key to trace input handling...")

func analyze_engine_state():
	print("\n🔧 ENGINE STATE:")
	diagnostic_data["phase1"]["engine"] = {}

	var engine_info = {
		"godot_version": Engine.get_version_info(),
		"current_scene": get_tree().current_scene.name if get_tree().current_scene else "NONE",
		"scene_tree_paused": get_tree().paused,
		"total_nodes": get_tree().get_node_count_in_group(""),
		"physics_fps": Engine.physics_ticks_per_second,
		"time_scale": Engine.time_scale
	}

	for key in engine_info:
		print("  🔧 %s: %s" % [key, engine_info[key]])
		diagnostic_data["phase1"]["engine"][key] = engine_info[key]

func analyze_input_actions():
	print("\n📋 INPUT ACTION ANALYSIS:")
	diagnostic_data["phase1"]["input_actions"] = {}

	var critical_actions = ["inventory", "crafting", "market", "save_game", "ui_cancel"]

	for action in critical_actions:
		var action_data = {}

		if InputMap.has_action(action):
			action_data["exists"] = true
			var events = InputMap.action_get_events(action)
			action_data["event_count"] = events.size()
			action_data["events"] = []

			for event in events:
				if event is InputEventKey:
					var event_info = {
						"type": "Key",
						"keycode": event.keycode,
						"physical_keycode": event.physical_keycode,
						"unicode": event.unicode,
						"ctrl": event.ctrl_pressed,
						"shift": event.shift_pressed,
						"alt": event.alt_pressed
					}
					action_data["events"].append(event_info)
					print("    ✅ %s → Key %d (physical: %d)" % [action, event.keycode, event.physical_keycode])
				else:
					action_data["events"].append({"type": str(event.get_class())})
					print("    ✅ %s → %s" % [action, event.get_class()])
		else:
			action_data["exists"] = false
			print("    ❌ %s: NOT FOUND" % action)

		diagnostic_data["phase1"]["input_actions"][action] = action_data

func analyze_scene_structure():
	print("\n🏗️ SCENE STRUCTURE ANALYSIS:")
	diagnostic_data["phase1"]["scene_structure"] = {}

	var current_scene = get_tree().current_scene
	if not current_scene:
		print("  ❌ NO CURRENT SCENE")
		diagnostic_data["phase1"]["scene_structure"]["current_scene"] = null
		return

	print("  ✅ Current Scene: %s (%s)" % [current_scene.name, current_scene.get_class()])
	diagnostic_data["phase1"]["scene_structure"]["current_scene"] = current_scene.name

	# Map the scene hierarchy
	var hierarchy = map_scene_hierarchy(current_scene, 0, 3)  # Max depth 3
	diagnostic_data["phase1"]["scene_structure"]["hierarchy"] = hierarchy

	# Check for UI paths
	var ui_paths = [
		"UI", "UI/InventoryUI", "UI/CraftingUI", "UI/MarketUI", "UI/HUD",
		"InventoryUI", "CraftingUI", "MarketUI", "HUD",
		"Canvas", "Canvas/UI", "UserInterface"
	]

	diagnostic_data["phase1"]["scene_structure"]["ui_paths"] = {}
	print("  🔍 UI PATH SEARCH:")
	for path in ui_paths:
		var node = current_scene.get_node_or_null(path)
		var exists = node != null
		diagnostic_data["phase1"]["scene_structure"]["ui_paths"][path] = exists
		print("    %s %s: %s" % ["✅" if exists else "❌", path, "Found" if exists else "Missing"])
		if exists:
			print("      🔧 Type: %s, Children: %d" % [node.get_class(), node.get_child_count()])

func map_scene_hierarchy(node: Node, depth: int, max_depth: int) -> Dictionary:
	var node_info = {
		"name": node.name,
		"class": node.get_class(),
		"visible": node.get("visible") if node.has_method("get") else "N/A",
		"children": []
	}

	print("  %s%s (%s)" % ["  ".repeat(depth), node.name, node.get_class()])

	if depth < max_depth:
		for child in node.get_children():
			node_info["children"].append(map_scene_hierarchy(child, depth + 1, max_depth))

	return node_info

func analyze_ui_components():
	print("\n🎨 UI COMPONENT ANALYSIS:")
	diagnostic_data["phase1"]["ui_components"] = {}

	var ui_groups = ["inventory_ui", "crafting_ui", "market_ui", "hud", "ui_integration_manager"]

	for group in ui_groups:
		var nodes = get_tree().get_nodes_in_group(group)
		var group_data = {
			"count": nodes.size(),
			"nodes": []
		}

		print("  📂 Group '%s': %d nodes" % [group, nodes.size()])

		for i in range(nodes.size()):
			var node = nodes[i]
			var node_data = {
				"name": node.name,
				"class": node.get_class(),
				"path": node.get_path(),
				"visible": node.get("visible") if node.has_method("get") else "N/A",
				"methods": {}
			}

			# Check critical methods
			var critical_methods = [
				"_unhandled_input", "_input", "_toggle_inventory", "_open_inventory",
				"_close_inventory", "toggle", "show_ui", "hide_ui", "is_ui_open"
			]

			for method in critical_methods:
				node_data["methods"][method] = node.has_method(method)

			group_data["nodes"].append(node_data)
			print("    🔧 Node %d: %s (%s) - Path: %s" % [i+1, node.name, node.get_class(), node.get_path()])

			# Show method availability
			var available_methods = []
			for method in critical_methods:
				if node.has_method(method):
					available_methods.append(method)
			if available_methods.size() > 0:
				print("      ✅ Methods: %s" % ", ".join(available_methods))

		diagnostic_data["phase1"]["ui_components"][group] = group_data

func analyze_game_singleton():
	print("\n🎮 GAME SINGLETON ANALYSIS:")
	diagnostic_data["phase1"]["game_singleton"] = {}

	var game = get_node_or_null("/root/Game")
	if not game:
		print("  ❌ Game singleton NOT FOUND")
		diagnostic_data["phase1"]["game_singleton"]["exists"] = false
		return

	print("  ✅ Game singleton found")
	diagnostic_data["phase1"]["game_singleton"]["exists"] = true

	# Check Game singleton state
	var game_data = {
		"current_stage": game.current_stage != null,
		"ui_integration_manager": game.ui_integration_manager != null,
		"inventory_ui": game.inventory_ui != null,
		"crafting_ui": game.crafting_ui != null,
		"market_ui": game.market_ui != null
	}

	for key in game_data:
		print("  🔧 %s: %s" % [key, game_data[key]])
		diagnostic_data["phase1"]["game_singleton"][key] = game_data[key]

	# Check UIIntegrationManager if it exists
	if game.ui_integration_manager:
		var ui_manager = game.ui_integration_manager
		var ui_status = ui_manager.get_integration_status() if ui_manager.has_method("get_integration_status") else {}
		diagnostic_data["phase1"]["game_singleton"]["ui_integration_status"] = ui_status
		print("  🔧 UI Integration Status: %s" % ui_status)

func analyze_potential_conflicts():
	print("\n⚠️ POTENTIAL CONFLICT ANALYSIS:")
	diagnostic_data["phase1"]["conflicts"] = {}

	# Check for multiple input handlers
	var all_nodes = []
	_collect_all_nodes(get_tree().root, all_nodes)

	var input_handlers = []
	for node in all_nodes:
		if node.has_method("_input") or node.has_method("_unhandled_input"):
			input_handlers.append({
				"node": node.name,
				"path": node.get_path(),
				"class": node.get_class(),
				"has_input": node.has_method("_input"),
				"has_unhandled_input": node.has_method("_unhandled_input")
			})

	diagnostic_data["phase1"]["conflicts"]["input_handlers"] = input_handlers
	print("  🔍 Found %d nodes with input handlers:" % input_handlers.size())
	for handler in input_handlers:
		print("    📍 %s (%s) - Input: %s, Unhandled: %s" % [
			handler["node"], handler["class"],
			handler["has_input"], handler["has_unhandled_input"]
		])

func _collect_all_nodes(node: Node, collection: Array):
	collection.append(node)
	for child in node.get_children():
		_collect_all_nodes(child, collection)

# PHASE 2: REAL-TIME INPUT TRACING
func _input(event: InputEvent):
	if event.is_action_just_pressed("inventory"):
		print("\n🎯 PHASE 2: REAL-TIME INPUT TRACE - INVENTORY KEY DETECTED")
		print("=" * 80)
		trace_inventory_input_flow(event)

func trace_inventory_input_flow(event: InputEvent):
	frame_count += 1
	var trace_entry = {
		"frame": frame_count,
		"timestamp": Time.get_unix_time_from_system(),
		"event_info": {
			"class": event.get_class(),
			"pressed": event.pressed if event.has_method("is_pressed") else "N/A",
			"action_pressed": event.is_action_pressed("inventory"),
			"action_just_pressed": event.is_action_just_pressed("inventory")
		},
		"steps": []
	}

	print("📥 INPUT EVENT RECEIVED:")
	print("  🔧 Event Class: %s" % event.get_class())
	print("  🔧 Is Action Pressed: %s" % event.is_action_pressed("inventory"))
	print("  🔧 Is Action Just Pressed: %s" % event.is_action_just_pressed("inventory"))

	# Step 1: Check if Game singleton will handle this
	await _trace_game_singleton_handling(trace_entry)

	# Step 2: Check UI component responses
	await _trace_ui_component_responses(trace_entry)

	# Step 3: Check what actually happened
	await _trace_actual_results(trace_entry)

	input_trace.append(trace_entry)

	print("\n📊 TRACE COMPLETE - Frame %d" % frame_count)
	_print_trace_summary(trace_entry)

func _trace_game_singleton_handling(trace_entry: Dictionary):
	trace_entry["steps"].append("Checking Game singleton handling...")

	var game = get_node_or_null("/root/Game")
	if not game:
		print("  ❌ Game singleton not available for handling")
		return

	print("  🎮 Game singleton available - checking handling logic...")

	# Check if UIIntegrationManager will handle it
	if game.ui_integration_manager and game.ui_integration_manager.ui_systems_connected:
		print("    🔗 UIIntegrationManager connected - Game will delegate to it")
		trace_entry["steps"].append("Game delegating to UIIntegrationManager")
	else:
		print("    🔄 UIIntegrationManager not connected - Game will handle manually")
		trace_entry["steps"].append("Game handling manually")

		# Check if Game has UI references for manual handling
		if game.inventory_ui:
			print("      ✅ Game has inventory_ui reference")
		else:
			print("      ❌ Game missing inventory_ui reference - will try to find it")

func _trace_ui_component_responses(trace_entry: Dictionary):
	trace_entry["steps"].append("Checking UI component responses...")

	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if not inventory_ui:
		print("  ❌ No InventoryUI found in scene")
		return

	print("  ✅ InventoryUI found: %s" % inventory_ui.name)

	# Check if it has input handler
	if inventory_ui.has_method("_unhandled_input"):
		print("    ✅ InventoryUI has _unhandled_input method")
		trace_entry["steps"].append("InventoryUI has input handler")

		# Check if the method will be called (this is indirect detection)
		print("    🔍 InventoryUI should receive _unhandled_input call...")
	else:
		print("    ❌ InventoryUI missing _unhandled_input method")
		trace_entry["steps"].append("InventoryUI missing input handler")

func _trace_actual_results(trace_entry: Dictionary):
	trace_entry["steps"].append("Checking actual results...")

	# Wait a frame for processing to complete
	await get_tree().process_frame

	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		var is_visible = inventory_ui.visible
		print("  📊 InventoryUI visibility after input: %s" % is_visible)
		trace_entry["inventory_visible_after"] = is_visible

		if is_visible:
			print("    ✅ SUCCESS: Inventory is now visible!")
		else:
			print("    ❌ FAILURE: Inventory is still not visible")
	else:
		print("  ❌ Cannot check result - InventoryUI not found")

func _print_trace_summary(trace_entry: Dictionary):
	print("\n📋 TRACE SUMMARY:")
	for i in range(trace_entry["steps"].size()):
		print("  %d. %s" % [i+1, trace_entry["steps"][i]])

	if trace_entry.has("inventory_visible_after"):
		var success = trace_entry["inventory_visible_after"]
		print("\n🎯 FINAL RESULT: %s" % ["SUCCESS" if success else "FAILURE"])
		if not success:
			print("🚨 INVENTORY DID NOT RESPOND TO INPUT - ISSUE CONFIRMED")

# Unhandled input to catch what other handlers miss
func _unhandled_input(event: InputEvent):
	if event.is_action_just_pressed("inventory"):
		print("\n🔄 UNHANDLED INPUT: Inventory key reached diagnostic script")
		print("     ⚠️ This means NO other handler consumed the input!")

func get_diagnostic_results() -> Dictionary:
	return {
		"system_analysis": diagnostic_data,
		"input_traces": input_trace,
		"summary": _generate_diagnostic_summary()
	}

func _generate_diagnostic_summary() -> Dictionary:
	return {
		"total_traces": input_trace.size(),
		"system_health": "Analysis complete",
		"critical_issues": _identify_critical_issues()
	}

func _identify_critical_issues() -> Array:
	var issues = []

	# Check common failure points
	if not diagnostic_data.get("phase1", {}).get("input_actions", {}).get("inventory", {}).get("exists", false):
		issues.append("Inventory input action not defined")

	if diagnostic_data.get("phase1", {}).get("ui_components", {}).get("inventory_ui", {}).get("count", 0) == 0:
		issues.append("No InventoryUI component found in scene")

	if not diagnostic_data.get("phase1", {}).get("game_singleton", {}).get("exists", false):
		issues.append("Game singleton not found")

	return issues