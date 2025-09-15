extends CharacterBody3D

@export var movement_controller_path: NodePath
@export var rig_scene: PackedScene
@export var weapon_damage: float = 20.0

var rig: Node = null
var ballistics: Ballistics
var health: float = 100.0
var movement_controller: Node = null
var slow_factor: float = 1.0
var dot_remaining: float = 0.0
var dot_rate: float = 0.0
var dot_timer: float = 0.0

func _ready() -> void:
    # Spawn rig
    if rig_scene:
        rig = rig_scene.instantiate()
        add_child(rig)
    ballistics = Ballistics.new()
    add_child(ballistics)
    # Listen for perspective changes
    if has_node("/root/Game"):
        var g = get_node("/root/Game")
        g.connect("perspective_changed", Callable(self, "_on_perspective_changed"))
    # Resolve controller
    if movement_controller_path != NodePath(""):
        var node = get_node(movement_controller_path)
        if node:
            movement_controller = node

func _physics_process(delta: float) -> void:
    if movement_controller and movement_controller.has_method("move"):
        movement_controller.owner_body = self
        var old_speed := movement_controller.speed if movement_controller.has_variable("speed") else null
        if old_speed != null:
            movement_controller.speed = float(old_speed) * slow_factor
        movement_controller.move({}, delta)
        if old_speed != null:
            movement_controller.speed = old_speed
    if Input.is_action_just_pressed("fire"):
        _fire_weapon()
    _update_dot(delta)

func _fire_weapon() -> void:
    var origin := global_transform.origin + Vector3(0, 1.6, 0)
    var dir := Vector3.FORWARD
    if rig and rig.has_method("aim_vector"):
        dir = rig.aim_vector()
    ballistics.fire(origin, dir, weapon_damage, 1)
    if has_node("/root/Game"):
        get_node("/root/Game").event_bus.emit_signal("NoiseEmitted", self, 50.0, 10.0)

func apply_damage(amount: float, bodypart: String = "torso") -> void:
    health = max(0.0, health - amount)
    if health == 0.0:
        if has_node("/root/Game"):
            get_node("/root/Game").event_bus.emit_signal("PlayerDowned")

func get_health() -> float:
    return health

func apply_biominetrap(slow_amount: float, dot: float, duration: float) -> void:
    slow_factor = max(0.3, 1.0 - slow_amount)
    dot_remaining = duration
    dot_rate = dot
    dot_timer = 0.0

func _update_dot(delta: float) -> void:
    if dot_remaining > 0.0:
        dot_timer += delta
        if dot_timer >= 1.0:
            dot_timer = 0.0
            apply_damage(dot_rate, "torso")
            dot_remaining = max(0.0, dot_remaining - 1.0)
    else:
        slow_factor = 1.0

func _on_perspective_changed(mode: String) -> void:
    var map := {
        "FPS": preload("res://common/CameraRigs/FPSRig.tscn"),
        "TPS": preload("res://common/CameraRigs/TPSRig.tscn"),
        "Iso": preload("res://common/CameraRigs/IsoRig.tscn"),
        "Side": preload("res://common/CameraRigs/FPSRig.tscn") # placeholder
    }
    if rig:
        rig.queue_free()
    if map.has(mode):
        rig = map[mode].instantiate()
        add_child(rig)
