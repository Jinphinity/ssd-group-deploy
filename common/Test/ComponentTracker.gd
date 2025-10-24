extends Node

## Component Access Validation System
## Tracks designed UI components and validates they are actually accessed

# Track designed components and their expected usage
var designed_components: Dictionary = {
	"CharacterCreationScreen": false,
	"CharacterSelectScreen": false,
	"MarketInterface": false,
	"LoginScreen": false,
	"MainMenu": false,
	"GameHUD": false,
	"InventoryUI": false,
	"OptionsMenu": false
}

# Track expected user flows
var expected_flows: Dictionary = {
	"offline_character_creation": false,
	"online_character_creation": false,
	"character_selection": false,
	"market_access": false,
	"login_flow": false,
	"logout_flow": false
}

# Track component transition paths
var transition_paths: Array[String] = []
var current_component: String = ""

func _ready():
	"""Initialize component tracking"""
	FailureLogger.log_success("ComponentTracker initialized")
	_register_expected_flows()

func _register_expected_flows():
	"""Register expected component access patterns"""
	for flow_name in expected_flows.keys():
		FailureLogger.expect_path(flow_name)

## Component Access Tracking

func mark_component_accessed(component_name: String, context: Dictionary = {}):
	"""Mark component as successfully accessed"""
	if component_name in designed_components:
		if not designed_components[component_name]:
			designed_components[component_name] = true
			FailureLogger.component_accessed(component_name)
			_track_transition(component_name)

		# Mark related flow as reached
		_mark_related_flow(component_name)
	else:
		FailureLogger.log_failure("Undefined component accessed", {
			"component": component_name,
			"context": context
		})

func _mark_related_flow(component_name: String):
	"""Mark related user flow as reached based on component"""
	match component_name:
		"CharacterCreationScreen":
			if AuthController and AuthController.is_offline_mode():
				FailureLogger.reached_path("offline_character_creation")
			else:
				FailureLogger.reached_path("online_character_creation")
		"CharacterSelectScreen":
			FailureLogger.reached_path("character_selection")
		"MarketInterface":
			FailureLogger.reached_path("market_access")
		"LoginScreen":
			FailureLogger.reached_path("login_flow")

func _track_transition(component_name: String):
	"""Track component transitions for flow analysis"""
	if current_component != "":
		var transition = "%s -> %s" % [current_component, component_name]
		transition_paths.append(transition)
		FailureLogger.log_success("Component transition: %s" % transition)

	current_component = component_name

## Validation Functions

func validate_component_access():
	"""Check if all designed components were accessed during session"""
	var unaccessed_components: Array[String] = []

	for component in designed_components:
		if not designed_components[component]:
			unaccessed_components.append(component)

	if unaccessed_components.size() > 0:
		FailureLogger.log_failure("Designed components never accessed", {
			"components": unaccessed_components,
			"accessed": _get_accessed_components()
		})
		return false

	return true

func validate_expected_flows():
	"""Check if expected user flows were completed"""
	var incomplete_flows: Array[String] = []

	for flow_name in expected_flows:
		if not expected_flows[flow_name]:
			incomplete_flows.append(flow_name)

	if incomplete_flows.size() > 0:
		FailureLogger.log_failure("Expected flows not completed", {
			"incomplete": incomplete_flows,
			"completed": _get_completed_flows()
		})
		return false

	return true

func validate_critical_path(path_name: String) -> bool:
	"""Validate that a critical user path was accessed"""
	match path_name:
		"character_creation_offline":
			return _validate_offline_character_creation()
		"character_creation_online":
			return _validate_online_character_creation()
		"market_access_authenticated":
			return _validate_authenticated_market_access()
		_:
			FailureLogger.log_failure("Unknown critical path", {"path": path_name})
			return false

func _validate_offline_character_creation() -> bool:
	"""Validate offline character creation path"""
	var required_components = ["LoginScreen", "MainMenu", "CharacterCreationScreen"]
	var missing_components: Array[String] = []

	for component in required_components:
		if not designed_components.get(component, false):
			missing_components.append(component)

	if missing_components.size() > 0:
		FailureLogger.log_failure("Offline character creation path incomplete", {
			"missing_components": missing_components,
			"expected_flow": "LoginScreen -> Skip Online -> MainMenu -> New Game -> CharacterCreationScreen"
		})
		return false

	return true

func _validate_online_character_creation() -> bool:
	"""Validate online character creation path"""
	var required_components = ["LoginScreen", "MainMenu", "CharacterCreationScreen"]
	var missing_components: Array[String] = []

	for component in required_components:
		if not designed_components.get(component, false):
			missing_components.append(component)

	if missing_components.size() > 0:
		FailureLogger.log_failure("Online character creation path incomplete", {
			"missing_components": missing_components,
			"expected_flow": "LoginScreen -> Login -> MainMenu -> New Game -> CharacterCreationScreen"
		})
		return false

	return true

func _validate_authenticated_market_access() -> bool:
	"""Validate authenticated market access path"""
	var required_components = ["MainMenu", "MarketInterface"]
	var missing_components: Array[String] = []

	for component in required_components:
		if not designed_components.get(component, false):
			missing_components.append(component)

	if missing_components.size() > 0:
		FailureLogger.log_failure("Authenticated market access path incomplete", {
			"missing_components": missing_components,
			"expected_flow": "Authentication -> MainMenu -> Market Button -> MarketInterface"
		})
		return false

	return true

## Utility Functions

func _get_accessed_components() -> Array[String]:
	"""Get list of components that were accessed"""
	var accessed: Array[String] = []
	for component in designed_components:
		if designed_components[component]:
			accessed.append(component)
	return accessed

func _get_completed_flows() -> Array[String]:
	"""Get list of flows that were completed"""
	var completed: Array[String] = []
	for flow_name in expected_flows:
		if expected_flows[flow_name]:
			completed.append(flow_name)
	return completed

func get_transition_summary() -> Dictionary:
	"""Get summary of component transitions"""
	return {
		"transitions": transition_paths,
		"current_component": current_component,
		"accessed_components": _get_accessed_components(),
		"completed_flows": _get_completed_flows()
	}

## Reset Functions

func reset_tracking():
	"""Reset all component tracking for new test session"""
	for component in designed_components:
		designed_components[component] = false

	for flow_name in expected_flows:
		expected_flows[flow_name] = false

	transition_paths.clear()
	current_component = ""

	FailureLogger.reset_components()
	FailureLogger.log_success("Component tracking reset")

## Integration with Scene Changes

func _notification(what):
	"""Track scene changes automatically"""
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		var scene = get_tree().current_scene
		if scene:
			_detect_component_from_scene(scene.scene_file_path)

func _detect_component_from_scene(scene_path: String):
	"""Automatically detect component access from scene changes"""
	var scene_name = scene_path.get_file().get_basename()

	match scene_name:
		"CharacterCreation":
			mark_component_accessed("CharacterCreationScreen")
		"CharacterSelect":
			mark_component_accessed("CharacterSelectScreen")
		"MarketUI":
			mark_component_accessed("MarketInterface")
		"LoginScreen":
			mark_component_accessed("LoginScreen")
		"Menu":
			mark_component_accessed("MainMenu")
		"HUD":
			mark_component_accessed("GameHUD")
		"InventoryUI":
			mark_component_accessed("InventoryUI")
