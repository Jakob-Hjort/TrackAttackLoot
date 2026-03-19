extends CharacterBody3D
class_name EnemyBase

signal died(enemy)

const ROAM_RADIUS := 5.0
const ROAM_WAIT_MIN := 1.0
const ROAM_WAIT_MAX := 2.5

@export var player_path: NodePath
@export var attack_damage: int = 10
@export var xp_reward: int = 10
@export var coin_reward: int = 5
@export var mob_id: String = "enemy"
@export var drop_chance: float = 0.5
@export var is_elite: bool = false
@export var is_boss: bool = false
@export var loot_scene: PackedScene = preload("res://Scenes/loot.tscn")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayerMinion
@onready var animation_tree: AnimationTree = $AnimationTreeMinion
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

@onready var health_bar_anchor: Node3D = $HealthBarAnchor
@onready var health_bar_viewport: SubViewport = $HealthBarAnchor/SubViewport
@onready var health_bar_sprite: Sprite3D = $HealthBarAnchor/Sprite3D
@onready var enemy_health_bar = $HealthBarAnchor/SubViewport/Control/EnemyHealthBar

var player: Node3D = null
var current_anim := ""
var is_dead := false
var is_attacking := false
var is_hit := false

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
		animation_tree.active = false

	if health_component:
		if not health_component.damaged.is_connected(_on_damaged):
			health_component.damaged.connect(_on_damaged)
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

	if enemy_health_bar and health_component:
		enemy_health_bar.visible = false
		enemy_health_bar.set_health(health_component.current_health, health_component.max_health)

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

func roam(idle_anim: String, walk_anim: String, walk_speed: float) -> void:
	if is_attacking or is_dead or is_hit:
		return

	if is_waiting:
		velocity = Vector3.ZERO
		play_animation(idle_anim)
		return

	if not is_roaming:
		choose_new_roam_target()
		return

	var distance_to_target := global_position.distance_to(roam_target)
	if distance_to_target < 0.6:
		start_roam_wait(idle_anim)
		return

	nav_agent.target_position = roam_target

	if nav_agent.is_navigation_finished():
		choose_new_roam_target()
		velocity = Vector3.ZERO
		play_animation(idle_anim)
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		choose_new_roam_target()
		velocity = Vector3.ZERO
		play_animation(idle_anim)
		return

	move_direction = move_direction.normalized()
	velocity.x = move_direction.x * walk_speed
	velocity.z = move_direction.z * walk_speed

	face_direction(move_direction)
	play_animation(walk_anim)

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

func start_roam_wait(idle_anim: String) -> void:
	is_roaming = false
	is_waiting = true
	velocity = Vector3.ZERO
	play_animation(idle_anim)

	var wait_time := randf_range(ROAM_WAIT_MIN, ROAM_WAIT_MAX)
	await get_tree().create_timer(wait_time).timeout

	if not is_dead:
		is_waiting = false

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

func play_animation(anim_name: String) -> void:
	if animation_player == null:
		return
	if current_anim == anim_name:
		return
	if not animation_player.has_animation(anim_name):
		print("Animation not found: ", anim_name)
		return

	current_anim = anim_name
	animation_player.play(anim_name)

func update_health_bar() -> void:
	if enemy_health_bar == null or health_component == null:
		return

	enemy_health_bar.visible = true
	enemy_health_bar.set_health(health_component.current_health, health_component.max_health)

func _on_damaged(_damage_data: DamageData) -> void:
	if is_dead:
		return

	update_health_bar()

func _on_died() -> void:
	if is_dead:
		return
	die()

func die(death_anim: String = "") -> void:
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
	if death_anim != "":
		play_animation(death_anim)
		var anim := animation_player.get_animation(death_anim)
		if anim != null:
			await get_tree().create_timer(anim.length).timeout
		else:
			await get_tree().create_timer(1.0).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	queue_free()

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

	var loot := loot_scene.instantiate() as LootDrop
	if loot == null:
		print("Failed to instantiate loot scene")
		return

	var run_holder = get_tree().current_scene.get_node_or_null("RunContentHolder")
	if run_holder != null:
		run_holder.add_child(loot)
	else:
		get_tree().current_scene.add_child(loot)

	loot.global_position = global_position + Vector3(0, 1.0, 0)
	loot.set_item(item)
