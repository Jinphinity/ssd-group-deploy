extends Node

## Unified Character Service with Storage Adapter Pattern
## Provides consistent character management across local and server environments

# Storage adapter classes - loaded dynamically to avoid autoload issues
var CharacterStorageAdapterClass = null
var LocalCharacterStorageClass = null
var ServerCharacterStorageClass = null

signal roster_updated(characters: Array, info: Dictionary)
signal character_created(character: Dictionary)
signal character_deleted(character_id: String)
signal character_operation_failed(message: String)
signal current_character_changed(character: Dictionary)

const CACHE_ROSTER_KEY := "character_roster"
const CACHE_CURRENT_KEY := "current_character"

# Storage adapters
var local_storage = null
var server_storage = null
var current_storage = null

# State management
var characters: Array = []
var current_character: Dictionary = {}
var _is_loading: bool = false
var _last_source: String = "cache"

const _WEAPON_PROFICIENCY_KEYS := [
	"melee_knives",
	"melee_axes_clubs",
	"firearm_handguns",
	"firearm_rifles",
	"firearm_shotguns",
	"firearm_automatics"
]

const _EQUIPMENT_SLOTS := [
	"weapon",
	"head",
	"torso",
	"legs",
	"accessory"
]

func _ready() -> void:
	print("🔧 [CHAR] CharacterService._ready() called - initializing")
	_initialize_storage_adapters()
	_load_cached_state()
	_select_storage_adapter()

	# POTENTIAL FIX: Connect to auth state changes to re-select adapter when needed
	if AuthController:
		if not AuthController.user_logged_in.is_connected(_on_auth_state_changed):
			AuthController.user_logged_in.connect(_on_auth_state_changed)
		if not AuthController.user_logged_out.is_connected(_on_auth_state_changed):
			AuthController.user_logged_out.connect(_on_auth_state_changed)
		print("✅ [CHAR] Connected to AuthController state change signals")
	else:
		print("⚠️ [CHAR] AuthController not available during initialization")

	print("🔧 [CHAR] CharacterService initialization complete")

## Initialize storage adapters
func _initialize_storage_adapters() -> void:
	print("🔧 Initializing character storage adapters...")

	# Load classes dynamically to avoid autoload dependency issues
	CharacterStorageAdapterClass = load("res://common/Data/CharacterStorageAdapter.gd")
	LocalCharacterStorageClass = load("res://common/Data/LocalCharacterStorage.gd")
	ServerCharacterStorageClass = load("res://common/Data/ServerCharacterStorage.gd")

	# Create storage adapters with error handling
	if LocalCharacterStorageClass:
		local_storage = LocalCharacterStorageClass.new()
		if local_storage:
			print("✅ Local character storage initialized")
		else:
			print("❌ Failed to create local character storage instance")
			character_operation_failed.emit("Failed to initialize local storage")
			return
	else:
		print("❌ LocalCharacterStorageClass failed to load")
		character_operation_failed.emit("LocalCharacterStorageClass not available")
		return

	if ServerCharacterStorageClass:
		server_storage = ServerCharacterStorageClass.new()
		if server_storage:
			print("✅ Server character storage initialized")
			# Connect to server storage signals if they exist
			if server_storage.has_signal("operation_completed"):
				server_storage.operation_completed.connect(_on_server_operation_completed)
			if server_storage.has_signal("characters_loaded"):
				server_storage.characters_loaded.connect(_on_server_characters_loaded)
		else:
			print("❌ Failed to create server character storage instance")
			character_operation_failed.emit("Failed to initialize server storage")
			return
	else:
		print("❌ ServerCharacterStorageClass not loaded")
		character_operation_failed.emit("ServerCharacterStorageClass not available")
		return
	
	print("🔧 Character storage adapters initialized successfully")

## Handle authentication state changes
func _on_auth_state_changed(_user_data: Dictionary = {}) -> void:
	print("🔄 [CHAR] Auth state changed - re-selecting storage adapter")
	_select_storage_adapter()

