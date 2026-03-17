extends CharacterBody3D

signal died(enemy)

const WALK_SPEED := 1.5
const RUN_SPEED := 2.8
const CHASE_RANGE := 12.0
const COMBAT_STOP_RANGE := 1.5
const ATTACK_RANGE := 1.8
const ATTACK_COOLDOWN := 0.1
const ROAM_RADIUS := 5.0
const ROAM_WAIT_MIN := 1.0
const ROAM_WAIT_MAX := 2.5

@export var player_path: NodePath
@export var attack_damage: int = 10
@export var xp_reward: int = 10
@export var coin_reward: int = 5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayerMinion
@onready var animation_tree: AnimationTree = $AnimationTreeMinion
@onready var playback = animation_tree["parameters/playback"]
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

@onready var health_bar_anchor: Node3D = $HealthBarAnchor
@onready var health_bar_viewport: SubViewport = $HealthBarAnchor/SubViewport
@onready var health_bar_sprite: Sprite3D = $HealthBarAnchor/Sprite3D
@onready var enemy_health_bar = $HealthBarAnchor/SubViewport/Control/EnemyHealthBar

@export var mob_id: String = "skeleton_unarmed"
@export var drop_chance: float = 0.65
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var loot_scene: PackedScene = preload("res://Scenes/loot.tscn")

var player: Node3D = null
var current_anim := ""
var is_dead := false
var is_attacking := false
var is_hit := false
var can_attack := true

var spawn_position: Vector3
var roam_target: Vector3
var is_roaming := false
var is_waiting := false

func _ready() -> void:
	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()

	add_to_group("enemies")

	_find_player()

	spawn_position = global_position
	roam_target = global_position

	if animation_tree:
		animation_tree.active = true
		animation_tree.advance(0)

	if health_component:
		if not health_component.damaged.is_connected(_on_damaged):
			health_component.damaged.connect(_on_damaged)
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()

	if enemy_health_bar and health_component:
		enemy_health_bar.visible = false
		enemy_health_bar.set_health(health_component.current_health, health_component.max_health)

	play_animation("Skeletons_Idle")

func _physics_process(_delta: float) -> void:
	if is_dead or is_hit:
		move_and_slide()
		return

	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			velocity = Vector3.ZERO
			play_animation("Skeletons_Idle")
			move_and_slide()
			return

	var flat_player_pos := player.global_position
	flat_player_pos.y = global_position.y

	var distance_to_player := global_position.distance_to(flat_player_pos)
	var can_see_player := has_line_of_sight_to_player()

	if distance_to_player <= ATTACK_RANGE and can_see_player:
		velocity = Vector3.ZERO
		face_player()

		if can_attack and not is_attacking:
			start_attack()

	elif distance_to_player <= CHASE_RANGE and can_see_player:
		chase_player()
	else:
		roam()

	move_and_slide()

func _find_player() -> void:
	if player_path != NodePath():
		player = get_node_or_null(player_path) as Node3D
	else:
		player = get_tree().get_first_node_in_group("player") as Node3D

func has_line_of_sight_to_player() -> bool:
	if player == null:
		return false

	var from := global_position + Vector3(0.0, 1.0, 0.0)
	var to := player.global_position + Vector3(0.0, 1.0, 0.0)

	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return true

	return result["collider"] == player

func chase_player() -> void:
	if is_dead or is_hit or player == null:
		return

	is_roaming = false
	is_waiting = false

	var target_pos := player.global_position
	target_pos.y = global_position.y

	var distance_to_player := global_position.distance_to(target_pos)

	if distance_to_player <= COMBAT_STOP_RANGE:
		velocity = Vector3.ZERO
		face_player()

		if not is_attacking:
			play_animation("Skeletons_Idle")
		return

	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		play_animation("Skeletons_Idle")
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		velocity = Vector3.ZERO
		play_animation("Skeletons_Idle")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * RUN_SPEED
	velocity.z = move_direction.z * RUN_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Running_B")

func roam() -> void:
	if is_attacking or is_dead or is_hit:
		return

	if is_waiting:
		velocity = Vector3.ZERO
		play_animation("Skeletons_Idle")
		return

	if not is_roaming:
		choose_new_roam_target()
		return

	var distance_to_target := global_position.distance_to(roam_target)

	if distance_to_target < 0.6:
		start_roam_wait()
		return

	nav_agent.target_position = roam_target

	if nav_agent.is_navigation_finished():
		choose_new_roam_target()
		velocity = Vector3.ZERO
		play_animation("Skeletons_Idle")
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		choose_new_roam_target()
		velocity = Vector3.ZERO
		play_animation("Skeletons_Idle")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * WALK_SPEED
	velocity.z = move_direction.z * WALK_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Skeletons_Walking")

