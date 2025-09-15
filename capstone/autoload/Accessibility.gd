extends Node

## Accessibility toggles

signal setting_changed()

var high_contrast: bool = false
var show_captions: bool = true

func toggle_high_contrast() -> void:
    high_contrast = !high_contrast
    setting_changed.emit()

func toggle_captions() -> void:
    show_captions = !show_captions
    setting_changed.emit()

