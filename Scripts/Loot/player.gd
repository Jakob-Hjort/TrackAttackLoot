extends CharacterBody3D

# ==================================================
# MOVEMENT / CAMERA CONSTANTS
# ==================================================
const WALK_SPEED := 3.5
const RUN_SPEED := 6.0
const BACKWARD_MULTIPLIER := 0.6
const BLOCK_MOVE_MULTIPLIER := 0.55
const ROTATION_SPEED := 10.0
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
const MOUSE_SENSITIVITY := 0.01

# ==================================================
# DEBUG EQUIP TESTS
# ==================================================
const DEBUG_EQUIP_TESTS_ENABLED := true
const DEBUG_ITEM_1H_AXE := "axe-1-handed"
const DEBUG_ITEM_2H_AXE := "axe-2-handed"
const DEBUG_ITEM_SHIELD := "shield"

# ==================================================
# NODE REFERENCES
# ==================================================
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_pitch: Node3D = $CameraPivot/CameraPitch
@onready var camera: Camera3D = $CameraPivot/CameraPitch/Camera3D

@export var character_class: CharacterClassData

@onready var visual_root: Node3D = $VisualRoot
@onready var barbarian: Node3D = $VisualRoot/Barbarian

@onready var animation_tree: AnimationTree = $VisualRoot/Barbarian/AnimationTree
@onready var animation_player: AnimationPlayer = $VisualRoot/Barbarian/AnimationPlayerPlayer
@onready var playback = animation_tree["parameters/playback"]

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var inventory: PlayerInventory = $PlayerInventory
@onready var inventory_ui: CanvasLayer = get_tree().get_first_node_in_group("inventory_ui") as CanvasLayer

@onready var unarmed_hitbox: HitboxComponent = $VisualRoot/Barbarian/Rig_Medium/Skeleton3D/Right_Hand/UnarmedHitbox

# ==================================================
# WEAPON HOLDERS
# ==================================================
var weapon_holder_main: Node3D = null
var weapon_holder_off: Node3D = null

# ==================================================
# STATE
# ==================================================
var current_anim := ""
var is_dead := false
var is_attacking := false
var is_blocking := false

var attack_move_multiplier := 0.35
var attack_turn_multiplier := 0.45
var combat_action_token: int = 0

var locomotion_blend_pos: Vector2 = Vector2.ZERO

# ==================================================
# EQUIPPED VISUALS / HITBOXES / BLOCK
# ==================================================
var equipped_main_hand_visual: Node3D = null
var equipped_off_hand_visual: Node3D = null

var main_hand_hitbox: HitboxComponent = null
var off_hand_hitbox: HitboxComponent = null
var shield_block_area: ShieldBlock = null

# ==================================================
# COMBAT PROFILES
# ==================================================
var current_attack_index: int = 0

var unarmed_profile: CombatProfile
var one_handed_profile: CombatProfile
var two_handed_profile: CombatProfile
var dual_wield_profile: CombatProfile
var one_handed_and_shield_profile: CombatProfile

# ==================================================
# READY
# ==================================================
func _ready() -> void:
	animation_tree.active = true
	animation_tree.advance(0)
	set_locomotion_blend(Vector2.ZERO)

	add_to_group("player")

	_find_weapon_holders()
	_apply_character_class_data()
	_setup_combat_profiles()

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

	if unarmed_hitbox != null:
		unarmed_hitbox.set_active(false)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	locomotion_blend_pos = Vector2.ZERO

