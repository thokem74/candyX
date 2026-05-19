extends Control
class_name MatchBoard

signal score_changed(score: int)
signal moves_changed(moves_remaining: int)
signal goal_changed(text: String)
signal level_finished(success: bool)

const GameTypes = preload("res://scripts/game_types.gd")
const PIECE_SCENE := preload("res://scenes/Piece.tscn")
const BOARD_SIZE := 8

var grid: Array = []
var score := 0
var moves_remaining := 0
var level_data: Dictionary = {}

var input_locked := true
var game_over := false

var _available_colors: Array = []
var _goal_type := GameTypes.GoalType.SCORE
var _goal_count := 0
var _goal_color := -1
var _cleared_goal_color := 0
var _specials_triggered := 0

var _cell_size := 1.0
var _board_origin := Vector2.ZERO
var _selected_cell := GameTypes.INVALID_CELL
var _press_cell := GameTypes.INVALID_CELL
var _press_position := Vector2.ZERO

func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(false)

func start_level(new_level_data: Dictionary) -> void:
	level_data = new_level_data
	score = 0
	moves_remaining = int(level_data.get("moves", 20))
	_available_colors = level_data.get("colors", [0, 1, 2, 3])
	_goal_type = int(level_data.get("goal_type", GameTypes.GoalType.SCORE))
	_goal_count = int(level_data.get("goal_count", level_data.get("target_score", 1000)))
	_goal_color = int(level_data.get("goal_color", -1))
	_cleared_goal_color = 0
	_specials_triggered = 0
	game_over = false
	input_locked = true
	_selected_cell = GameTypes.INVALID_CELL
	_clear_board()
	_create_initial_board()
	_layout_pieces(false)
	input_locked = false
	_emit_state()

func restart_level() -> void:
	start_level(level_data)

