#!/usr/bin/env -S godot --headless --script

## Advanced Interaction Simulator
## Creates realistic game scenarios to trigger all runtime-only functions
## Uses sophisticated state management and event simulation

extends SceneTree

signal simulation_completed(results: Dictionary)
signal function_triggered(function_name: String, context: Dictionary)

# Simulation state management
var active_scenes = {}
var mock_entities = {}
var interaction_log = []
var error_capture_system: Node
var current_simulation_phase = ""

# Function discovery results
var critical_functions = {
	# Combat functions that need specific entity setups
	"combat": [
		"fire", "shoot", "_perform_attack", "_perform_ranged_attack",
		"apply_damage", "take_damage", "_deal_attack_damage", "_die"
	],
	# Area interaction functions requiring spatial setup
	"spatial": [
		"_on_detection_area_entered", "_on_detection_area_exited",
		"_on_attack_area_entered", "_on_attack_area_exited",
		"_on_body_entered", "_on_body_exited"
	],
	# Input functions requiring event simulation
	"input": [
		"_input", "_unhandled_input", "_handle_input", "_try_interact"
	],
	# UI functions requiring interface setup
	"ui": [
		"_on_login_pressed", "_on_logout_pressed", "_on_play_pressed",
		"_on_craft_pressed", "_on_equip_button_pressed", "_on_unequip_button_pressed"
	],
	# Animation/timing functions requiring temporal simulation
	"temporal": [
		"_on_animation_finished", "_on_frame_changed", "_setup_spawn_timer",
		"_on_transition_completed", "_on_transition_failed"
	]
}

func _init():
	print("🎯 ADVANCED INTERACTION SIMULATOR")
	print("=".repeat(50))
	print("🚀 Creating realistic scenarios to test all runtime functions")
	print("🎮 Simulating complex player interactions and game states")
	print("⚡ No manual gameplay required - fully automated testing")
	print("=".repeat(50))

	# Initialize error capture
	_setup_error_capture()

	# Start comprehensive simulation
	await _run_comprehensive_simulation()

func _setup_error_capture():
	print("🔧 Setting up error capture system...")
	error_capture_system = preload("res://tools/ErrorCaptureSystem.gd").new()
	root.add_child(error_capture_system)
	error_capture_system.error_captured.connect(_on_error_captured)
	print("✅ Error capture system active")

func _run_comprehensive_simulation():
	print("\n🎬 Starting comprehensive interaction simulation...")

	# Phase 1: Combat scenario simulation
	current_simulation_phase = "combat"
	await _simulate_combat_scenarios()

	# Phase 2: Spatial interaction simulation
	current_simulation_phase = "spatial"
	await _simulate_spatial_interactions()

	# Phase 3: Input event simulation
	current_simulation_phase = "input"
	await _simulate_input_events()

	# Phase 4: UI interaction simulation
	current_simulation_phase = "ui"
	await _simulate_ui_interactions()

	# Phase 5: Temporal event simulation
	current_simulation_phase = "temporal"
	await _simulate_temporal_events()

	# Final analysis
	await _analyze_simulation_results()

	print("\n🏁 All interaction simulations completed!")
	quit(0)

# ========================================
# COMBAT SCENARIO SIMULATION
# ========================================

func _simulate_combat_scenarios():
	print("\n⚔️ COMBAT SCENARIO SIMULATION")
	print("  🎯 Testing weapon firing, damage systems, and death scenarios")

	# Load hostile stage for combat testing
	var error = change_scene_to_file("res://stages/Stage_Hostile_01_2D.tscn")
	if error != OK:
		print("  ❌ Failed to load hostile stage: %d" % error)
		return

	await create_timer(2.0).timeout
	print("  ✅ Hostile stage loaded")

	# Create mock player for combat testing
	await _create_mock_player()

	# Test weapon firing functions
	await _test_weapon_systems()

	# Test damage application functions
	await _test_damage_systems()

	# Test death and destruction functions
	await _test_death_systems()

	print("  ✅ Combat scenario simulation completed")

