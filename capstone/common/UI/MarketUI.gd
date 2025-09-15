extends CanvasLayer

@onready var buy_list: ItemList = $Root/Panel/BuyList
@onready var sell_list: ItemList = $Root/Panel/SellList
@onready var price_label: Label = $Root/Panel/PriceInfo

var market: MarketController = null
var inv: Inventory = null
var money: int = 100

func _ready() -> void:
    visible = false
    var stage := get_tree().current_scene
    market = stage.get_node_or_null("MarketController")
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_node("Inventory"):
        inv = player.get_node("Inventory")
    _refresh()

func _refresh() -> void:
    if market == null:
        return
    buy_list.clear()
    for k in market.current_prices.keys():
        buy_list.add_item("%s — $%d" % [k, int(market.current_prices[k])])
    sell_list.clear()
    if inv:
        for it in inv.items:
            sell_list.add_item("%s" % it.get("name", "Item"))
    price_label.text = "Money: $%d" % money

func _on_buy_pressed() -> void:
    var idx := buy_list.get_selected_items()
    if idx.size() == 0:
        return
    var name := market.current_prices.keys()[idx[0]]
    var price := int(market.current_prices[name])
    if money >= price and inv:
        if inv.add_item({"name": name, "slot_size": 1, "weight": 1.0, "durability": 100}):
            money -= price
            _refresh()

func _on_sell_pressed() -> void:
    var idx := sell_list.get_selected_items()
    if idx.size() == 0 or inv == null:
        return
    var name := inv.items[idx[0]].get("name", "Item")
    var price := int(market.current_prices.get(name, 10))
    inv.remove_item(idx[0])
    money += int(price * 0.5)
    _refresh()

