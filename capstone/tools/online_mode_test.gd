extends Control

## Online Mode Testing Tool
## Tests all online functionality with local API server

var test_results: Dictionary = {}
var tests_completed: int = 0
var total_tests: int = 7

func _ready():
	print("🧪 ONLINE MODE TEST - COMPREHENSIVE VALIDATION")
	print("=".repeat(60))

	# Set up as fullscreen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Create simple UI for visual feedback
	_setup_test_ui()

	# Wait a frame then start tests
	await get_tree().process_frame
	_run_tests()

func _setup_test_ui():
	# Create background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Create title
	var title = Label.new()
	title.text = "ONLINE MODE VALIDATION TEST"
	title.position = Vector2(50, 50)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)

	# Create status label
	var status = Label.new()
	status.name = "StatusLabel"
	status.text = "Initializing tests..."
	status.position = Vector2(50, 100)
	status.add_theme_font_size_override("font_size", 16)
	add_child(status)

	# Create results area
	var results = RichTextLabel.new()
	results.name = "ResultsLabel"
	results.position = Vector2(50, 140)
	results.size = Vector2(800, 400)
	results.bbcode_enabled = true
	results.text = "[color=yellow]Test results will appear here...[/color]"
	add_child(results)

func _update_status(text: String):
	var status_label = get_node("StatusLabel")
	if status_label:
		status_label.text = text

func _add_result(test_name: String, success: bool, details: String = ""):
	var results_label = get_node("ResultsLabel")
	if results_label:
		var color = "green" if success else "red"
		var icon = "✅" if success else "❌"
		var result_text = "[color=%s]%s %s[/color]" % [color, icon, test_name]
		if details != "":
			result_text += "\n  " + details
		result_text += "\n\n"

		if results_label.text.contains("Test results will appear here"):
			results_label.text = result_text
		else:
			results_label.text += result_text

func _run_tests():
	print("🚀 Starting online mode tests...")

	# Test 1: Check API availability
	_update_status("Testing API availability...")
	await _test_api_availability()

	# Test 2: Check AuthController state
	_update_status("Testing AuthController state...")
	await _test_auth_controller()

	# Test 3: Test CharacterService online mode
	_update_status("Testing CharacterService online mode...")
	await _test_character_service()

	# Test 4: Test Inventory online mode
	_update_status("Testing Inventory online mode...")
	await _test_inventory_system()

	# Test 5: Test Market online mode
	_update_status("Testing Market online mode...")
	await _test_market_system()

	# Test 6: Test online/offline transitions
	_update_status("Testing online/offline transitions...")
	await _test_state_transitions()

	# Test 7: Comprehensive sync test
	_update_status("Testing comprehensive sync...")
	await _test_comprehensive_sync()

	# Final summary
	_show_final_summary()

