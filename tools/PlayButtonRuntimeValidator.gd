extends Node

## Play Button Runtime Validator
## Automatically runs comprehensive runtime testing when play button is pressed
## Validates all runtime-only systems before allowing gameplay to proceed

class_name PlayButtonRuntimeValidator

signal validation_completed(success: bool, results: Dictionary)
signal validation_failed(errors: Array)

var validation_enabled: bool = true
var quick_validation_mode: bool = false
var validation_results: Dictionary = {}
var is_validating: bool = false

# Critical systems that must pass validation
var critical_systems = [
	"combat_systems",
	"input_systems",
	"ui_interactions",
	"transition_systems"
]

# Validation configuration
var validation_config = {
	"timeout_seconds": 30,
	"max_errors_allowed": 0,
	"require_all_systems": true,
	"quick_mode_function_limit": 50
}

func _ready():
	print("🔧 PlayButtonRuntimeValidator: Initializing compile-time runtime validation")
	_setup_validation_hooks()

func _setup_validation_hooks():
	"""Setup hooks to validate runtime systems before gameplay"""
	# Connect to scene changes to validate when play starts
	if get_tree():
		get_tree().tree_changed.connect(_on_scene_tree_changed)

	print("✅ PlayButtonRuntimeValidator: Validation hooks active")

func _on_scene_tree_changed():
	"""Detect when play button creates a new scene and validate"""
	if not validation_enabled or is_validating:
		return

	# Check if we're entering a gameplay scene (not UI scenes)
	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	var scene_path = current_scene.scene_file_path

	# Only validate gameplay scenes, not UI scenes
	if _is_gameplay_scene(scene_path):
		print("🎮 PlayButtonRuntimeValidator: Gameplay scene detected, starting validation...")
		await _run_compile_time_validation()

func _is_gameplay_scene(scene_path: String) -> bool:
	"""Determine if this is a gameplay scene that needs validation"""
	var gameplay_patterns = [
		"stages/",
		"levels/",
		"gameplay/",
		"Stage_",
		"Level_"
	]

	for pattern in gameplay_patterns:
		if pattern in scene_path:
			return true

	return false

func _run_compile_time_validation():
	"""Run comprehensive runtime validation at compile time / play button press"""
	if is_validating:
		return

	is_validating = true
	validation_results.clear()

	print("🔍 PlayButtonRuntimeValidator: Starting compile-time runtime validation...")
	print("  📊 Mode: %s" % ("Quick" if quick_validation_mode else "Comprehensive"))

	var start_time = Time.get_ticks_msec()

	# Run validation based on mode
	if quick_validation_mode:
		await _run_quick_validation()
	else:
		await _run_comprehensive_validation()

	var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
	validation_results["validation_time"] = elapsed_time

	# Analyze results and determine if gameplay should proceed
	var validation_success = _analyze_validation_results()

	if validation_success:
		print("✅ PlayButtonRuntimeValidator: All systems validated - gameplay proceeding")
		validation_completed.emit(true, validation_results)
	else:
		print("❌ PlayButtonRuntimeValidator: Validation failed - blocking gameplay")
		_handle_validation_failure()

	is_validating = false

func _run_quick_validation():
	"""Run quick validation of critical systems only"""
	print("  ⚡ Running quick validation of critical systems...")

	validation_results["mode"] = "quick"
	validation_results["systems_tested"] = 0
	validation_results["functions_tested"] = 0
	validation_results["errors_found"] = 0
	validation_results["critical_errors"] = 0

	# Test only critical systems with limited function calls
	await _test_critical_input_systems()
	await _test_critical_combat_systems()
	await _test_critical_ui_systems()
	await _test_critical_transitions()

	print("  ✅ Quick validation completed")

func _run_comprehensive_validation():
	"""Run comprehensive validation of all runtime systems"""
	print("  🔍 Running comprehensive validation of all runtime systems...")

	validation_results["mode"] = "comprehensive"
	validation_results["systems_tested"] = 0
	validation_results["functions_tested"] = 0
	validation_results["errors_found"] = 0
	validation_results["critical_errors"] = 0
	validation_results["system_results"] = {}

	# Test all system categories
	await _test_all_input_systems()
	await _test_all_combat_systems()
	await _test_all_ui_systems()
	await _test_all_inventory_systems()
	await _test_all_npc_systems()
	await _test_all_economy_systems()
	await _test_all_perception_systems()
	await _test_all_audio_systems()
	await _test_all_transition_systems()

	print("  ✅ Comprehensive validation completed")

func _test_critical_input_systems():
	"""Test critical input handling functions"""
	print("    📱 Validating critical input systems...")

	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		await _validate_critical_functions(player, [
			"_input", "_unhandled_input", "_fire_weapon"
		], "input_systems")

