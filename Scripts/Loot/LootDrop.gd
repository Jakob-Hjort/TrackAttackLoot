extends Area3D
class_name LootDrop

var item_data: ItemData
@export var pickup_radius: float = 3.0
@export var spin_speed: float = 1.5
@export var bob_height: float = 0.15
@export var bob_speed: float = 2.0

var _base_y: float = 0.0
var _player_in_range: bool = false
var _picked_up: bool = false

@onready var mesh_root: Node3D = $MeshRoot
@onready var label_3d: Label3D = $Label3D
@onready var glow_light: OmniLight3D = $GlowLight
@onready var interact_label: Label3D = $InteractLabel
@onready var rarity_beam: MeshInstance3D = $RarityBeam

func _ready() -> void:
	_base_y = global_position.y
	update_visuals()
	update_interaction_label()

func set_item(data: ItemData) -> void:
	item_data = data
	update_visuals()
	update_interaction_label()

func _process(delta: float) -> void:
	if _picked_up:
		return

	# Spin
	rotate_y(delta * spin_speed)

	# Bob up/down
	var pos := global_position
	pos.y = _base_y + sin(Time.get_ticks_msec() / 1000.0 * bob_speed) * bob_height
	global_position = pos

	check_player_in_range()
	update_interaction_label()

	if _player_in_range and Input.is_action_just_pressed("pickup_loot"):
		try_pickup()

func check_player_in_range() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		_player_in_range = false
		return

	var distance := global_position.distance_to(player.global_position)
	_player_in_range = distance <= pickup_radius

func try_pickup() -> void:
	if item_data == null:
		print("Loot has no item_data")
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	var inventory := player.get_node_or_null("PlayerInventory") as PlayerInventory
	if inventory == null:
		print("No PlayerInventory found on player")
		return

	_picked_up = true
	inventory.add_item(item_data)
	print("LOOT PICKED:", item_data.get_display_text())
	queue_free()
	
func _apply_rarity_to_beam(color: Color) -> void:
	if rarity_beam == null:
		return

	var mat := rarity_beam.get_active_material(0)

	if mat == null:
		return

	if mat is StandardMaterial3D:
		var beam_mat := mat.duplicate() as StandardMaterial3D
		beam_mat.albedo_color = color
		rarity_beam.set_surface_override_material(0, beam_mat)

func update_visuals() -> void:
	if item_data == null:
		return

	var rarity_color := LootGenerator.get_rarity_color(item_data.rarity)

	# Item navn
	if label_3d:
		label_3d.text = item_data.item_name
		label_3d.modulate = rarity_color

	# Interact text
	if interact_label:
		interact_label.modulate = Color.WHITE

	# Glow
	if glow_light:
		glow_light.light_color = rarity_color
		glow_light.light_energy = 0.8

	# Beam
	_apply_rarity_to_beam(rarity_color)


	# Fjern gammelt mesh
	if mesh_root:
		for child in mesh_root.get_children():
			child.queue_free()

		# Spawn item mesh
		if item_data.drop_mesh_scene != null:
			var mesh_instance = item_data.drop_mesh_scene.instantiate()
			mesh_root.add_child(mesh_instance)

			# Nulstil så mesh starter pænt
			if mesh_instance is Node3D:
				mesh_instance.position = Vector3.ZERO
				mesh_instance.rotation_degrees = Vector3.ZERO
				mesh_instance.scale = Vector3.ONE

func update_interaction_label() -> void:
	if interact_label == null:
		return

	if item_data == null:
		interact_label.visible = false
		return

	interact_label.visible = _player_in_range
	if _player_in_range:
		interact_label.text = "[E] Pick up"
