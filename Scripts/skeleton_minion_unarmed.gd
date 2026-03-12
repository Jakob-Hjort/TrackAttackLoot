extends CharacterBody3D

signal died(enemy)

const WALK_SPEED := 1.5
const RUN_SPEED := 2.8
const CHASE_RANGE := 12.0
const ATTACK_RANGE := 1.8
const ATTACK_COOLDOWN := 1.2
const ROAM_RADIUS := 5.0
const ROAM_WAIT_MIN := 1.0
const ROAM_WAIT_MAX := 2.5

@export var player_path: NodePath

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animation_player: AnimationPlayer = $AnimationPlayerMinion
@onready var animation_tree: AnimationTree = $AnimationTreeMinion

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var attack_hitbox: HitboxComponent = $AttackHitbox

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

func _ready():
	add_to_group("enemies")

	player = get_node_or_null(player_path)
	spawn_position = global_position
	roam_target = global_position

	if animation_tree:
		animation_tree.active = false

	attack_hitbox.set_active(false)

	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

	play_animation("Minions Animation/Idle_B")

func _physics_process(_delta):
	if is_dead or is_hit:
		move_and_slide()
		return

	if player == null:
		return

	var flat_player_pos := player.global_position
	flat_player_pos.y = global_position.y

	var distance_to_player := global_position.distance_to(flat_player_pos)

	if distance_to_player <= ATTACK_RANGE:
		velocity = Vector3.ZERO
		face_player()

		if can_attack and not is_attacking:
			start_attack()
	elif distance_to_player <= CHASE_RANGE:
		chase_player()
	else:
		roam()

	move_and_slide()

func chase_player():
	if is_dead or is_hit:
		return

	is_roaming = false
	is_waiting = false

	nav_agent.set_target_position(player.global_position)
	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0

	if move_direction.length() < 0.05:
		velocity = Vector3.ZERO
		play_animation("Minions Animation/Idle_B")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * RUN_SPEED
	velocity.z = move_direction.z * RUN_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Minions Animation/Running_B")

func roam():
	if is_attacking or is_dead or is_hit:
		return

	if is_waiting:
		velocity = Vector3.ZERO
		play_animation("Minions Animation/Idle_B")
		return

	if not is_roaming:
		choose_new_roam_target()
		return

	var distance_to_target := global_position.distance_to(roam_target)

	if distance_to_target < 0.6:
		start_roam_wait()
		return

	nav_agent.set_target_position(roam_target)
	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0

	if move_direction.length() < 0.05:
		velocity = Vector3.ZERO
		play_animation("Minions Animation/Idle_B")
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * WALK_SPEED
	velocity.z = move_direction.z * WALK_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation("Minions Animation/Walking_B")

func choose_new_roam_target():
	is_roaming = true

	var random_offset := Vector3(
		randf_range(-ROAM_RADIUS, ROAM_RADIUS),
		0,
		randf_range(-ROAM_RADIUS, ROAM_RADIUS)
	)

	roam_target = spawn_position + random_offset

func start_roam_wait():
	is_roaming = false
	is_waiting = true
	velocity = Vector3.ZERO
	play_animation("Minions Animation/Idle_B")

	var wait_time := randf_range(ROAM_WAIT_MIN, ROAM_WAIT_MAX)
	await get_tree().create_timer(wait_time).timeout

	if not is_dead:
		is_waiting = false

func start_attack():
	if is_dead:
		return

	is_attacking = true
	can_attack = false
	current_anim = ""
	play_animation("Minions Animation/Melee_Unarmed_Attack_Punch_A")

	# Aktivér hitbox når slaget lander
	await get_tree().create_timer(0.20).timeout
	attack_hitbox.set_active(true)

	await get_tree().create_timer(0.12).timeout
	attack_hitbox.set_active(false)

	var anim = animation_player.get_animation("Minions Animation/Melee_Unarmed_Attack_Punch_A")
	if anim != null:
		await get_tree().create_timer(max(anim.length - 0.32, 0.1)).timeout
	else:
		await get_tree().create_timer(0.4).timeout

	is_attacking = false
	current_anim = ""

	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

func _on_damaged(damage_data: DamageData):
	if is_dead:
		return

	print("Minion took damage:", damage_data.amount)
	play_hit()

func _on_died():
	if is_dead:
		return

	die()

func play_hit():
	if is_dead:
		return

	is_hit = true
	is_attacking = false
	velocity = Vector3.ZERO
	current_anim = ""
	play_animation("Minions Animation/Hit_B")

	var anim = animation_player.get_animation("Minions Animation/Hit_B")
	if anim != null:
		await get_tree().create_timer(anim.length).timeout
	else:
		await get_tree().create_timer(0.35).timeout

	is_hit = false
	current_anim = ""

func die():
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_hit = false
	velocity = Vector3.ZERO

	died.emit(self)

	current_anim = ""
	play_animation("Minions Animation/Death_A")

	var anim = animation_player.get_animation("Minions Animation/Death_A")
	if anim != null:
		await get_tree().create_timer(anim.length).timeout
	else:
		await get_tree().create_timer(1.0).timeout

	queue_free()

func face_player():
	if player == null:
		return

	var target_pos := player.global_position
	target_pos.y = global_position.y
	look_at(target_pos, Vector3.UP)

func face_direction(move_direction: Vector3):
	if move_direction.length() <= 0.01:
		return

	var target_pos := global_position + move_direction
	target_pos.y = global_position.y
	look_at(target_pos, Vector3.UP)

func play_animation(anim_name: String):
	if current_anim == anim_name:
		return

	current_anim = anim_name
	animation_player.play(anim_name)