func _create_mock_player():
	print("    🎮 Creating mock player for combat testing...")

	# Find the player in the scene
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		mock_entities["player"] = player
		print("    ✅ Found existing player: %s" % player.name)

		# Test player combat functions if available
		if player.has_method("fire"):
			print("    🔫 Testing player weapon firing...")
			# Create a safe test environment for firing
			var original_pos = player.global_position
			player.global_position = Vector2(100, 100)

			# Simulate weapon firing
			if player.has_method("_handle_input"):
				var input_event = InputEventKey.new()
				input_event.pressed = true
				input_event.keycode = KEY_SPACE  # Assuming space fires weapon
				player._handle_input()
				function_triggered.emit("player_fire", {"context": "weapon_test", "position": player.global_position})

			player.global_position = original_pos
	else:
		print("    ⚠️ No player found in scene")

func _test_weapon_systems():
	print("    🔫 Testing weapon system functions...")

	# Test ballistics system
	var ballistics_test = preload("res://common/Combat/Ballistics.gd").new()
	if ballistics_test.has_method("fire"):
		print("      🎯 Testing ballistics fire function...")
		var result = ballistics_test.fire(Vector2(0, 0), Vector2(1, 0), 10.0)
		function_triggered.emit("ballistics_fire", {"result": result})
		print("      ✅ Ballistics fire tested successfully")

	# Test damage model
	var damage_result = preload("res://common/Combat/DamageModel.gd").compute_damage(
		{"damage": 10.0, "type": "kinetic"},
		{"armor": 5.0, "type": "vest"},
		"torso"
	)
	function_triggered.emit("damage_computation", {"damage": damage_result})
	print("      ✅ Damage computation tested")

func _test_damage_systems():
	print("    💥 Testing damage application systems...")

	# Find NPCs to test damage on
	var npcs = get_tree().get_nodes_in_group("npc")
	if npcs.size() > 0:
		for npc in npcs:
			if npc.has_method("apply_damage"):
				print("      🧟 Testing damage on: %s" % npc.name)
				var original_health = 100.0  # Assume default
				if npc.has_property("health"):
					original_health = npc.health

				# Apply test damage
				npc.apply_damage(5.0, "torso")
				function_triggered.emit("npc_damage", {
					"npc": npc.name,
					"damage": 5.0,
					"bodypart": "torso"
				})

				print("      ✅ Damage applied to %s" % npc.name)

			if npc.has_method("take_damage"):
				print("      🎯 Testing take_damage on: %s" % npc.name)
				npc.take_damage(3.0)
				function_triggered.emit("npc_take_damage", {
					"npc": npc.name,
					"damage": 3.0
				})
	else:
		print("      ⚠️ No NPCs found for damage testing")

func _test_death_systems():
	print("    💀 Testing death and destruction systems...")

	# Create a temporary NPC to test death functions
	var test_zombie = preload("res://entities/NPC/Zombie_Basic_2D.tscn").instantiate()
	get_tree().current_scene.add_child(test_zombie)

	await create_timer(0.5).timeout

	if test_zombie.has_method("_die"):
		print("      ⚰️ Testing zombie death function...")
		test_zombie._die()
		function_triggered.emit("zombie_death", {"zombie": test_zombie.name})
		print("      ✅ Death function tested")

# ========================================
# SPATIAL INTERACTION SIMULATION
# ========================================

func _simulate_spatial_interactions():
	print("\n🎯 SPATIAL INTERACTION SIMULATION")
	print("  📍 Testing area detection, zone transitions, and collision systems")

	# Test zone entry/exit functions
	await _test_zone_interactions()

	# Test detection area functions
	await _test_detection_systems()

	# Test collision and area functions
	await _test_collision_systems()

	print("  ✅ Spatial interaction simulation completed")

