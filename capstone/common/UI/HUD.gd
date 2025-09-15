extends CanvasLayer

@onready var perspective_label: Label = $Root/TopBar/PerspectiveLabel
@onready var health_label: Label = $Root/TopBar/HealthLabel
@onready var captions_label: Label = $Root/Captions

func _ready() -> void:
    if has_node("/root/Game"):
        var g = get_node("/root/Game")
        g.connect("perspective_changed", Callable(self, "_on_perspective_changed"))
        _on_perspective_changed(g.current_perspective)
        g.event_bus.connect("WeaponFired", Callable(self, "_on_weapon_fired"))
    var player := get_tree().get_first_node_in_group("player")
    if player:
        set_process(true)
    if has_node("/root/Accessibility"):
        var a = get_node("/root/Accessibility")
        a.connect("setting_changed", Callable(self, "_on_accessibility_changed"))
        _on_accessibility_changed()

func _process(delta: float) -> void:
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("get_health"):
        health_label.text = "HP: %d" % int(player.get_health())

func _on_perspective_changed(mode: String) -> void:
    perspective_label.text = "Perspective: %s" % mode

func _on_weapon_fired(_id, _params):
    if has_node("/root/Accessibility") and get_node("/root/Accessibility").show_captions:
        captions_label.text = "Bang!"
        captions_label.modulate = Color(1,1,1,1)
        get_tree().create_timer(0.6).timeout.connect(func(): captions_label.modulate = Color(1,1,1,0))

func _on_accessibility_changed():
    var high = get_node("/root/Accessibility").high_contrast if has_node("/root/Accessibility") else false
    var col = Color(1,1,1) if high else Color(1,1,1,0.85)
    perspective_label.modulate = col
    health_label.modulate = col
    captions_label.modulate = Color(1,1,0,1) if high else Color(1,1,1,1)
