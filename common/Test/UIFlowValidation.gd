extends RefCounted
class_name UIFlowValidation

## UI Flow Validation Test Script
## Tests the fixed authentication and character flow issues

static func run_validation() -> Dictionary:
    var results = {
        "authentication_state": test_authentication_state(),
        "menu_button_states": test_menu_button_states(),
        "character_flows": test_character_flows(),
        "scene_transitions": test_scene_transitions(),
        "overall_status": "pending"
    }
    
    var all_passed = true
    for test_name in results:
        if test_name != "overall_status" and not results[test_name].get("passed", false):
            all_passed = false
            break
    
    results["overall_status"] = "PASSED" if all_passed else "FAILED"
    return results

static func test_authentication_state() -> Dictionary:
    print("🔍 Testing Authentication State Management...")
    var test = {"name": "Authentication State", "passed": true, "issues": []}
    
    # Check if AuthController has state management
    if not AuthController.has_method("_validate_auth_consistency"):
        test.passed = false
        test.issues.append("Missing authentication consistency validation")
    
    if not AuthController.has_method("_process_state_change"):
        test.passed = false
        test.issues.append("Missing state change debouncing")
    
    # Check auth status structure
    var auth_status = AuthController.get_auth_status()
    if not auth_status.has("state_stable"):
        test.passed = false
        test.issues.append("Auth status missing state stability indicator")
    
    print("✅ Authentication state test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_menu_button_states() -> Dictionary:
    print("🔍 Testing Menu Button State Management...")
    var test = {"name": "Menu Button States", "passed": true, "issues": []}
    
    # Would test Menu scene but can't instantiate in validation script
    # Check if Menu.gd has the necessary caching functions
    var menu_script = load("res://common/UI/Menu.gd")
    if menu_script:
        var menu_instance = menu_script.new()
        if not menu_instance.has_method("_auth_states_equal"):
            test.passed = false
            test.issues.append("Missing authentication state comparison method")
        
        if not menu_instance.has_method("_process_pending_auth_update"):
            test.passed = false
            test.issues.append("Missing auth update debouncing method")
        
        menu_instance.queue_free()
    
    print("✅ Menu button states test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_character_flows() -> Dictionary:
    print("🔍 Testing Character Flow Separation...")
    var test = {"name": "Character Flows", "passed": true, "issues": []}
    
    # Check if CharacterCreation scene exists
    if not FileAccess.file_exists("res://common/UI/CharacterCreation.tscn"):
        test.passed = false
        test.issues.append("CharacterCreation.tscn does not exist")
    
    # Check if CharacterSelect has create_new_requested signal
    var select_script = load("res://common/UI/CharacterSelect.gd")
    if select_script:
        var select_instance = select_script.new()
        if not select_instance.has_signal("create_new_requested"):
            test.passed = false
            test.issues.append("CharacterSelect missing create_new_requested signal")
        select_instance.queue_free()
    
    # Check if Menu has character creation scene reference
    var menu_script = load("res://common/UI/Menu.gd")
    if menu_script:
        var menu_instance = menu_script.new()
        if not menu_instance.has_method("_show_character_creation"):
            test.passed = false
            test.issues.append("Menu missing character creation method")
        
        if not menu_instance.has_method("_on_create_new_requested"):
            test.passed = false
            test.issues.append("Menu missing create new handler")
        
        menu_instance.queue_free()
    
    print("✅ Character flows test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_scene_transitions() -> Dictionary:
    print("🔍 Testing Scene Transition Management...")
    var test = {"name": "Scene Transitions", "passed": true, "issues": []}
    
    # Check if AuthController has improved scene management
    if not AuthController.has_method("show_login_screen"):
        test.passed = false
        test.issues.append("Missing login screen management")
    
    # This would require runtime testing to fully validate
    # For now, just check that the methods exist
    
    print("✅ Scene transitions test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func print_validation_results(results: Dictionary) -> void:
    print("\n" + "=".repeat(50))
    print("UI FLOW VALIDATION RESULTS")
    print("=".repeat(50))
    
    for test_name in results:
        if test_name == "overall_status":
            continue
            
        var test = results[test_name]
        var status = "✅ PASSED" if test.passed else "❌ FAILED"
        print("%s: %s" % [test.name, status])
        
        if not test.passed:
            for issue in test.issues:
                print("  - %s" % issue)
    
    print("\nOVERALL STATUS: %s" % results.overall_status)
    print("=".repeat(50))

## Usage: UIFlowValidation.run_validation() or from debug console
static func validate_ui_flows() -> void:
    var results = run_validation()
    print_validation_results(results)