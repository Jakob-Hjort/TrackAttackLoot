extends Node
class_name LootGenerator

static func roll_rarity(is_elite: bool = false, is_boss: bool = false) -> String:
	var roll := randf()

	if is_boss:
		if roll < 0.7:
			return "rare"
		return "epic"

	if is_elite:
		if roll < 0.6:
			return "uncommon"
		return "rare"

	if roll < 0.8:
		return "common"
	return "uncommon"

static func get_stat_count_for_rarity(rarity: String) -> int:
	match rarity:
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		_:
			return 1

static func get_possible_stats(item_type: String) -> Array[String]:
	match item_type:
		"axe-1-handed":
			return ["damage", "strength", "attack_speed"]
		"sword-1-handed":
			return ["damage", "strength", "attack_speed"]
		"axe-2-handed":
			return ["damage", "strength", "attack_speed"]
		"sword-2-handed":
			return ["damage", "strength", "attack_speed"]
		"crossbow":
			return ["damage", "agility", "crit_chance"]
		"staff":
			return ["spell_power", "intelligence", "mana"]
		"wand":
			return ["spell_power", "intelligence", "mana"]
		_:
			return ["damage"]

static func roll_stat_value(stat_name: String, rarity: String) -> int:
	match stat_name:
		"damage":
			match rarity:
				"common": return randi_range(1, 3)
				"uncommon": return randi_range(3, 6)
				"rare": return randi_range(6, 10)
				"epic": return randi_range(10, 16)

		"strength", "agility", "intelligence", "mana", "spell_power":
			match rarity:
				"common": return randi_range(1, 2)
				"uncommon": return randi_range(2, 4)
				"rare": return randi_range(4, 7)
				"epic": return randi_range(7, 12)

		"attack_speed", "crit_chance":
			match rarity:
				"common": return randi_range(1, 2)
				"uncommon": return randi_range(2, 4)
				"rare": return randi_range(4, 6)
				"epic": return randi_range(6, 10)

	return 1

static func build_item_name(item_type: String, rarity: String) -> String:
	var pretty_type := item_type.replace("-", " ")
	return rarity.capitalize() + " " + pretty_type.capitalize()

static func generate_item(item_type: String, is_elite: bool = false, is_boss: bool = false) -> ItemData:
	var item := ItemData.new()

	item.item_type = item_type
	item.rarity = roll_rarity(is_elite, is_boss)
	item.item_name = build_item_name(item_type, item.rarity)

	match item_type:
		"axe-1-handed":
			item.equip_slot = "weapon"
		"sword-1-handed":
			item.equip_slot = "weapon"
		"axe-2-handed":
			item.equip_slot = "weapon"
		"sword-2-handed":
			item.equip_slot = "weapon"
		"crossbow":
			item.equip_slot = "weapon"
		"staff":
			item.equip_slot = "weapon"
		"wand":
			item.equip_slot = "weapon"
		_:
			item.equip_slot = "weapon"

	var possible_stats: Array[String] = get_possible_stats(item_type)
	var stat_count: int = min(get_stat_count_for_rarity(item.rarity), possible_stats.size())
	var rolled_stats: Dictionary = {}

	possible_stats.shuffle()

	for i in range(stat_count):
		var stat_name: String = possible_stats[i]
		rolled_stats[stat_name] = roll_stat_value(stat_name, item.rarity)

	item.stats = rolled_stats
	return item