# ==================================================
# INPUT
# ==================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if inventory_ui == null or not inventory_ui.visible:
			camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()

	if DEBUG_EQUIP_TESTS_ENABLED:
		_debug_handle_test_keys(event)

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
		stop_block()

		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED)

		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		move_and_slide()

		if not is_attacking:
			if not is_on_floor():
				play_animation("Jump_Full_Short")
			else:
				_play_idle_for_style()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not is_attacking and not is_blocking:
		velocity.y = JUMP_VELOCITY

	if _has_input_action("block") and Input.is_action_pressed("block") and not is_attacking:
		start_block()
	else:
		stop_block()

	if Input.is_action_just_pressed("attack") and not is_attacking:
		if Input.is_action_pressed("block") and get_combat_style() == "one_handed_and_shield":
			start_shield_attack()
		elif not is_blocking:
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
	var is_sprinting := false

	var current_speed := WALK_SPEED
	if is_sprinting and input_vector.y > 0.0 and not is_blocking:
		current_speed = RUN_SPEED

	if input_vector.y < 0.0:
		current_speed *= BACKWARD_MULTIPLIER

	if is_blocking:
		current_speed *= BLOCK_MOVE_MULTIPLIER

	var applied_speed := current_speed
	if is_attacking:
		applied_speed *= attack_move_multiplier

	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * applied_speed
		velocity.z = move_direction.z * applied_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, applied_speed)
		velocity.z = move_toward(velocity.z, 0.0, applied_speed)

	#var backward_only: bool = input_vector.y < 0.0 and abs(input_vector.x) < 0.1

	if move_direction != Vector3.ZERO:
		var target_rotation := atan2(forward.x, forward.z)
		var turn_speed := ROTATION_SPEED

		if is_attacking:
			target_rotation = atan2(move_direction.x, move_direction.z)
			turn_speed *= attack_turn_multiplier

		barbarian.rotation.y = lerp_angle(
			barbarian.rotation.y,
			target_rotation,
			turn_speed * delta
	)

	move_and_slide()

	if not is_attacking:
		if not is_on_floor():
			play_animation("Jump_Full_Short")
		elif is_blocking:
			_play_block_movement_animation(input_vector)
		elif move_direction != Vector3.ZERO:
			_play_movement_animation(input_vector, is_sprinting)
		else:
			_play_idle_for_style()

	if Input.is_action_just_pressed("ui_page_down"):
		if inventory and inventory.has_method("debug_print_inventory"):
			inventory.debug_print_inventory()

# ==================================================
# COMBAT STYLE
# ==================================================
func get_combat_style() -> String:
	return CombatStyleHelper.get_style_from_inventory(inventory)

# ==================================================
# ATTACK
# ==================================================
func start_attack() -> void:
	if is_dead:
		return

	var action := get_current_auto_attack()
	if action == null:
		print("ATTACK FAIL: no auto attack action for current style")
		return

	_advance_auto_attack_index()
	execute_combat_action(action)

func start_shield_attack() -> void:
	var action := get_ability_action(0)
	if action == null:
		print("SHIELD ATTACK FAIL: no ability action for current style")
		return

	execute_combat_action(action)

func get_ability_action(slot_index: int) -> CombatAction:
	var profile := get_current_combat_profile()
	if profile == null:
		return null

	if slot_index < 0 or slot_index >= profile.abilities.size():
		return null

	return profile.abilities[slot_index]

func execute_combat_action(action: CombatAction) -> void:
	if action == null:
		return
	if is_dead or is_attacking:
		return

	combat_action_token += 1
	var my_token := combat_action_token

	var style := get_combat_style()
	var atk_speed := get_attack_speed_multiplier()
	var active_hitbox := _get_hitbox_for_action(action)

	if active_hitbox == null:
		print("ATTACK FAIL: no hitbox for style:", style, " action:", action.action_id)
		return

	stop_block()

	is_attacking = true
	current_anim = ""

	attack_move_multiplier = action.move_multiplier
	attack_turn_multiplier = action.turn_multiplier

	play_animation(action.animation_name)

	print("PLAYER ACTION START:", action.animation_name, " style:", style, " action:", action.action_id)

	await get_tree().create_timer(action.hitbox_time / atk_speed).timeout
	if my_token != combat_action_token:
		return
	attack_hitbox_on_for_action(action)

	await get_tree().create_timer(action.hitbox_duration / atk_speed).timeout
	if my_token != combat_action_token:
		return
	attack_hitbox_off_for_action(action)

	var anim := animation_player.get_animation("Player_runtime/" + action.animation_name)

	if anim != null:
		await get_tree().create_timer(max((anim.length - 0.12) / atk_speed, 0.05)).timeout
	else:
		await get_tree().create_timer(max(action.recovery_time / atk_speed, 0.05)).timeout

	if my_token != combat_action_token:
		return

	attack_hitbox_off_for_action(action)
	is_attacking = false
	current_anim = ""

func attack_hitbox_on_for_action(action: CombatAction) -> void:
	var hitbox := _get_hitbox_for_action(action)
	if hitbox != null:
		hitbox.set_active(true)
		print("HITBOX ON:", action.action_id)