func _gui_input(event: InputEvent) -> void:
	if input_locked or game_over:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_position = event.position
			_press_cell = _cell_from_local(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.position
			_press_cell = _cell_from_local(event.position)
		else:
			_handle_release(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_pieces(false)
		queue_redraw()

func _draw() -> void:
	var board_rect := Rect2(_board_origin, Vector2.ONE * _cell_size * BOARD_SIZE)
	draw_rect(board_rect.grow(_cell_size * 0.06), Color(0.08, 0.09, 0.14, 0.92))
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell_rect := Rect2(_board_origin + Vector2(x, y) * _cell_size, Vector2.ONE * _cell_size).grow(-_cell_size * 0.045)
			var shade := Color(1, 1, 1, 0.08 if (x + y) % 2 == 0 else 0.13)
			draw_rect(cell_rect, shade)
	if _is_valid_cell(_selected_cell):
		var selected_rect := Rect2(_cell_top_left(_selected_cell), Vector2.ONE * _cell_size).grow(-_cell_size * 0.08)
		draw_rect(selected_rect, Color.WHITE, false, max(3.0, _cell_size * 0.055))

func _handle_release(release_position: Vector2) -> void:
	if not _is_valid_cell(_press_cell):
		return
	var release_cell := _cell_from_local(release_position)
	var delta := release_position - _press_position
	var drag_threshold := _cell_size * 0.34
	if delta.length() >= drag_threshold:
		var direction := Vector2i.ZERO
		if abs(delta.x) > abs(delta.y):
			direction.x = 1 if delta.x > 0.0 else -1
		else:
			direction.y = 1 if delta.y > 0.0 else -1
		var target := _press_cell + direction
		if _is_valid_cell(target):
			_try_player_swap(_press_cell, target)
	else:
		if _is_valid_cell(release_cell):
			_handle_tap(release_cell)

func _handle_tap(cell: Vector2i) -> void:
	if not _is_valid_cell(cell):
		return
	if not _is_valid_cell(_selected_cell):
		_selected_cell = cell
		queue_redraw()
		return
	if cell == _selected_cell:
		_selected_cell = GameTypes.INVALID_CELL
		queue_redraw()
		return
	if _are_adjacent(_selected_cell, cell):
		var from_cell := _selected_cell
		_selected_cell = GameTypes.INVALID_CELL
		queue_redraw()
		_try_player_swap(from_cell, cell)
	else:
		_selected_cell = cell
		queue_redraw()

func _try_player_swap(a: Vector2i, b: Vector2i) -> void:
	if input_locked or game_over or not _are_adjacent(a, b):
		return
	input_locked = true
	_selected_cell = GameTypes.INVALID_CELL
	queue_redraw()
	var piece_a = _piece_at(a)
	var piece_b = _piece_at(b)
	if piece_a == null or piece_b == null:
		input_locked = false
		return
	await _swap_pieces(a, b, true)
	var combo_cells := _combo_clear_cells(piece_a, piece_b)
	var matches := _find_matches()
	if combo_cells.is_empty() and matches.is_empty():
		await _swap_pieces(a, b, true)
		play_swap_sound()
		input_locked = false
		return
	moves_remaining -= 1
	play_swap_sound()
	emit_signal("moves_changed", moves_remaining)
	await _resolve_after_swap(a, b, combo_cells)
	_check_end_state()
	if not game_over:
		await _ensure_possible_move()
		input_locked = false

func _resolve_after_swap(a: Vector2i, b: Vector2i, initial_combo_cells: Array) -> void:
	var preferred_cells := [b, a]
	if not initial_combo_cells.is_empty():
		await _clear_cells(initial_combo_cells, null)
		await _collapse_columns()
	while true:
		var matches := _find_matches()
		if matches.is_empty():
			break
		await _resolve_matches(matches, preferred_cells)
		await _collapse_columns()

func _resolve_matches(matches: Array, preferred_cells: Array) -> void:
	var special_cell := _choose_special_cell(matches, preferred_cells)
	var special_type := _special_type_from_matches(matches)
	var cells_to_clear := _cells_from_matches(matches)
	var new_special_piece = null
	if special_type != GameTypes.SpecialType.NONE and _is_valid_cell(special_cell):
		new_special_piece = _piece_at(special_cell)
		cells_to_clear.erase(special_cell)
	var expanded_cells := _expand_special_activations(cells_to_clear)
	await _clear_cells(expanded_cells, new_special_piece)
	if new_special_piece != null:
		new_special_piece.set_special(special_type)
		await new_special_piece.animate_special_pulse()

func _clear_cells(cells: Array, protected_piece) -> void:
	var unique_cells := _unique_valid_cells(cells)
	if unique_cells.is_empty():
		return
	var clear_tasks: Array = []
	var pieces_to_free: Array = []
	for cell in unique_cells:
		var piece = _piece_at(cell)
		if piece == null or piece == protected_piece:
			continue
		if piece.special_type != GameTypes.SpecialType.NONE:
			_specials_triggered += 1
			play_special_sound()
		if _goal_type == GameTypes.GoalType.CLEAR_COLOR and piece.color_id == _goal_color:
			_cleared_goal_color += 1
		score += 60 if piece.special_type == GameTypes.SpecialType.NONE else 140
		grid[cell.x][cell.y] = null
		pieces_to_free.append(piece)
		clear_tasks.append(piece.animate_clear())
	for task in clear_tasks:
		await task
	for piece in pieces_to_free:
		piece.queue_free()
	play_match_sound()
	_emit_state()

func _expand_special_activations(base_cells: Array) -> Array:
	var result := _unique_valid_cells(base_cells)
	var index := 0
	while index < result.size():
		var cell: Vector2i = result[index]
		var piece = _piece_at(cell)
		if piece != null and piece.special_type != GameTypes.SpecialType.NONE:
			var extra := _activation_cells_for_special(cell, piece.special_type, -1)
			for extra_cell in extra:
				if _is_valid_cell(extra_cell) and not result.has(extra_cell):
					result.append(extra_cell)
		index += 1
	return result

func _combo_clear_cells(piece_a, piece_b) -> Array:
	if piece_a == null or piece_b == null:
		return []
	var a: Vector2i = piece_a.grid_position
	var b: Vector2i = piece_b.grid_position
	var a_special: int = piece_a.special_type
	var b_special: int = piece_b.special_type
	if a_special == GameTypes.SpecialType.NONE and b_special == GameTypes.SpecialType.NONE:
		return []
	if a_special == GameTypes.SpecialType.COLOR_BOMB and b_special == GameTypes.SpecialType.COLOR_BOMB:
		return _all_board_cells()
	if a_special == GameTypes.SpecialType.COLOR_BOMB:
		return _color_bomb_combo_cells(a, piece_b.color_id, b_special)
	if b_special == GameTypes.SpecialType.COLOR_BOMB:
		return _color_bomb_combo_cells(b, piece_a.color_id, a_special)
	if _is_striped(a_special) and _is_striped(b_special):
		return _row_cells(a.y) + _column_cells(b.x)
	if a_special == GameTypes.SpecialType.WRAPPED and b_special == GameTypes.SpecialType.WRAPPED:
		return _area_cells(a, 2) + _area_cells(b, 2)
	return _activation_cells_for_special(a, a_special, -1) + _activation_cells_for_special(b, b_special, -1)

func _color_bomb_combo_cells(color_bomb_cell: Vector2i, target_color: int, other_special: int) -> Array:
	var cells: Array = [color_bomb_cell]
	if other_special == GameTypes.SpecialType.COLOR_BOMB:
		return _all_board_cells()
	if _is_striped(other_special):
		var converted := 0
		for cell in _cells_with_color(target_color):
			var piece = _piece_at(cell)
			if piece != null and converted < 6:
				piece.set_special(GameTypes.SpecialType.STRIPED_ROW if converted % 2 == 0 else GameTypes.SpecialType.STRIPED_COLUMN)
				cells += _activation_cells_for_special(cell, piece.special_type, target_color)
				converted += 1
		return cells
	if other_special == GameTypes.SpecialType.WRAPPED:
		for cell in _cells_with_color(target_color):
			cells += _area_cells(cell, 1)
		return cells
	return cells + _cells_with_color(target_color)

func _activation_cells_for_special(cell: Vector2i, special_type: int, target_color: int) -> Array:
	match special_type:
		GameTypes.SpecialType.STRIPED_ROW:
			return _row_cells(cell.y)
		GameTypes.SpecialType.STRIPED_COLUMN:
			return _column_cells(cell.x)
		GameTypes.SpecialType.WRAPPED:
			return _area_cells(cell, 1)
		GameTypes.SpecialType.COLOR_BOMB:
			if target_color >= 0:
				return [cell] + _cells_with_color(target_color)
			var piece = _piece_at(cell)
			if piece != null:
				return [cell] + _cells_with_color(piece.color_id)
			return [cell]
		_:
			return [cell]

func _collapse_columns() -> void:
	for x in BOARD_SIZE:
		var write_y := BOARD_SIZE - 1
		for y in range(BOARD_SIZE - 1, -1, -1):
			var piece = grid[x][y]
			if piece != null:
				if y != write_y:
					grid[x][write_y] = piece
					grid[x][y] = null
					piece.set_grid_position(Vector2i(x, write_y))
				write_y -= 1
		for y in range(write_y, -1, -1):
			var new_piece = _spawn_piece(Vector2i(x, y), false)
			new_piece.position = _cell_top_left(Vector2i(x, y - BOARD_SIZE))
	var tweens: Array = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var piece = _piece_at(Vector2i(x, y))
			if piece != null:
				tweens.append(_animate_piece_to_cell(piece, Vector2i(x, y), 0.22))
	for tween in tweens:
		await tween

func _swap_pieces(a: Vector2i, b: Vector2i, animated: bool) -> void:
	var piece_a = _piece_at(a)
	var piece_b = _piece_at(b)
	grid[a.x][a.y] = piece_b
	grid[b.x][b.y] = piece_a
	piece_a.set_grid_position(b)
	piece_b.set_grid_position(a)
	if animated:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece_a, "position", _cell_top_left(b), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece_b, "position", _cell_top_left(a), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished
	else:
		piece_a.position = _cell_top_left(b)
		piece_b.position = _cell_top_left(a)

func _animate_piece_to_cell(piece, cell: Vector2i, duration: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(piece, "position", _cell_top_left(cell), duration).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return tween.finished

func _create_initial_board() -> void:
	var attempts := 0
	while attempts < 200:
		attempts += 1
		_clear_board()
		grid.clear()
		for x in BOARD_SIZE:
			var column := []
			for y in BOARD_SIZE:
				column.append(null)
			grid.append(column)
		for y in BOARD_SIZE:
			for x in BOARD_SIZE:
				var color_id := _random_color_without_start_match(x, y)
				var piece = _create_piece(color_id, GameTypes.SpecialType.NONE, Vector2i(x, y))
				grid[x][y] = piece
		if _find_matches().is_empty() and _has_possible_move():
			return

func _clear_board() -> void:
	for child in get_children():
		child.queue_free()
	grid.clear()

func _spawn_piece(cell: Vector2i, animate: bool):
	var piece = _create_piece(_available_colors.pick_random(), GameTypes.SpecialType.NONE, cell)
	grid[cell.x][cell.y] = piece
	if animate:
		piece.animate_spawn()
	return piece

func _create_piece(color_id: int, special_type: int, cell: Vector2i):
	var piece = PIECE_SCENE.instantiate()
	add_child(piece)
	piece.setup(color_id, special_type, cell)
	piece.position = _cell_top_left(cell)
	piece.size = Vector2.ONE * _cell_size
	return piece

func _random_color_without_start_match(x: int, y: int) -> int:
	var candidates := _available_colors.duplicate()
	candidates.shuffle()
	for color_id in candidates:
		var horizontal: bool = x >= 2 and grid[x - 1][y] != null and grid[x - 2][y] != null and grid[x - 1][y].color_id == color_id and grid[x - 2][y].color_id == color_id
		var vertical: bool = y >= 2 and grid[x][y - 1] != null and grid[x][y - 2] != null and grid[x][y - 1].color_id == color_id and grid[x][y - 2].color_id == color_id
		if not horizontal and not vertical:
			return color_id
	return candidates[0]

func _find_matches() -> Array:
	var matches: Array = []
	for y in BOARD_SIZE:
		var x := 0
		while x < BOARD_SIZE:
			var piece = _piece_at(Vector2i(x, y))
			if piece == null:
				x += 1
				continue
			var color_id: int = piece.color_id
			var run: Array[Vector2i] = [Vector2i(x, y)]
			var nx := x + 1
			while nx < BOARD_SIZE:
				var next_piece = _piece_at(Vector2i(nx, y))
				if next_piece == null or next_piece.color_id != color_id:
					break
				run.append(Vector2i(nx, y))
				nx += 1
			if run.size() >= 3:
				matches.append({"cells": run, "orientation": "h", "color": color_id})
			x = nx
	for x in BOARD_SIZE:
		var y := 0
		while y < BOARD_SIZE:
			var piece = _piece_at(Vector2i(x, y))
			if piece == null:
				y += 1
				continue
			var color_id: int = piece.color_id
			var run: Array[Vector2i] = [Vector2i(x, y)]
			var ny := y + 1
			while ny < BOARD_SIZE:
				var next_piece = _piece_at(Vector2i(x, ny))
				if next_piece == null or next_piece.color_id != color_id:
					break
				run.append(Vector2i(x, ny))
				ny += 1
			if run.size() >= 3:
				matches.append({"cells": run, "orientation": "v", "color": color_id})
			y = ny
	return matches

func _special_type_from_matches(matches: Array) -> int:
	for match_data in matches:
		if match_data["cells"].size() >= 5:
			return GameTypes.SpecialType.COLOR_BOMB
	if _has_intersection(matches):
		return GameTypes.SpecialType.WRAPPED
	for match_data in matches:
		if match_data["cells"].size() == 4:
			return GameTypes.SpecialType.STRIPED_ROW if match_data["orientation"] == "h" else GameTypes.SpecialType.STRIPED_COLUMN
	return GameTypes.SpecialType.NONE

func _has_intersection(matches: Array) -> bool:
	for h_match in matches:
		if h_match["orientation"] != "h":
			continue
		for v_match in matches:
			if v_match["orientation"] != "v" or h_match["color"] != v_match["color"]:
				continue
			for h_cell in h_match["cells"]:
				if v_match["cells"].has(h_cell):
					return true
	return false

func _choose_special_cell(matches: Array, preferred_cells: Array) -> Vector2i:
	var all_cells := _cells_from_matches(matches)
	for preferred in preferred_cells:
		if all_cells.has(preferred):
			return preferred
	for h_match in matches:
		if h_match["orientation"] != "h":
			continue
		for v_match in matches:
			if v_match["orientation"] != "v" or h_match["color"] != v_match["color"]:
				continue
			for h_cell in h_match["cells"]:
				if v_match["cells"].has(h_cell):
					return h_cell
	return all_cells[0] if not all_cells.is_empty() else GameTypes.INVALID_CELL

func _cells_from_matches(matches: Array) -> Array:
	var cells: Array = []
	for match_data in matches:
		for cell in match_data["cells"]:
			if not cells.has(cell):
				cells.append(cell)
	return cells

func _has_possible_move() -> bool:
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell := Vector2i(x, y)
			for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
				var other = cell + dir
				if not _is_valid_cell(other):
					continue
				_swap_cells_data(cell, other)
				var has_match := not _find_matches().is_empty() or not _combo_clear_cells(_piece_at(cell), _piece_at(other)).is_empty()
				_swap_cells_data(cell, other)
				if has_match:
					return true
	return false

func _ensure_possible_move() -> void:
	var reshuffles := 0
	while not _has_possible_move() and reshuffles < 25:
		reshuffles += 1
		await _reshuffle_board()

func _reshuffle_board() -> void:
	var pieces: Array = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var piece = _piece_at(Vector2i(x, y))
			if piece != null:
				pieces.append(piece)
	pieces.shuffle()
	var index := 0
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var piece = pieces[index]
			index += 1
			grid[x][y] = piece
			piece.set_grid_position(Vector2i(x, y))
	_layout_pieces(true)
	await get_tree().create_timer(0.22).timeout
	while not _find_matches().is_empty():
		await _resolve_after_swap(GameTypes.INVALID_CELL, GameTypes.INVALID_CELL, [])

func _layout_pieces(animated: bool) -> void:
	_cell_size = min(size.x, size.y) / float(BOARD_SIZE)
	_board_origin = (size - Vector2.ONE * _cell_size * BOARD_SIZE) * 0.5
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var piece = _piece_at(Vector2i(x, y))
			if piece != null:
				piece.size = Vector2.ONE * _cell_size
				if animated:
					_animate_piece_to_cell(piece, Vector2i(x, y), 0.18)
				else:
					piece.position = _cell_top_left(Vector2i(x, y))
	queue_redraw()

func _check_end_state() -> void:
	if _is_goal_complete():
		game_over = true
		input_locked = true
		play_level_complete_sound()
		emit_signal("level_finished", true)
	elif moves_remaining <= 0:
		game_over = true
		input_locked = true
		play_level_failed_sound()
		emit_signal("level_finished", false)

func _is_goal_complete() -> bool:
	match _goal_type:
		GameTypes.GoalType.CLEAR_COLOR:
			return _cleared_goal_color >= _goal_count and score >= int(level_data.get("target_score", 0))
		GameTypes.GoalType.SPECIALS:
			return _specials_triggered >= _goal_count and score >= int(level_data.get("target_score", 0))
		_:
			return score >= _goal_count

func _goal_text() -> String:
	match _goal_type:
		GameTypes.GoalType.CLEAR_COLOR:
			return "%s %d/%d  |  Score %d/%d" % [
				GameTypes.label_for(_goal_color),
				_cleared_goal_color,
				_goal_count,
				score,
				int(level_data.get("target_score", 0)),
			]
		GameTypes.GoalType.SPECIALS:
			return "Specials %d/%d  |  Score %d/%d" % [
				_specials_triggered,
				_goal_count,
				score,
				int(level_data.get("target_score", 0)),
			]
		_:
			return "Score %d/%d" % [score, _goal_count]

func _emit_state() -> void:
	emit_signal("score_changed", score)
	emit_signal("moves_changed", moves_remaining)
	emit_signal("goal_changed", _goal_text())

func _swap_cells_data(a: Vector2i, b: Vector2i) -> void:
	var piece_a = grid[a.x][a.y]
	var piece_b = grid[b.x][b.y]
	grid[a.x][a.y] = piece_b
	grid[b.x][b.y] = piece_a
	if piece_a != null:
		piece_a.set_grid_position(b)
	if piece_b != null:
		piece_b.set_grid_position(a)

func _piece_at(cell: Vector2i):
	if not _is_valid_cell(cell) or grid.is_empty():
		return null
	return grid[cell.x][cell.y]

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE

func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return _is_valid_cell(a) and _is_valid_cell(b) and abs(a.x - b.x) + abs(a.y - b.y) == 1

func _cell_from_local(local_position: Vector2) -> Vector2i:
	var board_position := local_position - _board_origin
	var cell := Vector2i(floori(board_position.x / _cell_size), floori(board_position.y / _cell_size))
	return cell if _is_valid_cell(cell) else GameTypes.INVALID_CELL

func _cell_top_left(cell: Vector2i) -> Vector2:
	return _board_origin + Vector2(cell.x, cell.y) * _cell_size

func _row_cells(row: int) -> Array:
	var cells: Array = []
	for x in BOARD_SIZE:
		cells.append(Vector2i(x, row))
	return cells

func _column_cells(column: int) -> Array:
	var cells: Array = []
	for y in BOARD_SIZE:
		cells.append(Vector2i(column, y))
	return cells

func _area_cells(center: Vector2i, radius: int) -> Array:
	var cells: Array = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var cell := Vector2i(x, y)
			if _is_valid_cell(cell):
				cells.append(cell)
	return cells

func _all_board_cells() -> Array:
	var cells: Array = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			cells.append(Vector2i(x, y))
	return cells

func _cells_with_color(color_id: int) -> Array:
	var cells: Array = []
	for y in BOARD_SIZE:
		for x in BOARD_SIZE:
			var cell := Vector2i(x, y)
			var piece = _piece_at(cell)
			if piece != null and piece.color_id == color_id:
				cells.append(cell)
	return cells

func _unique_valid_cells(cells: Array) -> Array:
	var result: Array = []
	for cell in cells:
		if _is_valid_cell(cell) and not result.has(cell):
			result.append(cell)
	return result

func _is_striped(special_type: int) -> bool:
	return special_type == GameTypes.SpecialType.STRIPED_ROW or special_type == GameTypes.SpecialType.STRIPED_COLUMN

func play_swap_sound() -> void:
	# TODO: Add a generated or imported swap sound here when audio polish begins.
	pass

func play_match_sound() -> void:
	# TODO: Add a generated or imported match sound here when audio polish begins.
	pass

func play_special_sound() -> void:
	# TODO: Add a generated or imported special-piece sound here when audio polish begins.
	pass

func play_level_complete_sound() -> void:
	# TODO: Add a generated or imported level-complete sound here when audio polish begins.
	pass

func play_level_failed_sound() -> void:
	# TODO: Add a generated or imported level-failed sound here when audio polish begins.
	pass