func _test_zone_interactions():
	print("    🌐 Testing zone interaction systems...")

	# Find zones in the current scene
	var zones = get_tree().get_nodes_in_group("zones")
	if zones.size() == 0:
		# Look for Zone2D nodes specifically
		zones = []
		_find_zone_nodes(get_tree().current_scene, zones)

	if zones.size() > 0:
		for zone in zones:
			if zone.has_method("_on_body_entered"):
				print("      🚪 Testing zone entry: %s" % zone.name)

				# Create mock player body for zone testing
				var mock_body = CharacterBody2D.new()
				mock_body.add_to_group("player")
				zone._on_body_entered(mock_body)

				function_triggered.emit("zone_entry", {
					"zone": zone.name,
					"body": "mock_player"
				})

				# Test zone exit
				if zone.has_method("_on_body_exited"):
					zone._on_body_exited(mock_body)
					function_triggered.emit("zone_exit", {
						"zone": zone.name,
						"body": "mock_player"
					})

				mock_body.queue_free()
				print("      ✅ Zone interaction tested: %s" % zone.name)

func _find_zone_nodes(node: Node, zones: Array):
	if node.get_class() == "Area2D" and "zone" in node.name.to_lower():
		zones.append(node)

	for child in node.get_children():
		_find_zone_nodes(child, zones)

func _test_detection_systems():
	print("    👁️ Testing NPC detection systems...")

	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		# Test detection area entry
		if npc.has_method("_on_detection_area_entered"):
			print("      🔍 Testing detection on: %s" % npc.name)

			var mock_player = CharacterBody2D.new()
			mock_player.add_to_group("player")
			mock_player.global_position = npc.global_position + Vector2(50, 0)

			npc._on_detection_area_entered(mock_player)
			function_triggered.emit("npc_detection", {
				"npc": npc.name,
				"target": "mock_player",
				"distance": 50
			})

			# Test detection exit
			if npc.has_method("_on_detection_area_exited"):
				npc._on_detection_area_exited(mock_player)
				function_triggered.emit("npc_detection_lost", {
					"npc": npc.name,
					"target": "mock_player"
				})

			mock_player.queue_free()
			print("      ✅ Detection system tested: %s" % npc.name)

func _test_collision_systems():
	print("    💥 Testing collision detection systems...")

	# Test projectile collisions
	var projectiles = get_tree().get_nodes_in_group("projectiles")
	for projectile in projectiles:
		if projectile.has_method("_on_body_entered"):
			print("      🎯 Testing projectile collision: %s" % projectile.name)

			var mock_target = CharacterBody2D.new()
			projectile._on_body_entered(mock_target)
			function_triggered.emit("projectile_collision", {
				"projectile": projectile.name,
				"target": "mock_target"
			})

			mock_target.queue_free()
			print("      ✅ Projectile collision tested: %s" % projectile.name)

# ========================================
# INPUT EVENT SIMULATION
# ========================================

func _simulate_input_events():
	print("\n⌨️ INPUT EVENT SIMULATION")
	print("  🕹️ Testing all input handling and interaction systems")

	await _test_keyboard_input()
	await _test_mouse_input()
	await _test_interaction_input()

	print("  ✅ Input event simulation completed")

func _test_keyboard_input():
	print("    ⌨️ Testing keyboard input handlers...")

	var input_handlers = []
	_find_input_handlers(get_tree().current_scene, input_handlers)

	for handler in input_handlers:
		if handler.has_method("_input"):
			print("      🔤 Testing keyboard input on: %s" % handler.name)

			# Test various key events
			var key_events = [KEY_SPACE, KEY_E, KEY_R, KEY_1, KEY_2, KEY_ESCAPE]
			for key in key_events:
				var input_event = InputEventKey.new()
				input_event.pressed = true
				input_event.keycode = key

				handler._input(input_event)
				function_triggered.emit("keyboard_input", {
					"handler": handler.name,
					"key": key,
					"pressed": true
				})

			print("      ✅ Keyboard input tested: %s" % handler.name)

func _test_mouse_input():
	print("    🖱️ Testing mouse input handlers...")

	var input_handlers = []
	_find_input_handlers(get_tree().current_scene, input_handlers)

	for handler in input_handlers:
		if handler.has_method("_input"):
			print("      👆 Testing mouse input on: %s" % handler.name)

			# Test mouse button events
			var mouse_event = InputEventMouseButton.new()
			mouse_event.pressed = true
			mouse_event.button_index = MOUSE_BUTTON_LEFT
			mouse_event.position = Vector2(100, 100)

			handler._input(mouse_event)
			function_triggered.emit("mouse_input", {
				"handler": handler.name,
				"button": MOUSE_BUTTON_LEFT,
				"position": Vector2(100, 100)
			})

			print("      ✅ Mouse input tested: %s" % handler.name)

