extends Node

## Human-Like Interaction Simulation Framework
## Simulates realistic mouse, keyboard, and form interactions for automated testing

signal interaction_completed(interaction_type: String, success: bool)
signal interaction_failed(interaction_type: String, reason: String)

# Timing configurations for realistic simulation
const CLICK_DURATION := 0.1
const TYPING_SPEED := 0.02  # 50 WPM equivalent
const FORM_FIELD_DELAY := 0.05
const SCENE_TRANSITION_TIMEOUT := 5.0
const BUTTON_SEARCH_TIMEOUT := 2.0

# State tracking
var _current_viewport: Viewport = null
var _interaction_history: Array[Dictionary] = []

func _ready():
    _current_viewport = get_viewport()
    FailureLogger.log_success("HumanSimulator initialized")

## Core Interaction Methods

func simulate_mouse_click(target_node: Node, position: Vector2 = Vector2.ZERO, click_duration: float = CLICK_DURATION) -> bool:
    """Simulate realistic mouse click with proper timing"""
    if not _validate_node_clickable(target_node):
        return false

    var click_position = _calculate_click_position(target_node, position)

    ComponentTracker.mark_component_accessed("Interaction:MouseClick:%s" % target_node.name)

    # Press event
    var press_event = InputEventMouseButton.new()
    press_event.button_index = MOUSE_BUTTON_LEFT
    press_event.pressed = true
    press_event.position = click_position
    press_event.global_position = click_position

    _current_viewport.push_input(press_event)

    # Wait for realistic click duration
    await get_tree().create_timer(click_duration).timeout

    # Release event
    var release_event = InputEventMouseButton.new()
    release_event.button_index = MOUSE_BUTTON_LEFT
    release_event.pressed = false
    release_event.position = click_position
    release_event.global_position = click_position

    _current_viewport.push_input(release_event)

    _record_interaction("mouse_click", {"target": target_node.name, "position": click_position})
    interaction_completed.emit("mouse_click", true)
    return true

func simulate_text_input(target_field: LineEdit, text: String, typing_speed: float = TYPING_SPEED) -> bool:
    """Simulate realistic text input with human-like typing speed"""
    if not _validate_text_field(target_field):
        return false

    # Focus the field first
    target_field.grab_focus()
    await get_tree().create_timer(FORM_FIELD_DELAY).timeout

    # Clear existing text
    target_field.text = ""

    ComponentTracker.mark_component_accessed("Interaction:TextInput:%s" % target_field.name)

    # Type each character with realistic timing
    for i in range(text.length()):
        var char = text[i]

        # Create key press event
        var key_event = InputEventKey.new()
        key_event.unicode = char.unicode_at(0)
        key_event.pressed = true

        _current_viewport.push_input(key_event)

        # Immediately add character to field (more reliable than waiting for event processing)
        target_field.text += char

        # Release event
        key_event.pressed = false
        _current_viewport.push_input(key_event)

        # Wait between characters for realistic typing
        if i < text.length() - 1:  # Don't wait after last character
            await get_tree().create_timer(typing_speed).timeout

    _record_interaction("text_input", {"target": target_field.name, "text": text})
    interaction_completed.emit("text_input", true)
    return true

func simulate_button_press(button_identifier: String, timeout: float = BUTTON_SEARCH_TIMEOUT) -> bool:
    """Find and click a button by name or text with timeout"""
    var button = await _find_button_with_timeout(button_identifier, timeout)

    if not button:
        var error_msg = "Button not found: %s" % button_identifier
        FailureLogger.log_failure("Button interaction failed", {
            "button_identifier": button_identifier,
            "reason": error_msg,
            "timeout": timeout
        })
        interaction_failed.emit("button_press", error_msg)
        return false

    if button.disabled:
        var error_msg = "Button is disabled: %s" % button_identifier
        FailureLogger.log_failure("Button interaction failed", {
            "button_identifier": button_identifier,
            "reason": error_msg
        })
        interaction_failed.emit("button_press", error_msg)
        return false

    ComponentTracker.mark_component_accessed("Button:%s" % button_identifier)
    return await simulate_mouse_click(button)

