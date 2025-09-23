extends CanvasLayer

## Main menu with authentication integration

@onready var user_label: Label = $Root/VBoxContainer/UserInfo/UserLabel
@onready var login_button: Button = $Root/VBoxContainer/UserInfo/LoginButton
@onready var logout_button: Button = $Root/VBoxContainer/UserInfo/LogoutButton
@onready var status_label: Label = $Root/VBoxContainer/StatusLabel
@onready var market_button: Button = $Root/VBoxContainer/GameControls/MarketButton

func _ready() -> void:
	# Connect to authentication signals
	AuthController.user_logged_in.connect(_on_user_logged_in)
	AuthController.user_logged_out.connect(_on_user_logged_out)

	# Update UI based on current authentication status
	_update_authentication_ui()

	_show_status("Welcome to Dizzy's Disease", "info")

func _update_authentication_ui() -> void:
	"""Update UI elements based on authentication status"""
	var auth_status = AuthController.get_auth_status()

	if auth_status.is_authenticated:
		# User is logged in
		user_label.text = "Welcome, " + auth_status.user_display_name
		login_button.visible = false
		logout_button.visible = true
		market_button.disabled = false
	elif auth_status.offline_mode:
		# Offline mode
		user_label.text = "Playing offline"
		login_button.visible = true
		logout_button.visible = false
		market_button.disabled = true
	else:
		# Not logged in
		user_label.text = "Not logged in"
		login_button.visible = true
		logout_button.visible = false
		market_button.disabled = true

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
	get_tree().change_scene_to_file("res://stages/Stage_Outpost.tscn")

func _on_new_game_pressed() -> void:
	"""Start new game"""
	# Clear save data for new game
	Save.clear_save_data()
	get_tree().change_scene_to_file("res://stages/Stage_Outpost.tscn")

func _on_market_pressed() -> void:
	"""Open market - requires authentication"""
	if AuthController.require_authentication():
		# User is authenticated, open market
		_show_status("Opening market...", "info")
		# For now, just show a message - in full game this would open market scene
		await get_tree().create_timer(1.0).timeout
		_show_status("Market feature coming soon!", "info")
	else:
		_show_status("Please login to access the market", "warning")

func _on_options_pressed() -> void:
	"""Open options menu"""
	_show_status("Options menu coming soon!", "info")

func _on_quit_pressed() -> void:
	"""Quit the game"""
	get_tree().quit()

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