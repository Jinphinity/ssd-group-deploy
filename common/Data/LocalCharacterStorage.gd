extends "res://common/Data/CharacterStorageAdapter.gd"

## Local file-based character storage adapter
## Provides server-compatible validation and persistence for offline development

class_name LocalCharacterStorage

const CHARACTERS_FILE_PATH := "user://characters_local.save"
const MAX_CHARACTERS := 10

var _characters: Array = []
var _loaded: bool = false

func _init():
	_load_characters()
	for character in _characters:
		_apply_missing_fields(character)

## Create a new character with full validation
func create_character(payload: Dictionary) -> CreationResult:
	var result = CreationResult.new()
	
	# Validate character data
	var validation = validate_character(payload)
	if not validation.is_valid:
		result.error_message = "Validation failed: " + ", ".join(validation.errors)
		return result
	
	# Check character limit
	if _characters.size() >= MAX_CHARACTERS:
		result.error_message = "Maximum characters reached (%d)" % MAX_CHARACTERS
		return result
	
	# Check name uniqueness
	var name = String(payload.get("name", "")).strip_edges()
	if not is_name_unique(name):
		result.error_message = "Character name '%s' already exists" % name
		return result
	
	# Create character with local storage type
	var character = create_character_template(payload, StorageType.LOCAL)
	_apply_missing_fields(character)
	
	# Add to local storage
	_characters.append(character.duplicate(true))
	_save_characters()
	
	# Return success result
	result.success = true
	result.character = character.duplicate(true)
	
	print("📦 Created local character: %s (ID: %s)" % [character.name, character.id])
	return result

## Get all locally stored characters
func get_characters() -> Array:
	if not _loaded:
		_load_characters()
	return _characters.duplicate(true)

## Validate character data with comprehensive business rules
func validate_character(payload: Dictionary) -> ValidationResult:
	# Use base validation first
	var result = validate_common_fields(payload)
	
	# Add local-specific validation if needed
	# (Currently using same rules as server for consistency)
	
	return result

## Check if character name is unique in local storage
func is_name_unique(name: String) -> bool:
	var clean_name = name.strip_edges().to_lower()
	for character in _characters:
		if String(character.get("name", "")).to_lower() == clean_name:
			return false
	return true

## Get storage type identifier
func get_storage_type() -> StorageType:
	return StorageType.LOCAL

## Check if local storage is available (always true for file system)
func is_available() -> bool:
	return true

## Get maximum number of characters allowed in local storage
func get_max_characters() -> int:
	return MAX_CHARACTERS

## Get character by ID
func get_character_by_id(id: String) -> Dictionary:
	for character in _characters:
		if String(character.get("id", "")) == id:
			return character.duplicate(true)
	return {}

## Update existing character
func update_character(character_id: String, updates: Dictionary) -> bool:
	for i in range(_characters.size()):
		if String(_characters[i].get("id", "")) == character_id:
			# Apply updates while preserving core fields
			for key in updates:
				if key not in ["id", "created_at", "storage_type"]:
					var value = updates[key]
					match typeof(value):
						TYPE_DICTIONARY:
							_characters[i][key] = value.duplicate(true)
						TYPE_ARRAY:
							var array_copy: Array = []
							for element in value:
								if typeof(element) == TYPE_DICTIONARY:
									array_copy.append(element.duplicate(true))
								else:
									array_copy.append(element)
							_characters[i][key] = array_copy
						_:
							_characters[i][key] = value
			
			_apply_missing_fields(_characters[i])
			
			_save_characters()
			print("📦 Updated local character: %s" % character_id)
			return true
	return false

## Delete character by ID
func delete_character(character_id: String) -> bool:
	for i in range(_characters.size()):
		if String(_characters[i].get("id", "")) == character_id:
			var character = _characters.pop_at(i)
			_save_characters()
			print("📦 Deleted local character: %s (%s)" % [character.get("name", ""), character_id])
			return true
	return false

## Mark character as synced with server
func mark_synced(character_id: String, server_id: String = "") -> bool:
	for character in _characters:
		if String(character.get("id", "")) == character_id:
			character["synced"] = true
			if server_id != "":
				character["server_id"] = server_id
			_save_characters()
			return true
	return false

## Get unsynced characters (for sync operations)
func get_unsynced_characters() -> Array:
	var unsynced: Array = []
	for character in _characters:
		if not character.get("synced", false):
			unsynced.append(character.duplicate(true))
	return unsynced

## Clear all local character data
func clear_all_characters() -> void:
	_characters.clear()
	_save_characters()
	print("📦 Cleared all local characters")

