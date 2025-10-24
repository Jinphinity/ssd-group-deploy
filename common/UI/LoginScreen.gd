extends CanvasLayer

## Login/Register screen with full authentication integration

@onready var mode_title: Label = $CenterContainer/LoginPanel/VBoxContainer/ModeTitle
@onready var backend_warning_label: Label = $CenterContainer/LoginPanel/VBoxContainer/BackendWarning
@onready var backend_warning_separator: HSeparator = $CenterContainer/LoginPanel/VBoxContainer/HSeparatorBackend
@onready var email_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/EmailInput
@onready var email_error: Label = $CenterContainer/LoginPanel/VBoxContainer/EmailError
@onready var password_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/PasswordInput
@onready var password_error: Label = $CenterContainer/LoginPanel/VBoxContainer/PasswordError
@onready var display_name_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/DisplayNameInput
@onready var display_name_error: Label = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/DisplayNameError
@onready var confirm_password_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/ConfirmPasswordInput
@onready var confirm_password_error: Label = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/ConfirmPasswordError
@onready var register_panel: VBoxContainer = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel
@onready var status_label: Label = $CenterContainer/LoginPanel/VBoxContainer/StatusLabel
@onready var login_button: Button = $CenterContainer/LoginPanel/VBoxContainer/LoginButton
@onready var register_button: Button = $CenterContainer/LoginPanel/VBoxContainer/RegisterButton
@onready var create_account_button: Button = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/CreateAccountButton
@onready var back_to_login_button: Button = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/BackToLoginButton

var is_register_mode: bool = false
var pending_request: HTTPRequest = null
var backend_available: bool = false

var email_valid: bool = false
var password_valid: bool = false
var display_name_valid: bool = false
var passwords_match: bool = false

const MIN_PASSWORD_LENGTH := 8

signal login_successful(user_data: Dictionary)
signal login_skipped()

func _ready() -> void:
	if AuthController != null:
		if not login_successful.is_connected(AuthController._on_login_successful):
			login_successful.connect(AuthController._on_login_successful)
		if not login_skipped.is_connected(AuthController._on_login_skipped):
			login_skipped.connect(AuthController._on_login_skipped)

	if OS.has_feature("web"):
		_call_deferred("_apply_fullscreen_web_layout")

	if not Accessibility.setting_changed.is_connected(_on_accessibility_changed):
		Accessibility.setting_changed.connect(_on_accessibility_changed)

	_clear_input_errors()

	# Check for web-passed authentication token (HTML5 export)
	if OS.has_feature("web"):
		var web_token = _get_web_auth_token()
		if web_token != "":
			Api.set_jwt(web_token)
			# Store the token for persistence
			Save.set_value("jwt_token", web_token)
			Save.save_data()
			_show_status("Authenticated via web interface", "success")
			await get_tree().create_timer(1.0).timeout
			_complete_login({"email": "web_user", "display_name": "Web User"})
			return
	
	# Check if user has a stored token and validate it
	if Save.has_value("jwt_token"):
		var stored_token = Save.get_value("jwt_token", "")
		if stored_token != "":
			print("🔐 Found stored authentication token, validating...")
			_show_status("Validating saved session...", "info")
			
			# Set token temporarily to test it
			Api.set_jwt(stored_token)
			
			# Try to validate the token by making a test API call
			await _validate_stored_token(stored_token)
			return

	_apply_backend_state()
	_apply_font_scale()
	_apply_accessibility()
	_toggle_register_mode(false)

func _apply_fullscreen_web_layout() -> void:
	var background := get_node_or_null("Background")
	if background:
		background.anchor_left = 0.0
		background.anchor_top = 0.0
		background.anchor_right = 1.0
		background.anchor_bottom = 1.0
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
	var center := get_node_or_null("CenterContainer")
	if center:
		center.anchor_left = 0.0
		center.anchor_top = 0.0
		center.anchor_right = 1.0
		center.anchor_bottom = 1.0
		center.offset_left = 0.0
		center.offset_top = 0.0
		center.offset_right = 0.0
		center.offset_bottom = 0.0

func _on_login_pressed() -> void:
	if _validate_login_input():
		_perform_login()

func _on_register_pressed() -> void:
	_toggle_register_mode(true)

func _on_create_account_pressed() -> void:
	if _validate_register_input():
		_perform_register()

func _on_back_to_login_pressed() -> void:
	_toggle_register_mode(false)

func _on_skip_pressed() -> void:
	_show_status("Playing in offline mode", "info")
	# Emit immediately for responsive UI
	login_skipped.emit()

