extends Node

var save_path := "user://savegame.save"
var session_path := "user://session_data.save"
var queue_path := "user://offline_queue.save"

var queue: Array = []
var session_data: Dictionary = {}
var processing_queue: bool = false

func _ready() -> void:
    _load_session()
    _load_persistent_queue()

func save_local(data: Dictionary) -> void:
    _store_var(save_path, data)

func load_local() -> Dictionary:
    var value = _load_var(save_path)
    if typeof(value) == TYPE_DICTIONARY:
        return value
    return {}

func enqueue_request(payload: Dictionary) -> void:
    queue.append(payload.duplicate(true))
    _save_persistent_queue()

func dequeue_request() -> Dictionary:
    if queue.is_empty():
        return {}
    var request = queue[0]
    queue.remove_at(0)
    _save_persistent_queue()
    if typeof(request) == TYPE_DICTIONARY:
        return request
    return {}

func process_offline_queue() -> void:
    if queue.is_empty() or Api == null:
        return

    var pending := queue.duplicate(true)
    queue.clear()
    _save_persistent_queue()

    for request in pending:
        if typeof(request) != TYPE_DICTIONARY:
            continue
        var method := String(request.get("method", ""))
        var path := String(request.get("path", ""))
        var body := request.get("body", {})
        var request_id := String(request.get("request_id", ""))

        if method == "POST":
            if typeof(body) != TYPE_DICTIONARY:
                body = {}
            Api.post(path, body, request_id)

func snapshot() -> Dictionary:
    var scene_path := "res://stages/Stage_Outpost.tscn"
    if get_tree().current_scene and get_tree().current_scene.scene_file_path != "":
        scene_path = get_tree().current_scene.scene_file_path

    var inventory_data: Array = []
    var player_stats: Dictionary = {}
    var player = get_tree().get_first_node_in_group("player")

    if player:
        if player.has_node("Inventory"):
            var inventory_node = player.get_node("Inventory")
            var stored_items = inventory_node.get("items")
            if typeof(stored_items) == TYPE_ARRAY:
                inventory_data = stored_items.duplicate(true)
        if player.has_method("get_character_stats"):
            var stats = player.get_character_stats()
            if typeof(stats) == TYPE_DICTIONARY:
                player_stats = stats

    return {
        "stage": scene_path,
        "inventory": inventory_data,
        "player_stats": player_stats,
        "timestamp": Time.get_unix_time_from_system()
    }

func save_data() -> void:
    _store_var(session_path, session_data)

func load_data() -> void:
    _load_session()

func has_value(key: String) -> bool:
    return session_data.has(key)

func get_value(key: String, default_value = null):
    return session_data.get(key, default_value)

func set_value(key: String, value) -> void:
    session_data[key] = value
    save_data()

func remove_value(key: String) -> void:
    if session_data.has(key):
        session_data.erase(key)
        save_data()

func clear_save_data() -> void:
    session_data.clear()
    save_data()

func _load_session() -> void:
    var value = _load_var(session_path)
    if typeof(value) == TYPE_DICTIONARY:
        session_data = value
    else:
        session_data = {}

func _save_persistent_queue() -> void:
    _store_var(queue_path, queue)

func _load_persistent_queue() -> void:
    var value = _load_var(queue_path)
    if typeof(value) == TYPE_ARRAY:
        queue = value
    else:
        queue = []

func _store_var(path: String, value) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_var(value)
        file.close()

func _load_var(path: String):
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        return null
    var value = file.get_var()
    file.close()
    return value
