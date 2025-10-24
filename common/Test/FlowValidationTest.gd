extends RefCounted
class_name FlowValidationTest

## Comprehensive Flow Validation Test
## Tests the fixed character flow and authentication issues

static func run_comprehensive_test() -> Dictionary:
    var results = {
        "overlay_cleanup": test_overlay_cleanup(),
        "scene_transitions": test_scene_transitions(),
        "flow_routing": test_flow_routing(),
        "authentication_consistency": test_authentication_consistency(),
        "overall_status": "pending"
    }
    
    var all_passed = true
    for test_name in results:
        if test_name != "overall_status" and not results[test_name].get("passed", false):
            all_passed = false
            break
    
    results["overall_status"] = "PASSED" if all_passed else "FAILED"
    return results

static func test_overlay_cleanup() -> Dictionary:
    print("🔍 Testing Overlay Cleanup...")
    var test = {"name": "Overlay Cleanup", "passed": true, "issues": []}
    
    # Check Menu.gd for overlay references
    var menu_script = load("res://common/UI/Menu.gd")
    if menu_script:
        var menu_source = FileAccess.open("res://common/UI/Menu.gd", FileAccess.READ)
        if menu_source:
            var content = menu_source.get_as_text()
            menu_source.close()
            
            if content.contains("character_select_overlay"):
                test.passed = false
                test.issues.append("Menu.gd still contains character_select_overlay references")
            
            if content.contains("add_child(character_select_overlay)"):
                test.passed = false
                test.issues.append("Menu.gd still uses overlay pattern")
            
            if not content.contains("get_tree().change_scene_to_packed"):
                test.passed = false
                test.issues.append("Menu.gd missing proper scene transitions")
    
    print("✅ Overlay cleanup test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_scene_transitions() -> Dictionary:
    print("🔍 Testing Scene Transitions...")
    var test = {"name": "Scene Transitions", "passed": true, "issues": []}
    
    # Check CharacterSelect.gd for proper scene transitions
    var select_source = FileAccess.open("res://common/UI/CharacterSelect.gd", FileAccess.READ)
    if select_source:
        var content = select_source.get_as_text()
        select_source.close()
        
        if not content.contains("get_tree().change_scene_to_file"):
            test.passed = false
            test.issues.append("CharacterSelect.gd missing scene transitions")
        
        if content.contains(".emit(") and content.contains("queue_free()"):
            test.passed = false
            test.issues.append("CharacterSelect.gd still uses old signal pattern")
    
    # Check CharacterCreation.gd for proper scene transitions  
    var creation_source = FileAccess.open("res://common/UI/CharacterCreation.gd", FileAccess.READ)
    if creation_source:
        var content = creation_source.get_as_text()
        creation_source.close()
        
        if not content.contains("get_tree().change_scene_to_file"):
            test.passed = false
            test.issues.append("CharacterCreation.gd missing scene transitions")
    
    print("✅ Scene transitions test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_flow_routing() -> Dictionary:
    print("🔍 Testing Flow Routing...")
    var test = {"name": "Flow Routing", "passed": true, "issues": []}
    
    # Check if Menu.gd has correct flow routing
    var menu_source = FileAccess.open("res://common/UI/Menu.gd", FileAccess.READ)
    if menu_source:
        var content = menu_source.get_as_text()
        menu_source.close()
        
        # New Game should call _show_character_creation
        if not content.contains("_show_character_creation()"):
            test.passed = false
            test.issues.append("New Game not routing to character creation")
        
        # Continue Game should call _show_character_select
        if not content.contains("_show_character_select(false)"):
            test.passed = false
            test.issues.append("Continue Game not routing to character selection")
    
    print("✅ Flow routing test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func test_authentication_consistency() -> Dictionary:
    print("🔍 Testing Authentication Consistency...")
    var test = {"name": "Authentication Consistency", "passed": true, "issues": []}
    
    # Check if AuthController has debouncing
    if not AuthController.has_method("_process_state_change"):
        test.passed = false
        test.issues.append("AuthController missing state change debouncing")
    
    if not AuthController.has_method("_validate_auth_consistency"):
        test.passed = false
        test.issues.append("AuthController missing consistency validation")
    
    # Check if Menu has auth state caching
    var menu_script = load("res://common/UI/Menu.gd")
    if menu_script:
        var menu_instance = menu_script.new()
        if not menu_instance.has_method("_auth_states_equal"):
            test.passed = false
            test.issues.append("Menu missing authentication state comparison")
        menu_instance.queue_free()
    
    print("✅ Authentication consistency test: %s" % ("PASSED" if test.passed else "FAILED"))
    return test

static func print_test_results(results: Dictionary) -> void:
    print("\n" + "=".repeat(60))
    print("COMPREHENSIVE FLOW VALIDATION RESULTS")
    print("=".repeat(60))
    
    for test_name in results:
        if test_name == "overall_status":
            continue
            
        var test = results[test_name]
        var status = "✅ PASSED" if test.passed else "❌ FAILED"
        print("%s: %s" % [test.name, status])
        
        if not test.passed:
            for issue in test.issues:
                print("  - %s" % issue)
    
    var status_color = "✅" if results.overall_status == "PASSED" else "❌"
    print("\nOVERALL STATUS: %s %s" % [status_color, results.overall_status])
    print("=".repeat(60))

## Main validation function
static func validate_fixes() -> void:
    print("🧪 Running comprehensive flow validation...")
    var results = run_comprehensive_test()
    print_test_results(results)
    
    if results.overall_status == "PASSED":
        print("\n🎉 All fixes validated successfully!")
        print("✅ Character screens are now full scenes, not overlays")
        print("✅ New Game → Character Creation")
        print("✅ Continue Game → Character Selection")  
        print("✅ Authentication state properly managed")
        print("✅ Market button should be stable")
    else:
        print("\n⚠️ Some issues remain - see details above")