func simulate_form_fill(form_data: Dictionary, typing_speed: float = TYPING_SPEED) -> bool:
    """Fill multiple form fields in sequence"""
    ComponentTracker.mark_component_accessed("Interaction:FormFill")

    for field_name in form_data:
        var field_node = _find_form_field(field_name)

        if not field_node:
            FailureLogger.log_failure("Form field not found", {
                "field_name": field_name,
                "available_fields": _get_available_form_fields()
            })
            return false

        var success = await simulate_text_input(field_node, form_data[field_name], typing_speed)
        if not success:
            return false

        # Brief pause between fields for realism
        await get_tree().create_timer(FORM_FIELD_DELAY * 2).timeout

    _record_interaction("form_fill", {"fields": form_data.keys()})
    return true

## Scene Transition Validation

func validate_scene_transition(expected_scene: String, timeout: float = SCENE_TRANSITION_TIMEOUT) -> bool:
    """Wait for and validate scene transition"""
    var start_time = Time.get_ticks_msec()

    while (Time.get_ticks_msec() - start_time) < (timeout * 1000):
        var current_scene = get_tree().current_scene

        if current_scene and current_scene.scene_file_path.ends_with(expected_scene):
            ComponentTracker.mark_component_accessed("Scene:%s" % expected_scene)
            FailureLogger.reached_path("scene_transition:%s" % expected_scene)
            _record_interaction("scene_transition", {"expected": expected_scene, "success": true})
            return true

        await get_tree().create_timer(0.1).timeout

    # Timeout occurred
    var current_scene_path = get_tree().current_scene.scene_file_path if get_tree().current_scene else "None"
    FailureLogger.log_failure("Scene transition timeout", {
        "expected_scene": expected_scene,
        "current_scene": current_scene_path,
        "timeout": timeout
    })

    _record_interaction("scene_transition", {"expected": expected_scene, "success": false, "timeout": true})
    return false

## State Validation Methods

func validate_authentication_state(expected_state: String) -> bool:
    """Validate current authentication state matches expected"""
    var auth_status = AuthController.get_auth_status()

    match expected_state:
        "authenticated":
            if not auth_status.is_authenticated:
                FailureLogger.log_failure("Expected authenticated state", {
                    "expected": "authenticated",
                    "actual": "not_authenticated",
                    "auth_status": auth_status
                })
                return false

        "offline":
            if not auth_status.offline_mode:
                FailureLogger.log_failure("Expected offline mode", {
                    "expected": "offline_mode",
                    "actual": "online_mode",
                    "auth_status": auth_status
                })
                return false

        "unauthenticated":
            if auth_status.is_authenticated or auth_status.offline_mode:
                FailureLogger.log_failure("Expected unauthenticated state", {
                    "expected": "unauthenticated",
                    "actual": "authenticated_or_offline",
                    "auth_status": auth_status
                })
                return false

    # Success case - silent in failure-only logging
    ComponentTracker.mark_component_accessed("AuthState:%s" % expected_state)
    return true

func validate_ui_element_state(element_name: String, expected_state: String) -> bool:
    """Validate UI element state (enabled/disabled/visible/hidden)"""
    var element = _find_ui_element(element_name)

    if not element:
        FailureLogger.log_failure("UI element not found for validation", {
            "element_name": element_name
        })
        return false

    var actual_state = _get_element_state(element)

    if actual_state != expected_state:
        FailureLogger.log_failure("UI element state mismatch", {
            "element_name": element_name,
            "expected_state": expected_state,
            "actual_state": actual_state
        })
        return false

    return true

## Helper Methods

func _validate_node_clickable(node: Node) -> bool:
    """Validate node can be clicked"""
    if not node:
        FailureLogger.log_failure("Node is null for click simulation")
        return false

    if not node.is_inside_tree():
        FailureLogger.log_failure("Node not in scene tree", {"node_name": node.name})
        return false

    # For buttons, check if disabled
    if node is Button and node.disabled:
        FailureLogger.log_failure("Button is disabled", {"button_name": node.name})
        return false

    return true

func _validate_text_field(field: LineEdit) -> bool:
    """Validate text field can receive input"""
    if not field:
        FailureLogger.log_failure("Text field is null")
        return false

    if not field.is_inside_tree():
        FailureLogger.log_failure("Text field not in scene tree", {"field_name": field.name})
        return false

    if field.editable == false:
        FailureLogger.log_failure("Text field not editable", {"field_name": field.name})
        return false

    return true

