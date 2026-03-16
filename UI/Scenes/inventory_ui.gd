extends CanvasLayer

const ITEM_SLOT_SCENE := preload("res://UI/Scenes/item_slot.tscn")

@onready var level_label: Label = find_child("LevelLabel", true, false) as Label
@onready var coins_label: Label = find_child("CoinsLabel", true, false) as Label
@onready var stats_text: RichTextLabel = find_child("StatsText", true, false) as RichTextLabel
@onready var inventory_grid: GridContainer = find_child("InventoryGrid", true, false) as GridContainer

@onready var main_hand_icon: TextureRect = find_child("MainHandIcon", true, false) as TextureRect
@onready var off_hand_icon: TextureRect = find_child("OffHandIcon", true, false) as TextureRect
@onready var off_hand_label: Label = find_child("OffHandLabel", true, false) as Label

@onready var main_hand_button: Button = find_child("MainHandButton", true, false) as Button
@onready var off_hand_button: Button = find_child("OffHandButton", true, false) as Button

@onready var detail_title: Label = find_child("DetailTitle", true, false) as Label
@onready var detail_rarity: Label = find_child("DetailRarity", true, false) as Label
@onready var detail_type: Label = find_child("DetailType", true, false) as Label
@onready var detail_stats: RichTextLabel = find_child("DetailStats", true, false) as RichTextLabel
@onready var detail_action_button: Button = find_child("DetailActionButton", true, false) as Button
@onready var detail_info_label: Label = find_child("DetailInfoLabel", true, false) as Label
@onready var main_hand_slot: Panel = find_child("MainHandSlot", true, false) as Panel
@onready var off_hand_slot: Panel = find_child("OffHandSlot", true, false) as Panel

var player_inventory: PlayerInventory = null
var selected_item: ItemData = null

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common":
			return Color("bfc7d5")
		"uncommon":
			return Color("5ec46e")
		"rare":
			return Color("4a8dff")
		"epic":
			return Color("a56cff")
		"legendary":
			return Color("ffb347")
		_:
			return Color.WHITE


func _ready() -> void:
	visible = false
	add_to_group("inventory_ui")
	call_deferred("_find_player_inventory")

	if detail_action_button != null:
		detail_action_button.pressed.connect(_on_detail_action_button_pressed)

	if main_hand_button != null:
		main_hand_button.pressed.connect(_on_main_hand_pressed)

	if off_hand_button != null:
		off_hand_button.pressed.connect(_on_off_hand_pressed)

func _find_player_inventory() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		print("InventoryUI: player not found")
		return

	player_inventory = player.get_node_or_null("PlayerInventory") as PlayerInventory
	if player_inventory == null:
		print("InventoryUI: PlayerInventory not found on player")
		return

	player_inventory.inventory_changed.connect(_refresh_ui)
	player_inventory.coins_changed.connect(_on_coins_changed)
	player_inventory.xp_changed.connect(_on_xp_changed)
	player_inventory.equipment_changed.connect(_refresh_ui)
	player_inventory.stats_changed.connect(_refresh_ui)

	_refresh_ui()

func _refresh_ui() -> void:
	if player_inventory == null:
		return

	if level_label != null:
		level_label.text = "Level %d" % player_inventory.level

	if coins_label != null:
		coins_label.text = str(player_inventory.coins)

	var total_stats := player_inventory.get_total_stats()

	if stats_text != null:
		stats_text.text = ""
		stats_text.append_text("Health: %d\n" % int(total_stats.get("max_health", 0)))
		stats_text.append_text("Damage: %d\n" % int(total_stats.get("damage", 0)))
		stats_text.append_text("Defense: %d\n" % int(total_stats.get("defense", 0)))
		stats_text.append_text("Crit Chance: %d\n" % int(total_stats.get("crit_chance", 0)))
		stats_text.append_text("Attack Speed: %d\n" % int(total_stats.get("attack_speed", 0)))

	_refresh_equipment_ui()
	_refresh_inventory_grid()
	_refresh_detail_panel()

func _refresh_equipment_ui() -> void:
	if player_inventory == null:
		return

	# Main hand icon + slot style
	if main_hand_icon != null:
		if player_inventory.equipped_main_hand != null and player_inventory.equipped_main_hand.icon != null:
			main_hand_icon.texture = player_inventory.equipped_main_hand.icon
		else:
			main_hand_icon.texture = null

	if main_hand_slot != null:
		if player_inventory.equipped_main_hand != null:
			_apply_slot_style(main_hand_slot, player_inventory.equipped_main_hand.rarity)
		else:
			_apply_slot_style(main_hand_slot)

	# Off hand icon + slot style
	if off_hand_icon != null:
		if player_inventory.equipped_off_hand != null and player_inventory.equipped_off_hand.icon != null:
			off_hand_icon.texture = player_inventory.equipped_off_hand.icon
		else:
			off_hand_icon.texture = null

	if off_hand_slot != null:
		if player_inventory.is_off_hand_blocked():
			_apply_slot_style(off_hand_slot, "", true)
		elif player_inventory.equipped_off_hand != null:
			_apply_slot_style(off_hand_slot, player_inventory.equipped_off_hand.rarity)
		else:
			_apply_slot_style(off_hand_slot)

	if off_hand_label != null:
		if player_inventory.is_off_hand_blocked():
			off_hand_label.text = "Offhand (Blocked)"
		else:
			off_hand_label.text = "Offhand"

