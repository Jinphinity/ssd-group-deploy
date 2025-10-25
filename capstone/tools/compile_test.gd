#!/usr/bin/env -S godot --headless --script

## Simple Compilation Test
## Tests if the main files compile without autoload dependency errors

extends SceneTree

func _init():
	print("🔧 COMPILATION TEST")
	print("=" * 40)
	print("🔍 Testing compilation fixes")
	print("=" * 40)

	_test_compilation()

func _test_compilation():
	print("\n✅ Basic compilation test started")

	# Load the main scene to trigger compilation
	var error = change_scene_to_file("res://common/UI/LoginScreen.tscn")
	if error == OK:
		print("✅ LoginScreen loaded successfully")
		await create_timer(1.0).timeout

		# Try loading a gameplay scene
		error = change_scene_to_file("res://stages/Stage_Outpost_2D.tscn")
		if error == OK:
			print("✅ Stage_Outpost loaded successfully")
			await create_timer(1.0).timeout

			# Try loading hostile scene
			error = change_scene_to_file("res://stages/Stage_Hostile_01_2D.tscn")
			if error == OK:
				print("✅ Stage_Hostile loaded successfully")
			else:
				print("❌ Failed to load Stage_Hostile: %d" % error)
		else:
			print("❌ Failed to load Stage_Outpost: %d" % error)
	else:
		print("❌ Failed to load LoginScreen: %d" % error)

	print("\n🎯 COMPILATION TEST COMPLETE")
	print("📊 Check the log for any remaining SCRIPT ERROR messages")
	quit(0)