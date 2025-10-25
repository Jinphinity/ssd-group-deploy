extends ZombieBasic2D

## Alarm zombie: alerts the horde when eliminated.

class_name ZombieAlarm2D

@export var alert_spawn_count: int = 4
@export var alert_noise_radius: float = 320.0
@export var alert_cooldown: float = 0.5

var _alarm_triggered := false
var _alert_timer: float = 0.0

func _ready() -> void:
	speed = 55.0
	attack_damage = 8.0
	health = 45.0
	super._ready()
	var label := get_node_or_null("ZombieVisual/ZombieLabel")
	if label:
		label.text = "ALARM"
	var rect := get_node_or_null("ZombieVisual")
	if rect and rect is ColorRect:
		rect.color = Color(0.95, 0.75, 0.1, 1.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _alert_timer > 0.0:
		_alert_timer -= delta

func take_damage(damage: float) -> void:
	if _alert_timer <= 0.0 and has_node("/root/Game"):
		var game = get_node("/root/Game")
		var bus = game.get("event_bus") if game else null
		if bus and bus.has_signal("NoiseEmitted"):
			bus.emit_signal("NoiseEmitted", self, 1.0, alert_noise_radius)
		_alert_timer = alert_cooldown
	super.take_damage(damage)

func _die() -> void:
	_trigger_alarm()
	super._die()

func _trigger_alarm() -> void:
	if _alarm_triggered:
		return
	_alarm_triggered = true
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		var bus = game.get("event_bus") if game else null
		if bus and bus.has_signal("WaveSpawnerAlert"):
			bus.emit_signal("WaveSpawnerAlert", {
				"count": alert_spawn_count,
				"source": self,
				"type": "alarm"
			})
