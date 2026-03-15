extends Node3D

@onready var ranged_anim: AnimationPlayer = $Rig_Medium_CombatRanged/AnimationPlayer

func _ready() -> void:
	ranged_anim.play("Ranged_2H_Aiming")
