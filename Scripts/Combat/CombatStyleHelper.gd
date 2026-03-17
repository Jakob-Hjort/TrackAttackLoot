extends RefCounted
class_name CombatStyleHelper

static func get_style_from_inventory(inventory: PlayerInventory) -> String:
	if inventory == null:
		return "unarmed"

	var main := inventory.equipped_main_hand
	var off := inventory.equipped_off_hand

	if main == null and off == null:
		return "unarmed"

	if main != null and main.is_two_handed:
		return "two_handed"

	if main != null and off != null:
		if off.equip_slot == "shield":
			return "one_handed_and_shield"
		return "dual_wield"

	if main != null:
		return "one_handed"

	if off != null and off.equip_slot == "shield":
		return "unarmed"

	return "unarmed"
