extends Node3D

@export var run_content_scene: PackedScene

@onready var player: Node3D = $Player

func reset_run() -> void:
	print("RESET RUN CALLED")

	if player != null:
		GameState.save_player_state(player)

	var old_run := get_node_or_null("RunContentHolder")
	if old_run == null:
		push_warning("RunContentHolder not found")
		return

	var parent := old_run.get_parent()
	if parent == null:
		push_warning("RunContentHolder has no parent")
		return

	parent.remove_child(old_run)
	old_run.queue_free()

	await get_tree().process_frame

	if run_content_scene != null:
		var new_run = run_content_scene.instantiate()
		new_run.name = "RunContentHolder"
		parent.add_child(new_run)

	if player != null and GameState.pending_restore:
		GameState.restore_player_state(player)
