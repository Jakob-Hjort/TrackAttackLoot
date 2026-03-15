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

var current_anim := ""
var is_attacking := false
var is_dead := false

var equipped_weapon: Node3D = null
var attack_hitbox: HitboxComponent = null

var attack_animations: Array[String] = [
	"Melee_1H_Attack_Chop",
	"Melee_1H_Attack_Slice_Diagonal",
	"Melee_1H_Attack_Stab"
]

var current_attack_index: int = 0

func _ready() -> void:
	animation_tree.active = true
	animation_tree.advance(0)
	play_animation("Idle_A")
	add_to_group("player")

	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)

	equip_weapon(preload("res://Assets/Characters/Scenes/Weapons/onhanded_axe.tscn"))

func equip_weapon(weapon_scene: PackedScene) -> void:
	if weapon_scene == null:
		return

	if equipped_weapon != null and is_instance_valid(equipped_weapon):
		equipped_weapon.queue_free()
		equipped_weapon = null
		attack_hitbox = null

	var weapon = weapon_scene.instantiate() as Node3D
	if weapon == null:
		push_error("Weapon scene kunne ikke instantieres som Node3D")
		return

	var hand: Node3D = $VisualRoot/Barbarian/Rig_Medium/Skeleton3D/Right_Hand
	hand.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY

	equipped_weapon = weapon
	attack_hitbox = weapon.get_node_or_null("AttackHitbox") as HitboxComponent

	print("WEAPON EQUIPPED:", weapon.name)
	print("ATTACK HITBOX FOUND:", attack_hitbox)

	if attack_hitbox == null:
		push_error("AttackHitbox blev ikke fundet på våbnet")
		return

	attack_hitbox.set_active(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

func _physics_process(delta: float) -> void:
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

	forward.y = 0.0
	right.y = 0.0
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
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)

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
			
	if Input.is_action_just_pressed("ui_page_down"):
		var inventory = get_node_or_null("PlayerInventory")
		if inventory and inventory.has_method("debug_print_inventory"):
			inventory.debug_print_inventory()

func start_attack() -> void:
	if is_dead or attack_hitbox == null:
		print("ATTACK FAIL: no hitbox")
		return

	if attack_animations.is_empty():
		print("ATTACK FAIL: no attack animations")
		return

	is_attacking = true
	current_anim = ""

	var attack_name := attack_animations[current_attack_index]
	play_animation(attack_name)

	print("PLAYER ATTACK START:", attack_name)

	current_attack_index += 1
	if current_attack_index >= attack_animations.size():
		current_attack_index = 0

	# Midlertidigt tilbage til timer, indtil method tracks er sat op
	await get_tree().create_timer(0.14).timeout
	attack_hitbox_on()

	await get_tree().create_timer(0.18).timeout
	attack_hitbox_off()

	var anim := animation_player.get_animation("Player_barbarian/" + attack_name)
	if anim != null:
		await get_tree().create_timer(max(anim.length - 0.32, 0.08)).timeout
	else:
		await get_tree().create_timer(0.4).timeout

	attack_hitbox_off()
	is_attacking = false
	current_anim = ""

func attack_hitbox_on() -> void:
	if attack_hitbox:
		print("PLAYER HITBOX ON")
		attack_hitbox.set_active(true)

func attack_hitbox_off() -> void:
	if attack_hitbox:
		print("PLAYER HITBOX OFF")
		attack_hitbox.set_active(false)

func play_animation(anim_name: String) -> void:
	if current_anim == anim_name:
		return

	current_anim = anim_name
	playback.travel(anim_name)

func _on_damaged(damage_data: DamageData) -> void:
	print("Player took damage:", damage_data.amount)

func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	velocity = Vector3.ZERO

	print("Player died")

func _on_health_changed(current_health: int, max_health: int) -> void:
	print("Player health:", current_health, "/", max_health)