## Select appropriate storage adapter based on environment
func _select_storage_adapter() -> void:
	print("🔍 [CHAR] _select_storage_adapter() called")

	# Validate storage adapters are initialized
	if not local_storage:
		print("❌ Local storage not initialized, cannot select adapter")
		character_operation_failed.emit("Local storage not available")
		return

	if not server_storage:
		print("❌ Server storage not initialized, cannot select adapter")
		character_operation_failed.emit("Server storage not available")
		return

	# Get current auth state for decision making
	var auth_available = AuthController != null
	var is_authenticated = false
	var is_offline = false

	if auth_available:
		is_authenticated = AuthController.is_authenticated
		is_offline = AuthController.is_offline_mode()
	else:
		print("⚠️ [CHAR] AuthController not available - defaulting to local storage")

	print("🔍 [CHAR] Auth state for storage selection:")
	print("  - AuthController available: %s" % auth_available)
	print("  - is_authenticated: %s" % is_authenticated)
	print("  - is_offline_mode: %s" % is_offline)

	# Select appropriate adapter based on authentication status
	if auth_available and is_authenticated and not is_offline:
		if server_storage.is_available():
			current_storage = server_storage
			_last_source = "server"
			print("📡 [CHAR] Using server character storage")
		else:
			print("⚠️ [CHAR] Server storage not available, falling back to local storage")
			current_storage = local_storage
			_last_source = "local"
			print("💾 [CHAR] Using local character storage (fallback)")
	else:
		current_storage = local_storage
		_last_source = "local"
		print("💾 [CHAR] Using local character storage (offline/unauthenticated)")

	print("✅ [CHAR] Storage adapter selected: %s (source: %s)" % [current_storage.get_script().get_path() if current_storage else "none", _last_source])

## Load cached character state
func _load_cached_state() -> void:
	var cached_roster = Save.get_value(CACHE_ROSTER_KEY, [])
	if typeof(cached_roster) == TYPE_ARRAY:
		characters.clear()
		for entry in cached_roster:
			if typeof(entry) == TYPE_DICTIONARY:
				characters.append(_ensure_character_defaults(entry.duplicate(true)))
	
	var cached_current = Save.get_value(CACHE_CURRENT_KEY, {})
	if typeof(cached_current) == TYPE_DICTIONARY:
		current_character = _ensure_character_defaults(cached_current.duplicate(true))
		if not current_character.is_empty():
			current_character_changed.emit(current_character)

## Create new character using current storage adapter
func create_character(payload: Dictionary) -> void:
	if not current_storage:
		character_operation_failed.emit("Character storage not available.")
		return
	
	_is_loading = true
	
	if current_storage.get_storage_type() == 0:  # LOCAL
		# Local storage is synchronous
		var result = current_storage.create_character(payload)
		_handle_creation_result(result)
	else:
		# Server storage is asynchronous - result will come via signal
		var result = current_storage.create_character(payload)
		if not result.success and result.error_message != "":
			# Immediate failure (validation, etc.)
			_handle_creation_result(result)

## Handle character creation result (both sync and async)
func _handle_creation_result(result) -> void:
	_is_loading = false
	
	if result.success:
		var normalized_character: Dictionary = _ensure_character_defaults(result.character.duplicate(true))

		# Add character to roster
		characters.append(normalized_character.duplicate(true))
		Save.set_value(CACHE_ROSTER_KEY, characters)
		
		# Set as current character
		set_current_character(normalized_character)
		
		# Emit success signals
		character_created.emit(normalized_character.duplicate(true))
		_emit_roster_updated()
	else:
		# Emit failure signal
		character_operation_failed.emit(result.error_message)

## Delete character by ID
func delete_character(character_id: String) -> void:
	if not current_storage:
		character_operation_failed.emit("Character storage not available.")
		return

	# Find character to delete for verification
	var character_to_delete: Dictionary = {}
	for character in characters:
		if String(character.get("id", "")) == character_id:
			character_to_delete = character.duplicate(true)
			break

	if character_to_delete.is_empty():
		character_operation_failed.emit("Character not found.")
		return

	# Delete from storage
	var success = current_storage.delete_character(character_id)
	if success:
		# Remove from cached roster
		for i in range(characters.size()):
			if String(characters[i].get("id", "")) == character_id:
				characters.remove_at(i)
				break

		# Update cache
		Save.set_value(CACHE_ROSTER_KEY, characters)

		# Clear current character if it was the deleted one
		if String(current_character.get("id", "")) == character_id:
			clear_current_character()

		# Emit success signals
		character_deleted.emit(character_id)
		_emit_roster_updated()

		print("✅ [CHAR] Character deleted: %s (%s)" % [character_to_delete.get("name", ""), character_id])
	else:
		character_operation_failed.emit("Failed to delete character.")

## Refresh character roster from current storage
func refresh_roster() -> void:
	if not current_storage:
		_emit_roster("unavailable", true)
		return
	
	_is_loading = true
	
	if current_storage.get_storage_type() == 0:  # LOCAL
		# Local storage is synchronous
		var roster = current_storage.get_characters()
		characters.clear()
		for entry in roster:
			if typeof(entry) == TYPE_DICTIONARY:
				characters.append(_ensure_character_defaults(entry.duplicate(true)))
		Save.set_value(CACHE_ROSTER_KEY, characters)
		_is_loading = false
		_emit_roster("local", false)
	else:
		# Server storage is asynchronous - will update via signal
		current_storage.get_characters()  # Triggers async load

