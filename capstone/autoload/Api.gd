extends Node

## HTTP client wrapper with JWT auth, idempotency, and offline queue

signal response_received(response_data: Dictionary, request_id: String)

var base_url: String = ""
var jwt: String = ""

# Environment configuration
const DEV_API_URL: String = "http://localhost:8000"
const STAGING_API_URL: String = "https://dizzy-api-app.azurewebsites.net"
const PROD_API_URL: String = "https://dizzy-api-app.azurewebsites.net"
const STATIC_HOST_HINTS := [
	"azurestaticapps.net",
	"dizzy-disease"  # custom domains or keyword hints can be added here
]

func _ready() -> void:
	_detect_and_set_environment()

func _detect_and_set_environment() -> void:
	"""Detect runtime environment and configure API URL accordingly"""
	if OS.has_feature("web"):
		# In browser - detect from current URL
		var current_url = _get_browser_url()
		if current_url.is_empty():
			# Unable to detect URL (e.g., eval disabled) - default to prod in web build
			base_url = PROD_API_URL
			print("🌐 [API] Browser detected but URL unavailable - defaulting to PROD API: %s" % base_url)
		elif current_url.contains("localhost") or current_url.contains("127.0.0.1"):
			base_url = DEV_API_URL
			print("🌐 [API] Browser detected - using DEV API: %s" % base_url)
		else:
			var matches_static_host := false
			for hint in STATIC_HOST_HINTS:
				if current_url.find(String(hint)) != -1:
					matches_static_host = true
					break
			if matches_static_host:
				base_url = PROD_API_URL
				print("🌐 [API] Browser detected static host - using PROD API: %s" % base_url)
			elif current_url.contains("staging"):
				base_url = STAGING_API_URL
				print("🌐 [API] Browser detected - using STAGING API: %s" % base_url)
			else:
				base_url = PROD_API_URL
				print("🌐 [API] Browser detected - using PROD API: %s" % base_url)
	else:
		# Desktop/editor - use dev by default
		base_url = DEV_API_URL
		print("💻 [API] Desktop detected - using DEV API: %s" % base_url)

func _get_browser_url() -> String:
	"""Get current browser URL for environment detection"""
	if OS.has_feature("web"):
		if Engine.has_singleton("JavaScriptBridge"):
			var href = JavaScriptBridge.eval("window.location.href", true)
			if typeof(href) == TYPE_STRING:
				return href
		return ""
	return ""

func use_online_base(url: String = STAGING_API_URL) -> void:
	base_url = url
	print("🔧 [API] Manually set API URL: %s" % base_url)

func use_offline_base() -> void:
	base_url = DEV_API_URL
	print("🔧 [API] Switched to offline/dev API: %s" % base_url)

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

func get_json(path: String, request_id: String = "") -> HTTPRequest:
	return _request("GET", path, "", request_id)

func post(path: String, body: Dictionary, request_id: String = "") -> HTTPRequest:
	return _request("POST", path, JSON.stringify(body), request_id)

func delete(path: String, request_id: String = "") -> HTTPRequest:
	return _request("DELETE", path, "", request_id)

func _request(method: String, path: String, body: String, request_id: String = "") -> HTTPRequest:
	var req := HTTPRequest.new()
	get_tree().root.add_child(req)

	# Connect to completion signal to emit response_received
	req.request_completed.connect(_on_request_completed.bind(request_id))

	var url := base_url.rstrip("/") + "/" + path.lstrip("/")
	var headers := _headers(request_id)
	var http_method := HTTPClient.METHOD_GET
	match method:
		"GET":
			http_method = HTTPClient.METHOD_GET
		"POST":
			http_method = HTTPClient.METHOD_POST
		"DELETE":
			http_method = HTTPClient.METHOD_DELETE
		_:
			push_warning("Unsupported HTTP method '%s' - defaulting to GET" % method)
			http_method = HTTPClient.METHOD_GET

	var request_body := body if method == "POST" else ""
	req.request(url, headers, http_method, request_body)
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
		"timestamp": GameTime.get_unix_time_from_system()
	})
	return post("market/buy", payload, request_id)

func process_offline_queue() -> void:
	# Process pending requests from offline queue
	while Save.queue.size() > 0:
		var req_data = Save.dequeue_request()
		if req_data.has("method") and req_data.has("path"):
			if req_data.get("method", "") == "POST":
				var body: Variant = req_data.get("body", {})
				var request_id := String(req_data.get("request_id", ""))
				var path := String(req_data.get("path", ""))
				if typeof(body) != TYPE_DICTIONARY:
					body = {}
				post(path, body, request_id)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, request_id: String) -> void:
	"""Handle HTTP request completion and emit response_received signal"""
	var response_data: Dictionary = {}

	# Parse JSON response if available
	if body.size() > 0:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			response_data = json.data
		else:
			response_data["_raw_body"] = body.get_string_from_utf8()

	# Add metadata about the request result
	response_data["_meta"] = {
		"result": result,
		"response_code": response_code,
		"headers": headers,
		"success": response_code >= 200 and response_code < 300
	}

	# Emit signal for listeners (InventoryUI, ServerCharacterStorage, etc.)
	response_received.emit(response_data, request_id)

func _generate_uuid() -> String:
	# Simple UUID v4 generation
	var uuid = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		var hex_digit = randi() % 16
		uuid += "%x" % hex_digit
	return uuid
