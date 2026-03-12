extends CharacterBody3D

const WALK_SPEED := 3.5
const RUN_SPEED := 6.0
const BACKWARD_MULTIPLIER := 0.6
const ROTATION_SPEED := 10.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.01

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_pitch: Node3D = $CameraPivot/CameraPitch
@onready var camera: Camera3D = $CameraPivot/CameraPitch/Camera3D
@onready var barbarian: Node3D = $VisualRoot/Barbarian
@onready var animation_tree: AnimationTree = $VisualRoot/Barbarian/AnimationTreePlayer
@onready var animation_player: AnimationPlayer = $VisualRoot/Barbarian/AnimationPlayerPlayer
@onready var playback = animation_tree["parameters/playback"]

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var attack_hitbox: HitboxComponent = $AttackHitbox

var current_anim := ""
var is_attacking := false
var is_dead := false

func _ready():
	animation_tree.active = true
	animation_tree.advance(0)
	play_animation("Idle_A")

	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)

	attack_hitbox.set_active(false)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not is_attacking:
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("attack") and not is_attacking:
		start_attack()

	var input_vector := Input.get_vector("left", "right", "down", "up")

	var camera_basis := camera.global_transform.basis
	var forward := -camera_basis.z
	var right := camera_basis.x

	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var move_direction := (right * input_vector.x + forward * input_vector.y).normalized()
	var is_sprinting := Input.is_action_pressed("sprint")

	var current_speed := WALK_SPEED
	if is_sprinting and input_vector.y > 0.0:
		current_speed = RUN_SPEED

	if input_vector.y < 0.0:
		current_speed *= BACKWARD_MULTIPLIER

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed

		var backward_only: bool = input_vector.y < 0.0 and abs(input_vector.x) < 0.1
		if not backward_only:
			var target_rotation := atan2(move_direction.x, move_direction.z)
			barbarian.rotation.y = lerp_angle(barbarian.rotation.y, target_rotation, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)

	move_and_slide()

	if not is_attacking:
		if not is_on_floor():
			play_animation("Jump_Full_Short")
		elif move_direction != Vector3.ZERO:
			if is_sprinting and input_vector.y > 0.0:
				play_animation("Running_A")
			else:
				play_animation("Walking_A")
		else:
			play_animation("Idle_A")

func start_attack():
	if is_dead:
		return

	is_attacking = true
	current_anim = ""
	play_animation("Melee_1H_Attack_Chop")

	# Aktiver hitbox midt i angrebet
	await get_tree().create_timer(0.20).timeout
	attack_hitbox.set_active(true)

	await get_tree().create_timer(0.15).timeout
	attack_hitbox.set_active(false)

	var anim := animation_player.get_animation("Player_barbarian/Melee_1H_Attack_Chop")
	if anim != null:
		await get_tree().create_timer(max(anim.length - 0.35, 0.1)).timeout
	else:
		await get_tree().create_timer(0.45).timeout

	is_attacking = false
	current_anim = ""

func play_animation(anim_name: String):
	if current_anim == anim_name:
		return

	current_anim = anim_name
	playback.travel(anim_name)

func _on_damaged(damage_data: DamageData):
	print("Player took damage:", damage_data.amount)

func _on_died():
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO

	print("Player died")

	# Hvis du har en death animation, kan du skifte til den her
	# current_anim = ""
	# play_animation("Death_A")

func _on_health_changed(current_health: int, max_health: int):
	print("Player health:", current_health, "/", max_health)
