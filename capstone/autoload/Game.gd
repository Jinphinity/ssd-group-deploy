extends Node

## Game singleton: high-level game state, scene loads, transitions

signal perspective_changed(mode)

var current_stage: Node = null
var event_bus: Node = null
var current_perspective: String = "FPS" # FPS, TPS, Iso, Side
var hud: CanvasLayer = null
var market_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null

func _ready() -> void:
    _ensure_input_map()
    # Create a lightweight EventBus node for global signals
    event_bus = preload("res://common/Util/EventBus.gd").new()
    event_bus.name = "EventBus"
    add_child(event_bus)
    # Attempt to load saved state
    var data := Save.load_local()
    if data.has("stage"):
        call_deferred("load_stage", data["stage"])
    # UI toggles routed here
    set_process_input(true)

func load_stage(packed_path: String) -> void:
    if current_stage and current_stage.is_inside_tree():
        current_stage.queue_free()
    var p := load(packed_path)
    if p:
        current_stage = p.instantiate()
        get_tree().root.add_child(current_stage)
        get_tree().current_scene = current_stage
        # Grab UIs if present
        hud = current_stage.get_node_or_null("HUD")
        market_ui = current_stage.get_node_or_null("MarketUI")
        inventory_ui = current_stage.get_node_or_null("InventoryUI")
        # Restore inventory if present in save
        var data := Save.load_local()
        if data.has("inventory"):
            var player := current_stage.get_node_or_null("Player")
            if player and player.has_node("Inventory"):
                for it in data["inventory"]:
                    player.get_node("Inventory").add_item(it)

func set_perspective(mode: String) -> void:
    if current_perspective == mode:
        return
    current_perspective = mode
    emit_signal("perspective_changed", mode)

func _ensure_input_map() -> void:
    var actions := [
        "move_forward", "move_back", "move_left", "move_right",
        "fire", "aim", "interact", "reload", "inventory", "market", "pause",
        "acc_toggle_high_contrast", "acc_toggle_captions"
    ]
    for a in actions:
        if not InputMap.has_action(a):
            InputMap.add_action(a)
    # Default bindings (safe duplicates are ignored by Godot)
    _bind_key("move_forward", KEY_W)
    _bind_key("move_back", KEY_S)
    _bind_key("move_left", KEY_A)
    _bind_key("move_right", KEY_D)
    _bind_mouse_button("fire", MOUSE_BUTTON_LEFT)
    _bind_mouse_button("aim", MOUSE_BUTTON_RIGHT)
    _bind_key("interact", KEY_E)
    _bind_key("reload", KEY_R)
    _bind_key("inventory", KEY_I)
    _bind_key("market", KEY_M)
    _bind_key("pause", KEY_ESCAPE)
    _bind_key("acc_toggle_high_contrast", KEY_H)
    _bind_key("acc_toggle_captions", KEY_C)

func _bind_key(action: StringName, keycode: int) -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = keycode
    InputMap.action_add_event(action, ev)

func _bind_mouse_button(action: StringName, button: int) -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = button
    InputMap.action_add_event(action, ev)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("inventory"):
        if inventory_ui == null and has_node("/root/stages/InventoryUI"): inventory_ui = get_node("/root/stages/InventoryUI")
        if inventory_ui:
            inventory_ui.visible = not inventory_ui.visible
    elif event.is_action_pressed("market"):
        if market_ui == null and has_node("/root/stages/MarketUI"): market_ui = get_node("/root/stages/MarketUI")
        if market_ui:
            market_ui.visible = not market_ui.visible
    elif event.is_action_pressed("acc_toggle_high_contrast") and has_node("/root/Accessibility"):
        get_node("/root/Accessibility").toggle_high_contrast()
    elif event.is_action_pressed("acc_toggle_captions") and has_node("/root/Accessibility"):
        get_node("/root/Accessibility").toggle_captions()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        Save.save_local(Save.snapshot())
        get_tree().quit()
