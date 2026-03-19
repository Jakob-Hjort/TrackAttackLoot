extends Area3D

@export var speed: float = 20.0
@export var damage: int = 10
@export var lifetime: float = 4.0

var direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	await get_tree().create_timer(lifetime).timeout
	if is_inside_tree():
		queue_free()

func _physics_process(delta: float) -> void:
	if direction == Vector3.ZERO:
		return

	global_position += direction * speed * delta

func setup(dir: Vector3) -> void:
	direction = dir.normalized()
	look_at(global_position + direction, Vector3.UP)

func set_damage(value: int) -> void:
	damage = value

func _on_body_entered(body: Node) -> void:
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area is HurtboxComponent:
		var dmg := DamageData.new()
		dmg.amount = damage
		dmg.damage_type = "physical"
		dmg.source = self
		area.receive_hit(dmg)

	queue_free()
