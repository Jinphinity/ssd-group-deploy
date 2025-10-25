extends RefCounted

## Abstract base class for character storage adapters
## Provides unified interface for both local and server-based character storage

class_name CharacterStorageAdapter

enum StorageType {
	LOCAL,
	SERVER, 
	HYBRID
}

const DEFAULT_WEAPON_PROFICIENCIES := {
	"melee_knives": 0,
	"melee_axes_clubs": 0,
	"firearm_handguns": 0,
	"firearm_rifles": 0,
	"firearm_shotguns": 0,
	"firearm_automatics": 0
}

const DEFAULT_EQUIPMENT_SLOTS := {
	"weapon": null,
	"head": null,
	"torso": null,
	"legs": null,
	"accessory": null
}

func _default_equipment_modifiers() -> Dictionary:
	return {
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

# Validation result structure
class ValidationResult:
	var is_valid: bool = false
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	func _init(valid: bool = false):
		is_valid = valid

# Character creation result structure  
class CreationResult:
	var success: bool = false
	var character: Dictionary = {}
	var error_message: String = ""
	
	func _init(success_val: bool = false):
		success = success_val

# Abstract methods - must be implemented by subclasses

## Create a new character with the given payload
## Returns CreationResult with character data or error info
func create_character(payload: Dictionary) -> CreationResult:
	assert(false, "create_character must be implemented by subclass")
	return CreationResult.new()

## Get all characters for the current user
## Returns Array of character dictionaries
func get_characters() -> Array:
	assert(false, "get_characters must be implemented by subclass") 
	return []

## Validate character data according to business rules
## Returns ValidationResult with validation status and errors
func validate_character(payload: Dictionary) -> ValidationResult:
	assert(false, "validate_character must be implemented by subclass")
	return ValidationResult.new()

## Check if character name is unique in storage
## Returns true if name is available, false if taken
func is_name_unique(name: String) -> bool:
	assert(false, "is_name_unique must be implemented by subclass")
	return false

## Get storage type identifier
func get_storage_type() -> StorageType:
	assert(false, "get_storage_type must be implemented by subclass")
	return StorageType.LOCAL

## Check if storage backend is available
func is_available() -> bool:
	assert(false, "is_available must be implemented by subclass")
	return false

## Get maximum number of characters allowed in this storage
func get_max_characters() -> int:
	assert(false, "get_max_characters must be implemented by subclass")
	return 5

## Delete character by ID
## Returns true if character was deleted successfully, false if not found or error
func delete_character(character_id: String) -> bool:
	assert(false, "delete_character must be implemented by subclass")
	return false

# Common utility methods available to all adapters

## Generate unique character ID based on storage type
func generate_character_id(storage_type: StorageType) -> String:
	match storage_type:
		StorageType.LOCAL:
			return "local_%d" % Time.get_unix_time_from_system()
		StorageType.SERVER:
			# Server will assign actual ID, use temp for client
			return "temp_%d" % Time.get_unix_time_from_system()
		StorageType.HYBRID:
			return "hybrid_%d" % Time.get_unix_time_from_system()
		_:
			return "unknown_%d" % Time.get_unix_time_from_system()

## Create standardized character template
func create_character_template(payload: Dictionary, storage_type: StorageType) -> Dictionary:
	return {
		"id": generate_character_id(storage_type),
		"name": String(payload.get("name", "")),
		"strength": int(payload.get("strength", 1)),
		"dexterity": int(payload.get("dexterity", 1)), 
		"agility": int(payload.get("agility", 1)),
		"endurance": int(payload.get("endurance", 1)),
		"accuracy": int(payload.get("accuracy", 1)),
		"level": 1,
		"experience": 0,
		"health": 100.0,
		"available_stat_points": 0,
		"max_health": 100.0,
		"current_health": 100.0,
		"nourishment_level": 100.0,
		"sleep_level": 100.0,
		"weapon_proficiencies": DEFAULT_WEAPON_PROFICIENCIES.duplicate(true),
		"equipment": DEFAULT_EQUIPMENT_SLOTS.duplicate(true),
		"equipment_modifiers": _default_equipment_modifiers(),
		"inventory_items": [],
		"inventory_capacity_slots": 12,
		"inventory_carry_weight_max": 25.0,
		"created_at": Time.get_datetime_string_from_system(),
		"storage_type": StorageType.keys()[storage_type].to_lower(),
		"synced": false
	}

## Validate common character fields
func validate_common_fields(payload: Dictionary) -> ValidationResult:
	var result = ValidationResult.new()
	var errors: Array[String] = []
	
	# Validate name
	var name = String(payload.get("name", "")).strip_edges()
	if name.is_empty():
		errors.append("Character name is required")
	elif name.length() < 2:
		errors.append("Character name must be at least 2 characters")
	elif name.length() > 30:
		errors.append("Character name must be 30 characters or less")
	elif not name.is_valid_identifier():
		errors.append("Character name contains invalid characters")
	
	# Validate stats (1-10 range)
	var stats = ["strength", "dexterity", "agility", "endurance", "accuracy"]
	for stat in stats:
		var value = int(payload.get(stat, 0))
		if value < 1 or value > 10:
			errors.append("%s must be between 1 and 10" % stat.capitalize())
	
	# Calculate total stat points
	var total_points = 0
	for stat in stats:
		total_points += int(payload.get(stat, 1))
	
	if total_points > 25:  # Max 25 total stat points (5 stats * 5 average)
		errors.append("Total stat points cannot exceed 25")
	
	result.errors = errors
	result.is_valid = errors.is_empty()
	return result
