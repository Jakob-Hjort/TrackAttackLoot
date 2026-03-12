extends Area3D
class_name HurtboxComponent

signal hit_received(damage_data)

@export var health_component_path: NodePath
@onready var health_component: HealthComponent = get_node_or_null(health_component_path)

func receive_hit(damage_data: DamageData):
	hit_received.emit(damage_data)

	if health_component:
		health_component.apply_damage(damage_data)
