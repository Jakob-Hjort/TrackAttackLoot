extends MeshInstance3D

@export_group("Surface Indices")
@export var center_surface: int = 1
@export var trim_surface: int = 2
@export var stone_surface: int = 3

@export_group("Base Colors")
@export var center_color: Color = Color("2B332B")
@export var trim_color: Color = Color("23262D")
@export var stone_color: Color = Color("4C5058")

@export_group("Emission")
@export var emission_enabled: bool = true
@export var emission_color: Color = Color("5E7A52")
@export_range(0.0, 5.0, 0.01) var emission_energy: float = 0.22

@export_group("Surface Properties")
@export_range(0.0, 1.0, 0.01) var roughness_value: float = 1.0
@export_range(0.0, 1.0, 0.01) var metallic_value: float = 0.0

@export_group("Pulse")
@export var pulse_enabled: bool = false
@export_range(0.0, 10.0, 0.01) var pulse_speed: float = 1.0
@export_range(0.0, 5.0, 0.01) var pulse_min: float = 0.12
@export_range(0.0, 5.0, 0.01) var pulse_max: float = 0.35

var _center_material: StandardMaterial3D
var _time: float = 0.0
var _pulse_offset: float = 0.0

func _ready() -> void:
	_pulse_offset = randf() * TAU
	_setup_materials()

func _process(delta: float) -> void:
	if not pulse_enabled:
		return
	if _center_material == null:
		return
	if not emission_enabled:
		return

	_time += delta * pulse_speed
	var t := (sin(_time + _pulse_offset) + 1.0) * 0.5
	_center_material.emission_energy_multiplier = lerp(pulse_min, pulse_max, t)

func _setup_materials() -> void:
	_center_material = _make_unique_material(center_surface)
	var trim_material := _make_unique_material(trim_surface)
	var stone_material := _make_unique_material(stone_surface)

	if _center_material != null:
		_center_material.albedo_color = center_color
		_center_material.roughness = roughness_value
		_center_material.metallic = metallic_value
		_center_material.emission_enabled = emission_enabled
		_center_material.emission = emission_color
		_center_material.emission_energy_multiplier = emission_energy

	if trim_material != null:
		trim_material.albedo_color = trim_color
		trim_material.roughness = roughness_value
		trim_material.metallic = metallic_value
		trim_material.emission_enabled = false

	if stone_material != null:
		stone_material.albedo_color = stone_color
		stone_material.roughness = roughness_value
		stone_material.metallic = metallic_value
		stone_material.emission_enabled = false

func _make_unique_material(surface_index: int) -> StandardMaterial3D:
	var mat := get_active_material(surface_index) as StandardMaterial3D
	if mat == null:
		return null

	var unique_mat := mat.duplicate() as StandardMaterial3D
	set_surface_override_material(surface_index, unique_mat)
	return unique_mat

func apply_theme(
	new_center_color: Color,
	new_trim_color: Color,
	new_stone_color: Color,
	new_emission_enabled: bool,
	new_emission_color: Color,
	new_emission_energy: float,
	new_pulse_enabled: bool,
	new_pulse_speed: float,
	new_pulse_min: float,
	new_pulse_max: float
) -> void:
	center_color = new_center_color
	trim_color = new_trim_color
	stone_color = new_stone_color
	emission_enabled = new_emission_enabled
	emission_color = new_emission_color
	emission_energy = new_emission_energy
	pulse_enabled = new_pulse_enabled
	pulse_speed = new_pulse_speed
	pulse_min = new_pulse_min
	pulse_max = new_pulse_max

	_setup_materials()
