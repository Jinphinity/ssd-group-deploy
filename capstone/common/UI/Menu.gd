extends CanvasLayer

## Main menu with authentication integration

@onready var root_control: Control = $Root
@onready var background_rect: ColorRect = $Root/Background
@onready var user_label: Label = $Root/VBoxContainer/UserInfo/UserLabel
@onready var login_button: Button = $Root/VBoxContainer/UserInfo/LoginButton
@onready var logout_button: Button = $Root/VBoxContainer/UserInfo/LogoutButton
@onready var status_label: Label = $Root/VBoxContainer/StatusLabel
@onready var options_overlay: ColorRect = $Root/OptionsOverlay
@onready var options_panel: PanelContainer = $Root/OptionsOverlay/OptionsCenter/OptionsPanel
@onready var high_contrast_check: CheckBox = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/HighContrastCheck
@onready var captions_check: CheckBox = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/CaptionsCheck
@onready var font_scale_slider: HSlider = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/FontScaleRow/FontScaleSlider
@onready var font_scale_value: Label = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/FontScaleRow/FontScaleValue
@onready var resolution_option: OptionButton = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/ResolutionRow/ResolutionOption
@onready var binding_hint: Label = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/BindingHint
@onready var close_options_button: Button = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/OptionsButtons/CloseOptionsButton
@onready var reset_bindings_button: Button = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/OptionsButtons/ResetBindingsButton

const BINDABLE_ACTIONS := [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"fire",
	"jump",
	"crouch",
	"aim",
	"reload",
	"sprint",
	"interact",
	"inventory",
]
const DEFAULT_BINDINGS := {
	"move_forward": {"type": "key", "physical": KEY_W},
	"move_back": {"type": "key", "physical": KEY_S},
	"move_left": {"type": "key", "physical": KEY_A},
	"move_right": {"type": "key", "physical": KEY_D},
	"jump": {"type": "key", "physical": KEY_W},
	"crouch": {"type": "key", "physical": KEY_S},
	"fire": {"type": "key", "physical": KEY_SPACE},
	"aim": {"type": "mouse", "button": MOUSE_BUTTON_RIGHT},
	"reload": {"type": "key", "physical": KEY_R},
	"sprint": {"type": "key", "physical": KEY_SHIFT},
	"interact": {"type": "key", "physical": KEY_E},
	"inventory": {"type": "key", "physical": KEY_I},
}

const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const MIN_RESOLUTION := Vector2i(1280, 720)
const RESOLUTION_PRESETS := [
	{"size": Vector2i(1280, 720), "label": "1280 x 720"},
	{"size": Vector2i(1366, 768), "label": "1366 x 768"},
	{"size": Vector2i(1600, 900), "label": "1600 x 900"},
	{"size": Vector2i(1920, 1080), "label": "1920 x 1080"},
	{"size": Vector2i(2560, 1440), "label": "2560 x 1440"},
	{"size": Vector2i(2560, 1600), "label": "2560 x 1600"},
	{"size": Vector2i(3440, 1440), "label": "3440 x 1440"},
	{"size": Vector2i(3840, 2160), "label": "3840 x 2160"},
]

var binding_buttons: Dictionary = {}
var rebinding_action: String = ""
var _resolution_metadata: Dictionary = {}
# Scene references for full scene transitions

var character_select_scene := preload("res://common/UI/CharacterSelect.tscn")
var character_creation_scene := preload("res://common/UI/CharacterCreation.tscn")

# Authentication state caching and debouncing
var _cached_auth_state: Dictionary = {}
var _auth_update_timer: Timer = null
var _pending_auth_update: bool = false

func _ready() -> void:
	print("🎮 [MENU] Menu._ready() called - initializing menu")
	if OS.has_feature("web"):
		call_deferred("_apply_fullscreen_web_layout")

	# Initialize authentication state management
	_initialize_auth_management()

	# Connect to authentication signals
	AuthController.user_logged_in.connect(_on_user_logged_in)
	AuthController.user_logged_out.connect(_on_user_logged_out)

	# Update UI based on current authentication status
	print("🔍 [MENU] Calling initial auth UI update")
	_update_authentication_ui_immediate()

	_show_status("Welcome to Dizzy's Disease", "info")
	_initialize_options_panel()
	Accessibility.setting_changed.connect(_on_accessibility_setting_changed)
	_apply_high_contrast()
	_apply_font_scale(font_scale_slider.value)
	print("🎮 [MENU] Menu initialization complete")

