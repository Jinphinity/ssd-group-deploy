extends Node

class_name Inventory

signal item_added(item)
signal item_removed(item)
signal item_updated(item)

@export var capacity_slots: int = 12
@export var carry_weight_max: float = 25.0

var items: Array = [] # array of Dictionaries or Resources

func add_item(item: Dictionary) -> bool:
    if get_slots_used() + int(item.get("slot_size", 1)) > capacity_slots:
        return false
    if get_weight() + float(item.get("weight", 0.0)) > carry_weight_max:
        return false
    items.append(item)
    item_added.emit(item)
    return true

func remove_item(idx: int) -> Dictionary:
    if idx < 0 or idx >= items.size():
        return {}
    var it = items.pop_at(idx)
    item_removed.emit(it)
    return it

func get_slots_used() -> int:
    var s := 0
    for it in items:
        s += int(it.get("slot_size", 1))
    return s

func get_weight() -> float:
    var w := 0.0
    for it in items:
        w += float(it.get("weight", 0.0))
    return w

