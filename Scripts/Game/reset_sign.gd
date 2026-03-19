extends Area3D

@export var interact_distance: float = 3.0
@onready var label_3d: Label3D = $ResetLabel

func _ready() -> void:
	print("RESET SIGN READY")
	if label_3d != null:
		label_3d.visible = false

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		if label_3d != null:
			label_3d.visible = false
		return

	var sign_pos := global_position
	var player_pos := player.global_position
	sign_pos.y = 0.0
	player_pos.y = 0.0

	var distance := sign_pos.distance_to(player_pos)
	var player_in_range := distance <= interact_distance

	if label_3d != null:
		label_3d.visible = player_in_range

	if player_in_range and Input.is_key_pressed(KEY_E):
		print("RESET KEY PRESSED")
		var world = get_tree().current_scene
		if world != null and world.has_method("reset_run"):
			world.reset_run()
