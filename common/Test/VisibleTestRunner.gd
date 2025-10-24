#!/usr/bin/env godot
## Visible GUI Automation Test Runner
## Launches autonomous testing with visible GUI navigation

extends SceneTree

var auto_player: GameAutoPlayer
var test_overlay: Control

func _init():
	print("🚀 Starting VISIBLE GUI Automation Testing")
	print("   You should see the bot navigating the interface!")
	print("   Close the window or press ESC to stop testing")

	call_deferred("start_visible_testing")

func start_visible_testing():
	"""Start visible autonomous testing in GUI mode"""

	# Load the login screen scene
	var login_scene = load("res://common/UI/LoginScreen.tscn")
	var scene_instance = login_scene.instantiate()
	root.add_child(scene_instance)
	current_scene = scene_instance

	# Create test overlay for visual feedback
	create_test_overlay()

	# Create and start the autonomous player
	auto_player = GameAutoPlayer.new()
	auto_player.show_automation_cursor = true
	auto_player.enable_verbose_logging = true
	auto_player.automation_speed = 0.8  # Slightly slower so you can see it

	# Connect signals
	auto_player.automation_started.connect(_on_automation_started)
	auto_player.automation_completed.connect(_on_automation_completed)
	auto_player.automation_step_completed.connect(_on_step_completed)
	auto_player.automation_failed.connect(_on_automation_failed)

	root.add_child(auto_player)

	# Start autonomous testing
	print("🤖 Bot taking control - watch the magic happen!")
	await auto_player.start_auto_play()

func create_test_overlay():
	"""Create overlay showing test progress"""
	test_overlay = Control.new()
	test_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	test_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create status panel
	var status_panel = Panel.new()
	status_panel.position = Vector2(10, 10)
	status_panel.size = Vector2(300, 100)

	var status_label = Label.new()
	status_label.text = "🤖 Autonomous Testing Active\nPress ESC to stop"
	status_label.position = Vector2(10, 10)
	status_label.size = Vector2(280, 80)

	status_panel.add_child(status_label)
	test_overlay.add_child(status_panel)
	root.add_child(test_overlay)

func _input(event):
	"""Handle input to stop testing"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			print("🛑 Testing stopped by user")
			quit()

func _on_automation_started(scenario_name: String):
	"""Handle automation start"""
	print("▶️ Starting scenario: %s" % scenario_name)
	update_status("Running: %s" % scenario_name)

func _on_automation_completed(scenario_name: String, results: Dictionary):
	"""Handle automation completion"""
	print("✅ Completed scenario: %s" % scenario_name)
	var success = results.get("success", false)
	update_status("Completed: %s (%s)" % [scenario_name, "✅" if success else "❌"])

func _on_step_completed(step_name: String, success: bool):
	"""Handle step completion"""
	var icon = "✅" if success else "❌"
	print("  %s %s" % [icon, step_name])

func _on_automation_failed(scenario_name: String, error: String):
	"""Handle automation failure"""
	print("❌ Failed scenario: %s - %s" % [scenario_name, error])
	update_status("Failed: %s" % scenario_name)

func update_status(text: String):
	"""Update the status overlay"""
	if test_overlay and test_overlay.get_child_count() > 0:
		var panel = test_overlay.get_child(0)
		if panel.get_child_count() > 0:
			var label = panel.get_child(0)
			label.text = "🤖 Autonomous Testing\n%s\nPress ESC to stop" % text