extends CanvasLayer

@onready var list: ItemList = $Root/Panel/ItemList
@onready var info: Label = $Root/Panel/Info

var inv: Inventory = null

func _ready() -> void:
    visible = false
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_node("Inventory"):
        inv = player.get_node("Inventory")
        _refresh()
        inv.item_added.connect(_refresh)
        inv.item_removed.connect(_refresh)

func _refresh(_a = null) -> void:
    if inv == null:
        return
    list.clear()
    for it in inv.items:
        var name := it.get("name", "Item")
        var d := it.get("durability", 0)
        list.add_item("%s (dur %d)" % [name, d])
    info.text = "Slots: %d/%d  Weight: %.1f/%.1f" % [inv.get_slots_used(), inv.capacity_slots, inv.get_weight(), inv.carry_weight_max]

