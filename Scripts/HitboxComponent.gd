extends Area3D
class_name HitboxComponent

signal hit_landed(target, damage_data)

@export var damage_amount: int = 10
@export var damage_type: String = "physical"

var already_hit: Array = []

func _ready():
	monitoring = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func set_active(value: bool):
	monitoring = value
	if not value:
		already_hit.clear()

func _on_area_entered(area: Area3D):
	if not monitoring:
		return

	if area in already_hit:
		return

	# Ram ikke dig selv eller egne children
	if owner != null and (area == owner or owner.is_ancestor_of(area)):
		return

	if area.has_method("receive_hit"):
		var dmg := DamageData.new()
		dmg.amount = damage_amount
		dmg.damage_type = damage_type
		dmg.source = owner

		area.receive_hit(dmg)
		already_hit.append(area)
		hit_landed.emit(area, dmg)

func _on_body_entered(_body: Node):
	pass
