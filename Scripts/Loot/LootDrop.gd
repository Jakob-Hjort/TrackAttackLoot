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
@onready var glow_plane: MeshInstance3D = $GlowPlane

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

	rotate_y(delta * spin_speed)

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

func _update_glow_plane(color: Color) -> void:
	if glow_plane == null:
		return

	var mat := glow_plane.get_active_material(0)
	if mat == null:
		return

	if mat is StandardMaterial3D:
		var glow_mat := mat.duplicate() as StandardMaterial3D
		glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
		glow_plane.set_surface_override_material(0, glow_mat)

	glow_plane.visible = true

func update_visuals() -> void:
	if item_data == null:
		if glow_plane:
			glow_plane.visible = false
		return

	var rarity_color := LootGenerator.get_rarity_color(item_data.rarity)
	_update_glow_plane(rarity_color)

	if label_3d:
		label_3d.text = item_data.item_name
		label_3d.modulate = rarity_color

	if interact_label:
		interact_label.modulate = Color.WHITE

	if glow_light:
		glow_light.light_color = rarity_color
		glow_light.light_energy = 1.0
		glow_light.omni_range = 1.4

	if mesh_root:
		for child in mesh_root.get_children():
			child.queue_free()

		if item_data.drop_mesh_scene != null:
			var mesh_instance = item_data.drop_mesh_scene.instantiate()
			mesh_root.add_child(mesh_instance)

			if mesh_instance is Node3D:
				mesh_instance.position = Vector3(0, 0.12, 0)
				mesh_instance.rotation_degrees = Vector3.ZERO
				mesh_instance.scale = Vector3(1, 1, 1)

func update_interaction_label() -> void:
	if interact_label == null:
		return

	if item_data == null:
		interact_label.visible = false
		return

	interact_label.visible = _player_in_range
	if _player_in_range:
		interact_label.text = "[E] Pick up"
