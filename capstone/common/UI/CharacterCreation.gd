extends CanvasLayer

## Dedicated Character Creation Screen
## Clean, streamlined interface focused solely on creating new characters
## Full scene implementation

@onready var root_control: Control = $Root
@onready var dim_rect: ColorRect = $Root/Dim
@onready var panel: PanelContainer = $Root/Center/Panel
@onready var title_label: Label = $Root/Center/Panel/Margin/VBox/TitleLabel
@onready var name_input: LineEdit = $Root/Center/Panel/Margin/VBox/NameSection/NameInput
@onready var name_error: Label = $Root/Center/Panel/Margin/VBox/NameSection/NameError

# Stat controls
@onready var strength_slider: HSlider = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/StrengthSlider
@onready var strength_value: Label = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/StrengthValue
@onready var dexterity_slider: HSlider = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/DexteritySlider
@onready var dexterity_value: Label = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/DexterityValue
@onready var agility_slider: HSlider = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/AgilitySlider
@onready var agility_value: Label = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/AgilityValue
@onready var endurance_slider: HSlider = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/EnduranceSlider
@onready var endurance_value: Label = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/EnduranceValue
@onready var accuracy_slider: HSlider = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/AccuracySlider
@onready var accuracy_value: Label = $Root/Center/Panel/Margin/VBox/StatsSection/StatsGrid/AccuracyValue

@onready var points_remaining_label: Label = $Root/Center/Panel/Margin/VBox/StatsSection/PointsRemainingLabel
@onready var status_label: Label = $Root/Center/Panel/Margin/VBox/StatusLabel
@onready var create_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/CreateButton
@onready var cancel_button: Button = $Root/Center/Panel/Margin/VBox/ButtonRow/CancelButton

const TOTAL_STAT_POINTS: int = 25
const MIN_STAT_VALUE: int = 1
const MAX_STAT_VALUE: int = 10

var _stat_sliders: Array[HSlider] = []
var _stat_values: Array[Label] = []
var _pending_create: bool = false
var _available_points: int = TOTAL_STAT_POINTS

func _ready() -> void:
    _initialize_character_creation()
    _setup_stat_controls()
    _apply_accessibility()
    if OS.has_feature("web"):
        _call_deferred("_apply_fullscreen_web_layout")
    
    if not Accessibility.setting_changed.is_connected(_on_accessibility_changed):
        Accessibility.setting_changed.connect(_on_accessibility_changed)
    if not CharacterService.character_created.is_connected(_on_character_created):
        CharacterService.character_created.connect(_on_character_created)
    if not CharacterService.character_operation_failed.is_connected(_on_character_operation_failed):
        CharacterService.character_operation_failed.connect(_on_character_operation_failed)
    
    name_input.grab_focus()
    _update_stat_display()

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
    if CharacterService.character_created.is_connected(_on_character_created):
        CharacterService.character_created.disconnect(_on_character_created)
    if CharacterService.character_operation_failed.is_connected(_on_character_operation_failed):
        CharacterService.character_operation_failed.disconnect(_on_character_operation_failed)

func _initialize_character_creation() -> void:
    """Initialize character creation with default stats"""
    title_label.text = "Create New Survivor"
    status_label.text = "Enter survivor name and distribute stat points."
    name_error.visible = false
    
    # Set default stats (distribute points evenly)
    var base_points = TOTAL_STAT_POINTS / 5  # 5 stats
    var remaining = TOTAL_STAT_POINTS % 5
    
    strength_slider.value = base_points
    dexterity_slider.value = base_points
    agility_slider.value = base_points
    endurance_slider.value = base_points
    accuracy_slider.value = base_points + remaining  # Add remainder to accuracy
    
    print("✅ [CharCreation] Initialized with default stat distribution")

func _setup_stat_controls() -> void:
    """Setup stat sliders and connect signals"""
    _stat_sliders = [strength_slider, dexterity_slider, agility_slider, endurance_slider, accuracy_slider]
    _stat_values = [strength_value, dexterity_value, agility_value, endurance_value, accuracy_value]
    
    for i in range(_stat_sliders.size()):
        var slider = _stat_sliders[i]
        slider.min_value = MIN_STAT_VALUE
        slider.max_value = MAX_STAT_VALUE
        slider.step = 1
        slider.value_changed.connect(_on_stat_changed)

