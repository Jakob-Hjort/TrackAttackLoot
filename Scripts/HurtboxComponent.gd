extends Area3D
class_name HurtboxComponent

signal hit_received(damage_data)

@export var health_component_path: NodePath
@onready var health_component: HealthComponent = _resolve_health_component()

func receive_hit(damage_data: DamageData) -> void:
	print(name, " received hit: ", damage_data.amount)

	hit_received.emit(damage_data)

	if health_component:
		health_component.apply_damage(damage_data)

func _resolve_health_component() -> HealthComponent:
	if health_component_path != NodePath():
		return get_node_or_null(health_component_path) as HealthComponent

	var parent := get_parent()
	if parent == null:
		return null

	for child in parent.get_children():
		if child is HealthComponent:
			return child

	return null