func _calculate_click_position(node: Node, position: Vector2) -> Vector2:
    """Calculate click position - use provided or center of node"""
    if position != Vector2.ZERO:
        return position

    if node.has_method("get_global_rect"):
        var rect = node.get_global_rect()
        return rect.position + rect.size / 2
    elif node.has_method("get_global_position"):
        return node.get_global_position()
    else:
        return Vector2(100, 100)  # Fallback position

func _find_button_with_timeout(identifier: String, timeout: float) -> Button:
    """Find button by name or text with timeout"""
    var start_time = Time.get_ticks_msec()

    while (Time.get_ticks_msec() - start_time) < (timeout * 1000):
        var button = _find_button(identifier)
        if button:
            return button
        await get_tree().create_timer(0.1).timeout

    return null

func _find_button(identifier: String) -> Button:
    """Find button by name or text in current scene"""
    var current_scene = get_tree().current_scene
    if not current_scene:
        return null

    return _search_tree_for_button(current_scene, identifier)

func _search_tree_for_button(node: Node, identifier: String) -> Button:
    """Recursively search for button by name or text"""
    # Check current node
    if node is Button:
        var button = node as Button
        if (button.name.to_lower().contains(identifier.to_lower()) or
            button.text.to_lower().contains(identifier.to_lower())):
            return button

    # Search children
    for child in node.get_children():
        var result = _search_tree_for_button(child, identifier)
        if result:
            return result

    return null

func _find_form_field(field_name: String) -> LineEdit:
    """Find form field by name"""
    var current_scene = get_tree().current_scene
    if not current_scene:
        return null

    return _search_tree_for_form_field(current_scene, field_name)

func _search_tree_for_form_field(node: Node, field_name: String) -> LineEdit:
    """Recursively search for form field by name"""
    if node is LineEdit and node.name.to_lower().contains(field_name.to_lower()):
        return node as LineEdit

    for child in node.get_children():
        var result = _search_tree_for_form_field(child, field_name)
        if result:
            return result

    return null

func _find_ui_element(element_name: String) -> Node:
    """Find any UI element by name"""
    var current_scene = get_tree().current_scene
    if not current_scene:
        return null

    return _search_tree_for_element(current_scene, element_name)

func _search_tree_for_element(node: Node, element_name: String) -> Node:
    """Recursively search for any element by name"""
    if node.name.to_lower().contains(element_name.to_lower()):
        return node

    for child in node.get_children():
        var result = _search_tree_for_element(child, element_name)
        if result:
            return result

    return null

func _get_element_state(element: Node) -> String:
    """Get string representation of element state"""
    if not element.is_inside_tree():
        return "not_in_tree"

    if not element.visible:
        return "hidden"

    if element is Button:
        var button = element as Button
        return "enabled" if not button.disabled else "disabled"
    elif element is LineEdit:
        var line_edit = element as LineEdit
        return "editable" if line_edit.editable else "readonly"
    else:
        return "visible"

func _get_available_form_fields() -> Array[String]:
    """Get list of available form field names for debugging"""
    var fields: Array[String] = []
    var current_scene = get_tree().current_scene
    if current_scene:
        _collect_form_fields(current_scene, fields)
    return fields

func _collect_form_fields(node: Node, fields: Array[String]):
    """Recursively collect form field names"""
    if node is LineEdit:
        fields.append(node.name)

    for child in node.get_children():
        _collect_form_fields(child, fields)

func _record_interaction(interaction_type: String, details: Dictionary):
    """Record interaction for debugging and analysis"""
    _interaction_history.append({
        "type": interaction_type,
        "timestamp": Time.get_time_dict_from_system(),
        "details": details
    })

    # Keep history manageable
    if _interaction_history.size() > 100:
        _interaction_history = _interaction_history.slice(-50)

func get_interaction_history() -> Array[Dictionary]:
    """Get recorded interaction history"""
    return _interaction_history.duplicate()

func reset_interaction_history():
    """Clear interaction history"""
    _interaction_history.clear()