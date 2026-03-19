extends Node
class_name LootGenerator

# =========================
# ITEM VARIANTS
# =========================
static var ITEM_VARIANTS := {
	"axe-1-handed": [
		{
			"id": "axe_1handed_a",
			"name": "Hand Axe",
			"icon": preload("res://UI/ICONS/generated/axe_1handed2.png"),
			"equip_mesh": preload("res://Assets/Characters/Scenes/Weapons/1handaxes/axe_1handed_a_equip.tscn"),
			"drop_mesh": preload("res://Assets/Characters/Scenes/Weapons/1handaxes/axe_1handed_a_drop.tscn")
		}
	],

	"axe-2-handed": [
		{
			"id": "axe_2handed_a",
			"name": "Great Axe",
			"icon": preload("res://UI/ICONS/generated/axe_2handed2.png"),
			"equip_mesh": preload("res://Assets/Characters/Scenes/Weapons/2handaxes/axe_2_handed_a_equip.tscn"),
			"drop_mesh": preload("res://Assets/Characters/Scenes/Weapons/2handaxes/axe_2_handed_a_drop.tscn")
		}
	],

	"shield": [
		{
			"id": "shield_a",
			"name": "Wooden Shield",
			"icon": preload("res://UI/ICONS/generated/shield_a2.png"),
			"equip_mesh": preload("res://Assets/Characters/Scenes/Weapons/Shields/shield_a_equip.tscn"),
			"drop_mesh": preload("res://Assets/Characters/Scenes/Weapons/Shields/shield_a_drop.tscn")
		}
	],
	"crossbow": [
		{
			"id": "crossbow_a",
			"name": "Bone Crossbow",
			"icon": preload("res://UI/ICONS/generated/crossbow_2handed2.png"),
		#	"mesh": preload("res://Assets/Characters/Scenes/Weapons/crossbow_a.tscn")
		}
	],
	"health_potion": [
		{
			"id": "health_potion_small",
			"name": "Small Health Potion",
			"icon": preload("res://UI/ICONS/generated/potion_small_red2.png"),
			"drop_mesh": preload("res://Assets/Accessories/Player Accessories/Potions/potion_small_red_drop.tscn")
		},
		{
			"id": "health_potion_medium",
			"name": "Medium Health Potion",
			"icon": preload("res://UI/ICONS/generated/potion_medium_red2.png"),
			"drop_mesh": preload("res://Assets/Accessories/Player Accessories/Potions/potion_medium_red_drop.tscn")
		},
		{
			"id": "health_potion_large",
			"name": "Large Health Potion",
			"icon": preload("res://UI/ICONS/generated/potion_large_red2.png"),
			"drop_mesh": preload("res://Assets/Accessories/Player Accessories/Potions/potion_large_red_drop.tscn")
		},
		{
			"id": "health_potion_huge",
			"name": "Huge Health Potion",
			"icon": preload("res://UI/ICONS/generated/potion_huge_red2.png"),
			"drop_mesh": preload("res://Assets/Accessories/Player Accessories/Potions/potion_huge_red_drop.tscn")
		}
	]
}
# =========================
# MOB-SPECIFIC LOOT TABLES
# =========================
# weight = chance-vægt
# Jo højere weight, jo større chance for drop af netop den item_type
static var MOB_LOOT_TABLES := {
	"skeleton_unarmed": [
		{ "item_type": "axe-1-handed", "weight": 70 },
		{ "item_type": "health_potion", "weight": 30 }
	],

	"skeleton_warrior": [
		{ "item_type": "axe-1-handed", "weight": 40 },
		{ "item_type": "sword-1-handed", "weight": 35 },
		{ "item_type": "shield", "weight": 20 },
		{ "item_type": "health_potion", "weight": 5 }
	],

	"skeleton_archer": [
		{ "item_type": "crossbow", "weight": 75 },
		{ "item_type": "health_potion", "weight": 25 }
	],

	"skeleton_mage": [
		{ "item_type": "staff", "weight": 60 },
		{ "item_type": "wand", "weight": 30 },
		{ "item_type": "health_potion", "weight": 10 }
	],

	"orc_grunt": [
		{ "item_type": "axe-1-handed", "weight": 50 },
		{ "item_type": "axe-2-handed", "weight": 35 },
		{ "item_type": "health_potion", "weight": 15 }
	]
}

# =========================
# RARITY COLORS
# =========================
static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":
			return Color(0.85, 0.85, 0.85)
		"uncommon":
			return Color(0.25, 1.0, 0.35)
		"rare":
			return Color(0.25, 0.55, 1.0)
		"epic":
			return Color(0.75, 0.35, 1.0)
		_:
			return Color.WHITE

# =========================
# RARITY
# =========================
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

# =========================
# RARITY -> NUMBER OF STATS
# =========================
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

# =========================
# POSSIBLE STATS PER ITEM TYPE
# =========================
static func get_possible_stats(item_type: String) -> Array[String]:
	match item_type:
		"axe-1-handed", "sword-1-handed", "axe-2-handed", "sword-2-handed":
			return ["damage", "strength", "attack_speed"]
		"crossbow":
			return ["damage", "agility", "crit_chance"]
		"staff", "wand":
			return ["spell_power", "intelligence", "mana"]
		"shield":
			return ["defense", "block_chance", "max_health"]
		"health_potion":
			return ["heal_amount"]
		_:
			return ["damage"]

