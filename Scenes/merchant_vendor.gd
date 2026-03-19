extends Node3D
class_name MerchantVendor

@export var interaction_text: String = "[E] Shop"
@export var interact_distance: float = 3.0

var player_in_range := false
var shop_open := false

@onready var interact_label: Label3D = $InteractLabel
@onready var animation_player: AnimationPlayer = $VisualRoot/Engineer/AnimationPlayer

var player: Node3D = null
var shop_ui: ShopUI = null

func _ready() -> void:
	add_to_group("merchant_vendor")

	if interact_label != null:
		interact_label.text = interaction_text
		interact_label.visible = false

	if animation_player != null:
		if animation_player.has_animation("merchant/fake_wave"):
			animation_player.play("merchant/fake_wave")
		elif animation_player.has_animation("merchant/fake_idle"):
			animation_player.play("merchant/fake_idle")
		elif animation_player.has_animation("fake_wave"):
			animation_player.play("fake_wave")
		elif animation_player.has_animation("fake_idle"):
			animation_player.play("fake_idle")


func _physics_process(_delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			return

	if shop_ui == null:
		shop_ui = get_tree().get_first_node_in_group("shop_ui") as ShopUI

	player_in_range = global_position.distance_to(player.global_position) <= interact_distance

	if interact_label != null:
		interact_label.visible = player_in_range and not shop_open

	if player_in_range and Input.is_action_just_pressed("pickup_loot"):
		_toggle_shop()


func _toggle_shop() -> void:
	if shop_ui == null:
		print("MERCHANT: shop_ui not found")
		return

	shop_open = not shop_open

	if shop_open:
		shop_ui.open_shop()
	else:
		shop_ui.close_shop()

	if interact_label != null:
		interact_label.visible = player_in_range and not shop_open


func notify_shop_closed() -> void:
	shop_open = false

	if interact_label != null:
		interact_label.visible = player_in_range and not shop_open
