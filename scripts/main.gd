extends Control

const Levels = preload("res://scripts/level_data.gd")
const BOARD_SCENE := preload("res://scenes/Board.tscn")
const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/backgrounds/melle_candy_match3_background_blur.png")
const MUSIC_STREAM: AudioStreamOggVorbis = preload("res://assets/audio/music/zane_little_flowerbed_fields.ogg")
const UI_DISPLAY_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_display_rectangle.png")
const UI_DISPLAY_OUTLINE_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_display_outline_rectangle.png")
const UI_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_button_blue_depth_gradient.png")
const UI_BUTTON_PRESSED_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_button_green_depth_gradient.png")
const UI_TEXT_COLOR := Color("#23314f")
const PAGE_MARGIN_X := 24
const PAGE_MARGIN_TOP := 26
const PAGE_MARGIN_BOTTOM := 22
const MAX_PLAY_WIDTH := 640
const MIN_PLAY_WIDTH := 360
const STACK_FIXED_HEIGHT := 348
const SAVE_PATH := "user://candyx_progress.cfg"
const SAVE_SECTION := "progress"
const SAVE_LEVEL_KEY := "current_level_index"

var _level_index := 0

var _board
var _play_stack: VBoxContainer
var _board_frame: Control
var _level_label: Label
var _score_label: Label
var _target_label: Label
var _moves_label: Label
var _goal_label: Label
var _message_label: Label
var _new_game_button: Button
var _restart_button: Button
var _next_button: Button
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_build_ui()
	_start_music()
	_start_level(_load_progress())

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = BACKGROUND_TEXTURE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.72, 0.78, 0.9, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", PAGE_MARGIN_X)
	margin.add_theme_constant_override("margin_top", PAGE_MARGIN_TOP)
	margin.add_theme_constant_override("margin_right", PAGE_MARGIN_X)
	margin.add_theme_constant_override("margin_bottom", PAGE_MARGIN_BOTTOM)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "candyX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#fff8df"))
	root.add_child(title)

	var play_center := CenterContainer.new()
	play_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(play_center)

	_play_stack = VBoxContainer.new()
	_play_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_play_stack.add_theme_constant_override("separation", 0)
	play_center.add_child(_play_stack)

	var info_panel := _make_texture_panel(UI_DISPLAY_TEXTURE, Vector2(0, 116))
	_play_stack.add_child(info_panel)

	var info_grid := GridContainer.new()
	info_grid.columns = 2
	info_grid.add_theme_constant_override("h_separation", 18)
	info_grid.add_theme_constant_override("v_separation", 8)
	info_panel.add_child(info_grid)

	_level_label = _make_stat_label()
	_score_label = _make_stat_label()
	_target_label = _make_stat_label()
	_moves_label = _make_stat_label()
	info_grid.add_child(_level_label)
	info_grid.add_child(_score_label)
	info_grid.add_child(_target_label)
	info_grid.add_child(_moves_label)

	var goal_panel := _make_texture_panel(UI_DISPLAY_OUTLINE_TEXTURE, Vector2(0, 68))
	_play_stack.add_child(goal_panel)

	_goal_label = Label.new()
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 22)
	_goal_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_goal_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	_goal_label.add_theme_constant_override("shadow_offset_x", 0)
	_goal_label.add_theme_constant_override("shadow_offset_y", 1)
	goal_panel.add_child(_goal_label)

	_board_frame = Control.new()
	_board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_board_frame.custom_minimum_size = Vector2(MIN_PLAY_WIDTH, MIN_PLAY_WIDTH)
	_play_stack.add_child(_board_frame)

	_board = BOARD_SCENE.instantiate()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board_frame.add_child(_board)
	_board.score_changed.connect(_on_score_changed)
	_board.moves_changed.connect(_on_moves_changed)
	_board.goal_changed.connect(_on_goal_changed)
	_board.level_finished.connect(_on_level_finished)

	var message_panel := _make_texture_panel(UI_DISPLAY_TEXTURE, Vector2(0, 86))
	_play_stack.add_child(message_panel)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(0, 70)
	_message_label.add_theme_font_size_override("font_size", 24)
	_message_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_message_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	_message_label.add_theme_constant_override("shadow_offset_x", 0)
	_message_label.add_theme_constant_override("shadow_offset_y", 1)
	message_panel.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.custom_minimum_size = Vector2(0, 74)
	_play_stack.add_child(buttons)

	_new_game_button = Button.new()
	_new_game_button.text = "New Game"
	_new_game_button.custom_minimum_size = Vector2(142, 64)
	_style_menu_button(_new_game_button)
	_new_game_button.pressed.connect(_new_game)
	buttons.add_child(_new_game_button)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.custom_minimum_size = Vector2(142, 64)
	_style_menu_button(_restart_button)
	_restart_button.pressed.connect(_restart_level)
	buttons.add_child(_restart_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(142, 64)
	_style_menu_button(_next_button)
	_next_button.pressed.connect(_next_level)
	buttons.add_child(_next_button)
	_update_connected_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_connected_layout()

func _update_connected_layout() -> void:
	if not _play_stack or not _board_frame:
		return
	var viewport_size := get_viewport_rect().size
	var available_width := viewport_size.x - PAGE_MARGIN_X * 2.0
	var available_height := viewport_size.y - PAGE_MARGIN_TOP - PAGE_MARGIN_BOTTOM
	var height_limited_width: float = max(float(MIN_PLAY_WIDTH), available_height - float(STACK_FIXED_HEIGHT))
	var play_width: float = min(available_width, height_limited_width, float(MAX_PLAY_WIDTH))
	_play_stack.custom_minimum_size = Vector2(play_width, 0)
	_board_frame.custom_minimum_size = Vector2(play_width, play_width)

func _make_texture_panel(texture: Texture2D, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _make_texture_style(texture, 20, Color.WHITE))
	return panel

func _make_texture_style(texture: Texture2D, margin: int, tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	return style

func _style_menu_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_texture_style(UI_BUTTON_TEXTURE, 20, Color.WHITE))
	button.add_theme_stylebox_override("hover", _make_texture_style(UI_BUTTON_TEXTURE, 20, Color("#fff8df")))
	button.add_theme_stylebox_override("pressed", _make_texture_style(UI_BUTTON_PRESSED_TEXTURE, 20, Color.WHITE))
	button.add_theme_stylebox_override("disabled", _make_texture_style(UI_BUTTON_TEXTURE, 20, Color(1, 1, 1, 0.5)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#ccd2e6"))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)

func _make_stat_label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.custom_minimum_size = Vector2(164, 34)
	return label

func _start_level(index: int) -> void:
	_level_index = maxi(0, index)
	var data := Levels.level_for(_level_index)
	_level_label.text = "Level: %d" % [_level_index + 1]
	_target_label.text = "Target: %d" % int(data.get("target_score", data.get("goal_count", 0)))
	_message_label.text = data.get("description", "")
	_message_label.modulate.a = 1.0
	_next_button.visible = false
	_board.start_level(data)

func _new_game() -> void:
	_reset_progress()
	_start_level(0)

func _restart_level() -> void:
	_start_level(_level_index)

func _next_level() -> void:
	var next_level_index := _level_index + 1
	_save_progress(next_level_index)
	_start_level(next_level_index)

func _load_progress() -> int:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return 0
	var value = config.get_value(SAVE_SECTION, SAVE_LEVEL_KEY, 0)
	if value is int or value is float:
		return maxi(0, int(value))
	return 0

func _save_progress(index: int) -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, SAVE_LEVEL_KEY, maxi(0, index))
	var error := config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save progress to %s" % SAVE_PATH)

func _reset_progress() -> void:
	_save_progress(0)

func _on_score_changed(score: int) -> void:
	_score_label.text = "Score: %d" % score

func _on_moves_changed(moves_remaining: int) -> void:
	_moves_label.text = "Moves: %d" % moves_remaining

func _on_goal_changed(text: String) -> void:
	_goal_label.text = "Goal: %s" % text

func _on_level_finished(success: bool) -> void:
	if success:
		_message_label.text = "Level complete!"
		_next_button.visible = true
	else:
		_message_label.text = "Level failed. Try again."
		_next_button.visible = false
	var tween := create_tween()
	_message_label.scale = Vector2.ONE * 0.92
	tween.tween_property(_message_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -18.0
	add_child(_music_player)
	if MUSIC_STREAM == null:
		return
	var stream: AudioStreamOggVorbis = MUSIC_STREAM.duplicate()
	stream.loop = true
	_music_player.stream = stream
	_music_player.play()
