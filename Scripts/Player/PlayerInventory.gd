extends Node
class_name PlayerInventory

signal item_added(item_data)
signal coins_changed(new_amount)
signal xp_changed(current_xp, level)

@export var coins: int = 0
@export var xp: int = 0
@export var level: int = 1

var items: Array[ItemData] = []

func add_item(item_data: ItemData) -> void:
	if item_data == null:
		return

	items.append(item_data)
	print("ITEM ADDED TO INVENTORY:")
	print(item_data.get_display_text())
	item_added.emit(item_data)

func add_coins(amount: int) -> void:
	coins += amount
	print("COINS:", coins)
	coins_changed.emit(coins)

func add_xp(amount: int) -> void:
	xp += amount

	while xp >= get_xp_to_next_level():
		xp -= get_xp_to_next_level()
		level += 1
		print("LEVEL UP! New level:", level)

	print("XP:", xp, "/", get_xp_to_next_level(), " Level:", level)
	xp_changed.emit(xp, level)

func get_xp_to_next_level() -> int:
	return level * 100

func get_item_count() -> int:
	return items.size()

func debug_print_inventory() -> void:
	print("=== INVENTORY ===")
	print("Coins:", coins)
	print("XP:", xp)
	print("Level:", level)

	for i in range(items.size()):
		var item: ItemData = items[i]
		print(str(i + 1) + ".", item.get_display_text())