# =========================
# STAT VALUES
# =========================
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

		"defense":
			match rarity:
				"common": return randi_range(1, 2)
				"uncommon": return randi_range(2, 4)
				"rare": return randi_range(4, 6)
				"epic": return randi_range(6, 10)

		"block_chance":
			match rarity:
				"common": return randi_range(1, 2)
				"uncommon": return randi_range(2, 4)
				"rare": return randi_range(4, 6)
				"epic": return randi_range(6, 8)

		"max_health":
			match rarity:
				"common": return randi_range(5, 10)
				"uncommon": return randi_range(10, 20)
				"rare": return randi_range(20, 35)
				"epic": return randi_range(35, 50)

		"heal_amount":
			match rarity:
				"common": return randi_range(20, 30)
				"uncommon": return randi_range(35, 50)
				"rare": return randi_range(55, 75)
				"epic": return randi_range(80, 120)

	return 1

# =========================
# FALLBACK NAME
# =========================
static func build_item_name(item_type: String, rarity: String) -> String:
	var pretty_type := item_type.replace("-", " ")
	return rarity.capitalize() + " " + pretty_type.capitalize()

# =========================
# PICK RANDOM VARIANT
# =========================
static func get_random_variant(item_type: String) -> Dictionary:
	if not ITEM_VARIANTS.has(item_type):
		return {}

	var variants: Array = ITEM_VARIANTS[item_type]
	if variants.is_empty():
		return {}

	return variants[randi() % variants.size()]

# =========================
# EQUIP SLOT
# =========================
static func get_equip_slot_for_item_type(item_type: String) -> String:
	match item_type:
		"axe-1-handed", "sword-1-handed", "axe-2-handed", "sword-2-handed", "crossbow", "staff", "wand":
			return "weapon"
		"shield":
			return "shield"
		_:
			return ""

static func get_weapon_family_for_item_type(item_type: String) -> String:
	match item_type:
		"axe-1-handed", "axe-2-handed":
			return "axe"
		"sword-1-handed", "sword-2-handed":
			return "sword"
		"shield":
			return "shield"
		"crossbow":
			return "crossbow"
		"staff":
			return "staff"
		"wand":
			return "wand"
		_:
			return ""


# =========================
# PICK ITEM TYPE FROM MOB TABLE
# =========================
static func roll_item_type_for_mob(mob_id: String) -> String:
	if not MOB_LOOT_TABLES.has(mob_id):
		return ""

	var table: Array = MOB_LOOT_TABLES[mob_id]
	if table.is_empty():
		return ""

	var total_weight := 0
	for entry in table:
		total_weight += int(entry.get("weight", 0))

	if total_weight <= 0:
		return ""

	var roll := randi_range(1, total_weight)
	var running := 0

	for entry in table:
		running += int(entry.get("weight", 0))
		if roll <= running:
			return str(entry.get("item_type", ""))

	return ""

# =========================
# GENERATE FROM MOB
# =========================
static func generate_item_for_mob(mob_id: String, is_elite: bool = false, is_boss: bool = false) -> ItemData:
	var item_type := roll_item_type_for_mob(mob_id)
	if item_type == "":
		return null

	return generate_item(item_type, is_elite, is_boss)

# =========================
# MAIN ITEM GENERATION
# =========================
static func generate_item(item_type: String, is_elite: bool = false, is_boss: bool = false) -> ItemData:
	var item := ItemData.new()

	item.item_type = item_type
	item.rarity = roll_rarity(is_elite, is_boss)
	item.is_two_handed = is_two_handed_item_type(item_type)
	item.weapon_family = get_weapon_family_for_item_type(item_type)

	# Variant vælges først
	var variant := get_random_variant(item_type)

	# Sæt icon / mesh / navn hvis variant findes
	if not variant.is_empty():
		item.variant_id = str(variant.get("id", ""))
		item.icon = variant.get("icon", null)
		item.equip_mesh_scene = variant.get("equip_mesh", null)
		item.drop_mesh_scene = variant.get("drop_mesh", null)

		var base_name := str(variant.get("name", item_type.replace("-", " ").capitalize()))
		item.item_name = item.rarity.capitalize() + " " + base_name
	else:
		item.item_name = build_item_name(item_type, item.rarity)

	# Equip slot / stack logic
	item.equip_slot = get_equip_slot_for_item_type(item_type)

	if item_type == "health_potion":
		item.stackable = true
		item.max_stack = 10

	# Stats
	var possible_stats: Array[String] = get_possible_stats(item_type)
	var stat_count: int = min(get_stat_count_for_rarity(item.rarity), possible_stats.size())
	var rolled_stats: Dictionary = {}

	possible_stats.shuffle()

	for i in range(stat_count):
		var stat_name: String = possible_stats[i]
		rolled_stats[stat_name] = roll_stat_value(stat_name, item.rarity)

	item.stats = rolled_stats

	print("GENERATED ITEM:")
	print("  name =", item.item_name)
	print("  type =", item.item_type)
	print("  equip_slot =", item.equip_slot)
	print("  rarity =", item.rarity)
	print("  variant_id =", item.variant_id)

	return item

static func is_two_handed_item_type(item_type: String) -> bool:
	match item_type:
		"axe-2-handed", "sword-2-handed", "crossbow", "staff":
			return true
		_:
			return false
