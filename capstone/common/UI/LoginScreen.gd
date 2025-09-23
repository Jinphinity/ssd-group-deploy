extends CanvasLayer

## Login/Register screen with full authentication integration

@onready var email_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/EmailInput
@onready var password_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/PasswordInput
@onready var display_name_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/DisplayNameInput
@onready var confirm_password_input: LineEdit = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/ConfirmPasswordInput
@onready var register_panel: VBoxContainer = $CenterContainer/LoginPanel/VBoxContainer/RegisterPanel
@onready var status_label: Label = $CenterContainer/LoginPanel/VBoxContainer/StatusLabel
@onready var login_button: Button = $CenterContainer/LoginPanel/VBoxContainer/LoginButton
@onready var register_button: Button = $CenterContainer/LoginPanel/VBoxContainer/RegisterButton

var is_register_mode: bool = false
var pending_request: HTTPRequest = null

signal login_successful(user_data: Dictionary)
signal login_skipped()

func _ready() -> void:
	# Check if user is already logged in
	if Save.has_value("jwt_token"):
		var stored_token = Save.get_value("jwt_token", "")
		if stored_token != "":
			Api.set_jwt(stored_token)
			_show_status("Logged in with saved session", "success")
			await get_tree().create_timer(1.0).timeout
			_complete_login({"email": Save.get_value("user_email", ""), "display_name": Save.get_value("user_display_name", "")})
			return

	_show_status("Please login or register to continue", "info")

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
	await get_tree().create_timer(1.0).timeout
	login_skipped.emit()

func _toggle_register_mode(enable: bool) -> void:
	is_register_mode = enable
	register_panel.visible = enable

	if enable:
		register_button.text = "Switch to Login"
		status_label.text = "Create a new account"
	else:
		register_button.text = "Register New Account"
		status_label.text = "Login to your existing account"

func _validate_login_input() -> bool:
	var email = email_input.text.strip_edges()
	var password = password_input.text

	if email.is_empty():
		_show_status("Please enter your email", "error")
		email_input.grab_focus()
		return false

	if not email.contains("@"):
		_show_status("Please enter a valid email address", "error")
		email_input.grab_focus()
		return false

	if password.length() < 6:
		_show_status("Password must be at least 6 characters", "error")
		password_input.grab_focus()
		return false

	return true

func _validate_register_input() -> bool:
	if not _validate_login_input():
		return false

	var display_name = display_name_input.text.strip_edges()
	var confirm_password = confirm_password_input.text
	var password = password_input.text

	if display_name.is_empty():
		_show_status("Please enter a display name", "error")
		display_name_input.grab_focus()
		return false

	if display_name.length() < 2:
		_show_status("Display name must be at least 2 characters", "error")
		display_name_input.grab_focus()
		return false

	if password != confirm_password:
		_show_status("Passwords do not match", "error")
		confirm_password_input.grab_focus()
		return false

	return true

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
		var error_message = "Login failed"

		# Try to parse error message from response
		if body.size() > 0:
			var json = JSON.new()
			var parse_result = json.parse(body.get_string_from_utf8())
			if parse_result == OK:
				var response = json.data
				error_message = response.get("detail", error_message)

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
		var error_message = "Registration failed"

		# Try to parse error message from response
		if body.size() > 0:
			var json = JSON.new()
			var parse_result = json.parse(body.get_string_from_utf8())
			if parse_result == OK:
				var response = json.data
				error_message = response.get("detail", error_message)

		_show_status(error_message, "error")

	if pending_request:
		pending_request.queue_free()
		pending_request = null

func _complete_login(user_data: Dictionary) -> void:
	login_successful.emit(user_data)

func _show_status(message: String, type: String) -> void:
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

func _set_buttons_enabled(enabled: bool) -> void:
	login_button.disabled = not enabled
	register_button.disabled = not enabled

	if register_panel.visible:
		$CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/CreateAccountButton.disabled = not enabled
		$CenterContainer/LoginPanel/VBoxContainer/RegisterPanel/BackToLoginButton.disabled = not enabled

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