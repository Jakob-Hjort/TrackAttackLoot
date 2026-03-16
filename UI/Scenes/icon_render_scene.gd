extends Node

@onready var icon_viewport: SubViewport = $IconViewport
@onready var weapon_anchor: Node3D = $IconViewport/IconRoot/WeaponAnchor

func _ready() -> void:
	call_deferred("_save_icon")

func _save_icon() -> void:
	if weapon_anchor.get_child_count() == 0:
		print("No weapon found under WeaponAnchor")
		return

	var weapon := weapon_anchor.get_child(0) as Node3D
	if weapon == null:
		print("Weapon is not a Node3D")
		return

	var weapon_name := weapon.name.to_lower()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var image: Image = icon_viewport.get_texture().get_image()
	var path := "res://UI/ICONS/generated/%s.png" % weapon_name

	var err := image.save_png(path)
	if err == OK:
		print("PNG saved: ", path)
	else:
		print("Save failed: ", err)
