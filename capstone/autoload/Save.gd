extends Node

var save_path := "user://savegame.save"
var session_path := "user://session_data.save"
var queue_path := "user://offline_queue.save"

var queue: Array = []
var session_data: Dictionary = {}
var processing_queue: bool = false

func _ready() -> void:
	if OS.has_feature("web"):
		print("🌐 [SAVE] Browser environment detected - optimizing save system")
		# In browser, ensure we have write permissions
		_verify_browser_storage()
	_load_session()
	_load_persistent_queue()

func _verify_browser_storage() -> void:
	"""Verify browser storage is working properly"""
	var test_path = "user://browser_test.tmp"
	var test_file = FileAccess.open(test_path, FileAccess.WRITE)
	if test_file:
		test_file.store_string("test")
		test_file.close()
		print("✅ [SAVE] Browser storage verified - write access OK")
		# Clean up test file
		if FileAccess.file_exists(test_path):
			DirAccess.remove_absolute(test_path)
	else:
		print("❌ [SAVE] Browser storage issue - may have limited functionality")

func save_local(data: Dictionary) -> void:
	"""Save data with browser-compatible error handling"""
	var success = _store_var(save_path, data)
	if OS.has_feature("web") and not success:
		print("⚠️ [SAVE] Browser save failed - data may not persist across sessions")
	elif success:
		print("✅ [SAVE] Data saved successfully")

func load_local() -> Dictionary:
	"""Load data with browser-compatible fallbacks"""
	var value = _load_var(save_path)
	if typeof(value) == TYPE_DICTIONARY:
		if OS.has_feature("web"):
			print("✅ [SAVE] Browser data loaded successfully")
		return value
	else:
		if OS.has_feature("web"):
			print("ℹ️ [SAVE] No saved data found in browser - starting fresh")
		return {}

func enqueue_request(payload: Dictionary) -> void:
	queue.append(payload.duplicate(true))
	_save_persistent_queue()

func dequeue_request() -> Dictionary:
	if queue.is_empty():
		return {}
	var request = queue[0]
	queue.remove_at(0)
	_save_persistent_queue()
	if typeof(request) == TYPE_DICTIONARY:
		return request
	return {}

func process_offline_queue() -> void:
	if queue.is_empty() or Api == null:
		return

	var pending: Array = queue.duplicate(true)
	queue.clear()
	_save_persistent_queue()

	for request in pending:
		if typeof(request) != TYPE_DICTIONARY:
			continue
		var method := String(request.get("method", ""))
		var path := String(request.get("path", ""))
		var body: Variant = request.get("body", {})
		var request_id := String(request.get("request_id", ""))

		if method == "POST":
			if typeof(body) != TYPE_DICTIONARY:
				body = {}
			Api.post(path, body, request_id)

func snapshot() -> Dictionary:
	var scene_path := "res://stages/Stage_Outpost_2D.tscn"
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
		scene_path = get_tree().current_scene.scene_file_path

	var inventory_data: Array = []
	var player_stats: Dictionary = {}
	var player = get_tree().get_first_node_in_group("player")

	var market_state: Dictionary = {}
	var settlement_state: Dictionary = {}
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game and game.current_stage:
			var market_node = game.current_stage.get_node_or_null("MarketController")
			if market_node and market_node.has_method("get_state_snapshot"):
				market_state = market_node.get_state_snapshot()
			var settlement_node = game.current_stage.get_node_or_null("SettlementController")
			if settlement_node and settlement_node.has_method("get_state_snapshot"):
				settlement_state = settlement_node.get_state_snapshot()
	if player:
		if player.has_node("Inventory"):
			var inventory_node = player.get_node("Inventory")
			var stored_items = inventory_node.get("items")
			if typeof(stored_items) == TYPE_ARRAY:
				inventory_data = stored_items.duplicate(true)
		if player.has_method("get_character_stats"):
			var stats = player.get_character_stats()
			if typeof(stats) == TYPE_DICTIONARY:
				player_stats = stats

	return {
		"stage": scene_path,
		"inventory": inventory_data,
		"player_stats": player_stats,
		"timestamp": GameTime.get_unix_time_from_system(),
		"market": market_state,
		"settlement": settlement_state
	}

func save_data() -> void:
	_store_var(session_path, session_data)

func load_data() -> void:
	_load_session()

func has_value(key: String) -> bool:
	return session_data.has(key)

func get_value(key: String, default_value = null):
	return session_data.get(key, default_value)

func set_value(key: String, value) -> void:
	session_data[key] = value
	save_data()

func remove_value(key: String) -> void:
	if session_data.has(key):
		session_data.erase(key)
		save_data()

func clear_save_data() -> void:
	session_data.clear()
	save_data()

func _load_session() -> void:
	var value = _load_var(session_path)
	if typeof(value) == TYPE_DICTIONARY:
		session_data = value
	else:
		session_data = {}

func _save_persistent_queue() -> void:
	_store_var(queue_path, queue)

func _load_persistent_queue() -> void:
	var value = _load_var(queue_path)
	if typeof(value) == TYPE_ARRAY:
		queue = value
	else:
		queue = []

func _store_var(path: String, value) -> bool:
	"""Store variable with success return for browser compatibility"""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(value)
		file.close()
		return true
	else:
		if OS.has_feature("web"):
			print("❌ [SAVE] Failed to write to %s - browser storage may be restricted" % path)
		return false

func _load_var(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var value = file.get_var()
	file.close()
	return value