func _apply_fullscreen_web_layout() -> void:
	var root := get_node_or_null("Root")
	if root:
		root.anchor_left = 0.0
		root.anchor_top = 0.0
		root.anchor_right = 1.0
		root.anchor_bottom = 1.0
		root.offset_left = 0.0
		root.offset_top = 0.0
		root.offset_right = 0.0
		root.offset_bottom = 0.0
		root.layout_mode = Control.LAYOUT_FULL_RECT
	var overlay := get_node_or_null("Root/OptionsOverlay")
	if overlay:
		overlay.anchor_left = 0.0
		overlay.anchor_top = 0.0
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.offset_left = 0.0
		overlay.offset_top = 0.0
		overlay.offset_right = 0.0
		overlay.offset_bottom = 0.0
		overlay.layout_mode = Control.LAYOUT_FULL_RECT

func _initialize_auth_management() -> void:
	"""Initialize authentication state management with debouncing"""
	_auth_update_timer = Timer.new()
	_auth_update_timer.wait_time = 0.05  # 50ms debounce
	_auth_update_timer.one_shot = true
	_auth_update_timer.timeout.connect(_process_pending_auth_update)
	add_child(_auth_update_timer)
	
	# Cache initial auth state
	_cached_auth_state = AuthController.get_auth_status()
	print("🔧 [Menu] Authentication management initialized")

func _update_authentication_ui() -> void:
	"""Request a debounced authentication UI update"""
	_pending_auth_update = true
	if _auth_update_timer and not _auth_update_timer.is_stopped():
		_auth_update_timer.stop()
	if _auth_update_timer:
		_auth_update_timer.start()

func _update_authentication_ui_immediate() -> void:
	"""Update UI elements based on authentication status immediately"""
	print("🔄 [MENU] _update_authentication_ui_immediate() called")
	var auth_status = AuthController.get_auth_status()
	print("🔍 [MENU] AuthController.get_auth_status() returned: %s" % auth_status)

	# Check if state actually changed
	if _auth_states_equal(auth_status, _cached_auth_state):
		print("🔄 [Menu] Auth UI update skipped - no state change")
		return

	print("🔄 [Menu] Updating auth UI: %s → %s" % [_cached_auth_state.get("is_authenticated", false), auth_status.is_authenticated])
	print("🔍 [MENU] Previous cached state: %s" % _cached_auth_state)
	print("🔍 [MENU] New auth state: %s" % auth_status)
	_cached_auth_state = auth_status.duplicate(true)

	if auth_status.is_authenticated:
		# User is logged in
		user_label.text = "Welcome, " + auth_status.user_display_name
		login_button.visible = false
		logout_button.visible = true
		print("✅ [Menu] User authenticated")
	elif auth_status.offline_mode:
		# Offline mode
		user_label.text = "Playing offline"
		login_button.visible = true
		logout_button.visible = false
		print("⚠️ [Menu] Offline mode")
	else:
		# Not logged in
		user_label.text = "Not logged in"
		login_button.visible = true
		logout_button.visible = false
		print("⚠️ [Menu] Not logged in")

func _process_pending_auth_update() -> void:
	"""Process pending authentication UI update"""
	if _pending_auth_update:
		_pending_auth_update = false
		_update_authentication_ui_immediate()

func _auth_states_equal(state1: Dictionary, state2: Dictionary) -> bool:
	"""Compare two authentication states for equality"""
	if state1.is_empty() or state2.is_empty():
		return false
	
	return (state1.get("is_authenticated", false) == state2.get("is_authenticated", false) and
			state1.get("offline_mode", false) == state2.get("offline_mode", false) and
			state1.get("user_display_name", "") == state2.get("user_display_name", ""))

func _on_user_logged_in(user_data: Dictionary) -> void:
	"""Handle user login event"""
	_update_authentication_ui()
	_show_status("Welcome back, " + user_data.get("display_name", "Player") + "!", "success")

func _on_user_logged_out() -> void:
	"""Handle user logout event"""
	_update_authentication_ui()
	_show_status("Logged out successfully", "info")

func _on_login_pressed() -> void:
	"""Show login screen"""
	AuthController.show_login_screen()

func _on_logout_pressed() -> void:
	"""Logout current user"""
	AuthController.logout()

