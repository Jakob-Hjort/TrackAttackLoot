extends Node3D

@export_group("Theme Colors")
@export var center_color: Color = Color("2B332B")
@export var trim_color: Color = Color("23262D")
@export var stone_color: Color = Color("4C5058")

@export_group("Emission")
@export var emission_enabled: bool = true
@export var emission_color: Color = Color("5E7A52")
@export_range(0.0, 5.0, 0.01) var emission_energy: float = 0.22

@export_group("Pulse")
@export var pulse_enabled: bool = false
@export_range(0.0, 10.0, 0.01) var pulse_speed: float = 1.0
@export_range(0.0, 5.0, 0.01) var pulse_min: float = 0.12
@export_range(0.0, 5.0, 0.01) var pulse_max: float = 0.35

func _ready() -> void:
	_apply_theme_recursive(self)

func _apply_theme_recursive(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("apply_theme"):
			child.apply_theme(
				center_color,
				trim_color,
				stone_color,
				emission_enabled,
				emission_color,
				emission_energy,
				pulse_enabled,
				pulse_speed,
				pulse_min,
				pulse_max
			)

		_apply_theme_recursive(child)
