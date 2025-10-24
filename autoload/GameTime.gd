extends Node

## World time & scheduler

signal tick(dt)

var time_scale := 1.0
var accumulator := 0.0
var step := 0.2 # economic/AI tick
var _time_singleton: Object

func _ready() -> void:
    _time_singleton = Engine.get_singleton("Time")

func _process(delta: float) -> void:
    accumulator += delta * time_scale
    if accumulator >= step:
        accumulator -= step
        emit_signal("tick", step)

func _get_time_singleton() -> Object:
    if _time_singleton == null:
        _time_singleton = Engine.get_singleton("Time")
    return _time_singleton

func get_unix_time_from_system() -> float:
    var native_time = _get_time_singleton()
    if native_time and native_time.has_method("get_unix_time_from_system"):
        return native_time.get_unix_time_from_system()
    return 0.0

func get_datetime_string_from_system() -> String:
    var native_time = _get_time_singleton()
    if native_time and native_time.has_method("get_datetime_string_from_system"):
        return native_time.get_datetime_string_from_system()
    return ""

func get_time_dict_from_system() -> Dictionary:
    var native_time = _get_time_singleton()
    if native_time and native_time.has_method("get_time_dict_from_system"):
        return native_time.get_time_dict_from_system()
    return {}

func get_ticks_msec() -> int:
    var native_time = _get_time_singleton()
    if native_time and native_time.has_method("get_ticks_msec"):
        return native_time.get_ticks_msec()
    return 0
