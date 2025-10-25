extends CanvasLayer

## Character selection screen focused on selection with optional creation
## Full scene implementation - no longer an overlay

@export var new_game_mode: bool = false

@onready var root_control: Control = $Root
@onready var dim_rect: ColorRect = $Root/Dim
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var info_label: Label = $Root/Center/Panel/Margin/VBox/InfoLabel
@onready var roster_list: ItemList = $Root/Center/Panel/Margin/VBox/RosterList
@onready var status_label: Label = $Root/Center/Panel/Margin/VBox/StatusLabel
@onready var action_row: HBoxContainer = $Root/Center/Panel/Margin/VBox/ActionRow
@onready var play_button: Button = $Root/Center/Panel/Margin/VBox/ActionRow/PlayButton
@onready var cancel_button: Button = $Root/Center/Panel/Margin/VBox/ActionRow/CancelButton
@onready var create_new_button: Button = $Root/Center/Panel/Margin/VBox/ActionRow/CreateNewButton
var delete_button: Button = null

var _characters: Array = []
var _max_characters: int = 5
var _offline: bool = false
var _decided_offline: bool = false

func _ready() -> void:
	_apply_accessibility()

	if OS.has_feature("web"):
		call_deferred("_apply_fullscreen_web_layout")

	delete_button = action_row.get_node_or_null("DeleteButton") as Button
	_apply_roster_list_theme()

	if not Accessibility.setting_changed.is_connected(_on_accessibility_changed):
		Accessibility.setting_changed.connect(_on_accessibility_changed)
	if not CharacterService.roster_updated.is_connected(_on_roster_updated):
		CharacterService.roster_updated.connect(_on_roster_updated)
	if not CharacterService.character_deleted.is_connected(_on_character_deleted):
		CharacterService.character_deleted.connect(_on_character_deleted)

	# Connect ItemList selection signals
	if not roster_list.item_selected.is_connected(_on_roster_item_selected):
		roster_list.item_selected.connect(_on_roster_item_selected)
	if not roster_list.item_activated.is_connected(_on_roster_item_activated):
		roster_list.item_activated.connect(_on_roster_item_activated)

	# Connect button signals
	if delete_button and not delete_button.pressed.is_connected(_on_delete_button_pressed):
		delete_button.pressed.connect(_on_delete_button_pressed)

	# Get new_game_mode from saved state
	new_game_mode = Save.get_value("character_select_new_game_mode", false)
	Save.remove_value("character_select_new_game_mode")  # Clean up

	status_label.text = "Loading survivors..."
	info_label.text = "Preparing local roster..."

	_prime_cached_roster()
	CharacterService.refresh_roster()
	call_deferred("_retry_refresh_if_empty")

	if new_game_mode:
		info_label.text = "Select survivor or create new"
		create_new_button.grab_focus()
	else:
		info_label.text = "Select survivor to continue"
		roster_list.grab_focus()

	print("🎯 [CharSelect] Initialized (new_game_mode: %s)" % new_game_mode)

func _apply_fullscreen_web_layout() -> void:
	var root := get_node_or_null("Root")
	if root:
		root.anchor_left = 0.0
		root.anchor_top = 0.0
		root.anchor_right = 1.0
		root.anchor_bottom = 1.0
		root.offset_left = 0.0
		root.offset_top = 0.0
		root.offset_right = 0.0
		root.offset_bottom = 0.0
		root.layout_mode = Control.LAYOUT_FULL_RECT
	var dim := get_node_or_null("Root/Dim")
	if dim:
		dim.anchor_left = 0.0
		dim.anchor_top = 0.0
		dim.anchor_right = 1.0
		dim.anchor_bottom = 1.0
		dim.offset_left = 0.0
		dim.offset_top = 0.0
		dim.offset_right = 0.0
		dim.offset_bottom = 0.0
	var center := get_node_or_null("Root/Center")
	if center:
		center.anchor_left = 0.0
		center.anchor_top = 0.0
		center.anchor_right = 1.0
		center.anchor_bottom = 1.0
		center.offset_left = 0.0
		center.offset_top = 0.0
		center.offset_right = 0.0
		center.offset_bottom = 0.0

func _exit_tree() -> void:
	if Accessibility.setting_changed.is_connected(_on_accessibility_changed):
		Accessibility.setting_changed.disconnect(_on_accessibility_changed)
	if CharacterService.roster_updated.is_connected(_on_roster_updated):
		CharacterService.roster_updated.disconnect(_on_roster_updated)
	if CharacterService.character_deleted.is_connected(_on_character_deleted):
		CharacterService.character_deleted.disconnect(_on_character_deleted)

	# Disconnect ItemList signals
	if roster_list.item_selected.is_connected(_on_roster_item_selected):
		roster_list.item_selected.disconnect(_on_roster_item_selected)
	if roster_list.item_activated.is_connected(_on_roster_item_activated):
		roster_list.item_activated.disconnect(_on_roster_item_activated)

	# Disconnect button signals
	if delete_button and delete_button.pressed.is_connected(_on_delete_button_pressed):
		delete_button.pressed.disconnect(_on_delete_button_pressed)

