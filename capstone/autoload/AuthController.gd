extends Node

signal user_logged_in(user_data: Dictionary)
signal user_logged_out()
signal authentication_required()

# Logging configuration
enum LogLevel { ERROR, WARN, INFO, DEBUG }
var current_log_level: LogLevel = LogLevel.WARN

var current_user: Dictionary = {}
var is_authenticated: bool = false
var login_screen_scene: PackedScene = null  # Load dynamically to avoid circular dependency
var _login_screen: CanvasLayer = null

# State management and validation
var _last_auth_state: bool = false
var _state_change_debounce_timer: Timer = null
var _auth_state_lock: bool = false
var _stability_timer: Timer = null
var _is_state_stable: bool = false

func _ready() -> void:
    print("🔧 [AUTH] Enhanced debug mode active - AuthController initializing")
    _initialize_state_management()
    _check_existing_session()
    call_deferred("_capture_initial_login_screen")
    print("🔧 [AUTH] AuthController initialization complete")

func _initialize_state_management() -> void:
    """Initialize authentication state management with debouncing and stability tracking"""
    _state_change_debounce_timer = Timer.new()
    _state_change_debounce_timer.wait_time = 0.1
    _state_change_debounce_timer.one_shot = true
    _state_change_debounce_timer.timeout.connect(_process_state_change)
    add_child(_state_change_debounce_timer)

    _stability_timer = Timer.new()
    _stability_timer.wait_time = 0.5
    _stability_timer.one_shot = true
    _stability_timer.timeout.connect(_mark_state_stable)
    add_child(_stability_timer)

    _last_auth_state = is_authenticated
    _is_state_stable = true  # Start as stable
    print("🔧 [Auth] State management initialized")

func _capture_initial_login_screen() -> void:
    var current_scene := get_tree().current_scene
    if current_scene == null:
        return
    if current_scene.scene_file_path.ends_with("LoginScreen.tscn"):
        if current_scene is CanvasLayer:
            _attach_login_screen(current_scene)

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
    
    # Process any queued offline requests now that we have auth
    Save.process_offline_queue()
    
    user_logged_in.emit(current_user)

func show_login_screen() -> CanvasLayer:
    """Show login screen with proper cleanup and validation"""
    
    # If we already have a login screen active, return it
    if _login_screen and _login_screen.is_inside_tree():
        print("🔄 [Auth] Login screen already active")
        return _login_screen

    # Clean up any orphaned login screen
    if _login_screen:
        print("🧹 [Auth] Cleaning up orphaned login screen")
        _login_screen.queue_free()
        _login_screen = null

    print("🎯 [Auth] Creating new login screen")
    # Load scene dynamically to avoid circular dependency
    if login_screen_scene == null:
        login_screen_scene = load("res://common/UI/LoginScreen.tscn")
    var login_screen := login_screen_scene.instantiate()
    _attach_login_screen(login_screen)
    get_tree().root.add_child(login_screen)
    return login_screen

func _attach_login_screen(login_screen: CanvasLayer) -> void:
    if _login_screen and _login_screen != login_screen and _login_screen.is_inside_tree():
        _login_screen.queue_free()
    _login_screen = login_screen
    if not login_screen.login_successful.is_connected(_on_login_successful):
        login_screen.login_successful.connect(_on_login_successful)
    if not login_screen.login_skipped.is_connected(_on_login_skipped):
        login_screen.login_skipped.connect(_on_login_skipped)

func _on_login_successful(user_data: Dictionary) -> void:
    if _auth_state_lock:
        print("⚠️ [Auth] Login successful blocked - state lock active")
        return
    
    if is_authenticated and current_user.get("email", "") == user_data.get("email", ""):
        print("⚠️ [Auth] Duplicate login successful signal ignored")
        return
    
    _auth_state_lock = true
    current_user = user_data.duplicate(true)
    current_user["is_logged_in"] = true
    
    _set_authentication_state(true, "login_successful")
    
    print("✅ [Auth] User logged in:", current_user.get("email", "unknown"))
    _request_state_change()
    
    _cleanup_login_screen()
    call_deferred("_start_main_game")
    
    await get_tree().create_timer(0.5).timeout
    _auth_state_lock = false