func _refresh_inventory_grid() -> void:
	if inventory_grid == null or player_inventory == null:
		return

	for child in inventory_grid.get_children():
		child.queue_free()

	for i in range(player_inventory.items.size()):
		var item: ItemData = player_inventory.items[i]
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		inventory_grid.add_child(slot)
		slot.set_slot(i, item)
		slot.slot_clicked.connect(_on_inventory_slot_clicked)

func _refresh_detail_panel() -> void:
	if detail_title == null:
		return

	if player_inventory != null and selected_item != null:
		var exists_in_bag := player_inventory.items.has(selected_item)
		var is_equipped := player_inventory.is_item_equipped(selected_item)
		if not exists_in_bag and not is_equipped:
			selected_item = null

	if selected_item == null:
		detail_title.text = "No item selected"

		if detail_rarity != null:
			detail_rarity.text = ""

		if detail_type != null:
			detail_type.text = ""

		if detail_stats != null:
			detail_stats.text = ""

		if detail_action_button != null:
			detail_action_button.disabled = true
			detail_action_button.text = "No Action"

		if detail_info_label != null:
			detail_info_label.text = ""
			
		if selected_item == null:
			detail_title.text = "No item selected"

		if detail_title != null:
			detail_title.modulate = Color.WHITE

		if detail_rarity != null:
			detail_rarity.text = ""
			detail_rarity.modulate = Color.WHITE

		return

	detail_title.text = selected_item.item_name
	var rarity_color := _get_rarity_color(selected_item.rarity)

	if detail_title != null:
		detail_title.modulate = rarity_color

	if detail_rarity != null:
		detail_rarity.text = "Rarity: %s" % selected_item.rarity.capitalize()
		detail_rarity.modulate = rarity_color

	if detail_type != null:
		detail_type.text = "Type: %s" % selected_item.item_type

	if detail_stats != null:
		detail_stats.text = ""
		for key in selected_item.stats.keys():
			detail_stats.append_text("%s: +%s\n" % [str(key), str(selected_item.stats[key])])

		if selected_item.stackable:
			detail_stats.append_text("Amount: %d\n" % selected_item.quantity)

	if detail_action_button != null:
		detail_action_button.disabled = false
		detail_action_button.text = _get_action_text_for_item(selected_item)

	if detail_info_label != null:
		detail_info_label.text = _get_detail_info_text(selected_item)

func _get_action_text_for_item(item_data: ItemData) -> String:
	if item_data == null:
		return "No Action"

	if item_data.item_type == "health_potion":
		return "Use"

	if player_inventory != null and player_inventory.is_item_equipped(item_data):
		return "Unequip"

	if item_data.equip_slot == "weapon" or item_data.equip_slot == "shield":
		return "Equip"

	return "No Action"

func _get_detail_info_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	if item_data.is_two_handed:
		return "Two-Handed"

	if item_data.equip_slot == "shield":
		return "Offhand Item"

	if item_data.equip_slot == "weapon":
		return "Mainhand Item"

	if item_data.stackable:
		return "Stackable"

	return ""

func _on_inventory_slot_clicked(slot_index: int, item_data: ItemData) -> void:
	if item_data == null:
		return

	selected_item = item_data
	print("Selected item:", item_data.item_name, " at index:", slot_index)
	_refresh_detail_panel()

func _on_main_hand_pressed() -> void:
	if player_inventory == null:
		return

	selected_item = player_inventory.equipped_main_hand
	_refresh_detail_panel()

func _on_off_hand_pressed() -> void:
	if player_inventory == null:
		return

	selected_item = player_inventory.equipped_off_hand
	_refresh_detail_panel()

func _on_detail_action_button_pressed() -> void:
	if player_inventory == null or selected_item == null:
		return

	if selected_item.item_type == "health_potion":
		player_inventory.use_item(selected_item)

	elif player_inventory.is_item_equipped(selected_item):
		player_inventory.unequip_item(selected_item)

	else:
		player_inventory.equip_item(selected_item)

	_refresh_ui()

func _on_coins_changed(_new_amount: int) -> void:
	_refresh_ui()

func _on_xp_changed(_current_xp: int, _level: int) -> void:
	_refresh_ui()


func _apply_slot_style(panel: Panel, rarity: String = "", blocked: bool = false) -> void:
	if panel == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color("1b2027")
	style.set_corner_radius_all(4)

	if blocked:
		style.border_color = Color("7a7a7a")
		style.set_border_width_all(2)
	elif rarity != "":
		style.border_color = _get_rarity_color(rarity)
		style.set_border_width_all(2)
	else:
		style.border_color = Color("6a748a")
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)
