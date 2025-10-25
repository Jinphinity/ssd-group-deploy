extends Node
class_name CraftingController

signal recipe_started(recipe_id: String, duration: float)
signal recipe_completed(recipe_id: String, success: bool, outputs: Array)
signal recipe_failed(recipe_id: String, reason: String)
signal queue_updated(queue: Array)

const ItemDatabaseClass = preload("res://common/Data/ItemDatabase.gd")

var recipes: Dictionary = {}
var active_jobs: Array = []
var queue: Array = []
var is_paused: bool = false
var auto_start: bool = true
var max_parallel_jobs: int = 1
var inventory: Inventory = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	load_recipes()

func set_inventory(inv: Inventory) -> void:
	inventory = inv

func load_recipes(path: String = "res://config/recipes/recipes.json") -> void:
	recipes.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CraftingController: Failed to open recipes at %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("CraftingController: Invalid recipe manifest")
		return
	var recipe_list: Array = json.data.get("recipes", [])
	for entry in recipe_list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var recipe_id: String = entry.get("id", "")
		if recipe_id == "":
			continue
		recipes[recipe_id] = entry

func get_recipes() -> Array:
	var arr: Array = []
	for recipe in recipes.values():
		arr.append(recipe.duplicate(true))
	return arr

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}).duplicate(true)

func can_craft(recipe_id: String) -> Dictionary:
	var recipe: Variant = recipes.get(recipe_id)
	if recipe == null:
		return {"ok": false, "reason": "Recipe not found"}
	if inventory == null:
		return {"ok": false, "reason": "Inventory unavailable"}
	var inputs: Array = recipe.get("inputs", [])
	for requirement in inputs:
		var item_id: String = requirement.get("item_id", "")
		var quantity := int(requirement.get("quantity", 1))
		if item_id == "":
			return {"ok": false, "reason": "Invalid ingredient"}
		if not _inventory_has_item(item_id, quantity):
			return {"ok": false, "reason": "Missing %s x%d" % [item_id, quantity]}
	return {"ok": true}

func queue_recipe(recipe_id: String) -> Dictionary:
	var check := can_craft(recipe_id)
	if not check.get("ok", false):
		recipe_failed.emit(recipe_id, check.get("reason", "Unknown error"))
		return check
	queue.append({"id": recipe_id})
	queue_updated.emit(queue.duplicate(true))
	if auto_start:
		_process_queue()
	return check

func cancel_recipe(index: int) -> bool:
	if index < 0 or index >= queue.size():
		return false
	queue.remove_at(index)
	queue_updated.emit(queue.duplicate(true))
	return true

func set_paused(paused: bool) -> void:
	is_paused = paused
	if not is_paused:
		_process_queue()

func _process_queue() -> void:
	if is_paused:
		return
	while queue.size() > 0 and active_jobs.size() < max_parallel_jobs:
		var job: Variant = queue.pop_front()
		var recipe_id := String(job.get("id", ""))
		if recipe_id == "":
			continue
		var recipe: Variant = recipes.get(recipe_id, null)
		if recipe == null:
			recipe_failed.emit(recipe_id, "Recipe not found")
			continue
		var check := can_craft(recipe_id)
		if not check.get("ok", false):
			recipe_failed.emit(recipe_id, check.get("reason", "Unavailable"))
			continue
		_consume_inputs(recipe)
		var timer := Timer.new()
		timer.wait_time = float(recipe.get("duration", 5.0))
		timer.one_shot = true
		timer.autostart = true
		add_child(timer)
		var job_data := {
			"id": recipe_id,
			"timer": timer,
			"recipe": recipe
		}
		timer.timeout.connect(_on_job_completed.bind(job_data))
		recipe_started.emit(recipe_id, timer.wait_time)
		active_jobs.append(job_data)
	queue_updated.emit(queue.duplicate(true))

func _on_job_completed(job_data: Dictionary) -> void:
	var recipe_id := String(job_data.get("id", ""))
	var recipe: Dictionary = job_data.get("recipe", {})
	var timer: Timer = job_data.get("timer")
	if timer and timer.is_inside_tree():
		timer.queue_free()
	active_jobs = active_jobs.filter(func(job): return job.get("timer") != timer)
	var success_chance := float(recipe.get("success_chance", 1.0))
	var success := _rng_chance(success_chance)
	if success:
		var outputs := _grant_outputs(recipe)
		recipe_completed.emit(recipe_id, true, outputs)
	else:
		recipe_completed.emit(recipe_id, false, [])
	_process_queue()

func _rng_chance(chance: float) -> bool:
	chance = clamp(chance, 0.0, 1.0)
	return _rng.randf() <= chance

func _inventory_has_item(item_id: String, quantity: int) -> bool:
	var count := 0
	for item in inventory.items:
		if item.get("item_id", item.get("id", "")) == item_id:
			count += int(item.get("quantity", 1))
			if count >= quantity:
				return true
	return false

func _consume_inputs(recipe: Dictionary) -> void:
	var inputs: Array = recipe.get("inputs", [])
	for requirement in inputs:
		var item_id: String = requirement.get("item_id", "")
		var quantity := int(requirement.get("quantity", 1))
		_consume_item(item_id, quantity)

func _consume_item(item_id: String, quantity: int) -> void:
	var remaining := quantity
	for i in range(inventory.items.size() - 1, -1, -1):
		var item: Dictionary = inventory.items[i]
		if item.get("item_id", item.get("id", "")) != item_id:
			continue
		var stack_quantity := int(item.get("quantity", 1))
		if stack_quantity <= remaining:
			remaining -= stack_quantity
			inventory.remove_item(i)
		else:
			item["quantity"] = stack_quantity - remaining
			inventory.item_updated.emit(item)
			remaining = 0
		if remaining <= 0:
			break
	inventory.inventory_changed.emit()

func _grant_outputs(recipe: Dictionary) -> Array:
	var outputs: Array = []
	for entry in recipe.get("outputs", []):
		var item_id: String = entry.get("item_id", "")
		var quantity := int(entry.get("quantity", 1))
		if item_id == "" or quantity <= 0:
			continue
		var item_instance := ItemDatabaseClass.create_item_instance(item_id, quantity)
		if item_instance.is_empty():
			continue
		outputs.append(item_instance)
		inventory.add_item(item_instance)
	inventory.inventory_changed.emit()
	return outputs

func clear_queue() -> void:
	for job in active_jobs:
		var timer: Timer = job.get("timer")
		if timer and timer.is_inside_tree():
			timer.queue_free()
	active_jobs.clear()
	queue.clear()
	queue_updated.emit(queue.duplicate(true))

func get_queue() -> Array:
	return queue.duplicate(true)

func get_active_jobs() -> Array:
	return active_jobs.duplicate(true)
