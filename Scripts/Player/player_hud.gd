extends CanvasLayer

@export var player_path: NodePath

@onready var ability_slots := [
	$Control/AbilityBar/Slot1,
	$Control/AbilityBar/Slot2,
	$Control/AbilityBar/Slot3,
	$Control/AbilityBar/Slot4
]

@onready var potion_slot: Control = $Control/PotionSlot
@onready var potion_border = $Control/PotionSlot/Border
@onready var potion_icon: TextureRect = $Control/PotionSlot/Icon
@onready var potion_overlay: ColorRect = $Control/PotionSlot/CooldownOverlay
@onready var potion_key_label: Label = $Control/PotionSlot/KeyLabel
@onready var potion_name_label: Label = $Control/PotionSlot/NameLabel
@onready var potion_count_label: Label = $Control/PotionSlot/CooldownLabel

@onready var health_bar: ProgressBar = $Control/HealthBarContainer/HealthBar
@onready var health_text: Label = $Control/HealthBarContainer/HealthText

@onready var mana_bar: ProgressBar = $Control/ManaBarContainer/ManaBar
@onready var mana_text: Label = $Control/ManaBarContainer/ManaText

@onready var stamina_bar: ProgressBar = $Control/StaminaBarContainer/StaminaBar
@onready var stamina_text: Label = $Control/StaminaBarContainer/StaminaText

@onready var xp_bar: ProgressBar = $Control/XpBarContainer/XpBar

@onready var lvl_text: Label = $Control/LVLContainer/LevelText
@onready var coin_text: Label = $Control/Coin_Inventory/CoinText
@onready var inventory_text: Label = $Control/Coin_Inventory/InventoryText

var player: Node = null
var health_component: HealthComponent = null
var inventory = null
var player_script = null

func _ready() -> void:
	if player_path != NodePath():
		player = get_node_or_null(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		return

	player_script = player
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

		if inventory.has_signal("inventory_changed") and not inventory.inventory_changed.is_connected(_on_inventory_changed):
			inventory.inventory_changed.connect(_on_inventory_changed)

		if inventory.has_signal("active_potion_changed") and not inventory.active_potion_changed.is_connected(_on_active_potion_changed):
			inventory.active_potion_changed.connect(_on_active_potion_changed)

		_on_coins_changed(inventory.coins)
		_on_xp_changed(inventory.xp, inventory.level)
		_update_inventory_text()

	if player_script != null:
		_update_stamina_display(player_script.current_stamina, player_script.max_stamina)
		_update_mana_display(player_script.current_mana, player_script.max_mana)

	_update_potion_slot()


func _process(_delta: float) -> void:
	if player_script == null:
		return

	_update_stamina_display(player_script.current_stamina, player_script.max_stamina)
	_update_mana_display(player_script.current_mana, player_script.max_mana)
	_update_ability_bar()
	_update_potion_slot()


func _update_ability_bar() -> void:
	if player_script == null:
		return

	var abilities: Array = player_script.get_current_abilities()

	for i in range(ability_slots.size()):
		var slot = ability_slots[i]
		var border = slot.get_node("Border")
		var icon_rect: TextureRect = slot.get_node("Icon")
		var overlay: ColorRect = slot.get_node("CooldownOverlay")
		var key_label: Label = slot.get_node("KeyLabel")
		var cooldown_label: Label = slot.get_node("CooldownLabel")
		var name_label: Label = slot.get_node("NameLabel")

		key_label.text = str(i + 1)
		name_label.visible = false

		if i >= abilities.size():
			icon_rect.texture = null
			overlay.visible = false
			cooldown_label.text = ""
			border.modulate = Color(0.4, 0.4, 0.4, 1.0)
			slot.modulate = Color(0.6, 0.6, 0.6, 1.0)
			continue

		var action: CombatAction = abilities[i]

		icon_rect.texture = action.icon

		var remaining: float = player_script.get_action_cooldown_remaining(action.action_id)
		var has_resources: bool = player_script.has_enough_resources_for_action(action)

		if remaining > 0.0:
			overlay.visible = true
			cooldown_label.text = str(snapped(remaining, 0.1))
			border.modulate = Color(0.5, 0.5, 0.5, 1.0)
			slot.modulate = Color(0.75, 0.75, 0.75, 1.0)
		else:
			overlay.visible = false
			cooldown_label.text = ""

			if has_resources:
				border.modulate = Color(1.2, 1.1, 0.6, 1.0)
				slot.modulate = Color(1, 1, 1, 1)
			else:
				border.modulate = Color(0.7, 0.7, 0.7, 1.0)
				slot.modulate = Color(0.7, 0.7, 0.7, 1.0)


func _update_potion_slot() -> void:
	if inventory == null:
		return

	if potion_slot == null:
		return

	var potion: ItemData = inventory.get_active_health_potion()

	potion_key_label.text = "R"
	potion_name_label.visible = false
	potion_overlay.visible = false

	if potion == null:
		potion_icon.texture = null
		potion_count_label.text = ""
		potion_border.modulate = Color(0.4, 0.4, 0.4, 1.0)
		potion_slot.modulate = Color(0.6, 0.6, 0.6, 1.0)
		return

	potion_icon.texture = potion.icon
	potion_count_label.text = "x" + str(potion.quantity)
	potion_border.modulate = Color(1.0, 0.9, 0.9, 1.0)
	potion_slot.modulate = Color(1, 1, 1, 1)


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
	_update_potion_slot()


func _on_inventory_changed() -> void:
	_update_inventory_text()
	_update_potion_slot()


func _on_active_potion_changed(_item_data) -> void:
	_update_potion_slot()


func _update_inventory_text() -> void:
	if inventory_text == null or inventory == null:
		return

	var current_items: int = inventory.get_item_count()
	var max_items: int = inventory.max_slots
	inventory_text.text = str(current_items) + " / " + str(max_items)


func _update_mana_display(current_mana: float, max_mana: float) -> void:
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.value = current_mana

	if mana_text:
		mana_text.text = str(int(current_mana)) + " / " + str(int(max_mana))


func _update_stamina_display(current_stamina: float, max_stamina: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina

	if stamina_text:
		stamina_text.text = str(int(current_stamina)) + " / " + str(int(max_stamina))


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
