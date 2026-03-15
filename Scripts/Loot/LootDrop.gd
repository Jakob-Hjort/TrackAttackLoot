extends Area3D
class_name LootDrop

var item_data: ItemData
var pickup_radius: float = 3.0

func _ready() -> void:
	print("LOOT READY")

func set_item(data: ItemData) -> void:
	item_data = data
	print("LOOT ITEM SET:", item_data.get_display_text())

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var distance := global_position.distance_to(player.global_position)
	if distance > pickup_radius:
		return

	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if inventory == null:
		print("No PlayerInventory found on player")
		return

	inventory.add_item(item_data)
	print("LOOT PICKED:", item_data.get_display_text())
	queue_free()