func _on_login_skipped() -> void:
    print("📡 [AUTH] _on_login_skipped() called - processing offline mode")

    if _auth_state_lock:
        print("⚠️ [Auth] Login skipped blocked - state lock active")
        return

    if current_user.get("offline_mode", false):
        print("⚠️ [Auth] Duplicate login skipped signal ignored")
        return

    print("🔧 [AUTH] Setting offline mode - before: is_authenticated=%s, current_user=%s" % [is_authenticated, current_user])

    _auth_state_lock = true
    current_user = {"is_logged_in": false, "offline_mode": true}

    _set_authentication_state(false, "login_skipped")

    print("✅ [AUTH] Offline mode set - after: is_authenticated=%s, current_user=%s" % [is_authenticated, current_user])
    print("📡 [AUTH] Enhanced offline mode validation - is_offline_mode()=%s" % is_offline_mode())

    _request_state_change()

    _cleanup_login_screen()
    call_deferred("_start_main_game")

    await get_tree().create_timer(0.5).timeout
    _auth_state_lock = false
    print("🔓 [AUTH] Auth state lock released after offline mode setup")

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
    """Check authentication with validation and state consistency"""

    auth_log("ℹ️ [AUTH] require_authentication() called - starting validation", LogLevel.INFO)
    auth_log("🔍 [AUTH] Current state: is_authenticated=%s, current_user=%s" % [is_authenticated, current_user], LogLevel.DEBUG)
    auth_log("🔍 [AUTH] Offline mode check: is_offline_mode()=%s" % is_offline_mode(), LogLevel.DEBUG)
    auth_log("🔍 [AUTH] Auth state lock: %s" % _auth_state_lock, LogLevel.DEBUG)

    # POTENTIAL FIX: If state lock is active, wait briefly and retry
    if _auth_state_lock:
        auth_log("ℹ️ [AUTH] State lock active - waiting for completion", LogLevel.INFO)
        await get_tree().create_timer(0.1).timeout
        if _auth_state_lock:
            auth_log("ℹ️ [AUTH] State lock still active after wait - proceeding anyway", LogLevel.INFO)

    # Validate current state consistency
    var consistency_check = _validate_auth_consistency()
    print("🔍 [AUTH] State consistency validation: %s" % consistency_check)

    if not consistency_check:
        auth_log("⚠️ [Auth] Inconsistent state detected, clearing and requesting fresh auth", LogLevel.WARN)
        logout()
        authentication_required.emit()
        show_login_screen()
        return false

    if is_authenticated:
        print("✅ [Auth] Authentication valid - returning true")
        return true

    var offline_mode_result = is_offline_mode()
    print("🔍 [AUTH] Offline mode detailed check: is_offline_mode()=%s" % offline_mode_result)

    # POTENTIAL FIX: Additional offline mode validation
    if offline_mode_result:
        print("✅ [AUTH] Offline mode confirmed active: %s - returning true" % offline_mode_result)
        return true

    # POTENTIAL FIX: Check if we should be in offline mode based on current_user
    if current_user.has("offline_mode") and current_user.get("offline_mode", false):
        print("🔧 [AUTH] FIXING: Found offline_mode=true in current_user but is_offline_mode() returned false")
        print("✅ [AUTH] Corrected offline mode detection - returning true")
        return true

    print("⚠️ [Auth] Authentication required - returning false")
    print("🔍 [AUTH] Failed because: is_authenticated=%s, is_offline_mode()=%s" % [is_authenticated, offline_mode_result])
    authentication_required.emit()

    # Don't show login screen if we already have one active
    if not (_login_screen and _login_screen.is_inside_tree()):
        show_login_screen()

    return false

func get_user_display_name() -> String:
    return String(current_user.get("display_name", "Player")) if is_authenticated else "Guest"

func get_user_email() -> String:
    return String(current_user.get("email", "")) if is_authenticated else ""

func is_offline_mode() -> bool:
    var offline_value = current_user.get("offline_mode", false)
    var result = bool(offline_value)
    print("🔍 [AUTH] is_offline_mode() detail: current_user=%s, offline_value=%s, result=%s" % [current_user, offline_value, result])
    return result

func _cleanup_login_screen() -> void:
    if _login_screen and _login_screen.is_inside_tree():
        # CRITICAL FIX: Disable input blocking BEFORE queuing deletion
        # LoginScreen is a CanvasLayer that blocks input to nodes below it.
        # queue_free() doesn't execute immediately in WebGL, so the LoginScreen
        # can persist as a "zombie node" for 1-2 frames and block Menu button clicks.
        # By disabling visibility and input processing, we ensure buttons work even
        # if the LoginScreen CanvasLayer hasn't been fully deleted yet.
        _login_screen.visible = false
        _login_screen.set_process_input(false)
        _login_screen.set_process_unhandled_input(false)

        # Now safe to remove and queue for deletion
        _login_screen.get_parent().remove_child(_login_screen)
        _login_screen.queue_free()
    _login_screen = null

func _start_main_game() -> void:
    """Transition to main game interface with proper scene validation"""
    var current_scene = get_tree().current_scene
    if not current_scene:
        # Wait one frame and try again before forcing menu scene
        await get_tree().process_frame
        current_scene = get_tree().current_scene
        if not current_scene:
            print("🔄 [Auth] Scene not ready after frame, deferring to menu scene")
            get_tree().change_scene_to_file("res://common/UI/Menu.tscn")
            return
        else:
            print("✅ [Auth] Scene detected after frame wait")
    else:
        print("✅ [Auth] Scene detected immediately")
    
    var current_path = current_scene.scene_file_path
    print("🔄 [Auth] Current scene: %s" % current_path)
    
    # Don't change scene if already in appropriate main game interface
    if (current_path.ends_with("Menu.tscn") or 
        current_path.ends_with("Stage_Outpost_2D.tscn") or 
        current_path.ends_with("CharacterSelect.tscn") or
        current_path.ends_with("CharacterCreation.tscn")):
        print("✅ [Auth] Already in main game interface, no scene change needed")
        return

    # Only change to menu if we're coming from login screen
    if current_path.ends_with("LoginScreen.tscn"):
        print("🎯 [Auth] Transitioning from login to menu")
        get_tree().change_scene_to_file("res://common/UI/Menu.tscn")
    else:
        print("✅ [Auth] Scene change not needed from: %s" % current_path)

