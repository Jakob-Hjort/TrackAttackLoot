extends Area3D
class_name ShieldBlock

signal blocked_hit(attacker, damage_data)

@export var block_damage_multiplier: float = 0.0
@export var stamina_cost: float = 10.0

var blocking_enabled: bool = false

func _ready() -> void:
	monitoring = false
	monitorable = true

func can_block() -> bool:
	return blocking_enabled

func set_blocking_enabled(value: bool) -> void:
	blocking_enabled = value
	monitoring = value

func on_blocked_hit(attacker: Node, damage_data: DamageData) -> void:
	print("SHIELD BLOCKED HIT from:", attacker, " damage:", damage_data.amount)
	blocked_hit.emit(attacker, damage_data)
