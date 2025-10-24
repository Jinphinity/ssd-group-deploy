extends Node

## Minimal FSM helper

class_name FSM

var state: String = ""
var handlers: Dictionary = {}

func add_state(name: String, enter: Callable = Callable(), update: Callable = Callable(), exit: Callable = Callable()) -> void:
    handlers[name] = {"enter": enter, "update": update, "exit": exit}

func set_state(name: String) -> void:
    if state == name:
        return
    if handlers.has(state) and handlers[state]["exit"]: handlers[state]["exit"].call()
    state = name
    if handlers.has(state) and handlers[state]["enter"]: handlers[state]["enter"].call()

func update(delta: float) -> void:
    if handlers.has(state) and handlers[state]["update"]:
        handlers[state]["update"].call(delta)