func _on_play_pressed() -> void:
	"""Continue existing game"""
	print("🎮 [MENU] Continue Game button pressed - starting validation")

	if not _ensure_character_service():
		print("❌ [MENU] Character service not available")
		return

	print("🔍 [MENU] Calling AuthController.require_authentication()")
	var auth_result = await AuthController.require_authentication()
	print("🔍 [MENU] Auth result: %s" % auth_result)

	if not auth_result:
		print("❌ [MENU] Authentication failed - showing login message")
		_show_status("Please login to select a survivor", "warning")
		return

	print("✅ [MENU] Authentication passed - proceeding with character selection")
	_show_character_select(false)

func _on_new_game_pressed() -> void:
	"""Start new game with character creation"""
	print("🎮 [MENU] New Game button pressed - starting validation")

	if not _ensure_character_service():
		print("❌ [MENU] Character service not available")
		return

	print("🔍 [MENU] Calling AuthController.require_authentication()")
	var auth_result = await AuthController.require_authentication()
	print("🔍 [MENU] Auth result: %s" % auth_result)

	if not auth_result:
		print("❌ [MENU] Authentication failed - showing login message")
		_show_status("Please login to create a survivor", "warning")
		return

	print("✅ [MENU] Authentication passed - proceeding with character creation")
	Save.clear_save_data()
	CharacterService.clear_current_character()
	_show_character_creation()


func _on_options_pressed() -> void:
	"""Open options menu"""
	options_overlay.visible = true
	options_panel.grab_focus()
	rebinding_action = ""
	_update_binding_hint()

func _on_quit_pressed() -> void:
	"""Quit the game"""
	get_tree().quit()

func _ensure_character_service() -> bool:
	if not has_node("/root/CharacterService"):
		_show_status("Character service unavailable. Please restart the game.", "error")
		return false
	return true

func _show_character_creation() -> void:
	"""Show dedicated character creation screen as full scene"""
	print("🎯 [Menu] Transitioning to character creation scene")
	get_tree().change_scene_to_packed(character_creation_scene)

func _show_character_select(new_game_mode: bool) -> void:
	"""Show character selection screen as full scene"""
	print("🎯 [Menu] Transitioning to character selection scene (new_game_mode: %s)" % new_game_mode)
	# Store the mode for the character select scene to pick up
	Save.set_value("character_select_new_game_mode", new_game_mode)
	get_tree().change_scene_to_packed(character_select_scene)

# Character flow handlers no longer needed - using full scene transitions

func _show_status(message: String, type: String) -> void:
	"""Show status message with color coding"""
	var color_code = ""
	match type:
		"success":
			color_code = "[color=green]✅ "
		"error":
			color_code = "[color=red]❌ "
		"info":
			color_code = "[color=lightblue]ℹ️ "
		"warning":
			color_code = "[color=yellow]⚠️ "

	status_label.text = color_code + message + "[/color]"

	# Clear status after 3 seconds
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func():
		if status_label:
			status_label.text = ""
		timer.queue_free()
	)
	add_child(timer)
	timer.start()

func _initialize_options_panel() -> void:
	var grid: GridContainer = $Root/OptionsOverlay/OptionsCenter/OptionsPanel/Margin/VBox/BindingsGrid
	for action in BINDABLE_ACTIONS:
		var button: Button = grid.get_node("Bind_%s" % action) as Button
		binding_buttons[action] = button
	_update_binding_buttons()
	_load_input_bindings()
	var saved_scale := float(Save.get_value("ui_font_scale", 1.0))
	font_scale_slider.value = clamp(saved_scale, 0.8, 1.5)
	_update_font_scale_label(font_scale_slider.value)
	high_contrast_check.button_pressed = Accessibility.high_contrast
	captions_check.button_pressed = Accessibility.show_captions
	_initialize_resolution_options()
	options_overlay.visible = false

func _apply_high_contrast() -> void:
	if Accessibility.high_contrast:
		background_rect.color = Color(0, 0, 0, 1)
		options_panel.add_theme_color_override("panel", Color(0.1, 0.1, 0.1, 1))
	else:
		background_rect.color = Color(0.12, 0.12, 0.16, 1)
		options_panel.add_theme_color_override("panel", Color(0.2, 0.2, 0.25, 1))

