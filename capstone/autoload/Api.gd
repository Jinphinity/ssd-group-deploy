extends Node

## Simple HTTP client wrapper with token handling

var base_url: String = "http://localhost:8000" # configure for local dev
var jwt: String = ""

func set_base(url: String) -> void:
    base_url = url

func set_jwt(token: String) -> void:
    jwt = token

func _headers() -> PackedStringArray:
    var h := PackedStringArray(["Content-Type: application/json"])
    if jwt != "":
        h.append("Authorization: Bearer %s" % jwt)
    return h

func get(path: String) -> HTTPRequest:
    return _request("GET", path, "")

func post(path: String, body: Dictionary) -> HTTPRequest:
    return _request("POST", path, JSON.stringify(body))

func _request(method: String, path: String, body: String) -> HTTPRequest:
    var req := HTTPRequest.new()
    get_tree().root.add_child(req)
    var url := base_url.rstrip("/") + "/" + path.lstrip("/")
    req.request(url, _headers(), HTTPClient.METHOD_GET if method == "GET" else HTTPClient.METHOD_POST, body)
    return req