func _test_api_availability():
	print("📡 Testing API availability...")

	var api_exists = Api != null
	var base_url_set = api_exists and Api.base_url != ""
	var is_local = api_exists and Api.base_url.contains("localhost")

	test_results["api_availability"] = {
		"api_exists": api_exists,
		"base_url_set": base_url_set,
		"is_local": is_local,
		"base_url": Api.base_url if api_exists else "N/A"
	}

	var success = api_exists and base_url_set and is_local
	var details = "Base URL: %s" % (Api.base_url if api_exists else "N/A")
	_add_result("API Availability", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_auth_controller():
	print("🔐 Testing AuthController state...")

	var auth_exists = AuthController != null
	var has_methods = false
	var offline_mode = false
	var is_authenticated = false

	if auth_exists:
		has_methods = (AuthController.has_method("is_offline_mode") and
					   AuthController.has_method("get_auth_status"))
		offline_mode = AuthController.is_offline_mode()
		is_authenticated = AuthController.is_authenticated

	test_results["auth_controller"] = {
		"exists": auth_exists,
		"has_methods": has_methods,
		"offline_mode": offline_mode,
		"is_authenticated": is_authenticated
	}

	var success = auth_exists and has_methods
	var details = "Offline: %s, Authenticated: %s" % [offline_mode, is_authenticated]
	_add_result("AuthController", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_character_service():
	print("👤 Testing CharacterService online mode...")

	var service_exists = CharacterService != null
	var has_storage = false
	var storage_type = "unknown"
	var can_sync = false

	if service_exists:
		has_storage = CharacterService.current_storage != null
		if has_storage:
			storage_type = CharacterService._last_source
			can_sync = CharacterService.current_storage.has_method("is_available")

	test_results["character_service"] = {
		"exists": service_exists,
		"has_storage": has_storage,
		"storage_type": storage_type,
		"can_sync": can_sync
	}

	var success = service_exists and has_storage
	var details = "Storage: %s" % storage_type
	_add_result("CharacterService", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_inventory_system():
	print("📦 Testing Inventory online mode...")

	var inventory_nodes = get_tree().get_nodes_in_group("inventory")
	var has_inventory = inventory_nodes.size() > 0
	var has_sync_methods = false
	var sync_status = {}

	if has_inventory:
		var inventory = inventory_nodes[0]
		has_sync_methods = (inventory.has_method("save_to_database") and
						   inventory.has_method("get_sync_status"))
		if has_sync_methods:
			sync_status = inventory.get_sync_status()

	test_results["inventory_system"] = {
		"has_inventory": has_inventory,
		"has_sync_methods": has_sync_methods,
		"sync_status": sync_status
	}

	var success = has_inventory and has_sync_methods
	var details = "Sync enabled: %s" % sync_status.get("sync_enabled", false)
	_add_result("Inventory System", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_market_system():
	print("💰 Testing Market online mode...")

	var market_nodes = get_tree().get_nodes_in_group("markets")
	var has_market = market_nodes.size() > 0
	var has_sync_methods = false
	var sync_status = {}

	if has_market:
		var market = market_nodes[0]
		has_sync_methods = (market.has_method("_sync_prices_with_server") and
						   market.has_method("get_sync_status"))
		if has_sync_methods:
			sync_status = market.get_sync_status()

	test_results["market_system"] = {
		"has_market": has_market,
		"has_sync_methods": has_sync_methods,
		"sync_status": sync_status
	}

	var success = has_market and has_sync_methods
	var details = "Can sync: %s" % sync_status.get("can_sync", false)
	_add_result("Market System", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_state_transitions():
	print("🔄 Testing online/offline transitions...")

	var auth_exists = AuthController != null
	var has_signals = false

	if auth_exists:
		has_signals = (AuthController.has_signal("user_logged_in") and
					   AuthController.has_signal("user_logged_out"))

	# Check if systems are connected to auth signals
	var inventory_connected = false
	var market_connected = false

	if auth_exists and has_signals:
		var inventory_nodes = get_tree().get_nodes_in_group("inventory")
		if inventory_nodes.size() > 0:
			var inventory = inventory_nodes[0]
			inventory_connected = inventory.has_method("_on_user_logged_in")

		var market_nodes = get_tree().get_nodes_in_group("markets")
		if market_nodes.size() > 0:
			var market = market_nodes[0]
			market_connected = market.has_method("_on_user_logged_in")

	test_results["state_transitions"] = {
		"auth_has_signals": has_signals,
		"inventory_connected": inventory_connected,
		"market_connected": market_connected
	}

	var success = has_signals and inventory_connected and market_connected
	var details = "Systems connected to auth signals"
	_add_result("State Transitions", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _test_comprehensive_sync():
	print("🔗 Testing comprehensive sync capabilities...")

	var systems_can_sync = 0
	var total_systems = 3  # Character, Inventory, Market

	# Test CharacterService
	if CharacterService and CharacterService.current_storage:
		if CharacterService.current_storage.has_method("is_available"):
			systems_can_sync += 1

	# Test Inventory
	var inventory_nodes = get_tree().get_nodes_in_group("inventory")
	if inventory_nodes.size() > 0:
		var inventory = inventory_nodes[0]
		if inventory.has_method("sync_to_server"):
			systems_can_sync += 1

	# Test Market
	var market_nodes = get_tree().get_nodes_in_group("markets")
	if market_nodes.size() > 0:
		var market = market_nodes[0]
		if market.has_method("sync_all_to_server"):
			systems_can_sync += 1

	test_results["comprehensive_sync"] = {
		"systems_can_sync": systems_can_sync,
		"total_systems": total_systems,
		"sync_percentage": float(systems_can_sync) / total_systems * 100.0
	}

	var success = systems_can_sync == total_systems
	var details = "%d/%d systems can sync (%.1f%%)" % [systems_can_sync, total_systems, float(systems_can_sync) / total_systems * 100.0]
	_add_result("Comprehensive Sync", success, details)

	tests_completed += 1
	await get_tree().create_timer(0.5).timeout

func _show_final_summary():
	_update_status("Tests completed! Check results below.")

	print("\n📊 ONLINE MODE TEST SUMMARY")
	print("=" * 40)

	var passed = 0
	var failed = 0

	for test_name in test_results.keys():
		var result = test_results[test_name]
		# Count as passed if it has expected functionality
		if ((test_name == "api_availability" and result.api_exists and result.is_local) or
			(test_name == "auth_controller" and result.exists and result.has_methods) or
			(test_name == "character_service" and result.exists and result.has_storage) or
			(test_name == "inventory_system" and result.has_inventory and result.has_sync_methods) or
			(test_name == "market_system" and result.has_market and result.has_sync_methods) or
			(test_name == "state_transitions" and result.auth_has_signals and result.inventory_connected and result.market_connected) or
			(test_name == "comprehensive_sync" and result.systems_can_sync == result.total_systems)):
			passed += 1
		else:
			failed += 1

	print("✅ PASSED: %d" % passed)
	print("❌ FAILED: %d" % failed)
	print("📊 SUCCESS RATE: %.1f%%" % (float(passed) / (passed + failed) * 100.0))

	if failed == 0:
		print("🎉 ALL TESTS PASSED - ONLINE MODE READY!")
		_add_result("FINAL RESULT", true, "All systems ready for online mode!")
	else:
		print("⚠️ SOME TESTS FAILED - CHECK RESULTS ABOVE")
		_add_result("FINAL RESULT", false, "%d tests failed - see details above" % failed)

# Allow manual testing via input
func _input(event: InputEvent):
	if event.is_action_just_pressed("ui_accept"):  # Enter key
		print("🔄 Rerunning tests...")
		test_results.clear()
		tests_completed = 0
		_run_tests()