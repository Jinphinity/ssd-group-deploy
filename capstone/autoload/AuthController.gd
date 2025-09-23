extends Node

signal user_logged_in(user_data: Dictionary)
signal user_logged_out()
signal authentication_required()

var current_user: Dictionary = {}
var is_authenticated: bool = false
var login_screen_scene: PackedScene = preload("res://common/UI/LoginScreen.tscn")
var _login_screen: CanvasLayer = null

func _ready() -> void:
    _check_existing_session()

func _check_existing_session() -> void:
    if not Save.has_value("jwt_token"):
        return

    var token := String(Save.get_value("jwt_token", ""))
    if token == "":
        return

    Api.set_jwt(token)
    current_user = {
        "email": Save.get_value("user_email", ""),
        "display_name": Save.get_value("user_display_name", ""),
        "is_logged_in": true
    }
    is_authenticated = true
    print("[Auth] Restored user session:", current_user.get("email", "unknown"))
    user_logged_in.emit(current_user)

func show_login_screen() -> CanvasLayer:
    if _login_screen and _login_screen.is_inside_tree():
        return _login_screen

    var login_screen := login_screen_scene.instantiate()
    _login_screen = login_screen
    get_tree().root.add_child(login_screen)

    login_screen.login_successful.connect(_on_login_successful)
    login_screen.login_skipped.connect(_on_login_skipped)

    return login_screen

func _on_login_successful(user_data: Dictionary) -> void:
    current_user = user_data.duplicate(true)
    current_user["is_logged_in"] = true
    is_authenticated = true

    print("[Auth] User logged in:", current_user.get("email", "unknown"))
    user_logged_in.emit(current_user)

    _cleanup_login_screen()
    _start_main_game()

func _on_login_skipped() -> void:
    current_user = {"is_logged_in": false, "offline_mode": true}
    is_authenticated = false

    print("[Auth] Playing in offline mode")

    _cleanup_login_screen()
    _start_main_game()

func logout() -> void:
    Api.set_jwt("")
    Save.remove_value("jwt_token")
    Save.remove_value("user_email")
    Save.remove_value("user_display_name")
    Save.save_data()

    current_user = {}
    is_authenticated = false

    print("[Auth] User logged out")
    user_logged_out.emit()

func require_authentication() -> bool:
    if is_authenticated:
        return true

    authentication_required.emit()
    show_login_screen()
    return false

func get_user_display_name() -> String:
    return is_authenticated ? String(current_user.get("display_name", "Player")) : "Guest"

func get_user_email() -> String:
    return is_authenticated ? String(current_user.get("email", "")) : ""

func is_offline_mode() -> bool:
    return bool(current_user.get("offline_mode", false))

func _cleanup_login_screen() -> void:
    if _login_screen and _login_screen.is_inside_tree():
        _login_screen.queue_free()
    _login_screen = null

func _start_main_game() -> void:
    var current_scene = get_tree().current_scene
    if current_scene and current_scene.scene_file_path.ends_with("Stage_Outpost.tscn"):
        print("[Auth] Already in main game scene")
        return

    get_tree().change_scene_to_file("res://stages/Stage_Outpost.tscn")

func get_auth_status() -> Dictionary:
    return {
        "is_authenticated": is_authenticated,
        "user": current_user,
        "offline_mode": is_offline_mode(),
        "has_jwt": Api.jwt != "",
        "user_display_name": get_user_display_name(),
        "user_email": get_user_email()
    }
