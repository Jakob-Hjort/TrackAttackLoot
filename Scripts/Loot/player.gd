extends CharacterBody3D

# ==================================================
# MOVEMENT / CAMERA CONSTANTS
# ==================================================
const WALK_SPEED := 3.5
const RUN_SPEED := 6.0
const BACKWARD_MULTIPLIER := 0.6
const ROTATION_SPEED := 10.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.01

# ==================================================
# NODE REFERENCES
# ==================================================
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_pitch: Node3D = $CameraPivot/CameraPitch
@onready var camera: Camera3D = $CameraPivot/CameraPitch/Camera3D

@onready var visual_root: Node3D = $VisualRoot
@onready var barbarian: Node3D = $VisualRoot/Barbarian

@onready var animation_tree: AnimationTree = $VisualRoot/Barbarian/AnimationTreePlayer
@onready var animation_player: AnimationPlayer = $VisualRoot/Barbarian/AnimationPlayerPlayer
@onready var playback = animation_tree["parameters/playback"]

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var inventory: PlayerInventory = $PlayerInventory

@onready var inventory_ui: CanvasLayer = get_tree().get_first_node_in_group("inventory_ui") as CanvasLayer

# ==================================================
# WEAPON HOLDERS
# ==================================================
var weapon_holder_main: Node3D = null
var weapon_holder_off: Node3D = null

# ==================================================
# STATE
# ==================================================
var current_anim := ""
var is_attacking := false
var is_dead := false

# ==================================================
# EQUIPPED VISUALS / HITBOXES
# ==================================================
var equipped_main_hand_visual: Node3D = null
var equipped_off_hand_visual: Node3D = null

var main_hand_hitbox: HitboxComponent = null
var off_hand_hitbox: HitboxComponent = null

# ==================================================
# ATTACK ANIMATIONS
# ==================================================
var attack_animations: Array[String] = [
	"Melee_1H_Attack_Chop",
	"Melee_1H_Attack_Slice_Diagonal",
	"Melee_1H_Attack_Stab"
]

var current_attack_index: int = 0

# ==================================================
# READY
# ==================================================
func _ready() -> void:
	animation_tree.active = true
	animation_tree.advance(0)
	play_animation("Idle_A")
	add_to_group("player")

	_find_weapon_holders()

	# Midlertidig test item
	var test_item = LootGenerator.generate_item("axe-1-handed")
	inventory.add_item(test_item)
	inventory.equip_item(test_item)

	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)

	if inventory != null:
		inventory.stats_changed.connect(_on_inventory_stats_changed)
		inventory.equipment_changed.connect(_on_inventory_equipment_changed)

		_on_inventory_stats_changed()
		_on_inventory_equipment_changed()

	if inventory_ui != null:
		inventory_ui.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ==================================================
# INPUT
# ==================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if inventory_ui == null or not inventory_ui.visible:
			camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()

func toggle_inventory() -> void:
	if inventory_ui == null:
		return

	inventory_ui.visible = not inventory_ui.visible

	if inventory_ui.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ==================================================
# PHYSICS / MOVEMENT
# ==================================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if inventory_ui != null and inventory_ui.visible:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)

		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		move_and_slide()

		if not is_attacking:
			if not is_on_floor():
				play_animation("Jump_Full_Short")
			else:
				play_animation("Idle_A")
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
			barbarian.rotation.y = lerp_angle(
				barbarian.rotation.y,
				target_rotation,
				ROTATION_SPEED * delta
			)
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
		if inventory and inventory.has_method("debug_print_inventory"):
			inventory.debug_print_inventory()

# ==================================================
# ATTACK
# ==================================================
func start_attack() -> void:
	if is_dead or main_hand_hitbox == null:
		print("ATTACK FAIL: no main hand hitbox")
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
	if main_hand_hitbox:
		print("PLAYER MAIN HAND HITBOX ON")
		main_hand_hitbox.set_active(true)

func attack_hitbox_off() -> void:
	if main_hand_hitbox:
		print("PLAYER MAIN HAND HITBOX OFF")
		main_hand_hitbox.set_active(false)

# ==================================================
# ANIMATION
# ==================================================
func play_animation(anim_name: String) -> void:
	if current_anim == anim_name:
		return

	current_anim = anim_name
	playback.travel(anim_name)