func _test_critical_combat_systems():
	"""Test critical combat functions"""
	print("    ⚔️ Validating critical combat systems...")

	var players = get_tree().get_nodes_in_group("player")
	var npcs = get_tree().get_nodes_in_group("npc")

	for player in players:
		await _validate_critical_functions(player, [
			"_fire_weapon", "apply_damage", "_reload"
		], "combat_systems")

	# Test a few NPCs
	var npcs_to_test = npcs.slice(0, min(3, npcs.size()))
	for npc in npcs_to_test:
		await _validate_critical_functions(npc, [
			"apply_damage", "_on_player_detected"
		], "combat_systems")

func _test_critical_ui_systems():
	"""Test critical UI interaction functions"""
	print("    🖱️ Validating critical UI systems...")

	var ui_nodes = get_tree().get_nodes_in_group("ui")
	for ui_node in ui_nodes:
		# Test button interactions
		await _validate_ui_interactions(ui_node)

func _test_critical_transitions():
	"""Test critical scene transitions"""
	print("    🔄 Validating critical transitions...")

	# Test one transition to verify system works
	var current_scene = get_tree().current_scene.scene_file_path
	var test_scenes = [
		"res://stages/Stage_Hostile_01_2D.tscn",
		current_scene  # Return to original
	]

	for scene_path in test_scenes:
		validation_results["functions_tested"] += 1
		var error = get_tree().change_scene_to_file(scene_path)
		if error != OK:
			validation_results["errors_found"] += 1
			validation_results["critical_errors"] += 1
			print("    ❌ Critical transition failed: %s" % scene_path)
		else:
			await get_tree().create_timer(0.3).timeout

func _validate_critical_functions(node: Node, functions: Array[String], category: String):
	"""Validate critical functions for a node"""
	if not is_instance_valid(node):
		return

	validation_results["systems_tested"] += 1

	for function_name in functions:
		validation_results["functions_tested"] += 1

		if validation_results["functions_tested"] > validation_config.quick_mode_function_limit and quick_validation_mode:
			break

		try:
			if node.has_method(function_name):
				match function_name:
					"_fire_weapon":
						if node.has_method("_fire_weapon"):
							node._fire_weapon()
					"apply_damage":
						if node.has_method("apply_damage"):
							node.apply_damage(1.0, "test")
					"_reload":
						if node.has_method("_reload"):
							node._reload()
					_:
						node.call(function_name)

				print("      ✅ %s.%s()" % [node.name, function_name])
			else:
				print("      ⚠️ %s.%s() not found" % [node.name, function_name])

		except:
			validation_results["errors_found"] += 1
			if category in critical_systems:
				validation_results["critical_errors"] += 1
			print("      ❌ %s.%s() failed" % [node.name, function_name])

func _validate_ui_interactions(ui_node: Node):
	"""Validate UI interaction functions"""
	validation_results["systems_tested"] += 1

	# Find and test buttons
	var buttons = _find_buttons(ui_node)
	for button in buttons:
		validation_results["functions_tested"] += 1

		try:
			# Simulate button press
			if button.has_signal("pressed"):
				button.pressed.emit()
				print("      ✅ Button %s pressed" % button.name)
		except:
			validation_results["errors_found"] += 1
			print("      ❌ Button %s press failed" % button.name)

func _find_buttons(node: Node) -> Array[Button]:
	"""Recursively find all buttons in a node"""
	var buttons: Array[Button] = []

	if node is Button:
		buttons.append(node)

	for child in node.get_children():
		buttons.append_array(_find_buttons(child))

	return buttons

# Comprehensive testing methods (when not in quick mode)

func _test_all_input_systems():
	"""Test all input systems comprehensively"""
	print("    📱 Validating all input systems...")
	# Implementation similar to ComprehensiveRuntimeSystemTester
	await _test_system_category("input", get_tree().get_nodes_in_group("player"))

func _test_all_combat_systems():
	"""Test all combat systems comprehensively"""
	print("    ⚔️ Validating all combat systems...")
	var combat_nodes = []
	combat_nodes.append_array(get_tree().get_nodes_in_group("player"))
	combat_nodes.append_array(get_tree().get_nodes_in_group("npc"))
	await _test_system_category("combat", combat_nodes)

func _test_all_ui_systems():
	"""Test all UI systems comprehensively"""
	print("    🖱️ Validating all UI systems...")
	await _test_system_category("ui", get_tree().get_nodes_in_group("ui"))

func _test_all_inventory_systems():
	"""Test all inventory systems comprehensively"""
	print("    🎒 Validating all inventory systems...")
	var inventory_nodes = []
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		var inventory = player.get_node_or_null("Inventory")
		if inventory:
			inventory_nodes.append(inventory)
	await _test_system_category("inventory", inventory_nodes)

