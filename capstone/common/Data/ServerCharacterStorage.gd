extends "res://common/Data/CharacterStorageAdapter.gd"

## Server-based character storage adapter
## Wraps HTTP API functionality in unified storage interface

class_name ServerCharacterStorage

signal operation_completed(result: CreationResult)
signal characters_loaded(characters: Array)

var _pending_operations: Dictionary = {}
var _cached_characters: Array = []
var _cache_valid: bool = false

func _init():
	# Connect to Api response handling if available
	if Api and Api.has_signal("response_received"):
		Api.response_received.connect(_on_api_response)

## Create character via server API
func create_character(payload: Dictionary) -> CreationResult:
	var result = CreationResult.new()
	
	# Validate client-side first (same rules as local)
	var validation = validate_character(payload) 
	if not validation.is_valid:
		result.error_message = "Validation failed: " + ", ".join(validation.errors)
		return result
	
	# Check if server is available
	if not is_available():
		result.error_message = "Server is not available"
		return result
	
	# Sanitize payload to expected schema
	var clean_payload := {
		"name": String(payload.get("name", "")),
		"strength": int(payload.get("strength", 1)),
		"dexterity": int(payload.get("dexterity", 1)),
		"agility": int(payload.get("agility", 1)),
		"endurance": int(payload.get("endurance", 1)),
		"accuracy": int(payload.get("accuracy", 1))
	}
	
	# Generate unique request ID
	var request_id = "create_char_%d" % Time.get_unix_time_from_system()
	
	# Store pending operation
	_pending_operations[request_id] = {
		"type": "create_character",
		"payload": clean_payload,
		"result": result
	}
	
	# Make API request
	var request = Api.post("characters", clean_payload, request_id)
	if request:
		print("📡 Creating character via server: %s" % clean_payload.name)
		# Return result - will be populated asynchronously
		return result
	else:
		result.error_message = "Failed to initiate server request"
		return result

## Get characters from server (with caching)
func get_characters() -> Array:
	if _cache_valid:
		return _cached_characters.duplicate(true)
	
	# Trigger async load if not cached
	_load_characters_async()
	return []

## Validate character using same rules as local storage
func validate_character(payload: Dictionary) -> ValidationResult:
	# Use the same validation as local storage for consistency
	return validate_common_fields(payload)

## Check name uniqueness via server
func is_name_unique(name: String) -> bool:
	# For server storage, we rely on server-side uniqueness validation
	# This is a synchronous approximation - real check happens on create
	if _cache_valid:
		var clean_name = name.strip_edges().to_lower()
		for character in _cached_characters:
			if String(character.get("name", "")).to_lower() == clean_name:
				return false
	return true

## Get storage type identifier  
func get_storage_type() -> StorageType:
	return StorageType.SERVER

## Check if server storage is available
func is_available() -> bool:
	return (Api != null and
			AuthController != null and
			AuthController.is_authenticated and
			not AuthController.is_offline_mode())

## Get maximum number of characters allowed in server storage
func get_max_characters() -> int:
	# TODO: This could be fetched from server config in a full implementation
	return 10  # Server allows more characters than local storage

## Delete character by ID via server API
func delete_character(character_id: String) -> bool:
	if not is_available():
		print("⚠️ Server not available for character deletion")
		return false

	# Generate unique request ID
	var request_id = "delete_char_%d" % Time.get_unix_time_from_system()

	# Store pending operation
	_pending_operations[request_id] = {
		"type": "delete_character",
		"character_id": character_id
	}

	# Make DELETE request to server
	var request = Api.delete("characters/" + character_id, request_id)
	if request:
		print("📡 Deleting character via server: %s" % character_id)
		# Remove from local cache immediately (optimistic deletion)
		for i in range(_cached_characters.size()):
			if String(_cached_characters[i].get("id", "")) == character_id:
				_cached_characters.remove_at(i)
				break
		return true
	else:
		print("❌ Failed to initiate character deletion request")
		return false

## Load characters from server asynchronously
func _load_characters_async() -> void:
	if not is_available():
		print("⚠️ Server not available for character loading")
		return
	
	var request_id = "load_chars_%d" % Time.get_unix_time_from_system()
	_pending_operations[request_id] = {
		"type": "load_characters"
	}
	
	var request = Api.get_json("characters", request_id)
	if request:
		print("📡 Loading characters from server")
	else:
		print("❌ Failed to initiate character loading request")

