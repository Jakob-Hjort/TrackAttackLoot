extends Resource
class_name CombatAction

@export var action_id: String = ""
@export var display_name: String = ""

@export var animation_name: String = ""
@export var action_type: String = "auto" # auto / ability / block / modified
@export var icon: Texture2D

@export var required_level: int = 1
@export var show_in_hud: bool = true

@export var stamina_cost: float = 0.0
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0

@export var hitbox_time: float = 0.06
@export var hitbox_duration: float = 0.10
@export var recovery_time: float = 0.20

@export var damage_multiplier: float = 1.0
@export var damage_type: String = "physical"
@export var stun_time: float = 0.0

@export var move_multiplier: float = 0.35
@export var turn_multiplier: float = 0.45

@export var use_unarmed_hitbox: bool = false
@export var use_offhand_hitbox: bool = false

@export var allowed_styles: Array[String] = []
@export var required_weapon_family: String = ""