func _on_stat_changed(_value: float) -> void:
    """Handle stat slider changes with point allocation validation"""
    var total_assigned = 0
    for slider in _stat_sliders:
        total_assigned += int(slider.value)
    
    # If over limit, adjust the most recently changed slider
    if total_assigned > TOTAL_STAT_POINTS:
        var excess = total_assigned - TOTAL_STAT_POINTS
        var last_changed = get_viewport().gui_get_focus_owner() as HSlider
        if last_changed and last_changed in _stat_sliders:
            last_changed.value = max(MIN_STAT_VALUE, last_changed.value - excess)
    
    _update_stat_display()

func _update_stat_display() -> void:
    """Update stat value labels and remaining points"""
    var total_used = 0
    
    for i in range(_stat_sliders.size()):
        var value = int(_stat_sliders[i].value)
        _stat_values[i].text = str(value)
        total_used += value
    
    _available_points = TOTAL_STAT_POINTS - total_used
    points_remaining_label.text = "Points Remaining: %d" % _available_points
    
    # Update button state
    _update_create_button()

func _update_create_button() -> void:
    """Update create button state based on validation"""
    var character_name = name_input.text.strip_edges()
    var name_valid = character_name.length() >= 3 and character_name.length() <= 20
    var points_used = _available_points == 0
    
    create_button.disabled = _pending_create or not name_valid or not points_used
    
    if not name_valid:
        status_label.text = "Survivor name must be 3-20 characters."
    elif not points_used:
        status_label.text = "Please allocate all %d stat points." % TOTAL_STAT_POINTS
    else:
        status_label.text = "Ready to create survivor."

func _on_name_input_text_changed(_new_text: String) -> void:
    """Handle name input changes"""
    name_error.visible = false
    _update_create_button()

func _on_create_button_pressed() -> void:
    """Create the character with current settings"""
    if _pending_create:
        return
    
    var character_name = name_input.text.strip_edges()

    # Final validation
    if character_name.length() < 3 or character_name.length() > 20:
        name_error.text = "Name must be 3-20 characters long."
        name_error.visible = true
        name_input.grab_focus()
        return
    
    if _available_points != 0:
        status_label.text = "Please allocate all stat points."
        return
    
    _pending_create = true
    status_label.text = "Creating survivor..."
    _update_create_button()
    
    # Create character payload
    var character_data = {
        "name": character_name,
        "strength": int(strength_slider.value),
        "dexterity": int(dexterity_slider.value),
        "agility": int(agility_slider.value),
        "endurance": int(endurance_slider.value),
        "accuracy": int(accuracy_slider.value)
    }
    
    print("📋 [CharCreation] Creating character: %s" % character_data)
    CharacterService.create_character(character_data)

func _on_cancel_button_pressed() -> void:
    """Cancel character creation"""
    print("❌ [CharCreation] Creation cancelled, returning to menu")
    get_tree().change_scene_to_file("res://common/UI/Menu.tscn")

func _on_character_created(character: Dictionary) -> void:
    """Handle successful character creation"""
    _pending_create = false
    status_label.text = "Survivor created successfully!"
    
    print("✅ [CharCreation] Character created successfully: %s" % character.get("name", ""))
    
    # Set as current character and go to game
    CharacterService.set_current_character(character)

    # Clear player groups before scene transition to prevent duplicates
    var old_players = get_tree().get_nodes_in_group("player")
    for player in old_players:
        player.remove_from_group("player")
        player.remove_from_group("player_sniper")

    # Short delay for user feedback, then go to game
    await get_tree().create_timer(1.0).timeout
    get_tree().change_scene_to_file("res://stages/Stage_Outpost_2D.tscn")

func _on_character_operation_failed(message: String) -> void:
    """Handle character creation failure"""
    _pending_create = false
    status_label.text = message
    _update_create_button()
    
    print("❌ [CharCreation] Creation failed: %s" % message)

func _apply_accessibility() -> void:
    """Apply accessibility settings"""
    _apply_high_contrast()
    _apply_font_scale()

func _on_accessibility_changed(_setting: String) -> void:
    """Handle accessibility setting changes"""
    _apply_accessibility()

func _apply_high_contrast() -> void:
    """Apply high contrast theme"""
    if Accessibility.high_contrast:
        dim_rect.color = Color(0, 0, 0, 0.9)
        panel.add_theme_color_override("panel", Color(0.1, 0.1, 0.1, 1))
    else:
        dim_rect.color = Color(0, 0, 0, 0.7)
        panel.add_theme_color_override("panel", Color(0.15, 0.15, 0.18, 1))

func _apply_font_scale() -> void:
    """Apply font scaling"""
    var font_scale := float(Save.get_value("ui_font_scale", 1.0))
    font_scale = clampf(font_scale, 0.8, 1.5)
    root_control.scale = Vector2(font_scale, font_scale)