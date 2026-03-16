extends Resource
class_name ItemData

@export var item_name: String = ""
@export var item_type: String = ""
@export var variant_id: String = ""
@export var rarity: String = "common"

@export var mesh_scene: PackedScene
@export var icon: Texture2D

@export var equip_slot: String = ""
@export var is_two_handed: bool = false
@export var stats: Dictionary = {}

@export var stackable: bool = false
@export var max_stack: int = 1
@export var quantity: int = 1

var equip_mesh_scene: PackedScene
var drop_mesh_scene: PackedScene

func get_display_text() -> String:
	var result := item_name + " [" + rarity + "]"

	for key in stats.keys():
		result += "\n" + str(key) + ": +" + str(stats[key])

	if stackable:
		result += "\nAmount: " + str(quantity)

	return result
