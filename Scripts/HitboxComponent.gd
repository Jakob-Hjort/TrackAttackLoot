extends Area3D
class_name HitboxComponent

signal hit_landed(target, damage_data)
signal hit_blocked(target, damage_data)

@export var damage_amount: int = 10
@export var damage_type: String = "physical"

var is_active: bool = false
var already_hit: Array[Node] = []

func _ready() -> void:
	monitoring = false
	monitorable = false
	set_physics_process(false)

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func set_active(value: bool) -> void:
	is_active = value
	monitoring = value
	monitorable = false
	already_hit.clear()
	set_physics_process(value)

func force_hit_check() -> void:
	if not is_active:
		return

	var areas = get_overlapping_areas()
	var bodies = get_overlapping_bodies()

	print("HITBOX CHECK -> areas:", areas.size(), " bodies:", bodies.size())

	for area in areas:
		print("  overlap area:", area.name, " type:", area.get_class())
		_try_hit(area)

	for body in bodies:
		print("  overlap body:", body.name, " type:", body.get_class())
		_try_hit(body)

func _physics_process(_delta: float) -> void:
	if not is_active:
		return

	force_hit_check()

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	_try_hit(area)

func _on_body_entered(body: Node) -> void:
	if not is_active:
		return

	_try_hit(body)

func _try_hit(target: Node) -> void:
	if target == null:
		print("TRY_HIT: target null")
		return

	if target in already_hit:
		print("TRY_HIT: already hit ->", target.name)
		return

	if owner != null and (target == owner or owner.is_ancestor_of(target) or target.is_ancestor_of(owner)):
		print("TRY_HIT: ignored own hierarchy ->", target.name)
		return

	print("TRY_HIT target:", target.name, " class:", target.get_class())

	var dmg := DamageData.new()
	dmg.amount = damage_amount
	dmg.damage_type = damage_type
	dmg.source = owner

	# --------------------------------------------------
	# 1) Shield block check
	# --------------------------------------------------
	if target is ShieldBlock:
		var shield := target as ShieldBlock

		if shield.can_block():
			print("TRY_HIT: BLOCKED BY SHIELD ->", target.name)
			shield.on_blocked_hit(owner, dmg)
			already_hit.append(target)
			hit_blocked.emit(target, dmg)
			return
		else:
			print("TRY_HIT: shield found but not actively blocking ->", target.name)
			return

	# --------------------------------------------------
	# 2) Normal hurtbox damage
	# --------------------------------------------------
	if not (target is HurtboxComponent):
		print("TRY_HIT: not a HurtboxComponent or ShieldBlock")
		return

	print("TRY_HIT: DAMAGE SENT TO", target.name, " amount:", dmg.amount)

	var hurtbox := target as HurtboxComponent
	hurtbox.receive_hit(dmg)

	already_hit.append(target)
	hit_landed.emit(target, dmg)