## Handle API responses
func _on_api_response(response_data: Dictionary, request_id: String) -> void:
	if not _pending_operations.has(request_id):
		return
	
	var operation = _pending_operations[request_id]
	_pending_operations.erase(request_id)
	
	match operation.type:
		"create_character":
			_handle_create_character_response(response_data, operation)
		"load_characters":
			_handle_load_characters_response(response_data)
		"delete_character":
			_handle_delete_character_response(response_data, operation)

## Handle character creation response
func _handle_create_character_response(response_data: Dictionary, operation: Dictionary) -> void:
	var result: CreationResult = operation.result
	
	if response_data.get("success", false):
		var character_data = response_data.get("character", {})
		if typeof(character_data) == TYPE_DICTIONARY and not character_data.is_empty():
			# Normalize character data to our schema
			var character = _normalize_server_character(character_data)
			
			result.success = true
			result.character = character
			
			# Update cache
			_cached_characters.append(character)
			
			print("✅ Character created successfully: %s" % character.get("name", ""))
		else:
			result.error_message = "Invalid character data received from server"
	else:
		# Handle server errors
		var error_msg = response_data.get("error", "Unknown server error")
		result.error_message = error_msg
		print("❌ Character creation failed: %s" % error_msg)
	
	operation_completed.emit(result)

## Handle load characters response  
func _handle_load_characters_response(response_data: Dictionary) -> void:
	if response_data.get("success", false):
		var server_characters = response_data.get("characters", [])
		if typeof(server_characters) == TYPE_ARRAY:
			# Normalize all characters
			_cached_characters.clear()
			for char_data in server_characters:
				if typeof(char_data) == TYPE_DICTIONARY:
					var character = _normalize_server_character(char_data)
					_cached_characters.append(character)
			
			_cache_valid = true
			print("✅ Loaded %d characters from server" % _cached_characters.size())
			characters_loaded.emit(_cached_characters.duplicate(true))
		else:
			print("❌ Invalid characters data format from server")
	else:
		var error_msg = response_data.get("error", "Failed to load characters")
		print("❌ Failed to load characters: %s" % error_msg)

## Handle character deletion response
func _handle_delete_character_response(response_data: Dictionary, operation: Dictionary) -> void:
	var character_id = operation.character_id

	if response_data.get("success", false):
		print("✅ Character deleted successfully: %s" % character_id)
		# Character was already removed from cache optimistically
	else:
		# Deletion failed, we need to restore the character to cache if we had it
		var error_msg = response_data.get("error", "Unknown server error")
		print("❌ Character deletion failed: %s" % error_msg)
		# TODO: In a full implementation, we might want to restore the character to cache
		# or refresh the entire cache from server

## Normalize server character data to local schema
func _normalize_server_character(server_data: Dictionary) -> Dictionary:
	return {
		"id": server_data.get("id", ""),
		"name": server_data.get("name", ""),
		"strength": int(server_data.get("strength", 1)),
		"dexterity": int(server_data.get("dexterity", 1)),
		"agility": int(server_data.get("agility", 1)),
		"endurance": int(server_data.get("endurance", 1)),
		"accuracy": int(server_data.get("accuracy", 1)),
		"level": int(server_data.get("level", 1)),
		"experience": int(server_data.get("experience", 0)),
		"health": int(server_data.get("health", 100)),
		"created_at": server_data.get("created_at", ""),
		"storage_type": "server",
		"synced": true
	}

## Clear cached data (force reload on next access)
func invalidate_cache() -> void:
	_cache_valid = false
	_cached_characters.clear()
	print("🔄 Server character cache invalidated")

## Get character by ID (from cache)
func get_character_by_id(id: String) -> Dictionary:
	if not _cache_valid:
		return {}
	
	for character in _cached_characters:
		if String(character.get("id", "")) == id:
			return character.duplicate(true)
	return {}

## Check if operation is pending
func has_pending_operations() -> bool:
	return not _pending_operations.is_empty()

## Get pending operation count
func get_pending_operation_count() -> int:
	return _pending_operations.size()