func _toggle_register_mode(enable: bool) -> void:
	is_register_mode = enable
	register_panel.visible = enable
	_clear_input_errors()

	if enable:
		register_button.text = "Switch to Login"
		mode_title.text = "Create a New Account"
		_show_status("Fill in the additional fields to create your account", "info")
		create_account_button.grab_focus()
	else:
		register_button.text = "Register New Account"
		mode_title.text = "Login to Your Account"
		_show_status("Please login or register to continue", "info")
		email_input.grab_focus()

func _validate_login_input() -> bool:
	_clear_input_errors()

	var email = email_input.text.strip_edges()
	var password = password_input.text

	email_valid = true
	password_valid = true

	var messages: Array[String] = []

	if email.is_empty():
		email_valid = false
		var msg = "Email is required."
		email_error.text = msg
		email_error.visible = true
		messages.append(msg)
	elif not email.contains("@"):
		email_valid = false
		var msg = "Please enter a valid email address."
		email_error.text = msg
		email_error.visible = true
		messages.append(msg)

	if password.is_empty():
		password_valid = false
		var msg = "Password is required."
		password_error.text = msg
		password_error.visible = true
		messages.append(msg)
	elif is_register_mode and password.length() < MIN_PASSWORD_LENGTH:
		password_valid = false
		var msg = "Password must be at least %d characters." % MIN_PASSWORD_LENGTH
		password_error.text = msg
		password_error.visible = true
		messages.append(msg)

	if messages.size() > 0:
		_show_status("\n".join(messages), "error")
		if not email_valid:
			email_input.grab_focus()
		else:
			password_input.grab_focus()
		return false

	return true

func _validate_register_input() -> bool:
	if not _validate_login_input():
		return false

	var display_name = display_name_input.text.strip_edges()
	var confirm_password = confirm_password_input.text
	var password = password_input.text

	display_name_valid = true
	passwords_match = true

	var messages: Array[String] = []

	if display_name.is_empty():
		display_name_valid = false
		var msg = "Display name is required."
		display_name_error.text = msg
		display_name_error.visible = true
		messages.append(msg)
	elif display_name.length() < 2:
		display_name_valid = false
		var msg = "Display name must be at least 2 characters."
		display_name_error.text = msg
		display_name_error.visible = true
		messages.append(msg)

	var complexity_issues = _password_complexity_issues(password)
	if complexity_issues.size() > 0:
		password_valid = false
		password_error.text = complexity_issues[0]
		password_error.visible = true
		messages.append_array(complexity_issues)

	if password != confirm_password:
		passwords_match = false
		var msg = "Passwords do not match."
		confirm_password_error.text = msg
		confirm_password_error.visible = true
		messages.append(msg)

	if messages.size() > 0:
		_show_status("\n".join(messages), "error")
		if not password_valid:
			password_input.grab_focus()
		elif not display_name_valid:
			display_name_input.grab_focus()
		else:
			confirm_password_input.grab_focus()
		return false

	return true

func _password_complexity_issues(password: String) -> Array[String]:
	var issues: Array[String] = []
	if password.is_empty():
		return issues

	var has_upper := false
	var has_lower := false
	var has_digit := false
	var has_symbol := false

	for i in password.length():
		var code = password.unicode_at(i)
		if code >= 65 and code <= 90:
			has_upper = true
		elif code >= 97 and code <= 122:
			has_lower = true
		elif code >= 48 and code <= 57:
			has_digit = true
		else:
			has_symbol = true

	if not has_upper:
		issues.append("Password must contain an uppercase letter.")
	if not has_lower:
		issues.append("Password must contain a lowercase letter.")
	if not has_digit:
		issues.append("Password must contain a number.")
	if not has_symbol:
		issues.append("Password must contain a symbol.")

	return issues

func _extract_error_message(body: PackedByteArray, default_message: String) -> String:
	if body.size() == 0:
		return default_message

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return default_message

	var response = json.data
	if typeof(response) != TYPE_DICTIONARY:
		return default_message

	if response.has("detail"):
		return String(response.detail)

	if response.has("error") and typeof(response.error) == TYPE_DICTIONARY:
		var error_block: Dictionary = response.error
		var message = String(error_block.get("message", default_message))

		if error_block.has("details") and typeof(error_block.details) == TYPE_DICTIONARY:
			var details: Dictionary = error_block.details
			if details.has("validation_errors") and typeof(details.validation_errors) == TYPE_DICTIONARY:
				var validation: Dictionary = details.validation_errors
				var detail_lines: Array[String] = []
				for key in validation.keys():
					var value = validation[key]
					if typeof(value) == TYPE_STRING:
						detail_lines.append("%s: %s" % [String(key).capitalize(), value])
					else:
						detail_lines.append(String(value))
				if detail_lines.size() > 0:
					message += "\n" + "\n".join(detail_lines)

		return message

	return default_message

