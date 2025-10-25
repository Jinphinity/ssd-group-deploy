extends CharacterBody2D

## 2D Trader NPC for in-world market access
## Integrates with existing MarketController and MarketUI systems

class_name Trader2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_prompt: Label = $InteractionPrompt

var is_player_nearby: bool = false
var current_customer = null

signal market_interaction_started(trader: Trader2D)
signal market_interaction_ended(trader: Trader2D)

func _play_animation_safe(animation_name: String) -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		return
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)
	elif animated_sprite.sprite_frames.get_animation_names().size() > 0:
		# Fallback to first available animation
		animated_sprite.play(animated_sprite.sprite_frames.get_animation_names()[0])

func _ready() -> void:
	# Set up interaction area
	interaction_area.body_entered.connect(_on_player_entered_interaction_area)
	interaction_area.body_exited.connect(_on_player_exited_interaction_area)
	
	# Hide interaction prompt initially
	interaction_prompt.visible = false
	
	# Set up animation if available
	_play_animation_safe("idle")
	
	# Add to trader group for easy access
	add_to_group("traders")
	add_to_group("npcs")

func _input(event: InputEvent) -> void:
	if is_player_nearby and Input.is_action_just_pressed("interact"):
		_open_market()

func _on_player_entered_interaction_area(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		current_customer = body
		interaction_prompt.visible = true
		interaction_prompt.text = "Press E to trade"
		print("👤 Player can now interact with trader")

func _on_player_exited_interaction_area(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		current_customer = null
		interaction_prompt.visible = false
		_close_market()
		print("👤 Player left trader interaction area")

func _open_market() -> void:
	"""Open the market UI for trading"""
	if not await AuthController.require_authentication():
		_show_message("Please login to access the market")
		return
	
	# Close other UIs first via Game singleton
	if has_node("/root/Game"):
		var game = get_node("/root/Game")
		if game.has_method("_close_all_uis_except"):
			game._close_all_uis_except("market")
	
	# Get the market UI
	var market_ui = get_tree().get_first_node_in_group("market_ui")
	if not market_ui:
		# Try to find it as a child of the scene
		market_ui = get_tree().current_scene.get_node_or_null("MarketUI")
	
	if market_ui:
		market_ui.visible = true

		# Focus the buy list for proper keyboard navigation (CanvasLayer can't receive focus)
		var buy_list = market_ui.get_node_or_null("Root/Panel/BuyList")
		if buy_list and buy_list.has_method("grab_focus"):
			buy_list.grab_focus()

		market_interaction_started.emit(self)
		_show_message("Welcome to the market!")
		print("🛒 Market opened by trader")
	else:
		_show_message("Market system unavailable")
		print("❌ Market UI not found")

func _close_market() -> void:
	"""Close the market UI"""
	var market_ui = get_tree().get_first_node_in_group("market_ui")
	if not market_ui:
		market_ui = get_tree().current_scene.get_node_or_null("MarketUI")
	
	if market_ui and market_ui.visible:
		market_ui.visible = false
		market_interaction_ended.emit(self)
		print("🛒 Market closed by trader")

func _show_message(text: String) -> void:
	"""Show a message to the player"""
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_message"):
		hud.show_message(text)
	else:
		print("📢 Trader: %s" % text)

# Animation methods for different trader states
func play_idle_animation() -> void:
	_play_animation_safe("idle")

func play_greeting_animation() -> void:
	if animated_sprite:
		animated_sprite.play("greeting")

func play_trading_animation() -> void:
	if animated_sprite:
		animated_sprite.play("trading")

# Methods for interaction with the player
func interact(player: Node2D) -> void:
	"""Called when player interacts with trader"""
	_open_market()

func get_trader_info() -> Dictionary:
	"""Get trader information for UI display"""
	return {
		"name": "Marcus the Trader",
		"description": "Veteran survivor who trades supplies for survival",
		"specialties": ["Weapons", "Ammunition", "Medical Supplies"],
		"location": "Outpost Market District"
	}