func attack_hitbox_off_for_action(action: CombatAction) -> void:
	var hitbox := _get_hitbox_for_action(action)
	if hitbox != null:
		hitbox.set_active(false)
		print("HITBOX OFF:", action.action_id)

# ==================================================
# BLOCK
# ==================================================
func start_block() -> void:
	if is_dead:
		return
	if shield_block_area == null:
		return
	if is_blocking:
		return

	is_blocking = true
	shield_block_area.set_blocking_enabled(true)
	current_anim = ""
	play_animation("Melee_Block")

	print("PLAYER BLOCK START")

func stop_block() -> void:
	if not is_blocking:
		return

	is_blocking = false

	if shield_block_area != null:
		shield_block_area.set_blocking_enabled(false)

	print("PLAYER BLOCK STOP")

func has_shield_equipped() -> bool:
	return shield_block_area != null

# ==================================================
# MOVEMENT / LOCOMOTION
# ==================================================
func set_locomotion_blend(target_blend_pos: Vector2) -> void:
	if animation_tree == null:
		return

	if not animation_tree.active:
		animation_tree.active = true

	if current_anim != "Locomotion":
		playback.travel("Locomotion")
		current_anim = "Locomotion"

	locomotion_blend_pos = locomotion_blend_pos.lerp(target_blend_pos, 0.18)
	animation_tree["parameters/Locomotion/blend_position"] = locomotion_blend_pos

func _play_idle_for_style() -> void:
	set_locomotion_blend(Vector2.ZERO)

func _play_movement_animation(input_vector: Vector2, _is_sprinting: bool) -> void:
	var blend := input_vector.normalized()
	set_locomotion_blend(blend)

