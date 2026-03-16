extends Node
class_name PlayerInventory

signal item_added(item_data)
signal inventory_changed
signal coins_changed(new_amount)
signal xp_changed(current_xp, level)
signal equipment_changed()
signal stats_changed()

@export var coins: int = 0
@export var xp: int = 0
@export var level: int = 1

@export var base_max_health: int = 100
@export var base_damage: int = 5
@export var base_defense: int = 0
@export var base_crit_chance: int = 0
@export var base_attack_speed: int = 0

@export var max_slots: int = 20

var items: Array[ItemData] = []

var equipped_main_hand: ItemData = null
var equipped_off_hand: ItemData = null

func add_item(item_data: ItemData) -> void:
	if item_data == null:
		return

	if item_data.stackable:
		for existing_item in items:
			if existing_item.item_type == item_data.item_type \
			and existing_item.rarity == item_data.rarity \
			and existing_item.variant_id == item_data.variant_id \
			and existing_item.quantity < existing_item.max_stack:
				existing_item.quantity += item_data.quantity
				existing_item.quantity = min(existing_item.quantity, existing_item.max_stack)

				print("STACKED ITEM:")
				print(existing_item.get_display_text())

				item_added.emit(existing_item)
				inventory_changed.emit()
				return

	items.append(item_data)
	print("ITEM ADDED TO INVENTORY:")
	print(item_data.get_display_text())

	item_added.emit(item_data)
	inventory_changed.emit()

func add_coins(amount: int) -> void:
	coins += amount
	print("COINS:", coins)
	coins_changed.emit(coins)
	
func can_upgrade_inventory(cost: int) -> bool:
	return coins >= cost

func upgrade_inventory(cost: int, slot_increase: int = 5) -> bool:
	if coins < cost:
		return false

	coins -= cost
	max_slots += slot_increase

	coins_changed.emit(coins)
	inventory_changed.emit()
	return true

func add_xp(amount: int) -> void:
	xp += amount

	while xp >= get_xp_to_next_level():
		xp -= get_xp_to_next_level()
		level += 1
		apply_level_up_stats()
		print("LEVEL UP! New level:", level)

	print("XP:", xp, "/", get_xp_to_next_level(), " Level:", level)
	xp_changed.emit(xp, level)
	stats_changed.emit()

func get_xp_to_next_level() -> int:
	return level * 100

func get_item_count() -> int:
	return items.size()

func is_off_hand_blocked() -> bool:
	return equipped_main_hand != null and equipped_main_hand.is_two_handed

func equip_item(item_data: ItemData) -> void:
	if item_data == null:
		return

	match item_data.equip_slot:
		"weapon":
			_equip_main_hand(item_data)

		"shield":
			_equip_off_hand(item_data)

		_:
			print("Item can not be equipped:", item_data.item_name)
			return

	equipment_changed.emit()
	inventory_changed.emit()
	stats_changed.emit()

func _equip_main_hand(item_data: ItemData) -> void:
	if item_data == null:
		return

	# Hvis det nye item er 2-handed, så skal off-hand tømmes
	if item_data.is_two_handed and equipped_off_hand != null:
		items.append(equipped_off_hand)
		equipped_off_hand = null

	# Gammelt main-hand item tilbage i inventory
	if equipped_main_hand != null:
		items.append(equipped_main_hand)

	equipped_main_hand = item_data
	print("EQUIPPED:", equipped_main_hand.item_name)
	print("ICON:", equipped_main_hand.icon)
	print("EQUIP MESH:", equipped_main_hand.equip_mesh_scene)
	print("DROP MESH:", equipped_main_hand.drop_mesh_scene)
	
	items.erase(item_data)

func _equip_off_hand(item_data: ItemData) -> void:
	if item_data == null:
		return

	if is_off_hand_blocked():
		print("Cannot equip off-hand item while a two-handed weapon is equipped.")
		return

	if equipped_off_hand != null:
		items.append(equipped_off_hand)

	equipped_off_hand = item_data
	items.erase(item_data)

func unequip_main_hand() -> void:
	if equipped_main_hand == null:
		return

	items.append(equipped_main_hand)
	equipped_main_hand = null

	equipment_changed.emit()
	inventory_changed.emit()
	stats_changed.emit()
	
func is_item_equipped(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	return equipped_main_hand == item_data or equipped_off_hand == item_data


func unequip_item(item_data: ItemData) -> void:
	if item_data == null:
		return

	if equipped_main_hand == item_data:
		unequip_main_hand()
		return

	if equipped_off_hand == item_data:
		unequip_off_hand()
		return

func unequip_off_hand() -> void:
	if equipped_off_hand == null:
		return

	items.append(equipped_off_hand)
	equipped_off_hand = null

	equipment_changed.emit()
	inventory_changed.emit()
	stats_changed.emit()

func use_item(item_data: ItemData) -> void:
	if item_data == null:
		return

	match item_data.item_type:
		"health_potion":
			var player := get_parent()
			if player != null and player.has_method("heal"):
				var heal_amount := int(item_data.stats.get("heal_amount", 0))
				player.heal(heal_amount)

			if item_data.stackable and item_data.quantity > 1:
				item_data.quantity -= 1
			else:
				items.erase(item_data)

			print("USED POTION:", item_data.get_display_text())

			inventory_changed.emit()
			stats_changed.emit()

		_:
			print("Item cannot be used directly:", item_data.item_name)

func apply_level_up_stats() -> void:
	base_max_health += 10
	base_damage += 1

	if level % 2 == 0:
		base_defense += 1

func get_total_stats() -> Dictionary:
	var total := {
		"max_health": base_max_health,
		"damage": base_damage,
		"defense": base_defense,
		"crit_chance": base_crit_chance,
		"attack_speed": base_attack_speed
	}

	if equipped_main_hand != null:
		_add_item_stats_to_total(equipped_main_hand, total)

	if equipped_off_hand != null:
		_add_item_stats_to_total(equipped_off_hand, total)

	return total

func _add_item_stats_to_total(item_data: ItemData, total: Dictionary) -> void:
	for key in item_data.stats.keys():
		if not total.has(key):
			total[key] = 0
		total[key] += int(item_data.stats[key])

func debug_print_inventory() -> void:
	print("=== INVENTORY ===")
	print("Coins:", coins)
	print("XP:", xp)
	print("Level:", level)

	print("--- Equipped ---")
	if equipped_main_hand != null:
		print("Main Hand:", equipped_main_hand.get_display_text())
	else:
		print("Main Hand: none")

	if equipped_off_hand != null:
		print("Off Hand:", equipped_off_hand.get_display_text())
	else:
		if is_off_hand_blocked():
			print("Off Hand: blocked by two-handed weapon")
		else:
			print("Off Hand: none")

	print("--- Bag ---")
	for i in range(items.size()):
		var item: ItemData = items[i]
		print(str(i + 1) + ".", item.get_display_text())
