extends Control
class_name Piece

const Types = preload("res://scripts/game_types.gd")
const CANDY_ATLAS: Texture2D = preload("res://assets/sprites/candies/melle_candy_match3_assets_candy.png")

var color_id := 0
var special_type: int = Types.SpecialType.NONE
var grid_position: Vector2i = Types.INVALID_CELL

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5

func setup(new_color_id: int, new_special_type: int, new_grid_position: Vector2i) -> void:
	color_id = new_color_id
	special_type = new_special_type
	grid_position = new_grid_position
	queue_redraw()

func set_special(new_special_type: int) -> void:
	special_type = new_special_type
	queue_redraw()

func set_grid_position(new_grid_position: Vector2i) -> void:
	grid_position = new_grid_position

func animate_spawn() -> Signal:
	scale = Vector2.ONE * 0.25
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.14)
	return tween.finished

func animate_clear() -> Signal:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	return tween.finished

func animate_special_pulse() -> Signal:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.18, 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	return tween.finished

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.39
	var shadow_color := Color(0.05, 0.05, 0.08, 0.22)
	draw_circle(center + Vector2(0, size.y * 0.045), radius, shadow_color)

	if _draw_atlas_piece():
		return

	draw_circle(center, radius, Color("#5f6475"))
	draw_circle(center - Vector2(radius * 0.22, radius * 0.25), radius * 0.28, Color("#858b9d"))

func _draw_atlas_piece() -> bool:
	if CANDY_ATLAS == null:
		return false
	if not Types.has_atlas_region(color_id, special_type):
		return false
	var source_rect := Types.atlas_rect_for(color_id, special_type)
	var target_rect := Rect2(Vector2.ZERO, size).grow(-size.x * 0.04)
	draw_texture_rect_region(CANDY_ATLAS, target_rect, source_rect)
	return true
