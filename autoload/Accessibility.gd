extends Node

## Accessibility toggles

signal setting_changed()

var high_contrast: bool = false
var show_captions: bool = true

func _ready() -> void:
	high_contrast = bool(Save.get_value("ui_high_contrast", false))
	show_captions = bool(Save.get_value("ui_show_captions", true))
	setting_changed.emit()

func toggle_high_contrast() -> void:
	set_high_contrast(!high_contrast)

func toggle_captions() -> void:
	set_show_captions(!show_captions)

func set_high_contrast(enabled: bool) -> void:
	if high_contrast == enabled:
		return
	high_contrast = enabled
	Save.set_value("ui_high_contrast", high_contrast)
	setting_changed.emit()

func set_show_captions(enabled: bool) -> void:
	if show_captions == enabled:
		return
	show_captions = enabled
	Save.set_value("ui_show_captions", show_captions)
	setting_changed.emit()
