extends Resource
class_name CombatProfile

@export var style_id: String = ""
@export var auto_attack: CombatAction
@export var abilities: Array[CombatAction] = []
@export var block_action: CombatAction
@export var modified_attack_action: CombatAction