func _show_status(message: String, type: String) -> void:
	var prefix := ""
	var color := Color.WHITE

	match type:
		"success":
			prefix = "✅ "
			color = Color(0.3, 0.85, 0.3)
		"error":
			prefix = "❌ "
			color = Color(1, 0.3, 0.3)
		"info":
			prefix = "ℹ️ "
			color = Color(0.6, 0.8, 1.0)
		"warning":
			prefix = "⚠️ "
			color = Color(1, 0.8, 0.3)
		_:
			prefix = ""
			color = Color.WHITE

	status_label.modulate = color
	status_label.text = prefix + message
	status_label.visible = true

func _perform_login() -> void:
	_set_buttons_enabled(false)
	_show_status("Logging in...", "info")

	var email = email_input.text.strip_edges()
	var password = password_input.text

	var login_data = {
		"email": email,
		"password": password
	}

	pending_request = Api.post("auth/login", login_data)
	pending_request.request_completed.connect(_on_login_completed)

func _perform_register() -> void:
	_set_buttons_enabled(false)
	_show_status("Creating account...", "info")

	var email = email_input.text.strip_edges()
	var password = password_input.text
	var display_name = display_name_input.text.strip_edges()

	var register_data = {
		"email": email,
		"password": password,
		"display_name": display_name
	}

	pending_request = Api.post("auth/register", register_data)
	pending_request.request_completed.connect(_on_register_completed)

func _on_login_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_buttons_enabled(true)

	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())

		if parse_result == OK:
			var response = json.data
			if response.has("token"):
				var token = response.token
				var user_data = response.get("user", {})

				# Store authentication data
				Api.set_jwt(token)
				Save.set_value("jwt_token", token)
				Save.set_value("user_email", user_data.get("email", ""))
				Save.set_value("user_display_name", user_data.get("display_name", ""))
				Save.save_data()

				_show_status("Login successful! Welcome back.", "success")
				await get_tree().create_timer(1.0).timeout
				_complete_login(user_data)
			else:
				_show_status("Login failed: Invalid response from server", "error")
		else:
			_show_status("Login failed: Could not parse server response", "error")
	else:
		var error_message = _extract_error_message(body, "Login failed")
		_show_status(error_message, "error")

	if pending_request:
		pending_request.queue_free()
		pending_request = null

func _on_register_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_buttons_enabled(true)

	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())

		if parse_result == OK:
			var response = json.data
			if response.has("token"):
				var token = response.token
				var user_data = response.get("user", {})

				# Store authentication data
				Api.set_jwt(token)
				Save.set_value("jwt_token", token)
				Save.set_value("user_email", user_data.get("email", ""))
				Save.set_value("user_display_name", user_data.get("display_name", ""))
				Save.save_data()

				_show_status("Account created successfully! Welcome to Dizzy's Disease.", "success")
				await get_tree().create_timer(1.5).timeout
				_complete_login(user_data)
			else:
				_show_status("Registration failed: Invalid response from server", "error")
		else:
			_show_status("Registration failed: Could not parse server response", "error")
	else:
		var error_message = _extract_error_message(body, "Registration failed")
		_show_status(error_message, "error")

	if pending_request:
		pending_request.queue_free()
		pending_request = null

func _complete_login(user_data: Dictionary) -> void:
	login_successful.emit(user_data)
	
	# Process any queued offline requests now that we're authenticated
	Save.process_offline_queue()
	
	# AuthController will handle the scene transition after this signal

## Validate stored authentication token
func _validate_stored_token(token: String) -> void:
	# Make a test API call to validate the token
	var request = HTTPRequest.new()
	add_child(request)
	
	# Connect to the response handler
	request.request_completed.connect(_on_token_validation_response.bind(request, token))
	
	# Set timeout for token validation
	request.timeout = 5.0
	
	# Make a simple API call to validate the token (e.g., get user profile)
	var headers = PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + token])
	var error = request.request("http://localhost:8000/auth/me", headers, HTTPClient.METHOD_GET)
	
	if error != OK:
		print("❌ Failed to make token validation request (error: %d)" % error)
		_handle_server_unavailable()

## Handle response from token validation
func _on_token_validation_response(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, token: String) -> void:
	request.queue_free()
	
	# Check for network/connection errors
	if result != HTTPRequest.RESULT_SUCCESS:
		print("⚠️ Token validation failed due to network error (result: %d)" % result)
		_handle_server_unavailable()
		return
	
	if response_code == 200:
		# Token is valid, proceed with auto-login
		print("✅ Stored token is valid, logging in automatically")
		_show_status("Logged in with saved session", "success")
		await get_tree().create_timer(1.0).timeout
		_complete_login({"email": Save.get_value("user_email", ""), "display_name": Save.get_value("user_display_name", "")})
	elif response_code == 0:
		# Server unavailable/connection failed
		print("⚠️ Server unavailable for token validation")
		_handle_server_unavailable()
	else:
		# Token is invalid or expired
		print("⚠️ Stored token is invalid or expired (HTTP %d)" % response_code)
		_handle_invalid_token()

