extends CanvasLayer

@export var player_path: NodePath

@onready var health_bar: ProgressBar = $Control/HealthBarContainer/HealthBar
@onready var health_text: Label = $Control/HealthBarContainer/HealthText

@onready var mana_bar: ProgressBar = $Control/ManaBarContainer/ManaBar
@onready var mana_text: Label = $Control/ManaBarContainer/ManaText

@onready var xp_bar: ProgressBar = $Control/XpBarContainer/XpBar

@onready var lvl_text: Label = $Control/LVLContainer/LevelText
@onready var coin_text: Label = $Control/Coin_Inventory/CoinText
@onready var inventory_text: Label = $Control/Coin_Inventory/InventoryText

var player: Node = null
var health_component: HealthComponent = null
var inventory = null

func _ready() -> void:
	if player_path != NodePath():
		player = get_node_or_null(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	health_component = player.get_node_or_null("HealthComponent") as HealthComponent
	inventory = player.get_node_or_null("PlayerInventory")

	if health_component != null:
		if not health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.connect(_on_health_changed)

		_on_health_changed(health_component.current_health, health_component.max_health)

	if inventory != null:
		if inventory.has_signal("coins_changed") and not inventory.coins_changed.is_connected(_on_coins_changed):
			inventory.coins_changed.connect(_on_coins_changed)

		if inventory.has_signal("xp_changed") and not inventory.xp_changed.is_connected(_on_xp_changed):
			inventory.xp_changed.connect(_on_xp_changed)

		if inventory.has_signal("item_added") and not inventory.item_added.is_connected(_on_item_added):
			inventory.item_added.connect(_on_item_added)

		_on_coins_changed(inventory.coins)
		_on_xp_changed(inventory.xp, inventory.level)
		_update_inventory_text()

	_update_mana_display(100, 100) # midlertidig placeholder

func _on_health_changed(current_health: int, max_health: int) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		_set_health_bar_color(float(current_health) / float(max_health) * 100.0)

	if health_text:
		health_text.text = str(current_health) + " / " + str(max_health)

func _on_coins_changed(new_amount: int) -> void:
	if coin_text:
		coin_text.text = str(new_amount)

func _on_xp_changed(current_xp: int, level: int) -> void:
	if inventory == null:
		return

	var xp_to_next: int = inventory.get_xp_to_next_level()

	if xp_bar:
		xp_bar.max_value = xp_to_next
		xp_bar.value = current_xp


	if lvl_text:
		lvl_text.text = str(level)

func _on_item_added(_item_data) -> void:
	_update_inventory_text()

func _update_inventory_text() -> void:
	if inventory_text == null or inventory == null:
		return

	var current_items: int = inventory.get_item_count()
	var max_items := 20
	inventory_text.text = str(current_items) + " / " + str(max_items)

func _update_mana_display(current_mana: int, max_mana: int) -> void:
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana

	if mana_text:
		mana_text.text = str(current_mana) + " / " + str(max_mana)

func _set_health_bar_color(percent: float) -> void:
	var fill_style := health_bar.get_theme_stylebox("fill")

	if fill_style == null:
		return

	var style := fill_style.duplicate()

	if style is StyleBoxFlat:
		if percent >= 60.0:
			style.bg_color = Color("4CAF50")
		elif percent >= 30.0:
			style.bg_color = Color("FBC02D")
		else:
			style.bg_color = Color("D32F2F")

		health_bar.add_theme_stylebox_override("fill", style)
