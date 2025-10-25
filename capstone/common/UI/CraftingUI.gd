extends CanvasLayer
class_name CraftingUI

@onready var panel := $Panel
@onready var recipe_list: ItemList = $Panel/VBox/HBox/RecipeList
@onready var requirements: RichTextLabel = $Panel/VBox/HBox/Details/Requirements
@onready var title_label: Label = $Panel/VBox/HBox/Details/Title
@onready var craft_button: Button = $Panel/VBox/Buttons/CraftButton
@onready var cancel_button: Button = $Panel/VBox/Buttons/CancelButton
@onready var progress_bar: ProgressBar = $Panel/VBox/ProgressBar
@onready var close_button: Button = $Panel/CloseButton

var controller: CraftingController = null
var inventory: Inventory = null
var recipes: Array = []
var _active_recipe_id: String = ""
var _visible: bool = false

func _ready() -> void:

	visible = false
	panel.visible = false
	add_to_group("crafting_ui")
	set_process_unhandled_input(true)

	recipe_list.item_selected.connect(_on_recipe_selected)
	craft_button.pressed.connect(_on_craft_pressed)
	cancel_button.pressed.connect(func(): _set_visible(false))
	close_button.pressed.connect(func(): _set_visible(false))
	progress_bar.visible = false

func set_controller(controller_ref: CraftingController) -> void:
	controller = controller_ref
	if controller:
		controller.queue_updated.connect(_on_queue_updated)
		controller.recipe_started.connect(_on_recipe_started)
		controller.recipe_completed.connect(_on_recipe_completed)
		_load_recipes()

func set_inventory(inv: Inventory) -> void:
	inventory = inv

func _set_visible(flag: bool) -> void:
	_visible = flag
	visible = flag
	panel.visible = flag
	close_button.visible = flag
	if flag:
		_load_recipes()
		_update_requirements()

func toggle() -> void:
	_set_visible(not _visible)

# Input handling re-enabled - UIIntegrationManager not working correctly
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("crafting"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _visible and event.is_action_just_pressed("ui_cancel"):
		_set_visible(false)
		get_viewport().set_input_as_handled()

func _load_recipes() -> void:
	if controller == null:
		return
	recipes = controller.get_recipes()
	recipe_list.clear()
	for recipe in recipes:
		var label = recipe.get("name", recipe.get("id", "Recipe"))
		recipe_list.add_item(label)
	if recipes.size() > 0:
		recipe_list.select(0)
		_on_recipe_selected(0)

func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= recipes.size():
		_active_recipe_id = ""
		_update_requirements()
		return
	var recipe: Dictionary = recipes[index]
	_active_recipe_id = recipe.get("id", "")
	title_label.text = recipe.get("name", _active_recipe_id)
	_update_requirements()

func _update_requirements() -> void:
	if _active_recipe_id == "":
		requirements.bbcode_text = "[i]Select a recipe to see details.[/i]"
		craft_button.disabled = true
		return
	var recipe: Dictionary = controller.get_recipe(_active_recipe_id)
	var lines: Array[String] = []
	lines.append("[b]Inputs[/b]")
	for req in recipe.get("inputs", []):
		var name: String = _resolve_item_name(req.get("item_id", ""))
		var quantity := int(req.get("quantity", 1))
		lines.append("• %s x%d" % [name, quantity])
	lines.append("")
	lines.append("[b]Outputs[/b]")
	for out in recipe.get("outputs", []):
		var name: String = _resolve_item_name(out.get("item_id", ""))
		var quantity := int(out.get("quantity", 1))
		lines.append("• %s x%d" % [name, quantity])
	lines.append("")
	lines.append("[b]Duration:[/b] %.1f s" % float(recipe.get("duration", 5.0)))
	var chance := float(recipe.get("success_chance", 1.0)) * 100.0
	lines.append("[b]Success Chance:[/b] %.0f%%" % chance)
	requirements.bbcode_text = "\n".join(lines)
	var check: Dictionary = controller.can_craft(_active_recipe_id)
	craft_button.disabled = not check.get("ok", false)

func _resolve_item_name(item_id: String) -> String:
	var def: Dictionary = ItemDatabase.get_item_definition(item_id)
	if not def.is_empty():
		return def.get("name", item_id)
	return item_id

func _on_craft_pressed() -> void:
	if _active_recipe_id == "":
		return
	controller.queue_recipe(_active_recipe_id)

func _on_queue_updated(_queue: Array) -> void:
	# Future: display queue list
	pass

func _on_recipe_started(recipe_id: String, duration: float) -> void:
	if recipe_id != _active_recipe_id:
		return
	progress_bar.visible = true
	progress_bar.value = 0
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func():
		progress_bar.visible = false
		progress_bar.value = 0
	)
	add_child(timer)

func _on_recipe_completed(recipe_id: String, success: bool, _outputs: Array) -> void:
	if recipe_id == _active_recipe_id:
		progress_bar.visible = false
		progress_bar.value = 0
	_update_requirements()

func show_ui() -> void:
	_set_visible(true)

func hide_ui() -> void:
	_set_visible(false)

func is_ui_open() -> bool:
	return _visible