## Import characters from server data
func import_characters(server_characters: Array) -> int:
	var imported_count = 0
	
	for server_char in server_characters:
		if typeof(server_char) != TYPE_DICTIONARY:
			continue
			
		# Check if character already exists locally
		var exists = false
		for local_char in _characters:
			if (local_char.get("server_id") == server_char.get("id") or 
				local_char.get("name") == server_char.get("name")):
				exists = true
				break
		
		if not exists:
			# Convert server character to local format
			var local_char = server_char.duplicate(true)
			local_char["storage_type"] = "local"
			local_char["synced"] = true
			local_char["server_id"] = server_char.get("id", "")
			
			_characters.append(local_char)
			imported_count += 1
	
	if imported_count > 0:
		_save_characters()
		print("📦 Imported %d characters from server" % imported_count)
	
	return imported_count

# Private methods for file operations

func _load_characters() -> void:
	if FileAccess.file_exists(CHARACTERS_FILE_PATH):
		var file = FileAccess.open(CHARACTERS_FILE_PATH, FileAccess.READ)
		if file:
			var data = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(data) == OK:
				var parsed_data = json.data
				if typeof(parsed_data) == TYPE_ARRAY:
					_characters = parsed_data
					for character in _characters:
						_apply_missing_fields(character)
					print("📦 Loaded %d local characters" % _characters.size())
				else:
					print("⚠️ Invalid character data format, starting with empty roster")
					_characters = []
			else:
				print("⚠️ Failed to parse character data, starting with empty roster")
				_characters = []
		else:
			print("⚠️ Failed to open character file, starting with empty roster")
			_characters = []
	else:
		print("📦 No local character file found, starting with empty roster")
		_characters = []
	
	_loaded = true

func _save_characters() -> void:
	var file = FileAccess.open(CHARACTERS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(_characters)
		file.store_string(json_string)
		file.close()
		print("💾 Saved %d local characters" % _characters.size())
	else:
		print("❌ Failed to save character data")

func _apply_missing_fields(character: Dictionary) -> void:
	if character.is_empty():
		return
	if not character.has("max_health"):
		character["max_health"] = 100.0
	if not character.has("current_health"):
		character["current_health"] = character.get("health", 100.0)
	character["health"] = character["current_health"]
	if not character.has("nourishment_level"):
		character["nourishment_level"] = 100.0
	if not character.has("sleep_level"):
		character["sleep_level"] = 100.0
	if not character.has("available_stat_points"):
		character["available_stat_points"] = 0

	if not character.has("weapon_proficiencies") or typeof(character["weapon_proficiencies"]) != TYPE_DICTIONARY:
		character["weapon_proficiencies"] = {
			"melee_knives": 0,
			"melee_axes_clubs": 0,
			"firearm_handguns": 0,
			"firearm_rifles": 0,
			"firearm_shotguns": 0,
			"firearm_automatics": 0
		}
	else:
		var profs: Dictionary = character["weapon_proficiencies"]
		var defaults = ["melee_knives", "melee_axes_clubs", "firearm_handguns", "firearm_rifles", "firearm_shotguns", "firearm_automatics"]
		for key in defaults:
			if not profs.has(key):
				profs[key] = 0

	if not character.has("equipment") or typeof(character["equipment"]) != TYPE_DICTIONARY:
		character["equipment"] = {
			"weapon": null,
			"head": null,
			"torso": null,
			"legs": null,
			"accessory": null
		}
	else:
		var slots = ["weapon", "head", "torso", "legs", "accessory"]
		for slot in slots:
			if not character["equipment"].has(slot):
				character["equipment"][slot] = null

	if not character.has("equipment_modifiers") or typeof(character["equipment_modifiers"]) != TYPE_DICTIONARY:
		character["equipment_modifiers"] = {
			"stat_mods": {},
			"damage_bonus": 0.0,
			"defense_bonus": 0.0,
			"damage_reduction": 0.0,
			"speed_multiplier": 1.0,
			"magazine_size": 0,
			"reserve_ammo": 0,
			"capacity_bonus_slots": 0,
			"carry_weight_bonus": 0.0,
			"reload_speed_bonus": 0.0,
			"weapon_item": null,
			"weapon_params": {}
		}

	if not character.has("inventory_items") or typeof(character["inventory_items"]) != TYPE_ARRAY:
		character["inventory_items"] = []
	if not character.has("inventory_capacity_slots"):
		character["inventory_capacity_slots"] = 12
	if not character.has("inventory_carry_weight_max"):
		character["inventory_carry_weight_max"] = 25.0
