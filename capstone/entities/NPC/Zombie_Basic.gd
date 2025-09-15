extends CharacterBody3D

@export var speed: float = 3.0
@export var attack_range: float = 1.4
@export var attack_damage: float = 10.0
@export var vision: Vision

var target: Node3D = null
var health: float = 50.0
var fsm: FSM

func _ready() -> void:
    if not vision:
        vision = Vision.new()
        vision.owner_node = self
        add_child(vision)
    fsm = FSM.new()
    add_child(fsm)
    fsm.add_state("Idle", Callable(self, "_enter_idle"), Callable(self, "_update_idle"))
    fsm.add_state("Chase", Callable(self, "_enter_chase"), Callable(self, "_update_chase"))
    fsm.add_state("Attack", Callable(self, "_enter_attack"), Callable(self, "_update_attack"))
    fsm.set_state("Idle")

func _physics_process(delta: float) -> void:
    if target == null:
        target = get_tree().get_first_node_in_group("player")
    fsm.update(delta)
    move_and_slide()

func _enter_idle() -> void:
    velocity = Vector3.ZERO

func _update_idle(_dt: float) -> void:
    if target and vision.sees(target):
        fsm.set_state("Chase")

func _enter_chase() -> void:
    pass

func _update_chase(_dt: float) -> void:
    if not target:
        fsm.set_state("Idle")
        return
    var to := (target.global_transform.origin - global_transform.origin)
    var dist := to.length()
    if dist <= attack_range:
        fsm.set_state("Attack")
        return
    to.y = 0
    var dir := to.normalized()
    velocity.x = dir.x * speed
    velocity.z = dir.z * speed

func _enter_attack() -> void:
    velocity = Vector3.ZERO

func _update_attack(_dt: float) -> void:
    if not target:
        fsm.set_state("Idle")
        return
    var to := (target.global_transform.origin - global_transform.origin)
    if to.length() > attack_range * 1.2:
        fsm.set_state("Chase")
        return
    if target and target.has_method("apply_damage"):
        target.apply_damage(attack_damage, "torso")

func apply_damage(amount: float, bodypart: String = "torso") -> void:
    health = max(0.0, health - amount)
    if health == 0.0:
        queue_free()
