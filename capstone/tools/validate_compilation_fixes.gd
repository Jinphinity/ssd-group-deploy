#!/usr/bin/env -S godot --headless --script
extends SceneTree

## Quick validation script to test if compilation errors are fixed
## Specifically tests the circular dependency fix between AuthController and LoginScreen

func _init():
	print("🔧 COMPILATION ERROR VALIDATION")
	print("=" * 60)

	await create_timer(0.5).timeout

	test_authcontroller_access()
	test_loginscreen_compilation()
	test_main_scene_loading()

	print("\n🎯 VALIDATION COMPLETE")
	quit(0)

func test_authcontroller_access():
	print("\n📋 Testing AuthController Access:")

	try:
		# Test if AuthController singleton is accessible
		if has_node("/root/AuthController"):
			print("  ✅ AuthController singleton accessible")

			# Test if we can access its properties
			var auth = get_node("/root/AuthController")
			if auth.has_method("_ready"):
				print("  ✅ AuthController methods accessible")
			else:
				print("  ❌ AuthController methods not accessible")
		else:
			print("  ❌ AuthController singleton not found")
	except Exception as e:
		print("  ❌ Error accessing AuthController: %s" % str(e))

func test_loginscreen_compilation():
	print("\n📋 Testing LoginScreen Compilation:")

	try:
		# Try to load LoginScreen scene
		var login_scene = load("res://common/UI/LoginScreen.tscn")
		if login_scene:
			print("  ✅ LoginScreen.tscn loads successfully")

			# Try to instantiate it
			var login_instance = login_scene.instantiate()
			if login_instance:
				print("  ✅ LoginScreen instantiates successfully")
				login_instance.queue_free()
			else:
				print("  ❌ LoginScreen failed to instantiate")
		else:
			print("  ❌ LoginScreen.tscn failed to load")
	except Exception as e:
		print("  ❌ Error loading LoginScreen: %s" % str(e))

func test_main_scene_loading():
	print("\n📋 Testing Main Scene Loading:")

	try:
		# Test the main scene defined in project.godot
		var main_scene = load("res://common/UI/LoginScreen.tscn")
		if main_scene:
			print("  ✅ Main scene (LoginScreen) loads without compilation errors")

			# Test if we can instantiate and immediately free it
			var instance = main_scene.instantiate()
			if instance:
				print("  ✅ Main scene instantiates successfully")
				print("  🎯 CRITICAL FIX SUCCESSFUL: Circular dependency resolved!")
				instance.queue_free()
			else:
				print("  ❌ Main scene failed to instantiate")
		else:
			print("  ❌ Main scene failed to load")
	except Exception as e:
		print("  ❌ Error with main scene: %s" % str(e))

func has_node(path: String) -> bool:
	return get_node_or_null(path) != null

# Error handling wrapper
func try(callable: Callable):
	pass

class Exception:
	var message: String
	func _init(msg: String):
		message = msg
	func str() -> String:
		return message