func _on_roster_updated(characters: Array, info: Dictionary) -> void:
	# Prevent duplicate updates from cache + refresh
	if info.get("from_cache", false) and _characters.size() > 0:
		print("📋 [CharSelect] Skipping cache update - roster already populated (%d chars)" % _characters.size())
		return

	_characters = characters.duplicate(true)
	_max_characters = int(info.get("max_characters", 5))
	_offline = bool(info.get("offline", false))
	_decided_offline = _offline

	roster_list.clear()
	for character in _characters:
		var name := String(character.get("name", "Unnamed"))
		var level := int(character.get("level", 1))
		var stat_points := int(character.get("available_stat_points", 0))
		var label := "%s — Lv %d (SP %d)" % [name, level, stat_points]
		roster_list.add_item(label)
		var item_index := roster_list.get_item_count() - 1
		roster_list.set_item_custom_fg_color(item_index, Color(0.95, 0.95, 0.95))
		print("📋 [CharSelect] Survivor listed: %s" % name)

	# Auto-select first character if characters exist
	if not _characters.is_empty():
		roster_list.select(0)
		play_button.disabled = false
		if delete_button:
			delete_button.disabled = false
		var roster_names: Array[String] = []
		for character in _characters:
			roster_names.append(String(character.get("name", "Unnamed")))
		status_label.text = "Select a survivor and press Play."
		if not roster_names.is_empty():
			status_label.text += "\n• " + "\n• ".join(roster_names)
		roster_list.grab_focus()
	else:
		play_button.disabled = true
		if delete_button:
			delete_button.disabled = true
		status_label.text = "No survivors found. Create your first survivor."
		if new_game_mode:
			create_new_button.grab_focus()

	# Allow unlimited characters in offline mode, limit only applies to server storage
	create_new_button.disabled = not _offline and (_characters.size() >= _max_characters)

	if _offline and info.get("from_cache", false):
		info_label.text = "Offline mode: using cached survivors."
	elif _offline:
		info_label.text = "Local roster ready."
	elif info.get("source", "") == "online":
		info_label.text = "Roster synced from server."
	else:
		info_label.text = "Cached roster loaded."

	print("📋 [CharSelect] Updated roster: %d characters" % _characters.size())
	print("📋 [CharSelect] ItemList count: %d" % roster_list.get_item_count())
	print("📋 [CharSelect] Layout debug - ItemList: size=%s, parent_size=%s, visible=%s" % [
		roster_list.size, roster_list.get_parent().size, roster_list.visible
	])

func _on_character_deleted(character_id: String) -> void:
	"""Handle character deletion and refresh the UI"""
	print("🗑️ [CharSelect] Character deleted signal received: %s" % character_id)
	
	# Update local characters array
	for i in range(_characters.size()):
		if String(_characters[i].get("id", "")) == character_id:
			_characters.remove_at(i)
			break
	
	# Rebuild the roster list
	roster_list.clear()
	for character in _characters:
		var name := String(character.get("name", "Unnamed"))
		var level := int(character.get("level", 1))
		var stat_points := int(character.get("available_stat_points", 0))
		var label := "%s — Lv %d (SP %d)" % [name, level, stat_points]
		roster_list.add_item(label)
		var item_index := roster_list.get_item_count() - 1
		roster_list.set_item_custom_fg_color(item_index, Color(0.95, 0.95, 0.95))
	
	# Update UI state based on remaining characters
	if not _characters.is_empty():
		roster_list.select(0)
		play_button.disabled = false
		if delete_button:
			delete_button.disabled = false
		status_label.text = "Character deleted. Select a survivor and press Play."
		roster_list.grab_focus()
	else:
		play_button.disabled = true
		if delete_button:
			delete_button.disabled = true
		status_label.text = "No survivors found. Create your first survivor."
		if new_game_mode:
			create_new_button.grab_focus()
	
	print("📋 [CharSelect] UI refreshed after deletion. %d survivors remaining." % _characters.size())

func _on_create_new_button_pressed() -> void:
	"""Handle create new button press"""
	print("🎯 [CharSelect] Transitioning to character creation")
	get_tree().change_scene_to_file("res://common/UI/CharacterCreation.tscn")

func _on_play_button_pressed() -> void:
	if _characters.is_empty():
		status_label.text = "No survivors available."
		return

	var selected := roster_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a survivor first."
		return

	var index := int(selected[0])
	if index < 0 or index >= _characters.size():
		status_label.text = "Invalid selection."
		return

	var character: Dictionary = _characters[index].duplicate(true)
	CharacterService.set_current_character(character)
	print("✅ [CharSelect] Loading character: %s" % character.get("name", ""))

	# Clear player groups before scene transition to prevent duplicates
	var old_players = get_tree().get_nodes_in_group("player")
	for player in old_players:
		player.remove_from_group("player")
		player.remove_from_group("player_sniper")

	get_tree().change_scene_to_file("res://stages/Stage_Outpost_2D.tscn")