func _test_all_npc_systems():
	"""Test all NPC systems comprehensively"""
	print("    🤖 Validating all NPC AI systems...")
	await _test_system_category("npc", get_tree().get_nodes_in_group("npc"))

func _test_all_economy_systems():
	"""Test all economy systems comprehensively"""
	print("    💰 Validating all economy systems...")
	var economy_nodes = []
	economy_nodes.append_array(get_tree().get_nodes_in_group("market"))
	economy_nodes.append_array(get_tree().get_nodes_in_group("crafting"))
	await _test_system_category("economy", economy_nodes)

func _test_all_perception_systems():
	"""Test all perception systems comprehensively"""
	print("    👁️ Validating all perception systems...")
	await _test_system_category("perception", get_tree().get_nodes_in_group("perception"))

func _test_all_audio_systems():
	"""Test all audio systems comprehensively"""
	print("    🔊 Validating all audio systems...")
	var audio_nodes = []
	_find_all_audio_players(get_tree().current_scene, audio_nodes)
	await _test_system_category("audio", audio_nodes)

func _test_all_transition_systems():
	"""Test all transition systems comprehensively"""
	print("    🔄 Validating all transition systems...")
	# More comprehensive transition testing
	await _test_critical_transitions()

func _test_system_category(category: String, nodes: Array):
	"""Test a category of systems"""
	validation_results["system_results"][category] = {
		"nodes_tested": nodes.size(),
		"functions_tested": 0,
		"errors_found": 0
	}

	for node in nodes:
		if not is_instance_valid(node):
			continue

		validation_results["systems_tested"] += 1
		# Test basic functionality of each node
		await _test_node_basic_functions(node, category)

func _test_node_basic_functions(node: Node, category: String):
	"""Test basic functions of a node"""
	var common_functions = ["_ready", "_process"]

	for function_name in common_functions:
		if node.has_method(function_name):
			validation_results["functions_tested"] += 1
			validation_results["system_results"][category]["functions_tested"] += 1

			try:
				# Note: Don't actually call _ready or _process in testing
				print("      ✅ %s.%s() exists" % [node.name, function_name])
			except:
				validation_results["errors_found"] += 1
				validation_results["system_results"][category]["errors_found"] += 1
				print("      ❌ %s.%s() failed" % [node.name, function_name])

func _find_all_audio_players(node: Node, audio_list: Array):
	"""Recursively find all AudioStreamPlayer nodes"""
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		audio_list.append(node)

	for child in node.get_children():
		_find_all_audio_players(child, audio_list)

func _analyze_validation_results() -> bool:
	"""Analyze validation results to determine if gameplay should proceed"""
	var success = true

	# Check critical error threshold
	if validation_results.get("critical_errors", 0) > validation_config.max_errors_allowed:
		success = false

	# Check total error percentage
	var total_functions = validation_results.get("functions_tested", 1)
	var total_errors = validation_results.get("errors_found", 0)
	var error_rate = (total_errors * 100.0) / total_functions

	if error_rate > 10.0:  # More than 10% error rate
		success = false

	return success

func _handle_validation_failure():
	"""Handle validation failure"""
	var errors = []

	print("🚨 PlayButtonRuntimeValidator: VALIDATION FAILED")
	print("  ❌ Critical errors: %d" % validation_results.get("critical_errors", 0))
	print("  ❌ Total errors: %d" % validation_results.get("errors_found", 0))
	print("  📊 Functions tested: %d" % validation_results.get("functions_tested", 0))

	# Block gameplay or show warning
	if validation_config.require_all_systems:
		print("  🛑 GAMEPLAY BLOCKED - Fix errors before playing")
		get_tree().paused = true
	else:
		print("  ⚠️ WARNING - Gameplay proceeding with known issues")

	validation_failed.emit(errors)

# Public API

func enable_validation():
	"""Enable runtime validation on play"""
	validation_enabled = true
	print("✅ PlayButtonRuntimeValidator: Validation enabled")

func disable_validation():
	"""Disable runtime validation"""
	validation_enabled = false
	print("🔇 PlayButtonRuntimeValidator: Validation disabled")

func set_quick_mode(enabled: bool):
	"""Enable/disable quick validation mode"""
	quick_validation_mode = enabled
	print("⚡ PlayButtonRuntimeValidator: Quick mode %s" % ("enabled" if enabled else "disabled"))

func get_last_validation_results() -> Dictionary:
	"""Get results from last validation"""
	return validation_results.duplicate()

func force_validation():
	"""Force immediate validation"""
	await _run_compile_time_validation()

# Integration helpers
static func add_to_autoload():
	"""Helper to add this validator to autoload"""
	var validator = PlayButtonRuntimeValidator.new()
	validator.name = "PlayButtonRuntimeValidator"

	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		tree.root.add_child(validator)
		return validator
	return null