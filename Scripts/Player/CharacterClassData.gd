extends Resource
class_name CharacterClassData

@export var class_id: String = "barbarian"
@export var display_name: String = "Barbarian"

@export var base_max_health: int = 100
@export var base_damage: int = 5
@export var base_defense: int = 0
@export var base_crit_chance: float = 0.0
@export var base_attack_speed: float = 1.0
@export var base_move_speed_multiplier: float = 1.0
@export var base_block_multiplier: float = 1.0

@export var preferred_style: String = "two_handed"

@export var allow_one_handed: bool = true
@export var allow_two_handed: bool = true
@export var allow_shield: bool = true
@export var allow_dual_wield: bool = false
@export var allow_ranged: bool = false
@export var allow_magic: bool = false

@export var allowed_weapon_families: Array[String] = []
