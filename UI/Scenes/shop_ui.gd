extends CanvasLayer
class_name ShopUI

@export var player_path: NodePath

const ITEM_SLOT_SCENE := preload("res://UI/Scenes/item_slot.tscn")

const SMALL_PRICE := 10
const MEDIUM_PRICE := 25
const LARGE_PRICE := 50
const HUGE_PRICE := 90

const SMALL_HEAL := 25
const MEDIUM_HEAL := 50
const LARGE_HEAL := 80
const HUGE_HEAL := 120

const SMALL_ICON := preload("res://UI/ICONS/generated/potion_small_red2.png")
const MEDIUM_ICON := preload("res://UI/ICONS/generated/potion_medium_red2.png")
const LARGE_ICON := preload("res://UI/ICONS/generated/potion_large_red2.png")
const HUGE_ICON := preload("res://UI/ICONS/generated/potion_huge_red2.png")

@onready var shop_ui: Control = $ShopUI

@onready var title_label: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var shopcoins_label: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/TopBar/ShopcoinsLabel
@onready var coins_label: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/TopBar/CoinsLabel
@onready var close_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/TopBar/Closebutton

@onready var potion_small_icon: TextureRect = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionSmallRow/PotionSmallIcon
@onready var potion_small_name: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionSmallRow/PotionSmallText
@onready var potion_small_buy_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionSmallRow/PotionSmallBuyButton

@onready var potion_medium_icon: TextureRect = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionMediumRow/PotionMediumIcon
@onready var potion_medium_name: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionMediumRow/PotionMediumText
@onready var potion_medium_buy_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionMediumRow/PotionMediumBuyButton

@onready var potion_large_icon: TextureRect = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionLargeRow/PotionLargeIcon
@onready var potion_large_name: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionLargeRow/PotionLargeText
@onready var potion_large_buy_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionLargeRow/PotionLargeBuyButton

@onready var potion_huge_icon: TextureRect = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionHugeRow/PotionHugeIcon
@onready var potion_huge_name: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionHugeRow/PotionHugeText
@onready var potion_huge_buy_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/BuyPanel/BuyInnerPanel/BuyMargin/BuyItemVbox/PotionHugeRow/PotionHugeBuyButton

@onready var sell_grid: GridContainer = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SellPanel/SellInnerPanel/SellMargin/SellVBoxContainer/SellGrid

@onready var detail_title: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailTitle
@onready var detail_rarity: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailRarity
@onready var detail_type: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailType
@onready var detail_stats: RichTextLabel = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailStats
@onready var detail_action_button: Button = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailActionButton
@onready var detail_info_label: Label = $ShopUI/Panel/MarginContainer/VBoxContainer/HBoxContainer/SelectedPanel/SelectedInnerPanel/DetailMargin/DetailVbox/DetailInfoLabel

var player: Node = null
var inventory: PlayerInventory = null

var selected_item: ItemData = null
var selected_item_index: int = -1
var selected_mode: String = "" # "sell"

func _ready() -> void:
	add_to_group("shop_ui")

	if player_path != NodePath():
		player = get_node_or_null(player_path)
	else:
		player = get_tree().get_first_node_in_group("player")

	if player != null:
		inventory = player.get_node_or_null("PlayerInventory") as PlayerInventory

	visible = false
	_setup_static_text()
	_connect_buttons()
	_connect_inventory_signals()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_shop()


func open_shop() -> void:
	visible = true
	_refresh_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_shop() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var merchants = get_tree().get_nodes_in_group("merchant_vendor")
	for merchant in merchants:
		if merchant != null and merchant.has_method("notify_shop_closed"):
			merchant.notify_shop_closed()


func toggle_shop() -> void:
	if visible:
		close_shop()
	else:
		open_shop()


func _setup_static_text() -> void:
	title_label.text = "Merchant"
	shopcoins_label.text = "Merchant has 0 coins"

	potion_small_icon.texture = SMALL_ICON
	potion_small_name.text = "Small Health Potion + " + str(SMALL_PRICE) + " g"

	potion_medium_icon.texture = MEDIUM_ICON
	potion_medium_name.text = "Medium Health Potion" + str(MEDIUM_PRICE) + " g"

	potion_large_icon.texture = LARGE_ICON
	potion_large_name.text = "Large Health Potion" + str(LARGE_PRICE) + " g"

	potion_huge_icon.texture = HUGE_ICON
	potion_huge_name.text = "Huge Health Potion" + str(HUGE_PRICE) + " g"

	_clear_selected_panel()


func _connect_buttons() -> void:
	if not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	if not potion_small_buy_button.pressed.is_connected(_on_buy_small_pressed):
		potion_small_buy_button.pressed.connect(_on_buy_small_pressed)

	if not potion_medium_buy_button.pressed.is_connected(_on_buy_medium_pressed):
		potion_medium_buy_button.pressed.connect(_on_buy_medium_pressed)

	if not potion_large_buy_button.pressed.is_connected(_on_buy_large_pressed):
		potion_large_buy_button.pressed.connect(_on_buy_large_pressed)

	if not potion_huge_buy_button.pressed.is_connected(_on_buy_huge_pressed):
		potion_huge_buy_button.pressed.connect(_on_buy_huge_pressed)

	if not detail_action_button.pressed.is_connected(_on_detail_action_pressed):
		detail_action_button.pressed.connect(_on_detail_action_pressed)


func _connect_inventory_signals() -> void:
	if inventory == null:
		return

	if not inventory.coins_changed.is_connected(_on_coins_changed):
		inventory.coins_changed.connect(_on_coins_changed)

	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)

	if not inventory.item_added.is_connected(_on_item_added):
		inventory.item_added.connect(_on_item_added)


