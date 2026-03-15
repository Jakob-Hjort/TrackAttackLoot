extends Control

@export var bar_width: int = 64
@export var bar_height: int = 8

@export var hide_delay: float = 2.0
@export var damage_lerp_speed: float = 2.5

@export var green_left: Texture2D
@export var green_mid: Texture2D
@export var green_right: Texture2D

@export var yellow_left: Texture2D
@export var yellow_mid: Texture2D
@export var yellow_right: Texture2D

@export var red_left: Texture2D
@export var red_mid: Texture2D
@export var red_right: Texture2D

@export var back_left: Texture2D
@export var back_mid: Texture2D
@export var back_right: Texture2D

var max_health: float = 100.0
var current_health: float = 100.0

var target_ratio: float = 1.0
var display_ratio: float = 1.0

var visible_timer: float = 0.0
var bar_visible: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(bar_width, bar_height)
	visible = false
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if display_ratio > target_ratio:
		display_ratio = move_toward(display_ratio, target_ratio, damage_lerp_speed * delta)
		queue_redraw()
	elif display_ratio < target_ratio:
		display_ratio = target_ratio
		queue_redraw()

	if bar_visible:
		visible_timer -= delta
		if visible_timer <= 0.0:
			bar_visible = false
			visible = false

func set_health(current: float, maximum: float) -> void:
	print("SET HEALTH CALLED:", current, "/", maximum)
	max_health = max(maximum, 1.0)
	current_health = clamp(current, 0.0, max_health)

	var new_ratio: float = current_health / max_health

	if new_ratio > target_ratio:
		target_ratio = new_ratio
		display_ratio = new_ratio
	else:
		target_ratio = new_ratio

	# Vis altid når der sker en opdatering
	bar_visible = true
	visible = true
	visible_timer = hide_delay

	queue_redraw()

func force_show() -> void:
	bar_visible = true
	visible = true
	visible_timer = hide_delay
	queue_redraw()

func _draw() -> void:
	if back_left == null or back_mid == null or back_right == null:
		return

	# Baggrund
	_draw_bar(back_left, back_mid, back_right, 1.0, Color(1, 1, 1, 1))

	# Delayed damage bar
	if display_ratio > target_ratio:
		_draw_bar(yellow_left, yellow_mid, yellow_right, display_ratio, Color(1, 1, 1, 0.75))

	# Current bar
	var fill_left: Texture2D
	var fill_mid: Texture2D
	var fill_right: Texture2D

	if target_ratio > 0.6:
		fill_left = green_left
		fill_mid = green_mid
		fill_right = green_right
	elif target_ratio > 0.3:
		fill_left = yellow_left
		fill_mid = yellow_mid
		fill_right = yellow_right
	else:
		fill_left = red_left
		fill_mid = red_mid
		fill_right = red_right

	_draw_bar(fill_left, fill_mid, fill_right, target_ratio, Color(1, 1, 1, 1))

func _draw_bar(left_tex: Texture2D, mid_tex: Texture2D, right_tex: Texture2D, fill_ratio: float, tint: Color) -> void:
	if left_tex == null or mid_tex == null or right_tex == null:
		return

	if fill_ratio <= 0.0:
		return

	var left_w: int = left_tex.get_width()
	var right_w: int = right_tex.get_width()
	var total_w: int = bar_width
	var middle_w: int = total_w - left_w - right_w

	if middle_w < 1:
		return

	var fill_total_w: int = int(round(total_w * fill_ratio))
	fill_total_w = clamp(fill_total_w, 1, total_w)

	if fill_total_w <= left_w:
		var src_rect := Rect2(0, 0, fill_total_w, left_tex.get_height())
		var dst_rect := Rect2(0, 0, fill_total_w, bar_height)
		draw_texture_rect_region(left_tex, dst_rect, src_rect, tint)
		return

	draw_texture_rect(left_tex, Rect2(0, 0, left_w, bar_height), false, tint)

	var remaining: int = fill_total_w - left_w

	if remaining > 0:
		var mid_draw_w: int = remaining
		if mid_draw_w > middle_w:
			mid_draw_w = middle_w

		if mid_draw_w > 0:
			var dst_rect_mid := Rect2(left_w, 0, mid_draw_w, bar_height)
			draw_texture_rect(mid_tex, dst_rect_mid, true, tint)

		remaining -= mid_draw_w

	if remaining > 0:
		var right_draw_w: int = remaining
		if right_draw_w > right_w:
			right_draw_w = right_w

		var src_rect_right := Rect2(0, 0, right_draw_w, right_tex.get_height())
		var dst_rect_right := Rect2(left_w + middle_w, 0, right_draw_w, bar_height)
		draw_texture_rect_region(right_tex, dst_rect_right, src_rect_right, tint)