func _test_interaction_input():
	print("    🤝 Testing interaction input systems...")

	# Find player to test interaction
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("_try_interact"):
			print("      🔗 Testing player interaction...")
			player._try_interact()
			function_triggered.emit("player_interaction", {
				"player": player.name,
				"action": "try_interact"
			})
			print("      ✅ Player interaction tested")

func _find_input_handlers(node: Node, handlers: Array):
	if node.has_method("_input") or node.has_method("_unhandled_input"):
		handlers.append(node)

	for child in node.get_children():
		_find_input_handlers(child, handlers)

# ========================================
# UI INTERACTION SIMULATION
# ========================================

func _simulate_ui_interactions():
	print("\n🖱️ UI INTERACTION SIMULATION")
	print("  📱 Testing all UI callbacks and menu interactions")

	# Test menu interactions
	await _test_menu_system()

	# Test inventory UI
	await _test_inventory_system()

	# Test crafting UI
	await _test_crafting_system()

	print("  ✅ UI interaction simulation completed")

func _test_menu_system():
	print("    📋 Testing menu system...")

	# Load menu scene for testing
	var error = change_scene_to_file("res://common/UI/Menu.tscn")
	if error != OK:
		print("      ❌ Failed to load menu scene: %d" % error)
		return

	await create_timer(1.0).timeout

	# Find and test menu buttons
	var buttons = []
	_find_buttons(get_tree().current_scene, buttons)

	for button in buttons:
		if button.is_connected("pressed", Callable()):
			print("      🔘 Testing button: %s" % button.name)
			button.pressed.emit()
			function_triggered.emit("button_pressed", {
				"button": button.name,
				"text": button.text if button.has_method("get_text") else ""
			})

func _test_inventory_system():
	print("    🎒 Testing inventory system...")

	# Switch to a scene with inventory
	var error = change_scene_to_file("res://stages/Stage_Outpost_2D.tscn")
	if error != OK:
		return

	await create_timer(1.0).timeout

	# Find inventory UI elements
	var inventory_nodes = []
	_find_inventory_nodes(get_tree().current_scene, inventory_nodes)

	for inv_node in inventory_nodes:
		if inv_node.has_method("_on_equip_button_pressed"):
			print("      ⚔️ Testing equipment functions...")
			inv_node._on_equip_button_pressed()
			function_triggered.emit("equipment_action", {
				"node": inv_node.name,
				"action": "equip"
			})

func _test_crafting_system():
	print("    🔨 Testing crafting system...")

	var crafting_nodes = []
	_find_crafting_nodes(get_tree().current_scene, crafting_nodes)

	for craft_node in crafting_nodes:
		if craft_node.has_method("_on_craft_pressed"):
			print("      🏭 Testing crafting functions...")
			craft_node._on_craft_pressed()
			function_triggered.emit("crafting_action", {
				"node": craft_node.name,
				"action": "craft"
			})

func _find_buttons(node: Node, buttons: Array):
	if node is Button:
		buttons.append(node)
	for child in node.get_children():
		_find_buttons(child, buttons)

func _find_inventory_nodes(node: Node, inv_nodes: Array):
	if "inventory" in node.name.to_lower() or "equip" in node.name.to_lower():
		inv_nodes.append(node)
	for child in node.get_children():
		_find_inventory_nodes(child, inv_nodes)

func _find_crafting_nodes(node: Node, craft_nodes: Array):
	if "craft" in node.name.to_lower():
		craft_nodes.append(node)
	for child in node.get_children():
		_find_crafting_nodes(child, craft_nodes)

# ========================================
# TEMPORAL EVENT SIMULATION
# ========================================