func get_auth_status() -> Dictionary:
    var status = {
        "is_authenticated": is_authenticated,
        "user": current_user,
        "offline_mode": is_offline_mode(),
        "has_jwt": Api.jwt != "",
        "user_display_name": get_user_display_name(),
        "user_email": get_user_email(),
        "state_stable": _is_state_stable and not _auth_state_lock
    }
    auth_log("🔍 [AUTH] get_auth_status() returning: %s" % status, LogLevel.DEBUG)
    return status

## Logging Helper Functions

func auth_log(message: String, level: LogLevel = LogLevel.DEBUG) -> void:
    """Conditional logging based on current log level"""
    if level <= current_log_level:
        print(message)

func set_log_level(level: LogLevel) -> void:
    """Set the logging level for AuthController"""
    current_log_level = level
    auth_log("🔧 [Auth] Log level set to: %s" % LogLevel.keys()[level], LogLevel.INFO)

## State Management Helper Functions

func _mark_state_unstable() -> void:
    """Mark state as unstable and start stability timer"""
    _is_state_stable = false
    if _stability_timer:
        _stability_timer.stop()
        _stability_timer.start()

func _mark_state_stable() -> void:
    """Mark state as stable"""
    _is_state_stable = true
    print("🔒 [Auth] State marked as stable")

func _set_authentication_state(authenticated: bool, reason: String) -> void:
    """Set authentication state with validation and logging"""
    var old_state = is_authenticated
    is_authenticated = authenticated
    print("🔄 [Auth] State change: %s → %s (reason: %s)" % [old_state, authenticated, reason])
    _mark_state_unstable()  # Mark state as unstable during transitions

func _request_state_change() -> void:
    """Request a debounced state change notification"""
    if _state_change_debounce_timer and not _state_change_debounce_timer.is_stopped():
        _state_change_debounce_timer.stop()
    if _state_change_debounce_timer:
        _state_change_debounce_timer.start()

func _process_state_change() -> void:
    """Process authentication state change with duplicate signal prevention"""
    if is_authenticated != _last_auth_state:
        _last_auth_state = is_authenticated
        if is_authenticated:
            print("📡 [Auth] Emitting user_logged_in signal")
            user_logged_in.emit(current_user)
        else:
            print("📡 [Auth] Emitting user_logged_out signal") 
            user_logged_out.emit()
    else:
        print("🔄 [Auth] State change ignored - no actual change detected")

func _validate_auth_consistency() -> bool:
    """Validate authentication state consistency"""
    var jwt_exists = Api.jwt != ""
    var token_stored = Save.has_value("jwt_token") and Save.get_value("jwt_token", "") != ""
    var user_has_data = not current_user.is_empty()
    var offline_mode = current_user.get("offline_mode", false)

    print("🔍 [AUTH] Consistency check details:")
    print("  - is_authenticated: %s" % is_authenticated)
    print("  - jwt_exists: %s (Api.jwt='%s')" % [jwt_exists, Api.jwt])
    print("  - token_stored: %s" % token_stored)
    print("  - user_has_data: %s" % user_has_data)
    print("  - offline_mode: %s" % offline_mode)
    print("  - current_user: %s" % current_user)

    # POTENTIAL FIX: In offline mode, clear any conflicting JWT tokens
    if offline_mode and (jwt_exists or token_stored):
        print("🔧 [AUTH] FIXING: Offline mode detected but JWT tokens exist - clearing them")
        Api.set_jwt("")
        if token_stored:
            Save.remove_value("jwt_token")
            Save.save_data()
        print("✅ [AUTH] Cleared conflicting JWT tokens for offline mode")

    if is_authenticated and not (jwt_exists or offline_mode):
        print("⚠️ [Auth] Inconsistent state: authenticated but no JWT and not offline")
        return false

    if not is_authenticated and jwt_exists and not offline_mode:
        print("⚠️ [Auth] Inconsistent state: not authenticated but JWT exists")
        # POTENTIAL FIX: Clear the JWT if we're not authenticated and not offline
        print("🔧 [AUTH] FIXING: Clearing JWT token because not authenticated and not offline")
        Api.set_jwt("")
        print("✅ [AUTH] Cleared conflicting JWT token")

    print("✅ [AUTH] State consistency validated - all checks passed")
    return true