## Handle invalid or expired token
func _handle_invalid_token() -> void:
	# Clear invalid token
	print("🔄 Clearing invalid authentication data")
	Api.set_jwt("")
	Save.remove_value("jwt_token")
	Save.remove_value("user_email")
	Save.remove_value("user_display_name")
	Save.save_data()
	
	# Show login screen to user
	_show_status("Please login to continue", "info")
	_apply_backend_state()
	_apply_font_scale()
	_apply_accessibility()
	_toggle_register_mode(false)

## Handle server unavailable during token validation
func _handle_server_unavailable() -> void:
	# Don't clear the token since server might be temporarily unavailable
	# But reset the API client to avoid using a potentially invalid token
	Api.set_jwt("")
	
	# Show login screen with server unavailable message
	print("🌐 Server unavailable - showing login options")
	_show_status("Server unavailable. Choose login or play offline.", "warning")
	_apply_backend_state()
	_apply_font_scale()
	_apply_accessibility()
	_toggle_register_mode(false)

func _clear_input_errors() -> void:
	email_error.visible = false
	password_error.visible = false
	display_name_error.visible = false
	confirm_password_error.visible = false

func _apply_backend_state() -> void:
	backend_available = OS.has_environment("BACKEND_AVAILABLE") and OS.get_environment("BACKEND_AVAILABLE") == "1"

	if backend_available:
		backend_warning_label.visible = false
		backend_warning_separator.visible = false
	else:
		backend_warning_label.text = "Registration requires the backend API. Start the server or use Offline mode."
		backend_warning_label.visible = true
		backend_warning_separator.visible = true

func _on_email_text_changed(_new_text: String) -> void:
	email_error.visible = false
	confirm_password_error.visible = false

func _on_password_text_changed(_new_text: String) -> void:
	password_error.visible = false
	confirm_password_error.visible = false

func _on_display_name_text_changed(_new_text: String) -> void:
	display_name_error.visible = false

func _on_confirm_password_text_changed(_new_text: String) -> void:
	confirm_password_error.visible = false

func _apply_font_scale() -> void:
	var font_scale: float = clampf(float(Save.get_value("ui_font_scale", 1.0)), 0.8, 1.5)
	$CenterContainer.scale = Vector2(font_scale, font_scale)

func _apply_accessibility() -> void:
	if Accessibility.high_contrast:
		$Background.color = Color(0, 0, 0, 1)
	else:
		$Background.color = Color(0.1, 0.1, 0.15, 1)

func _on_accessibility_changed() -> void:
	_apply_accessibility()

func _set_buttons_enabled(enabled: bool) -> void:
	login_button.disabled = not enabled
	register_button.disabled = not enabled
	create_account_button.disabled = not enabled
	back_to_login_button.disabled = not enabled

func logout() -> void:
	"""Public method to logout user"""
	Api.set_jwt("")
	Save.remove_value("jwt_token")
	Save.remove_value("user_email")
	Save.remove_value("user_display_name")
	Save.save_data()

	_show_status("Logged out successfully", "success")

	# Reset form
	email_input.text = ""
	password_input.text = ""
	display_name_input.text = ""
	confirm_password_input.text = ""
	_toggle_register_mode(false)

func get_current_user() -> Dictionary:
	"""Get current logged in user data"""
	if Api.jwt != "":
		return {
			"email": Save.get_value("user_email", ""),
			"display_name": Save.get_value("user_display_name", ""),
			"is_logged_in": true
		}
	else:
		return {"is_logged_in": false}

func _get_web_auth_token() -> String:
	"""Get authentication token passed from web interface via JavaScript"""
	if not OS.has_feature("web"):
		return ""
	
	# Use JavaScriptBridge to access the token from the HTML environment
	# This accesses the window.__AUTH_TOKEN__ set by our custom HTML shell
	var js_code = """
	(function() {
		if (typeof window !== 'undefined' && window.__AUTH_TOKEN__) {
			return window.__AUTH_TOKEN__;
		}
		return '';
	})()
	"""
	
	var result = JavaScriptBridge.eval(js_code)
	if result and typeof(result) == TYPE_STRING and result != "":
		print("🔐 Web authentication token received: ", str(result).substr(0, 20), "...")
		return str(result)
	
	return ""
