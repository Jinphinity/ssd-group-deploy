extends Node

## HTTP client wrapper with JWT auth, idempotency, and offline queue

var base_url: String = "http://localhost:8000" # configure for local dev
var jwt: String = ""

func set_base(url: String) -> void:
    base_url = url

func set_jwt(token: String) -> void:
    jwt = token

func _headers(request_id: String = "") -> PackedStringArray:
    var h := PackedStringArray(["Content-Type: application/json"])
    if jwt != "":
        h.append("Authorization: Bearer %s" % jwt)
    if request_id != "":
        h.append("X-Request-Id: %s" % request_id)
    return h

func get_json(path: String) -> HTTPRequest:
    return _request("GET", path, "")

func post(path: String, body: Dictionary, request_id: String = "") -> HTTPRequest:
    return _request("POST", path, JSON.stringify(body), request_id)

func _request(method: String, path: String, body: String, request_id: String = "") -> HTTPRequest:
    var req := HTTPRequest.new()
    get_tree().root.add_child(req)
    var url := base_url.rstrip("/") + "/" + path.lstrip("/")
    var headers := _headers(request_id)
    var http_method := method == "GET" ? HTTPClient.METHOD_GET : HTTPClient.METHOD_POST
    req.request(url, headers, http_method, body)
    return req

# Idempotent market operations
func market_buy(settlement_id: int, item_id: int, quantity: int) -> HTTPRequest:
    var request_id := _generate_uuid()
    var payload := {
        "settlement_id": settlement_id,
        "item_id": item_id,
        "quantity": quantity
    }
    # Store in offline queue for retry
    Save.enqueue_request({
        "method": "POST",
        "path": "market/buy",
        "body": payload,
        "request_id": request_id,
        "timestamp": Time.get_unix_time_from_system()
    })
    return post("market/buy", payload, request_id)

func process_offline_queue() -> void:
    # Process pending requests from offline queue
    while Save.queue.size() > 0:
        var req_data = Save.dequeue_request()
        if req_data.has("method") and req_data.has("path"):
            if req_data.get("method", "") == "POST":
                var body := req_data.get("body", {})
                var request_id := String(req_data.get("request_id", ""))
                var path := String(req_data.get("path", ""))
                if typeof(body) != TYPE_DICTIONARY:
                    body = {}
                post(path, body, request_id)

func _generate_uuid() -> String:
    # Simple UUID v4 generation
    var uuid = ""
    for i in range(32):
        if i == 8 or i == 12 or i == 16 or i == 20:
            uuid += "-"
        var hex_digit = randi() % 16
        uuid += "%x" % hex_digit
    return uuid
