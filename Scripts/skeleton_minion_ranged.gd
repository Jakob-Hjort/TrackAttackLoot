extends CharacterBody3D

signal died(enemy)

const WALK_SPEED := 1.5
const RUN_SPEED := 2.5
const CHASE_RANGE := 16.0
const SHOOT_RANGE := 10.0
const TOO_CLOSE_RANGE := 4.0
const ATTACK_COOLDOWN := 1.5
const ROAM_RADIUS := 5.0
const ROAM_WAIT_MIN := 1.0
const ROAM_WAIT_MAX := 2.5

@export var player_path: NodePath
@export var projectile_scene: PackedScene
@export var attack_damage: int = 8
@export var xp_reward: int = 15
@export var coin_reward: int = 8

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayerMinion
@onready var animation_tree: AnimationTree = $AnimationTreeMinion
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

@onready var health_bar_anchor: Node3D = $HealthBarAnchor
@onready var health_bar_viewport: SubViewport = $HealthBarAnchor/SubViewport
@onready var health_bar_sprite: Sprite3D = $HealthBarAnchor/Sprite3D
@onready var enemy_health_bar = $HealthBarAnchor/SubViewport/Control/EnemyHealthBar

@onready var shoot_point: Node3D = $Rig_Medium/Skeleton3D/Right_Hand/Skeleton_Crossbow2/ShootPoint

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
		animation_tree.active = false

	if health_component:
		if not health_component.damaged.is_connected(_on_damaged):
			health_component.damaged.connect(_on_damaged)
		if not health_component.died.is_connected(_on_died):
			health_component.died.connect(_on_died)

	if enemy_health_bar and health_component:
		enemy_health_bar.visible = false
		enemy_health_bar.set_health(health_component.current_health, health_component.max_health)

	play_animation("Skeleton_ranged/Skeletons_Idle")

func _physics_process(_delta: float) -> void:
	if is_dead or is_hit:
		move_and_slide()
		return

	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			velocity = Vector3.ZERO
			play_animation("Skeleton_ranged/Skeletons_Idle")
			move_and_slide()
			return

	var flat_player_pos := player.global_position
	flat_player_pos.y = global_position.y

	var distance_to_player := global_position.distance_to(flat_player_pos)
	var can_see_player := has_line_of_sight_to_player()

	if can_see_player and distance_to_player <= TOO_CLOSE_RANGE:
		retreat_from_player()
	elif can_see_player and distance_to_player <= SHOOT_RANGE:
		velocity = Vector3.ZERO
		face_player()

		if can_attack and not is_attacking:
			start_attack()
		elif not is_attacking:
			play_animation("Skeleton_ranged/Ranged_2H_Aiming")
	elif can_see_player and distance_to_player <= CHASE_RANGE:
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

	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		play_animation("Skeleton_ranged/Skeletons_Idle")
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		velocity = Vector3.ZERO
		play_animation("Skeleton_ranged/Skeletons_Idle")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * RUN_SPEED
	velocity.z = move_direction.z * RUN_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Skeleton_ranged/Skeletons_Walking")

func retreat_from_player() -> void:
	if player == null:
		return

	var away_dir := global_position - player.global_position
	away_dir.y = 0.0

	if away_dir.length() < 0.01:
		velocity = Vector3.ZERO
		return

	away_dir = away_dir.normalized()

	velocity.x = away_dir.x * WALK_SPEED
	velocity.z = away_dir.z * WALK_SPEED

	face_player()

	if not is_attacking:
		play_animation("Skeleton_ranged/Skeletons_Walking")

func roam() -> void:
	if is_attacking or is_dead or is_hit:
		return

	if is_waiting:
		velocity = Vector3.ZERO
		play_animation("Skeleton_ranged/Skeletons_Idle")
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
		play_animation("Skeleton_ranged/Skeletons_Idle")
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		choose_new_roam_target()
		velocity = Vector3.ZERO
		play_animation("Skeleton_ranged/Skeletons_Idle")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * WALK_SPEED
	velocity.z = move_direction.z * WALK_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Skeleton_ranged/Skeletons_Walking")

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
	play_animation("Skeleton_ranged/Skeletons_Idle")

	var wait_time := randf_range(ROAM_WAIT_MIN, ROAM_WAIT_MAX)
	await get_tree().create_timer(wait_time).timeout

	if not is_dead:
		is_waiting = false

