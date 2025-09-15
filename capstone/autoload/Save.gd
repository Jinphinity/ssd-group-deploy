extends Node

## Save system: local save and offline queue for API sync

var save_path := "user://savegame.save"
var queue: Array = []

func save_local(data: Dictionary) -> void:
    var f := FileAccess.open(save_path, FileAccess.WRITE)
    if f:
        f.store_var(data)
        f.close()

func load_local() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return {}
    var f := FileAccess.open(save_path, FileAccess.READ)
    var data := f.get_var()
    f.close()
    return data if typeof(data) == TYPE_DICTIONARY else {}

func enqueue_request(payload: Dictionary) -> void:
    queue.push_back(payload)

func dequeue_request() -> Dictionary:
    if queue.size() == 0:
        return {}
    return queue.pop_front()

func snapshot() -> Dictionary:
    var scene_path := "res://stages/Stage_Outpost.tscn"
    if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
        scene_path = get_tree().current_scene.scene_file_path
    var player := get_tree().get_first_node_in_group("player")
    var inv_data := []
    if player and player.has_node("Inventory"):
        for it in player.get_node("Inventory").items:
            inv_data.append(it)
    return {
        "stage": scene_path,
        "inventory": inv_data
    }
