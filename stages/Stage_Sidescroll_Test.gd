extends Node2D

## Test stage for sidescrolling characters
## Demonstrates PlayerSniper and Juggernaut Boss in 2D perspective

@onready var player_sniper: PlayerSniper = $PlayerSniper
@onready var juggernaut_boss: ZombieJuggernaut = $ZombieJuggernaut
@onready var camera_rig: ICameraRig = $SideRig
@onready var ui_label: Label = $UI/Label

var perspective_mode: String = "side"

func _ready() -> void:
    # Set up player sniper group
    if player_sniper:
        player_sniper.add_to_group("player_sniper")
        player_sniper.add_to_group("player")
    
    # Configure camera
    if camera_rig:
        camera_rig.activate()
        if camera_rig.has_method("set_follow_target") and player_sniper:
            camera_rig.set_follow_target(player_sniper)
        if camera_rig.has_method("set_zoom"):
            camera_rig.set_zoom(0.8)  # Zoom out a bit for better view
    
    # Set up juggernaut patrol
    if juggernaut_boss:
        juggernaut_boss.patrol_points = [
            Vector2(400, 200),
            Vector2(800, 200)
        ]
    
    # Update UI
    _update_ui()

func _process(delta: float) -> void:
    _handle_input()
    _update_ui()

func _handle_input() -> void:
    # Future work: Multi-perspective switching
    # if Input.is_action_just_pressed("ui_up"):
    #     _switch_perspective("fps")
    # elif Input.is_action_just_pressed("ui_down"):
    #     _switch_perspective("side")
    # elif Input.is_action_just_pressed("ui_left"):
    #     _switch_perspective("tps")
    # elif Input.is_action_just_pressed("ui_right"):
    #     _switch_perspective("iso")
    
    # Debug commands
    if Input.is_action_just_pressed("ui_cancel"):
        _spawn_juggernaut()

# Future work: Multi-perspective switching
# func _switch_perspective(new_mode: String) -> void:
#     if new_mode == perspective_mode:
#         return
#
#     perspective_mode = new_mode
#
#     # Update character visibility
#     if player_sniper:
#         player_sniper.set_perspective_mode(perspective_mode)
#     if juggernaut_boss:
#         juggernaut_boss.set_perspective_mode(perspective_mode)
#
#     # Switch camera rigs
#     match perspective_mode:
#         "side":
#             camera_rig.activate()
#         _:
#             camera_rig.deactivate()
#             # In a full game, you'd switch to other camera rigs here

func _spawn_juggernaut() -> void:
    if player_sniper and juggernaut_boss:
        # Move juggernaut near player for testing
        juggernaut_boss.global_position = player_sniper.global_position + Vector2(200, 0)
        juggernaut_boss.target_player = player_sniper

func _update_ui() -> void:
    if not ui_label:
        return
    
    var info_text = "Sidescrolling Test Stage\n"
    info_text += "Mode: " + perspective_mode.capitalize() + "\n"
    info_text += "Controls:\n"
    info_text += "WASD - Move Sniper\n"
    info_text += "Mouse - Aim/Shoot\n"
    info_text += "R - Reload\n"
    info_text += "Arrow Keys - Switch Perspective\n"
    info_text += "ESC - Spawn Juggernaut\n"
    
    if player_sniper:
        info_text += "\nSniper Health: " + str(player_sniper.current_health) if player_sniper.has_method("get_health") else "N/A"
    
    if juggernaut_boss:
        info_text += "\nJuggernaut Health: %.0f/%.0f" % [juggernaut_boss.current_health, juggernaut_boss.max_health]
        info_text += "\nJuggernaut State: " + str(juggernaut_boss.current_state)
    
    ui_label.text = info_text