# ==================================================
# HEAL / HEALTH
# ==================================================
func heal(amount: int) -> void:
	if amount <= 0:
		return

	if is_dead:
		return

	if health_component == null:
		return

	if health_component.has_method("heal"):
		health_component.heal(amount)
		print("PLAYER HEALED:", amount)
	else:
		print("HealthComponent mangler heal(amount)")

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

# ==================================================
# INVENTORY / STATS
# ==================================================
func _on_inventory_stats_changed() -> void:
	if inventory == null or health_component == null:
		return

	var total_stats := inventory.get_total_stats()

	var old_max_health := health_component.max_health
	var new_max_health := int(total_stats.get("max_health", old_max_health))

	health_component.max_health = new_max_health

	if health_component.current_health > health_component.max_health:
		health_component.current_health = health_component.max_health

	health_component.health_changed.emit(
		health_component.current_health,
		health_component.max_health
	)

	print("PLAYER TOTAL STATS:", total_stats)

# ==================================================
# WEAPON HOLDERS
# ==================================================
func _find_weapon_holders() -> void:
	weapon_holder_main = visual_root.find_child("WeaponHolderMainHand", true, false) as Node3D
	weapon_holder_off = visual_root.find_child("WeaponHolderOffHand", true, false) as Node3D

	if weapon_holder_main == null:
		push_error("WeaponHolderMainHand not found!")
	else:
		print("Found main hand holder:", weapon_holder_main.get_path())

	if weapon_holder_off == null:
		push_error("WeaponHolderOffHand not found!")
	else:
		print("Found off hand holder:", weapon_holder_off.get_path())

# ==================================================
# EQUIPMENT VISUALS
# ==================================================
func _on_inventory_equipment_changed() -> void:
	if inventory == null:
		return

	_clear_equipped_main_hand_visual()
	_clear_equipped_off_hand_visual()

	# Main hand
	if inventory.equipped_main_hand != null:
		if inventory.equipped_main_hand.equip_mesh_scene == null:
			print("Main hand item has no equip_mesh_scene:", inventory.equipped_main_hand.item_name)
		else:
			_equip_main_hand_scene(inventory.equipped_main_hand.equip_mesh_scene)

	# Off hand
	if inventory.equipped_off_hand != null:
		if inventory.equipped_off_hand.equip_mesh_scene == null:
			print("Off hand item has no equip_mesh_scene:", inventory.equipped_off_hand.item_name)
		else:
			_equip_off_hand_scene(inventory.equipped_off_hand.equip_mesh_scene)

func _equip_main_hand_scene(weapon_scene: PackedScene) -> void:
	if weapon_scene == null or weapon_holder_main == null:
		return

	var weapon := weapon_scene.instantiate() as Node3D
	if weapon == null:
		push_error("Main hand weapon scene could not instantiate as Node3D")
		return

	weapon_holder_main.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY

	equipped_main_hand_visual = weapon
	main_hand_hitbox = weapon.get_node_or_null("AttackHitbox") as HitboxComponent

	print("MAIN HAND EQUIPPED:", weapon.name)
	print("MAIN HAND HITBOX FOUND:", main_hand_hitbox)

	if main_hand_hitbox != null:
		main_hand_hitbox.set_active(false)

func _equip_off_hand_scene(weapon_scene: PackedScene) -> void:
	if weapon_scene == null or weapon_holder_off == null:
		return

	var weapon := weapon_scene.instantiate() as Node3D
	if weapon == null:
		push_error("Off hand scene could not instantiate as Node3D")
		return

	weapon_holder_off.add_child(weapon)
	weapon.transform = Transform3D.IDENTITY

	equipped_off_hand_visual = weapon
	off_hand_hitbox = weapon.get_node_or_null("AttackHitbox") as HitboxComponent

	print("OFF HAND EQUIPPED:", weapon.name)
	print("OFF HAND HITBOX FOUND:", off_hand_hitbox)

	if off_hand_hitbox != null:
		off_hand_hitbox.set_active(false)

func _clear_equipped_main_hand_visual() -> void:
	if equipped_main_hand_visual != null and is_instance_valid(equipped_main_hand_visual):
		equipped_main_hand_visual.queue_free()

	equipped_main_hand_visual = null
	main_hand_hitbox = null

func _clear_equipped_off_hand_visual() -> void:
	if equipped_off_hand_visual != null and is_instance_valid(equipped_off_hand_visual):
		equipped_off_hand_visual.queue_free()

	equipped_off_hand_visual = null
	off_hand_hitbox = null
