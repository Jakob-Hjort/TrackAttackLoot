extends Node

var player_name: String = "Player"

var saved_player_data: Dictionary = {}
var pending_restore: bool = false


func save_player_state(player: Node) -> void:
	if player == null:
		return

	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	var health_component := player.get_node_or_null("HealthComponent")

	if inventory == null:
		return

	saved_player_data = {
		"player_name": player_name,
		"coins": inventory.coins,
		"xp": inventory.xp,
		"level": inventory.level,
		"base_max_health": inventory.base_max_health,
		"base_damage": inventory.base_damage,
		"base_defense": inventory.base_defense,
		"base_crit_chance": inventory.base_crit_chance,
		"base_attack_speed": inventory.base_attack_speed,
		"max_slots": inventory.max_slots,
		"items": [],
		"equipped_main_hand": null,
		"equipped_off_hand": null,
		"active_health_potion_variant_id": "",
		"current_health": 0,
		"max_health": 0
	}

	if health_component != null:
		saved_player_data["current_health"] = health_component.current_health
		saved_player_data["max_health"] = health_component.max_health

	for item in inventory.items:
		if item == null:
			continue
		saved_player_data["items"].append(_serialize_item(item))

	if inventory.equipped_main_hand != null:
		saved_player_data["equipped_main_hand"] = _serialize_item(inventory.equipped_main_hand)

	if inventory.equipped_off_hand != null:
		saved_player_data["equipped_off_hand"] = _serialize_item(inventory.equipped_off_hand)

	if inventory.active_health_potion != null:
		saved_player_data["active_health_potion_variant_id"] = inventory.active_health_potion.variant_id

	pending_restore = true


func restore_player_state(player: Node) -> void:
	if not pending_restore:
		return
	if player == null:
		return

	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	var health_component := player.get_node_or_null("HealthComponent")

	if inventory == null:
		return

	inventory.clear_all_items_for_restore()

	inventory.coins = int(saved_player_data.get("coins", 0))
	inventory.xp = int(saved_player_data.get("xp", 0))
	inventory.level = int(saved_player_data.get("level", 1))

	inventory.base_max_health = int(saved_player_data.get("base_max_health", 100))
	inventory.base_damage = int(saved_player_data.get("base_damage", 5))
	inventory.base_defense = int(saved_player_data.get("base_defense", 0))
	inventory.base_crit_chance = int(saved_player_data.get("base_crit_chance", 0))
	inventory.base_attack_speed = float(saved_player_data.get("base_attack_speed", 1.0))
	inventory.max_slots = int(saved_player_data.get("max_slots", 20))

	var saved_items: Array = saved_player_data.get("items", [])
	for item_dict in saved_items:
		var item := _deserialize_item(item_dict)
		if item != null:
			inventory.items.append(item)

	var saved_main = saved_player_data.get("equipped_main_hand", null)
	if saved_main != null:
		inventory.equipped_main_hand = _deserialize_item(saved_main)

	var saved_off = saved_player_data.get("equipped_off_hand", null)
	if saved_off != null:
		inventory.equipped_off_hand = _deserialize_item(saved_off)

	var active_variant_id := str(saved_player_data.get("active_health_potion_variant_id", ""))
	if active_variant_id != "":
		for item in inventory.items:
			if item != null and item.variant_id == active_variant_id and inventory.is_health_potion(item):
				inventory.active_health_potion = item
				break

	if inventory.active_health_potion == null:
		inventory.get_active_health_potion()

	if health_component != null:
		health_component.max_health = int(saved_player_data.get("max_health", health_component.max_health))
		health_component.current_health = health_component.max_health

		if health_component.has_signal("health_changed"):
			health_component.health_changed.emit(
				health_component.current_health,
				health_component.max_health
			)

	inventory.coins_changed.emit(inventory.coins)
	inventory.xp_changed.emit(inventory.xp, inventory.level)
	inventory.inventory_changed.emit()
	inventory.equipment_changed.emit()
	inventory.stats_changed.emit()
	inventory.active_potion_changed.emit(inventory.active_health_potion)

	pending_restore = false


func _serialize_item(item: ItemData) -> Dictionary:
	return {
		"item_name": item.item_name,
		"item_type": item.item_type,
		"variant_id": item.variant_id,
		"rarity": item.rarity,
		"weapon_family": item.weapon_family,
		"equip_slot": item.equip_slot,
		"is_two_handed": item.is_two_handed,
		"stats": item.stats.duplicate(true),
		"stackable": item.stackable,
		"max_stack": item.max_stack,
		"quantity": item.quantity
	}


func _deserialize_item(data: Dictionary) -> ItemData:
	var item := ItemData.new()

	item.item_name = str(data.get("item_name", ""))
	item.item_type = str(data.get("item_type", ""))
	item.variant_id = str(data.get("variant_id", ""))
	item.rarity = str(data.get("rarity", "common"))
	item.weapon_family = str(data.get("weapon_family", ""))
	item.equip_slot = str(data.get("equip_slot", ""))
	item.is_two_handed = bool(data.get("is_two_handed", false))
	item.stats = data.get("stats", {}).duplicate(true)
	item.stackable = bool(data.get("stackable", false))
	item.max_stack = int(data.get("max_stack", 1))
	item.quantity = int(data.get("quantity", 1))

	LootGenerator.apply_variant_data_to_item(item)

	return item
	