func _apply_font_scale(value: float) -> void:
	var ui_scale: float = clamp(value, 0.8, 1.5)
	root_control.scale = Vector2(ui_scale, ui_scale)
	_update_font_scale_label(ui_scale)
	Save.set_value("ui_font_scale", ui_scale)

func _update_font_scale_label(value: float) -> void:
	font_scale_value.text = "%.2fx" % value

func _on_high_contrast_toggled(toggled_on: bool) -> void:
	Accessibility.set_high_contrast(toggled_on)
	_apply_high_contrast()

func _on_captions_toggled(toggled_on: bool) -> void:
	Accessibility.set_show_captions(toggled_on)

func _on_font_scale_value_changed(value: float) -> void:
	_apply_font_scale(value)

func _on_binding_button_pressed(button: Button) -> void:
	var action := button.name.replace("Bind_", "")
	if not BINDABLE_ACTIONS.has(action):
		return
	rebinding_action = action
	for key_action in BINDABLE_ACTIONS:
		binding_buttons[key_action].disabled = key_action != action
	button.text = "Press a key or button"
	options_panel.grab_focus()
	_update_binding_hint()
	set_process_unhandled_input(true)

func _on_reset_bindings_pressed() -> void:
	_apply_default_bindings()
	_update_binding_buttons()
	Save.set_value("ui_input_bindings", _serialize_all_bindings())
	_show_status("Bindings reset to defaults", "info")
	rebinding_action = ""
	set_process_unhandled_input(false)
	_update_binding_hint()

func _initialize_resolution_options() -> void:
	if resolution_option == null:
		return
	if resolution_option.item_selected.is_connected(_on_resolution_option_selected):
		resolution_option.item_selected.disconnect(_on_resolution_option_selected)
	resolution_option.clear()
	_resolution_metadata.clear()

	var window := get_viewport().get_window()
	var window_id: int = 0
	if window:
		window_id = window.get_window_id()
	var screen_id := DisplayServer.window_get_current_screen(window_id)
	if screen_id < 0:
		screen_id = 0
	var screen_size := DisplayServer.screen_get_size(screen_id)
	var target_resolution := _get_saved_resolution()
	target_resolution = _clamp_resolution_to_screen(target_resolution, screen_size)

	var insertion_index := 0
	var selected_index := -1
	for preset in RESOLUTION_PRESETS:
		var size: Vector2i = preset.get("size", DEFAULT_RESOLUTION)
		if size.x > screen_size.x or size.y > screen_size.y:
			continue
		resolution_option.add_item(String(preset.get("label", "%d x %d" % [size.x, size.y])))
		resolution_option.set_item_metadata(insertion_index, size)
		_resolution_metadata[insertion_index] = size
		if size == target_resolution:
			selected_index = insertion_index
		insertion_index += 1

	if selected_index == -1:
		resolution_option.add_item("%d x %d" % [target_resolution.x, target_resolution.y])
		resolution_option.set_item_metadata(insertion_index, target_resolution)
		_resolution_metadata[insertion_index] = target_resolution
		selected_index = insertion_index

	resolution_option.selected = selected_index
	_apply_resolution(target_resolution, false)
	resolution_option.item_selected.connect(_on_resolution_option_selected)

func _on_resolution_option_selected(index: int) -> void:
	if not _resolution_metadata.has(index):
		return
	var size: Vector2i = _resolution_metadata[index]
	_apply_resolution(size, true)

func _apply_resolution(size: Vector2i, persist: bool) -> void:
	# HTML5 builds must keep the viewport stretched to the browser canvas; window sizing is unsupported.
	if OS.has_feature("web"):
		if persist:
			# Record the player preference so a desktop build can respect it later.
			Save.set_value("ui_display_resolution", {"width": size.x, "height": size.y})
			_show_status("Resolution preference saved (browser uses full canvas)", "info")
		return

	var window := get_viewport().get_window()
	var window_id: int = 0
	var min_allowed: Vector2i = Vector2i(min(MIN_RESOLUTION.x, size.x), min(MIN_RESOLUTION.y, size.y))
	if window:
		window.size = size
		window.min_size = min_allowed
		window_id = window.get_window_id()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, window_id)
	DisplayServer.window_set_size(size, window_id)
	if persist:
		Save.set_value("ui_display_resolution", {"width": size.x, "height": size.y})
		_show_status("Resolution set to %d x %d" % [size.x, size.y], "info")