func start_attack() -> void:
	if is_dead or animation_player == null or projectile_scene == null:
		return

	is_attacking = true
	can_attack = false
	current_anim = ""
	velocity = Vector3.ZERO

	play_animation("Skeleton_ranged/Ranged_2H_Shoot")

	var anim := animation_player.get_animation("Skeleton_ranged/Ranged_2H_Shoot")

	# Justér dette tal til det øjeblik hvor armbrøsten peger rigtigt frem
	await get_tree().create_timer(0.38).timeout
	if not is_dead and is_attacking:
		shoot_projectile()

	if anim != null:
		await get_tree().create_timer(max(anim.length - 0.38, 0.1)).timeout
	else:
		await get_tree().create_timer(0.35).timeout

	if is_dead:
		return

	play_animation("Skeleton_ranged/Ranged_2H_Reload")
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout

	if is_dead:
		return

	can_attack = true
	is_attacking = false
	current_anim = ""

func shoot_projectile() -> void:
	print("shoot_projectile CALLED")

	if player == null:
		print("FAIL: player is null")
		return

	if projectile_scene == null:
		print("FAIL: projectile_scene is null")
		return

	if shoot_point == null:
		print("FAIL: shoot_point is null")
		return

	var arrow = projectile_scene.instantiate()
	print("Arrow instantiated:", arrow)

	get_tree().current_scene.add_child(arrow)

	arrow.global_position = shoot_point.global_position
	print("Arrow spawn pos:", arrow.global_position)

	var target_pos := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target_pos - shoot_point.global_position).normalized()
	print("Arrow dir:", dir)

	if arrow.has_method("setup"):
		arrow.setup(dir)
		print("Arrow setup called")
	else:
		print("FAIL: arrow has no setup()")

func _on_damaged(_damage_data: DamageData) -> void:
	if is_dead:
		return

	update_health_bar()
	play_hit()

func _on_died() -> void:
	if is_dead:
		return

	die()

func play_hit() -> void:
	if is_dead or animation_player == null:
		return

	is_hit = true
	is_attacking = false
	is_roaming = false
	is_waiting = false
	velocity = Vector3.ZERO
	current_anim = ""
	play_animation("Skeleton_ranged/Skeletons_Taunt")

	var anim := animation_player.get_animation("Skeleton_ranged/Skeletons_Taunt")
	if anim != null:
		await get_tree().create_timer(min(anim.length, 0.35)).timeout
	else:
		await get_tree().create_timer(0.35).timeout

	is_hit = false
	current_anim = ""

func die() -> void:
	if enemy_health_bar:
		enemy_health_bar.visible = false
	
	if is_dead or animation_player == null:
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
	play_animation("Minions Animation/Death_A")

	var anim := animation_player.get_animation("Minions Animation/Death_A")
	if anim != null:
		await get_tree().create_timer(anim.length).timeout
	else:
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

func play_animation(anim_name: String) -> void:
	if animation_player == null:
		return

	if current_anim == anim_name:
		return

	current_anim = anim_name
	animation_player.play(anim_name)

func update_health_bar() -> void:
	if enemy_health_bar == null or health_component == null:
		return

	enemy_health_bar.visible = true
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

func spawn_loot():

	if randf() > 0.3:
		return

	var item = LootGenerator.generate_item("axe-1handed")

	var loot_scene = preload("res://Scenes/Loot.tscn")
	var loot = loot_scene.instantiate()

	get_tree().current_scene.add_child(loot)

	loot.global_position = global_position + Vector3(0, 1.0, 0)

	loot.set_item(item)