func _on_cancel_button_pressed() -> void:
	print("❌ [CharSelect] Selection cancelled, returning to menu")
	get_tree().change_scene_to_file("res://common/UI/Menu.tscn")

func _on_roster_item_selected(index: int) -> void:
	"""Handle character selection from roster list"""
	print("🎯 [CharSelect] Character selected at index: %d" % index)
	play_button.disabled = false
	if delete_button:
		delete_button.disabled = false

func _on_roster_item_activated(index: int) -> void:
	"""Handle character double-click (activate = double-click to play)"""
	print("🎯 [CharSelect] Character activated at index: %d" % index)
	_on_play_button_pressed()  # Double-click to play directly

func _on_delete_button_pressed() -> void:
	"""Handle delete button press with confirmation"""
	var selected := roster_list.get_selected_items()
	if selected.is_empty():
		status_label.text = "Select a survivor to delete."
		return

	var index := int(selected[0])
	if index < 0 or index >= _characters.size():
		status_label.text = "Invalid selection."
		return

	var character: Dictionary = _characters[index]
	var character_name = String(character.get("name", "Unnamed"))
	var character_id = String(character.get("id", ""))

	print("🗑️ [CharSelect] Delete button pressed for: %s (%s)" % [character_name, character_id])

	# Show confirmation dialog
	var confirmation = "Delete survivor '%s'?\nThis action cannot be undone." % character_name

	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = confirmation
	dialog.title = "Confirm Deletion"
	dialog.ok_button_text = "Delete"
	dialog.cancel_button_text = "Cancel"

	# Connect confirmed signal to perform deletion
	dialog.confirmed.connect(func():
		print("🗑️ [CharSelect] User confirmed deletion for: %s (%s)" % [character_name, character_id])
		CharacterService.delete_character(character_id)
		status_label.text = "Character deleted."
		dialog.queue_free()
	)
	
	# Connect cancelled signal
	dialog.canceled.connect(func():
		print("❌ [CharSelect] User cancelled deletion")
		status_label.text = "Deletion cancelled."
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()

func _apply_accessibility() -> void:
	_apply_high_contrast()
	_apply_font_scale()

func _on_accessibility_changed(_setting: String) -> void:
	_apply_accessibility()

func _apply_high_contrast() -> void:
	if Accessibility.high_contrast:
		dim_rect.color = Color(0, 0, 0, 0.85)
		panel.add_theme_color_override("panel", Color(0.12, 0.12, 0.12, 1))
	else:
		dim_rect.color = Color(0, 0, 0, 0.65)
		panel.add_theme_color_override("panel", Color(0.2, 0.2, 0.24, 1))

func _apply_font_scale() -> void:
	var font_scale := float(Save.get_value("ui_font_scale", 1.0))
	font_scale = clampf(font_scale, 0.8, 1.5)
	root_control.scale = Vector2(font_scale, font_scale)

func _apply_roster_list_theme() -> void:
	if not roster_list:
		return

	# Ensure proper sizing consistent with scene layout
	if roster_list.size_flags_vertical != Control.SIZE_FILL:
		roster_list.size_flags_vertical = Control.SIZE_FILL
		print("📋 [CharSelect] Set roster_list size_flags_vertical to FILL")

	# Add minimum size only if scene doesn't define it
	if roster_list.custom_minimum_size.y == 0:
		roster_list.custom_minimum_size = Vector2(300, 200)
		print("📋 [CharSelect] Set roster_list minimum size to 300x200")

	# Apply theme colors
	var text_color := Color(0.92, 0.92, 0.92, 1.0)
	roster_list.add_theme_color_override("font_color", text_color)
	roster_list.add_theme_color_override("font_color_hover", Color(1, 1, 1, 1))
	roster_list.add_theme_color_override("font_color_selected", Color(1, 1, 1, 1))
	roster_list.add_theme_color_override("selection_color", Color(0.2, 0.6, 0.8, 0.9))
	roster_list.add_theme_color_override("guide_color", Color(0.35, 0.35, 0.4, 0.6))
	roster_list.show()

	# Debug layout information
	print("📋 [CharSelect] ItemList configured: size=%s, flags=%s, visible=%s" % [
		roster_list.size, roster_list.size_flags_vertical, roster_list.visible
	])

func _prime_cached_roster() -> void:
	var cached := CharacterService.get_roster()
	if cached.is_empty():
		return

	var storage_type := CharacterService.get_current_storage_type()
	var info := {
		"source": "cache",
		"from_cache": true,
		"max_characters": CharacterService.get_max_characters(),
		"offline": storage_type == 0,
		"loading": CharacterService.is_loading(),
		"storage_type": ["local", "server", "hybrid"][clampi(storage_type, 0, 2)]
	}
	print("📁 [CharSelect] Priming roster from cache (%d survivors)" % cached.size())
	_on_roster_updated(cached, info)

func _retry_refresh_if_empty() -> void:
	if _characters.is_empty() or roster_list.item_count == 0:
		print("🔁 [CharSelect] Roster empty after first refresh, retrying...")
		CharacterService.refresh_roster()
	elif _decided_offline:
		status_label.text = "Select a survivor and press Play."