func _get_saved_resolution() -> Vector2i:
	var stored = Save.get_value("ui_display_resolution", null)
	if typeof(stored) == TYPE_DICTIONARY and stored.has("width") and stored.has("height"):
		var width := int(stored["width"])
		var height := int(stored["height"])
		return Vector2i(width, height)
	return DEFAULT_RESOLUTION

func _clamp_resolution_to_screen(size: Vector2i, screen_size: Vector2i) -> Vector2i:
	var clamped: Vector2i = size
	var min_width: int = min(MIN_RESOLUTION.x, screen_size.x)
	var min_height: int = min(MIN_RESOLUTION.y, screen_size.y)
	clamped.x = clampi(clamped.x, min_width, screen_size.x)
	clamped.y = clampi(clamped.y, min_height, screen_size.y)
	return clamped

func _on_close_options_pressed() -> void:
	rebinding_action = ""
	set_process_unhandled_input(false)
	_update_binding_buttons()
	options_overlay.visible = false
	_update_binding_hint()

func _on_accessibility_setting_changed() -> void:
	_apply_high_contrast()

func _unhandled_input(event: InputEvent) -> void:
	if rebinding_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cancel_rebinding()
			return
		_assign_binding(rebinding_action, event)
	elif event is InputEventMouseButton and event.pressed:
		_assign_binding(rebinding_action, event)

func _assign_binding(action: String, event: InputEvent) -> void:
	var clone := event.duplicate()
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, clone)
	Save.set_value("ui_input_bindings", _serialize_all_bindings())
	rebinding_action = ""
	set_process_unhandled_input(false)
	_update_binding_buttons()
	_update_binding_hint()
	_show_status("%s bound" % action.capitalize(), "success")
	for key_action in BINDABLE_ACTIONS:
		binding_buttons[key_action].disabled = false

func _cancel_rebinding() -> void:
	rebinding_action = ""
	set_process_unhandled_input(false)
	_update_binding_buttons()
	_update_binding_hint()
	for key_action in BINDABLE_ACTIONS:
		binding_buttons[key_action].disabled = false

func _update_binding_buttons() -> void:
	for action in BINDABLE_ACTIONS:
		var button: Button = binding_buttons[action]
		button.text = _binding_label(action)
		button.disabled = false

func _binding_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	return _event_to_string(events[0])

func _event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return OS.get_keycode_string(key_event.physical_keycode)
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Mouse Left"
			MOUSE_BUTTON_RIGHT:
				return "Mouse Right"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse Middle"
			_:
				return "Mouse %d" % mouse_event.button_index
	return "Unbound"

func _apply_default_bindings() -> void:
	for action in BINDABLE_ACTIONS:
		var data = DEFAULT_BINDINGS[action]
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _deserialize_binding(data))

func _load_input_bindings() -> void:
	var stored = Save.get_value("ui_input_bindings", null)
	if typeof(stored) != TYPE_DICTIONARY:
		return
	for action in BINDABLE_ACTIONS:
		if stored.has(action):
			var data = stored[action]
			var event = _deserialize_binding(data)
			if event:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)
	_update_binding_buttons()

func _deserialize_binding(data: Dictionary) -> InputEvent:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var type := String(data.get("type", ""))
	if type == "key" and data.has("physical"):
		var key_event := InputEventKey.new()
		var physical := int(data["physical"])
		key_event.physical_keycode = physical
		key_event.keycode = physical
		return key_event
	elif type == "mouse" and data.has("button"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(data["button"])
		return mouse_event
	return null

func _serialize_all_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action in BINDABLE_ACTIONS:
		var events := InputMap.action_get_events(action)
		if events.is_empty():
			continue
		var event: InputEvent = events[0]
		if event is InputEventKey:
			var key_event := event as InputEventKey
			result[action] = {"type": "key", "physical": key_event.physical_keycode}
		elif event is InputEventMouseButton:
			var mouse_event := event as InputEventMouseButton
			result[action] = {"type": "mouse", "button": mouse_event.button_index}
	return result

func _update_binding_hint() -> void:
	if rebinding_action == "":
		binding_hint.text = "Select a control to rebind, then press a key or mouse button. Press Esc to cancel."
	else:
		binding_hint.text = "Rebinding %s... Press a key or mouse button (Esc to cancel)." % rebinding_action.replace("_", " ")

# Character Selection Integration
