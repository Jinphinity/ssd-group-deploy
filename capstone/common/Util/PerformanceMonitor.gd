extends Node

signal performance_report_ready(report: Dictionary)

var monitor_enabled: bool = true
var report_interval: float = 60.0

var fps_samples: Array[float] = []
var memory_samples: Array[float] = []
var last_report_time: float = 0.0
var npc_count: int = 0

func _ready() -> void:
    var timer := Timer.new()
    timer.wait_time = 1.0
    timer.timeout.connect(_sample_performance)
    timer.autostart = true
    add_child(timer)

func _sample_performance() -> void:
    if not monitor_enabled:
        return

    fps_samples.append(Engine.get_frames_per_second())

    var memory_bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
    memory_samples.append(float(memory_bytes) / (1024.0 * 1024.0))

    npc_count = get_tree().get_nodes_in_group("npc").size()

    var current_time := Time.get_unix_time_from_system()
    if current_time - last_report_time >= report_interval:
        _send_performance_report()
        last_report_time = current_time

func _send_performance_report() -> void:
    if fps_samples.is_empty() or memory_samples.is_empty():
        return

    var avg_fps := _average(fps_samples)
    var min_fps := fps_samples.min()
    var max_fps := fps_samples.max()

    var avg_memory := _average(memory_samples)
    var max_memory := memory_samples.max()

    var performance_rating := _assess_performance(avg_fps, npc_count)

    var report := {
        "timestamp": Time.get_unix_time_from_system(),
        "duration_seconds": report_interval,
        "fps": {
            "average": avg_fps,
            "minimum": min_fps,
            "maximum": max_fps,
            "samples": fps_samples.size()
        },
        "memory": {
            "average_mb": avg_memory,
            "maximum_mb": max_memory,
            "samples": memory_samples.size()
        },
        "npcs": {
            "count": npc_count,
            "target": 5
        },
        "performance": {
            "rating": performance_rating,
            "meets_gate2_requirements": avg_fps >= 30.0 and npc_count >= 5
        },
        "platform": OS.get_name(),
        "renderer": _current_renderer()
    }

    if Api != null and Api.jwt != "":
        _send_to_api(report)

    performance_report_ready.emit(report)

    fps_samples.clear()
    memory_samples.clear()

func _send_to_api(report: Dictionary) -> void:
    var req := Api.post("performance/report", report)
    req.request_completed.connect(_on_report_sent)

func _on_report_sent(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    if response_code == 200:
        print("[Perf] Performance report sent successfully")
    else:
        print("[Perf] Failed to send performance report:", response_code)

func _average(samples: Array[float]) -> float:
    if samples.is_empty():
        return 0.0
    var total := 0.0
    for value in samples:
        total += value
    return total / samples.size()

func _assess_performance(avg_fps: float, npc_count_value: int) -> String:
    var is_html5 := OS.get_name() == "Web"
    var target_fps := is_html5 ? 30.0 : 60.0

    if avg_fps >= target_fps and npc_count_value >= 5:
        return "excellent"
    if avg_fps >= target_fps * 0.8:
        return "fair"
    return "poor"

func _current_renderer() -> String:
    var device := RenderingServer.get_rendering_device()
    return device != null ? device.get_device_name() : "Unknown"

func enable_monitoring() -> void:
    monitor_enabled = true
    last_report_time = Time.get_unix_time_from_system()

func disable_monitoring() -> void:
    monitor_enabled = false

func force_report() -> void:
    _send_performance_report()