## Set current character
func set_current_character(character: Dictionary, persist: bool = true) -> void:
	current_character = _ensure_character_defaults(character.duplicate(true))
	Save.set_value(CACHE_CURRENT_KEY, current_character)
	current_character_changed.emit(current_character)
	
	if persist and current_storage and current_storage.get_storage_type() == 0:
		var character_id := String(current_character.get("id", ""))
		if character_id != "":
			current_storage.update_character(character_id, current_character)

## Get current character
func get_current_character() -> Dictionary:
	return current_character.duplicate(true)

## Clear current character
func clear_current_character() -> void:
	current_character = {}
	Save.remove_value(CACHE_CURRENT_KEY)
	current_character_changed.emit(current_character)

## Check if we have characters
func has_characters() -> bool:
	return characters.size() > 0

## Check if loading
func is_loading() -> bool:
	return _is_loading

## Get character roster
func get_roster() -> Array:
	return characters.duplicate(true)

## Get maximum number of characters allowed by current storage
func get_max_characters() -> int:
	return current_storage.get_max_characters() if current_storage else 5

## Switch storage adapter (for testing or environment changes)
func switch_storage_adapter(adapter_type: int) -> void:
	match adapter_type:
		0:  # LOCAL
			current_storage = local_storage
			_last_source = "local"
			print("🔄 Switched to local character storage")
		1:  # SERVER
			if server_storage.is_available():
				current_storage = server_storage
				_last_source = "server"
				print("🔄 Switched to server character storage")
			else:
				print("⚠️ Server storage not available, keeping current adapter")
				return
	
	# Refresh roster with new adapter
	refresh_roster()

## Sync local characters to server (when going online)
func sync_local_to_server() -> void:
	if not server_storage.is_available():
		print("⚠️ Server not available for sync")
		return
	
	var unsynced = local_storage.get_unsynced_characters()
	if unsynced.is_empty():
		print("✅ No characters to sync")
		return
	
	print("🔄 Syncing %d local characters to server..." % unsynced.size())
	
	for character in unsynced:
		# Create payload for server
		var payload = {
			"name": character.name,
			"strength": character.strength,
			"dexterity": character.dexterity,
			"agility": character.agility,
			"endurance": character.endurance,
			"accuracy": character.accuracy
		}
		
		# Note: In a full implementation, we'd queue these and handle responses
		# For now, just trigger creation - server will handle uniqueness
		server_storage.create_character(payload)

## Import server characters to local storage
func import_server_to_local() -> void:
	if not server_storage.is_available():
		print("⚠️ Server not available for import")
		return
	
	# Get server characters (this will trigger async load)
	var server_chars = server_storage.get_characters()
	if not server_chars.is_empty():
		local_storage.import_characters(server_chars)

# Signal handlers for async server operations

func _on_server_operation_completed(result) -> void:
	_handle_creation_result(result)

func _on_server_characters_loaded(server_characters: Array) -> void:
	characters.clear()
	for entry in server_characters:
		if typeof(entry) == TYPE_DICTIONARY:
			characters.append(_ensure_character_defaults(entry.duplicate(true)))
	Save.set_value(CACHE_ROSTER_KEY, characters)
	_is_loading = false
	_emit_roster("server", false)

# Private helper methods

func _emit_roster_updated() -> void:
	var info = {
		"source": _last_source,
		"from_cache": false,
		"max_characters": get_max_characters(),
		"offline": current_storage.get_storage_type() == 0,  # LOCAL
		"loading": _is_loading,
		"storage_type": ["local", "server", "hybrid"][current_storage.get_storage_type()] if current_storage else "unknown"
	}
	roster_updated.emit(characters.duplicate(true), info)

func _emit_roster(source: String, from_cache: bool) -> void:
	var info = {
		"source": source,
		"from_cache": from_cache,
		"max_characters": get_max_characters(),
		"offline": current_storage.get_storage_type() == 0,  # LOCAL
		"loading": _is_loading,
		"storage_type": ["local", "server", "hybrid"][current_storage.get_storage_type()] if current_storage else "unknown"
	}
	roster_updated.emit(characters.duplicate(true), info)

# Development and testing utilities

## Get current storage type
func get_current_storage_type() -> int:
	return current_storage.get_storage_type() if current_storage else 0  # LOCAL

