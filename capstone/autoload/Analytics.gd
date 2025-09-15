extends Node

## Lightweight analytics logger

func log(event: String, data: Dictionary = {}) -> void:
    print("[ANALYTICS] %s :: %s" % [event, JSON.stringify(data)])

