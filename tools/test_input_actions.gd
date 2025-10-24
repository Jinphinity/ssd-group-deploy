extends Node

## Simple input action test - add this to a scene and run to test input detection

func _ready():
	print("🧪 INPUT ACTION TEST - Press keys to verify detection")
	print("=" * 50)
	print("⌨️  Try pressing: I, C, M, F5, H, Ctrl+C")
	print("✅ Working keys will show detection messages")
	print("❌ Silent keys indicate binding issues")
	print("=" * 50)

func _input(event: InputEvent):
	if event.is_action_pressed("inventory"):
		print("✅ DETECTED: Inventory (I) key pressed!")
	elif event.is_action_pressed("crafting"):
		print("✅ DETECTED: Crafting (C) key pressed!")
	elif event.is_action_pressed("market"):
		print("✅ DETECTED: Market (M) key pressed!")
	elif event.is_action_pressed("save_game"):
		print("✅ DETECTED: Save Game (F5) key pressed!")
	elif event.is_action_pressed("acc_toggle_high_contrast"):
		print("✅ DETECTED: High Contrast (H) key pressed!")
	elif event.is_action_pressed("acc_toggle_captions"):
		print("✅ DETECTED: Captions (Ctrl+C) keys pressed!")

func _unhandled_input(event: InputEvent):
	# This should also detect the same inputs
	if event.is_action_pressed("inventory"):
		print("🔄 UNHANDLED: Inventory (I) - this means Game.gd might not be handling it")
	elif event.is_action_pressed("crafting"):
		print("🔄 UNHANDLED: Crafting (C) - this means Game.gd might not be handling it")
	elif event.is_action_pressed("market"):
		print("🔄 UNHANDLED: Market (M) - this means Game.gd might not be handling it")