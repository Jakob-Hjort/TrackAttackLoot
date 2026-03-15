extends Node
class_name HealthComponent

signal health_changed(current_health, max_health)
signal damaged(damage_data)
signal died

@export var max_health: int = 150
var current_health: int

func _ready():
	current_health = max_health
	health_changed.emit(current_health, max_health)

func apply_damage(damage_data: DamageData):
	current_health -= damage_data.amount
	current_health = max(current_health, 0)

	damaged.emit(damage_data)
	health_changed.emit(current_health, max_health)

	if current_health <= 0:
		died.emit()

func heal(amount: int):
	current_health += amount
	current_health = min(current_health, max_health)
	health_changed.emit(current_health, max_health)
