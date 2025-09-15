extends Node3D

@onready var market: MarketController = $MarketController
@onready var settlement: SettlementController = $SettlementController

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    if has_node("/root/Time"):
        get_node("/root/Time").connect("tick", Callable(self, "_on_tick"))

func _on_tick(dt: float) -> void:
    # 10% chance to trigger an event
    if _rng.randf() < 0.1:
        var events := ["OutpostAttacked", "Shortage", "ConvoyArrived"]
        var e := events[_rng.randi_range(0, events.size()-1)]
        settlement.apply_event(e, {})
        market.adjust_for_event(e, {})