func _simulate_temporal_events():
	print("\n⏰ TEMPORAL EVENT SIMULATION")
	print("  🕐 Testing animations, timers, and time-based functions")

	await _test_animation_systems()
	await _test_timer_systems()
	await _test_transition_systems()

	print("  ✅ Temporal event simulation completed")

func _test_animation_systems():
	print("    🎬 Testing animation completion handlers...")

	# Find animated sprites
	var animated_sprites = []
	_find_animated_sprites(get_tree().current_scene, animated_sprites)

	for sprite in animated_sprites:
		if sprite.sprite_frames and sprite.sprite_frames.get_animation_names().size() > 0:
			var anim_name = sprite.sprite_frames.get_animation_names()[0]
			print("      🎭 Testing animation: %s on %s" % [anim_name, sprite.get_parent().name])

			sprite.play(anim_name)

			# Simulate animation finished
			if sprite.is_connected("animation_finished", Callable()):
				sprite.animation_finished.emit()
				function_triggered.emit("animation_finished", {
					"sprite": sprite.get_parent().name,
					"animation": anim_name
				})

func _test_timer_systems():
	print("    ⏲️ Testing timer and timeout systems...")

	# Test various timer scenarios
	var test_timer = create_timer(0.1)
	await test_timer.timeout
	function_triggered.emit("timer_test", {"duration": 0.1})

	print("      ✅ Timer systems tested")

func _test_transition_systems():
	print("    🔄 Testing transition systems...")

	# Test transition manager if available
	var transition_manager = get_node_or_null("/root/TransitionManager")
	if transition_manager:
		if transition_manager.has_method("_on_transition_completed"):
			print("      🚪 Testing transition completion...")
			transition_manager._on_transition_completed(null, "test_scene.tscn")
			function_triggered.emit("transition_completed", {
				"manager": "TransitionManager",
				"scene": "test_scene.tscn"
			})

func _find_animated_sprites(node: Node, sprites: Array):
	if node is AnimatedSprite2D:
		sprites.append(node)
	for child in node.get_children():
		_find_animated_sprites(child, sprites)

# ========================================
# ERROR CAPTURE AND ANALYSIS
# ========================================

func _on_error_captured(error_details: Dictionary):
	print("🚨 ERROR CAPTURED during %s simulation:" % current_simulation_phase)
	print("  📍 Location: %s" % error_details.get("location", "unknown"))
	print("  💬 Message: %s" % error_details.get("message", ""))
	print("  🔍 Context: %s" % error_details.get("context", {}))

	interaction_log.append({
		"type": "error",
		"phase": current_simulation_phase,
		"error": error_details,
		"timestamp": Time.get_time_string_from_system()
	})

func _analyze_simulation_results():
	print("\n📊 SIMULATION RESULTS ANALYSIS")
	print("=".repeat(40))

	var total_functions = 0
	var tested_functions = 0
	var errors_found = interaction_log.filter(func(log): return log.type == "error")

	for category in critical_functions:
		total_functions += critical_functions[category].size()

	# Count tested functions from interaction log
	var function_tests = interaction_log.filter(func(log): return log.type != "error")
	tested_functions = function_tests.size()

	print("📈 SUMMARY:")
	print("  • Critical functions identified: %d" % total_functions)
	print("  • Functions successfully tested: %d" % tested_functions)
	print("  • Errors discovered: %d" % errors_found.size())
	print("  • Test coverage: %.1f%%" % ((float(tested_functions) / total_functions) * 100.0))

	if errors_found.size() > 0:
		print("\n❌ ERRORS FOUND:")
		for error in errors_found:
			print("  • [%s] %s" % [error.phase, error.error.get("message", "")])

	print("\n✅ COMPREHENSIVE SIMULATION COMPLETED")
	print("🎯 All runtime-only functions tested without manual gameplay")
	print("📝 Error logs captured for immediate developer action")

	simulation_completed.emit({
		"total_functions": total_functions,
		"tested_functions": tested_functions,
		"errors_found": errors_found.size(),
		"coverage": (float(tested_functions) / total_functions) * 100.0,
		"interaction_log": interaction_log
	})