## Check if current storage is available
func is_storage_available() -> bool:
	return current_storage.is_available() if current_storage else false

## Get storage adapter for testing
func get_storage_adapter():
	return current_storage

## Force environment re-detection (for testing)
func refresh_storage_selection() -> void:
	_select_storage_adapter()
	refresh_roster()

func _ensure_character_defaults(character: Dictionary) -> Dictionary:
	if character.is_empty():
		return character

	if not character.has("max_health"):
		character["max_health"] = float(character.get("health", 100.0))
	if not character.has("current_health"):
		character["current_health"] = float(character.get("health", character.get("max_health", 100.0)))
	character["health"] = float(character.get("current_health", character.get("max_health", 100.0)))

	if not character.has("nourishment_level"):
		character["nourishment_level"] = 100.0
	if not character.has("sleep_level"):
		character["sleep_level"] = 100.0
	if not character.has("available_stat_points"):
		character["available_stat_points"] = 0
	if not character.has("experience"):
		character["experience"] = 0
	if not character.has("inventory_capacity_slots"):
		character["inventory_capacity_slots"] = 12
	if not character.has("inventory_carry_weight_max"):
		character["inventory_carry_weight_max"] = 25.0

	var profs: Dictionary = {}
	if character.has("weapon_proficiencies") and typeof(character["weapon_proficiencies"]) == TYPE_DICTIONARY:
		profs = character["weapon_proficiencies"]
	else:
		profs = {}
	for key in _WEAPON_PROFICIENCY_KEYS:
		profs[key] = int(profs.get(key, 0))
	character["weapon_proficiencies"] = profs

	var equipment: Dictionary = {}
	if character.has("equipment") and typeof(character["equipment"]) == TYPE_DICTIONARY:
		equipment = character["equipment"]
	else:
		equipment = {}
	for slot in _EQUIPMENT_SLOTS:
		var slot_value = equipment.get(slot, null)
		if typeof(slot_value) == TYPE_DICTIONARY:
			equipment[slot] = slot_value.duplicate(true)
		else:
			equipment[slot] = slot_value
	character["equipment"] = equipment

	var equipment_modifiers: Dictionary = {}
	if character.has("equipment_modifiers") and typeof(character["equipment_modifiers"]) == TYPE_DICTIONARY:
		equipment_modifiers = character["equipment_modifiers"]
	else:
		equipment_modifiers = {}
	if not equipment_modifiers.has("stat_mods") or typeof(equipment_modifiers["stat_mods"]) != TYPE_DICTIONARY:
		equipment_modifiers["stat_mods"] = {}
	equipment_modifiers["damage_bonus"] = float(equipment_modifiers.get("damage_bonus", 0.0))
	equipment_modifiers["defense_bonus"] = float(equipment_modifiers.get("defense_bonus", 0.0))
	equipment_modifiers["damage_reduction"] = float(equipment_modifiers.get("damage_reduction", 0.0))
	equipment_modifiers["speed_multiplier"] = float(equipment_modifiers.get("speed_multiplier", 1.0))
	equipment_modifiers["magazine_size"] = int(equipment_modifiers.get("magazine_size", 0))
	equipment_modifiers["reserve_ammo"] = int(equipment_modifiers.get("reserve_ammo", 0))
	equipment_modifiers["capacity_bonus_slots"] = int(equipment_modifiers.get("capacity_bonus_slots", 0))
	equipment_modifiers["carry_weight_bonus"] = float(equipment_modifiers.get("carry_weight_bonus", 0.0))
	equipment_modifiers["reload_speed_bonus"] = float(equipment_modifiers.get("reload_speed_bonus", 0.0))
	if equipment_modifiers.has("weapon_item") and typeof(equipment_modifiers["weapon_item"]) == TYPE_DICTIONARY:
		equipment_modifiers["weapon_item"] = equipment_modifiers["weapon_item"].duplicate(true)
	if equipment_modifiers.has("weapon_params") and typeof(equipment_modifiers["weapon_params"]) == TYPE_DICTIONARY:
		equipment_modifiers["weapon_params"] = equipment_modifiers["weapon_params"].duplicate(true)
	else:
		equipment_modifiers["weapon_params"] = {}
	character["equipment_modifiers"] = equipment_modifiers

	var inventory_items: Array = []
	if character.has("inventory_items") and typeof(character["inventory_items"]) == TYPE_ARRAY:
		for item in character["inventory_items"]:
			if typeof(item) == TYPE_DICTIONARY:
				inventory_items.append(item.duplicate(true))
			else:
				inventory_items.append(item)
	character["inventory_items"] = inventory_items

	return character