func _refresh_all() -> void:
	_update_coin_labels()
	_rebuild_sell_grid()
	_refresh_selected_panel_if_needed()


func _update_coin_labels() -> void:
	if inventory == null:
		shopcoins_label.text = "Merchant has 0 coins"
		coins_label.text = "You have 0 coins"
		return

	shopcoins_label.text = "Merchant has 9999 coins"
	coins_label.text = "You have " + str(inventory.coins) + " coins"


func _rebuild_sell_grid() -> void:
	if sell_grid == null:
		return

	for child in sell_grid.get_children():
		child.queue_free()

	if inventory == null:
		return

	for i in range(inventory.items.size()):
		var item: ItemData = inventory.items[i]
		var slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		if slot == null:
			continue

		sell_grid.add_child(slot)
		slot.set_slot(i, item)
		slot.slot_clicked.connect(_on_sell_slot_clicked)


func _on_sell_slot_clicked(slot_index: int, item_data: ItemData) -> void:
	selected_item_index = slot_index
	selected_item = item_data
	selected_mode = "sell"
	_update_selected_panel_for_item(item_data, "Sell", _get_sell_price(item_data))


func _update_selected_panel_for_item(item: ItemData, action_text: String, action_value: int) -> void:
	if item == null:
		_clear_selected_panel()
		return

	detail_title.text = item.item_name
	detail_rarity.text = "Rarity: " + item.rarity.capitalize()
	detail_type.text = "Type: " + item.item_type

	var stats_text := ""
	for key in item.stats.keys():
		stats_text += str(key).capitalize().replace("_", " ") + ": " + str(item.stats[key]) + "\n"

	if item.stackable and item.quantity > 1:
		stats_text += "Quantity: " + str(item.quantity) + "\n"

	detail_stats.text = stats_text.strip_edges()
	detail_action_button.text = action_text + " (" + str(action_value) + "g)"
	detail_action_button.disabled = false
	detail_info_label.text = ""


func _clear_selected_panel() -> void:
	selected_item = null
	selected_item_index = -1
	selected_mode = ""

	detail_title.text = "No item selected"
	detail_rarity.text = ""
	detail_type.text = ""
	detail_stats.text = ""
	detail_action_button.text = "No Action"
	detail_action_button.disabled = true
	detail_info_label.text = "Select an item"


func _refresh_selected_panel_if_needed() -> void:
	if inventory == null:
		_clear_selected_panel()
		return

	if selected_mode != "sell":
		return

	if selected_item == null:
		_clear_selected_panel()
		return

	if not inventory.items.has(selected_item):
		_clear_selected_panel()
		return

	_update_selected_panel_for_item(selected_item, "Sell", _get_sell_price(selected_item))


func _get_sell_price(item: ItemData) -> int:
	if item == null:
		return 0

	var base := 5

	match item.rarity:
		"common":
			base = 8
		"uncommon":
			base = 18
		"rare":
			base = 35
		"epic":
			base = 60
		_:
			base = 5

	if item.item_type == "health_potion":
		base = max(3, int(base * 0.5))

	if item.stackable:
		base *= max(item.quantity, 1)

	return base


func _sell_selected_item() -> void:
	if inventory == null or selected_item == null:
		return

	if not inventory.items.has(selected_item):
		_clear_selected_panel()
		return

	var item_to_sell := selected_item
	var sell_price := _get_sell_price(item_to_sell)

	_clear_selected_panel()

	inventory.items.erase(item_to_sell)
	inventory.add_coins(sell_price)
	inventory.inventory_changed.emit()

	print("SOLD ITEM:", item_to_sell.item_name, " for ", sell_price)

func _buy_potion(variant_id: String, item_name: String, icon: Texture2D, heal_amount: int, price: int) -> void:
	if inventory == null:
		return

	if inventory.coins < price:
		detail_info_label.text = "Not enough coins"
		return

	var potion := LootGenerator.generate_item("health_potion")
	if potion == null:
		return

	potion.variant_id = variant_id
	potion.item_name = item_name
	potion.icon = icon
	potion.stats["heal_amount"] = heal_amount
	potion.stackable = true
	potion.max_stack = 10

	inventory.coins -= price
	inventory.coins_changed.emit(inventory.coins)
	inventory.add_item(potion)

	print("BOUGHT POTION:", potion.item_name, " for ", price)


func _on_buy_small_pressed() -> void:
	_buy_potion("health_potion_small", "Small Health Potion", SMALL_ICON, SMALL_HEAL, SMALL_PRICE)


func _on_buy_medium_pressed() -> void:
	_buy_potion("health_potion_medium", "Medium Health Potion", MEDIUM_ICON, MEDIUM_HEAL, MEDIUM_PRICE)


func _on_buy_large_pressed() -> void:
	_buy_potion("health_potion_large", "Large Health Potion", LARGE_ICON, LARGE_HEAL, LARGE_PRICE)


func _on_buy_huge_pressed() -> void:
	_buy_potion("health_potion_huge", "Huge Health Potion", HUGE_ICON, HUGE_HEAL, HUGE_PRICE)


func _on_detail_action_pressed() -> void:
	if selected_mode == "sell":
		_sell_selected_item()


func _on_close_pressed() -> void:
	close_shop()


func _on_coins_changed(_new_amount: int) -> void:
	_refresh_all()


func _on_inventory_changed() -> void:
	_refresh_all()


func _on_item_added(_item_data) -> void:
	_refresh_all()