func choose_new_roam_target() -> void:
	is_roaming = true

	for _i in range(5):
		var random_offset := Vector3(
			randf_range(-ROAM_RADIUS, ROAM_RADIUS),
			0.0,
			randf_range(-ROAM_RADIUS, ROAM_RADIUS)
		)

		var candidate := spawn_position + random_offset
		nav_agent.target_position = candidate

		if not nav_agent.is_navigation_finished():
			roam_target = candidate
			return

	roam_target = spawn_position

func start_roam_wait() -> void:
	is_roaming = false
	is_waiting = true
	velocity = Vector3.ZERO
	play_animation("Skeletons_Idle")

	var wait_time := randf_range(ROAM_WAIT_MIN, ROAM_WAIT_MAX)
	await get_tree().create_timer(wait_time).timeout

	if not is_dead:
		is_waiting = false

func start_attack() -> void:
	if is_dead:
		return

	is_attacking = true
	can_attack = false
	current_anim = ""
	velocity = Vector3.ZERO

	play_animation("Melee_Unarmed_Attack_Punch_A")

	await get_tree().create_timer(0.16).timeout
	if not is_dead and is_attacking:
		perform_attack_hit()

	await get_tree().create_timer(0.35).timeout

	if is_dead:
		return

	can_attack = true
	is_attacking = false
	current_anim = ""
	play_animation("Skeletons_Idle")

	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	if is_dead:
		return

func perform_attack_hit() -> void:
	if player == null or is_dead:
		return

	if not is_instance_valid(player):
		return

	var player_hurtbox := player.get_node_or_null("HurtboxComponent") as HurtboxComponent
	if player_hurtbox == null:
		print("MINION: ingen player hurtbox")
		return

	print("MINION: sender damage nu")

	var dmg := DamageData.new()
	dmg.amount = attack_damage
	dmg.damage_type = "physical"
	dmg.source = self

	player_hurtbox.receive_hit(dmg)

func _on_damaged(_damage_data: DamageData) -> void:
	if is_dead:
		return

	print("MINION TOG SKADE")
	update_health_bar()
	play_hit()

func _on_died() -> void:
	if is_dead:
		return

	die()

func play_hit() -> void:
	if is_dead:
		return

	is_hit = true
	is_attacking = false
	is_roaming = false
	is_waiting = false
	velocity = Vector3.ZERO
	current_anim = ""

	play_animation("Hit_B")

	await get_tree().create_timer(0.35).timeout

	is_hit = false
	current_anim = ""

func die() -> void:
	if enemy_health_bar:
		enemy_health_bar.visible = false

	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_hit = false
	is_roaming = false
	is_waiting = false
	velocity = Vector3.ZERO

	died.emit(self)

	give_rewards_to_player()
	spawn_loot()

	current_anim = ""
	play_animation("Skeletons_Death")

	await get_tree().create_timer(1.0).timeout

	queue_free()

func face_player() -> void:
	if player == null:
		return

	var target_pos := player.global_position
	target_pos.y = global_position.y
	look_at(target_pos, Vector3.UP)

func face_direction(move_direction: Vector3) -> void:
	if move_direction.length() <= 0.01:
		return

	var target_pos := global_position + move_direction
	target_pos.y = global_position.y
	look_at(target_pos, Vector3.UP)

func play_animation(state_name: String) -> void:
	if animation_tree == null:
		return
	if playback == null:
		return
	if current_anim == state_name:
		return

	current_anim = state_name
	playback.travel(state_name)

func update_health_bar() -> void:
	if enemy_health_bar == null or health_component == null:
		print("HEALTHBAR FAIL: enemy_health_bar eller health_component er null")
		return

	print("UPDATE HEALTHBAR:", health_component.current_health, "/", health_component.max_health)
	enemy_health_bar.set_health(health_component.current_health, health_component.max_health)

func give_rewards_to_player() -> void:
	if player == null:
		return

	var inventory = player.get_node_or_null("PlayerInventory")
	if inventory == null:
		print("No PlayerInventory found on player")
		return

	if inventory.has_method("add_xp"):
		inventory.add_xp(xp_reward)

	if inventory.has_method("add_coins"):
		inventory.add_coins(coin_reward)

func spawn_loot() -> void:
	if randf() > drop_chance:
		print("No loot dropped")
		return

	var item := LootGenerator.generate_item_for_mob(mob_id, is_elite, is_boss)
	if item == null:
		print("No valid loot item generated for mob_id:", mob_id)
		return

	if loot_scene == null:
		print("Loot scene missing on enemy")
		return

	var loot = loot_scene.instantiate() as LootDrop
	if loot == null:
		print("Failed to instantiate loot scene")
		return

	get_tree().current_scene.add_child(loot)
	loot.global_position = global_position + Vector3(0, 1.0, 0)
	loot.set_item(item)

	print("Loot spawned at:", loot.global_position)
	print("Enemy died at:", global_position)
	print("Mob ID:", mob_id)
	print("Dropped item:", item.item_name, "rarity:", item.rarity)
