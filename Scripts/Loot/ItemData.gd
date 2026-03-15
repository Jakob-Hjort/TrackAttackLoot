extends Resource
class_name ItemData

@export var item_name: String = ""
@export var item_type: String = ""
@export var rarity: String = "common"
@export var mesh_scene: PackedScene
@export var equip_slot: String = ""
@export var stats: Dictionary = {}

func get_display_text() -> String:
	var result := item_name + " [" + rarity + "]"

	for key in stats.keys():
		result += "\n" + str(key) + ": +" + str(stats[key])

	return result
