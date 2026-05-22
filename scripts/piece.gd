extends Control
class_name Piece

const Types = preload("res://scripts/game_types.gd")
const CANDY_ATLAS: Texture2D = preload("res://assets/sprites/candies/melle_candy_match3_assets_candy.png")

var color_id := 0
var special_type: int = Types.SpecialType.NONE
var grid_position: Vector2i = Types.INVALID_CELL

var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_font_size_override("font_size", 22)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update_label()

func setup(new_color_id: int, new_special_type: int, new_grid_position: Vector2i) -> void:
	color_id = new_color_id
	special_type = new_special_type
	grid_position = new_grid_position
	_update_label()
	queue_redraw()

func set_special(new_special_type: int) -> void:
	special_type = new_special_type
	_update_label()
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
		if _label:
			_label.add_theme_font_size_override("font_size", max(16, int(size.x * 0.34)))
		queue_redraw()

func _update_label() -> void:
	if not _label:
		return
	var text := Types.label_for(color_id)
	var special_text := Types.special_label(special_type)
	if special_text != "":
		text = special_text
	_label.text = text

func _draw() -> void:
	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.39
	var base_color: Color = Types.color_for(color_id)
	var shadow_color := Color(0.05, 0.05, 0.08, 0.22)
	draw_circle(center + Vector2(0, size.y * 0.045), radius, shadow_color)

	if _draw_atlas_piece():
		return

	if special_type == Types.SpecialType.COLOR_BOMB:
		_draw_color_bomb(center, radius)
	else:
		_draw_normal_piece(center, radius, base_color)

	match special_type:
		Types.SpecialType.STRIPED_ROW:
			for offset in [-0.18, 0.0, 0.18]:
				var y: float = center.y + size.y * offset
				draw_line(Vector2(center.x - radius * 0.7, y), Vector2(center.x + radius * 0.7, y), Color.WHITE, max(2.0, size.x * 0.045), true)
		Types.SpecialType.STRIPED_COLUMN:
			for offset in [-0.18, 0.0, 0.18]:
				var x: float = center.x + size.x * offset
				draw_line(Vector2(x, center.y - radius * 0.7), Vector2(x, center.y + radius * 0.7), Color.WHITE, max(2.0, size.x * 0.045), true)
		Types.SpecialType.WRAPPED:
			var rect := Rect2(center - Vector2.ONE * radius * 0.92, Vector2.ONE * radius * 1.84)
			draw_rect(rect, Color.WHITE, false, max(3.0, size.x * 0.055))
		_:
			pass

func _draw_normal_piece(center: Vector2, radius: float, base_color: Color) -> void:
	match color_id % 6:
		0:
			draw_circle(center, radius, base_color)
			draw_circle(center - Vector2(radius * 0.22, radius * 0.25), radius * 0.3, base_color.lightened(0.28))
		1:
			var rect := Rect2(center - Vector2.ONE * radius * 0.86, Vector2.ONE * radius * 1.72)
			draw_rect(rect, base_color)
			draw_rect(rect.grow(-radius * 0.18), base_color.lightened(0.18))
		2:
			var points := PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, 0),
				center + Vector2(0, radius),
				center + Vector2(-radius, 0),
			])
			draw_polygon(points, PackedColorArray([base_color]))
			draw_polygon(PackedVector2Array([
				center + Vector2(0, -radius * 0.62),
				center + Vector2(radius * 0.62, 0),
				center + Vector2(0, radius * 0.62),
				center + Vector2(-radius * 0.62, 0),
			]), PackedColorArray([base_color.lightened(0.2)]))
		3:
			for i in 6:
				var angle := TAU * float(i) / 6.0
				draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.38, radius * 0.36, base_color)
			draw_circle(center, radius * 0.48, base_color.lightened(0.18))
		4:
			var points := PackedVector2Array()
			for i in 5:
				var angle := -PI * 0.5 + TAU * float(i) / 5.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_polygon(points, PackedColorArray([base_color]))
			draw_circle(center, radius * 0.45, base_color.lightened(0.2))
		_:
			var points := PackedVector2Array()
			for i in 3:
				var angle := -PI * 0.5 + TAU * float(i) / 3.0
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			draw_polygon(points, PackedColorArray([base_color]))
			draw_circle(center, radius * 0.38, base_color.lightened(0.2))

func _draw_color_bomb(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color("#20202a"))
	for i in Types.PIECE_COLORS.size():
		var angle := TAU * float(i) / float(Types.PIECE_COLORS.size())
		draw_circle(center + Vector2(cos(angle), sin(angle)) * radius * 0.48, radius * 0.18, Types.PIECE_COLORS[i])
	draw_circle(center, radius * 0.2, Color.WHITE)

func _draw_atlas_piece() -> bool:
	if CANDY_ATLAS == null:
		return false
	if color_id >= 5 and special_type != Types.SpecialType.COLOR_BOMB:
		return false
	var source_rect := _atlas_rect_for_piece()
	var target_rect := Rect2(Vector2.ZERO, size).grow(-size.x * 0.04)
	draw_texture_rect_region(CANDY_ATLAS, target_rect, source_rect)
	return true

func _atlas_rect_for_piece() -> Rect2:
	var normal_columns := [2, 1, 0, 3, 4]
	var column: int = normal_columns[color_id % normal_columns.size()]
	var row := 0
	match special_type:
		Types.SpecialType.STRIPED_ROW:
			row = 1
			column = clampi(column, 0, 4)
		Types.SpecialType.STRIPED_COLUMN:
			row = 2
			column = clampi(column, 0, 4)
		Types.SpecialType.WRAPPED:
			row = 4
			column = 2
		Types.SpecialType.COLOR_BOMB:
			row = 0
			column = 5
		_:
			pass
	return Rect2(column * 100, row * 100, 100, 100)
