extends TextureButton
class_name ItemSlot

signal slot_clicked(slot_index, item_data)

@onready var slot_background: Panel = $SlotBackground
@onready var item_icon: TextureRect = $ItemIcon

var slot_index: int = -1
var item_data: ItemData = null

func _ready() -> void:
	pressed.connect(_on_pressed)
	clear_slot()

func set_slot(index: int, data: ItemData) -> void:
	slot_index = index
	item_data = data

	if item_data == null:
		clear_slot()
		return

	if item_data.icon != null:
		item_icon.texture = item_data.icon
	else:
		item_icon.texture = null

	_apply_rarity_style(item_data.rarity)

func clear_slot() -> void:
	item_data = null
	item_icon.texture = null
	_apply_empty_style()

func _on_pressed() -> void:
	slot_clicked.emit(slot_index, item_data)

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

func _apply_empty_style() -> void:
	if slot_background == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color("16191f")
	style.border_color = Color("4c5566")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)

	slot_background.add_theme_stylebox_override("panel", style)

func _apply_rarity_style(rarity: String) -> void:
	if slot_background == null:
		return

	var rarity_color := _get_rarity_color(rarity)

	var style := StyleBoxFlat.new()
	style.bg_color = Color("16191f")
	style.border_color = rarity_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)

	slot_background.add_theme_stylebox_override("panel", style)
