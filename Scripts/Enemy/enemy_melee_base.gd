extends EnemyBase
class_name EnemyMeleeBase

const WALK_SPEED := 1.5
const RUN_SPEED := 2.8
const CHASE_RANGE := 12.0
const COMBAT_STOP_RANGE := 1.5
const ATTACK_RANGE := 1.8
const ATTACK_COOLDOWN := 0.35

@export var idle_animation: String = "SkeletonUnarmed_runtime/Skeletons_Idle"
@export var walk_animation: String = "SkeletonUnarmed_runtime/Skeletons_Walking"
@export var hit_animation: String = "SkeletonUnarmed_runtime/Hit_B"
@export var death_animation: String = "SkeletonUnarmed_runtime/Skeletons_Death"
@export var attack_animation: String = "SkeletonUnarmed_runtime/Melee_Unarmed_Attack_Punch_A"

@export var attack_hitbox_time: float = 0.16
@export var attack_hitbox_duration: float = 0.12
@export var post_attack_recovery: float = 0.35

@onready var attack_hitbox: HitboxComponent = find_child("AttackHitBox", true, false) as HitboxComponent

var can_attack := true

func _ready() -> void:
	super._ready()
	print("MELEE ENEMY attack_hitbox =", attack_hitbox)
	print("MELEE ENEMY hurtbox =", hurtbox)


	if attack_hitbox != null:
		attack_hitbox.damage_amount = attack_damage
		attack_hitbox.set_active(false)

	play_animation(idle_animation)

func _physics_process(_delta: float) -> void:
	if is_dead or is_hit:
		move_and_slide()
		return

	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			velocity = Vector3.ZERO
			play_animation(idle_animation)
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
		roam(idle_animation, walk_animation, WALK_SPEED)

	move_and_slide()

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
			play_animation(idle_animation)
		return

	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		play_animation(idle_animation)
		return

	var next_point := nav_agent.get_next_path_position()
	var move_direction := next_point - global_position
	move_direction.y = 0.0

	if move_direction.length() < 0.05:
		velocity = Vector3.ZERO
		play_animation(idle_animation)
		return

	move_direction = move_direction.normalized()

	velocity.x = move_direction.x * RUN_SPEED
	velocity.z = move_direction.z * RUN_SPEED

	face_direction(move_direction)

	if not is_attacking:
		play_animation(walk_animation)

func start_attack() -> void:
	if is_dead:
		return

	is_attacking = true
	can_attack = false
	current_anim = ""
	velocity = Vector3.ZERO

	if attack_hitbox != null:
		attack_hitbox.damage_amount = attack_damage
		attack_hitbox.set_active(false)

	play_animation(attack_animation)

	await get_tree().create_timer(attack_hitbox_time).timeout
	if not is_dead and is_attacking and attack_hitbox != null:
		attack_hitbox.set_active(true)

	await get_tree().create_timer(attack_hitbox_duration).timeout
	if attack_hitbox != null:
		attack_hitbox.set_active(false)

	await get_tree().create_timer(post_attack_recovery).timeout

	if is_dead:
		return

	can_attack = true
	is_attacking = false
	current_anim = ""
	play_animation(idle_animation)

	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	if is_dead:
		return

func _on_damaged(_damage_data: DamageData) -> void:
	if is_dead:
		return

	super._on_damaged(_damage_data)
	play_hit()

func play_hit() -> void:
	if is_dead:
		return

	is_hit = true
	is_attacking = false
	is_roaming = false
	is_waiting = false
	velocity = Vector3.ZERO
	current_anim = ""

	if attack_hitbox != null:
		attack_hitbox.set_active(false)

	play_animation(hit_animation)

	var anim := animation_player.get_animation(hit_animation)
	if anim != null:
		await get_tree().create_timer(min(anim.length, 0.35)).timeout
	else:
		await get_tree().create_timer(0.35).timeout

	is_hit = false
	current_anim = ""

func die(death_anim: String = death_animation) -> void:
	if attack_hitbox != null:
		attack_hitbox.set_active(false)

	await super.die(death_anim)
