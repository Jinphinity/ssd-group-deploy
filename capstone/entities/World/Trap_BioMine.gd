extends Area3D

@export var slow_amount: float = 0.5
@export var dot: float = 2.0
@export var duration: float = 5.0

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    # Apply a simple debuff effect
    if body and body.has_method("apply_biominetrap"):
        body.apply_biominetrap(slow_amount, dot, duration)
    queue_free()