func _play_block_movement_animation(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		play_animation("Melee_Blocking")
		return

	play_animation("Melee_Blocking")

# ==================================================
# ANIMATION
# ==================================================
func play_animation(anim_name: String) -> void:
	if current_anim == anim_name:
		return

	current_anim = anim_name

	if animation_tree != null:
		animation_tree.active = false

	animation_player.play("Player_runtime/" + anim_name, 0.08)

func play_locomotion_state(state_name: String) -> void:
	if animation_tree == null:
		return
	if playback == null:
		return
	if current_anim == state_name:
		return

	current_anim = state_name

	if animation_tree != null:
		animation_tree.active = true

	playback.travel(state_name)

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

	if is_blocking:
		current_anim = ""
		play_animation("Melee_Block_Hit")

func _on_died() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_blocking = false
	velocity = Vector3.ZERO

	if shield_block_area != null:
		shield_block_area.set_blocking_enabled(false)

	play_animation("Death_A")
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

	combat_action_token += 1
	is_attacking = false
	current_anim = ""
	stop_block()

	if animation_tree != null:
		animation_tree.active = true

	current_attack_index = 0

	_clear_equipped_main_hand_visual()
	_clear_equipped_off_hand_visual()

	if inventory.equipped_main_hand != null:
		if inventory.equipped_main_hand.equip_mesh_scene == null:
			print("Main hand item has no equip_mesh_scene:", inventory.equipped_main_hand.item_name)
		else:
			_equip_main_hand_scene(inventory.equipped_main_hand.equip_mesh_scene)

	if inventory.equipped_off_hand != null:
		if inventory.equipped_off_hand.equip_mesh_scene == null:
			print("Off hand item has no equip_mesh_scene:", inventory.equipped_off_hand.item_name)
		else:
			_equip_off_hand_scene(inventory.equipped_off_hand.equip_mesh_scene)

	locomotion_blend_pos = Vector2.ZERO

	_play_idle_for_style()

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
	main_hand_hitbox = weapon.find_child("AttackHitbox", true, false) as HitboxComponent

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
	off_hand_hitbox = weapon.find_child("AttackHitbox", true, false) as HitboxComponent
	shield_block_area = weapon.find_child("BlockArea", true, false) as ShieldBlock

	print("OFF HAND EQUIPPED:", weapon.name)
	print("OFF HAND HITBOX FOUND:", off_hand_hitbox)
	print("OFF HAND BLOCK AREA FOUND:", shield_block_area)

	if off_hand_hitbox != null:
		off_hand_hitbox.set_active(false)

	if shield_block_area != null:
		shield_block_area.set_blocking_enabled(false)

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
	shield_block_area = null
	is_blocking = false

# ==================================================
# HELPERS
# ==================================================
func _has_input_action(action_name: String) -> bool:
	return InputMap.has_action(action_name)

func _apply_character_class_data() -> void:
	if character_class == null:
		print("No character_class assigned on player")
		return

	if inventory == null:
		return

	inventory.character_class = character_class
	inventory.base_max_health = character_class.base_max_health
	inventory.base_damage = character_class.base_damage
	inventory.base_defense = character_class.base_defense
	inventory.base_crit_chance = int(character_class.base_crit_chance)
	inventory.base_attack_speed = character_class.base_attack_speed

	print("CHAR CLASS APPLIED:", character_class.display_name)

func get_attack_speed_multiplier() -> float:
	if inventory == null:
		return 1.0

	var total_stats := inventory.get_total_stats()
	return max(float(total_stats.get("attack_speed", 1.0)), 0.1)

func _setup_combat_profiles() -> void:
	unarmed_profile = CombatProfile.new()
	unarmed_profile.style_id = "unarmed"
	unarmed_profile.auto_attacks = [
		_make_action("unarmed_punch", "Punch", "Melee_Unarmed_Attack_Punch_A", true, false, 0.06, 0.10, 0.20, 1.0, 0.40, 0.55),
		_make_action("unarmed_kick", "Kick", "Melee_Unarmed_Attack_Kick", true, false, 0.08, 0.12, 0.24, 1.1, 0.40, 0.55)
	]

	one_handed_profile = CombatProfile.new()
	one_handed_profile.style_id = "one_handed"
	one_handed_profile.auto_attacks = [
		_make_action("1h_chop", "1H Chop", "Melee_1H_Attack_Chop", false, false, 0.06, 0.10, 0.20, 1.0, 0.35, 0.50),
		_make_action("1h_slice_diag", "1H Slice Diagonal", "Melee_1H_Attack_Slice_Diagonal", false, false, 0.06, 0.10, 0.20, 1.0, 0.35, 0.50),
		_make_action("1h_stab", "1H Stab", "Melee_1H_Attack_Stab", false, false, 0.06, 0.10, 0.20, 1.0, 0.35, 0.50)
	]

	two_handed_profile = CombatProfile.new()
	two_handed_profile.style_id = "two_handed"
	two_handed_profile.auto_attacks = [
		_make_action("2h_chop", "2H Chop", "Melee_2H_Attack_Chop", false, false, 0.07, 0.11, 0.24, 1.2, 0.20, 0.25),
		_make_action("2h_slice", "2H Slice", "Melee_2H_Attack_Slice", false, false, 0.07, 0.11, 0.24, 1.2, 0.20, 0.25),
		_make_action("2h_stab", "2H Stab", "Melee_2H_Attack_Stab", false, false, 0.07, 0.11, 0.24, 1.2, 0.20, 0.25)
	]

	dual_wield_profile = CombatProfile.new()
	dual_wield_profile.style_id = "dual_wield"
	dual_wield_profile.auto_attacks = [
		_make_action("dw_chop", "Dual Chop", "Melee_Dualwield_Attack_Chop", false, false, 0.05, 0.09, 0.18, 1.0, 0.45, 0.60),
		_make_action("dw_slice", "Dual Slice", "Melee_Dualwield_Attack_Slice", false, false, 0.05, 0.09, 0.18, 1.0, 0.45, 0.60),
		_make_action("dw_stab", "Dual Stab", "Melee_Dualwield_Attack_Stab", false, false, 0.05, 0.09, 0.18, 1.0, 0.45, 0.60)
	]

	one_handed_and_shield_profile = CombatProfile.new()
	one_handed_and_shield_profile.style_id = "one_handed_and_shield"
	one_handed_and_shield_profile.auto_attacks = [
		_make_action("ohs_chop", "Weapon Chop", "Melee_1H_Attack_Chop", false, false, 0.06, 0.10, 0.20, 1.0, 0.30, 0.40),
		_make_action("ohs_slice_diag", "Weapon Slice Diagonal", "Melee_1H_Attack_Slice_Diagonal", false, false, 0.06, 0.10, 0.20, 1.0, 0.30, 0.40),
		_make_action("ohs_stab", "Weapon Stab", "Melee_1H_Attack_Stab", false, false, 0.06, 0.10, 0.20, 1.0, 0.30, 0.40)
	]
	one_handed_and_shield_profile.abilities = [
		_make_action("shield_bash", "Shield Bash", "Melee_Block_Attack", false, true, 0.08, 0.12, 0.24, 1.0, 0.25, 0.35)
	]

func _make_action(
	action_id: String,
	display_name: String,
	animation_name: String,
	use_unarmed_hitbox: bool,
	use_offhand_hitbox: bool,
	hitbox_time: float,
	hitbox_duration: float,
	recovery_time: float,
	damage_multiplier: float,
	move_multiplier: float,
	turn_multiplier: float
) -> CombatAction:
	var action := CombatAction.new()
	action.action_id = action_id
	action.display_name = display_name
	action.animation_name = animation_name
	action.action_type = "auto"
	action.use_unarmed_hitbox = use_unarmed_hitbox
	action.use_offhand_hitbox = use_offhand_hitbox
	action.hitbox_time = hitbox_time
	action.hitbox_duration = hitbox_duration
	action.recovery_time = recovery_time
	action.damage_multiplier = damage_multiplier
	action.move_multiplier = move_multiplier
	action.turn_multiplier = turn_multiplier
	return action

func get_current_combat_profile() -> CombatProfile:
	match get_combat_style():
		"unarmed":
			return unarmed_profile
		"one_handed":
			return one_handed_profile
		"two_handed":
			return two_handed_profile
		"dual_wield":
			return dual_wield_profile
		"one_handed_and_shield":
			return one_handed_and_shield_profile
		_:
			return unarmed_profile

func get_current_auto_attack() -> CombatAction:
	var profile := get_current_combat_profile()
	if profile == null or profile.auto_attacks.is_empty():
		return null

	var index := current_attack_index % profile.auto_attacks.size()
	return profile.auto_attacks[index]

func _advance_auto_attack_index() -> void:
	var profile := get_current_combat_profile()
	if profile == null or profile.auto_attacks.is_empty():
		current_attack_index = 0
		return

	current_attack_index += 1
	if current_attack_index >= profile.auto_attacks.size():
		current_attack_index = 0

func _get_hitbox_for_action(action: CombatAction) -> HitboxComponent:
	if action == null:
		return null

	if action.use_unarmed_hitbox:
		return unarmed_hitbox

	if action.use_offhand_hitbox:
		return off_hand_hitbox

	return main_hand_hitbox

# ==================================================
# DEBUG EQUIP TESTS
# ==================================================
func _debug_handle_test_keys(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F1:
			print("DEBUG: Equip 1H axe")
			_debug_equip_loadout(DEBUG_ITEM_1H_AXE, "")
		KEY_F2:
			print("DEBUG: Equip 2H axe")
			_debug_equip_loadout(DEBUG_ITEM_2H_AXE, "")
		KEY_F3:
			print("DEBUG: Equip shield only")
			_debug_equip_loadout("", DEBUG_ITEM_SHIELD)
		KEY_F4:
			print("DEBUG: Equip 1H axe + shield")
			_debug_equip_loadout(DEBUG_ITEM_1H_AXE, DEBUG_ITEM_SHIELD)
		KEY_F5:
			print("DEBUG: Clear equipment")
			_debug_clear_equipment()

func _debug_equip_loadout(main_item_id: String, off_item_id: String) -> void:
	if inventory == null:
		print("DEBUG EQUIP FAIL: inventory missing")
		return

	_debug_clear_equipment()

	if main_item_id != "":
		var main_item := _debug_create_and_add_item(main_item_id)
		if main_item != null:
			inventory.equip_item(main_item)
		else:
			print("DEBUG EQUIP FAIL: could not create main item:", main_item_id)

	if off_item_id != "":
		var off_item := _debug_create_and_add_item(off_item_id)
		if off_item != null:
			inventory.equip_item(off_item)
		else:
			print("DEBUG EQUIP FAIL: could not create offhand item:", off_item_id)

	if inventory.has_method("debug_print_inventory"):
		inventory.debug_print_inventory()

func _debug_create_and_add_item(item_id: String) -> ItemData:
	var item := LootGenerator.generate_item(item_id)
	if item == null:
		print("DEBUG CREATE FAIL:", item_id)
		return null

	inventory.add_item(item)
	return item

func _debug_clear_equipment() -> void:
	if inventory == null:
		return

	inventory.unequip_off_hand()
	inventory.unequip_main_hand()

	if inventory.has_method("debug_print_inventory"):
		inventory.debug_print_inventory()
