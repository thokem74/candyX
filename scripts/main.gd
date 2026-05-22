extends Control

const Levels = preload("res://scripts/level_data.gd")
const BOARD_SCENE := preload("res://scenes/Board.tscn")
const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/sprites/backgrounds/melle_candy_match3_background_blur.png")
const MUSIC_STREAM: AudioStreamOggVorbis = preload("res://assets/audio/music/zane_little_flowerbed_fields.ogg")
const UI_DISPLAY_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_display_rectangle.png")
const UI_DISPLAY_OUTLINE_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_display_outline_rectangle.png")
const UI_BUTTON_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_button_blue_depth_gradient.png")
const UI_BUTTON_PRESSED_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_button_green_depth_gradient.png")
const UI_DIVIDER_TEXTURE: Texture2D = preload("res://assets/sprites/ui/kenney_ui_pack_divider_edges.png")
const UI_TEXT_COLOR := Color("#23314f")

var _levels: Array[Dictionary] = Levels.levels()
var _level_index := 0

var _board
var _level_label: Label
var _score_label: Label
var _target_label: Label
var _moves_label: Label
var _goal_label: Label
var _message_label: Label
var _restart_button: Button
var _next_button: Button
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_build_ui()
	_start_music()
	_start_level(0)

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
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "candyX"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#fff8df"))
	root.add_child(title)

	var info_panel := _make_texture_panel(UI_DISPLAY_TEXTURE, Vector2(0, 96))
	root.add_child(info_panel)

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

	var goal_panel := _make_texture_panel(UI_DISPLAY_OUTLINE_TEXTURE, Vector2(0, 54))
	root.add_child(goal_panel)

	_goal_label = Label.new()
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.add_theme_font_size_override("font_size", 18)
	_goal_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_goal_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	_goal_label.add_theme_constant_override("shadow_offset_x", 0)
	_goal_label.add_theme_constant_override("shadow_offset_y", 1)
	goal_panel.add_child(_goal_label)

	var board_frame := Control.new()
	board_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_frame.custom_minimum_size = Vector2(320, 320)
	root.add_child(board_frame)

	_board = BOARD_SCENE.instantiate()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_frame.add_child(_board)
	_board.score_changed.connect(_on_score_changed)
	_board.moves_changed.connect(_on_moves_changed)
	_board.goal_changed.connect(_on_goal_changed)
	_board.level_finished.connect(_on_level_finished)

	var divider := TextureRect.new()
	divider.texture = UI_DIVIDER_TEXTURE
	divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	divider.stretch_mode = TextureRect.STRETCH_SCALE
	divider.custom_minimum_size = Vector2(0, 8)
	root.add_child(divider)

	var message_panel := _make_texture_panel(UI_DISPLAY_TEXTURE, Vector2(0, 72))
	root.add_child(message_panel)

	_message_label = Label.new()
	_message_label.text = ""
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.custom_minimum_size = Vector2(0, 58)
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	_message_label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	_message_label.add_theme_constant_override("shadow_offset_x", 0)
	_message_label.add_theme_constant_override("shadow_offset_y", 1)
	message_panel.add_child(_message_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	root.add_child(buttons)

	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.custom_minimum_size = Vector2(128, 52)
	_style_menu_button(_restart_button)
	_restart_button.pressed.connect(_restart_level)
	buttons.add_child(_restart_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.custom_minimum_size = Vector2(128, 52)
	_style_menu_button(_next_button)
	_next_button.pressed.connect(_next_level)
	buttons.add_child(_next_button)

func _make_texture_panel(texture: Texture2D, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.add_theme_stylebox_override("panel", _make_texture_style(texture, 20, Color.WHITE))
	return panel

func _make_texture_style(texture: Texture2D, margin: int, modulate: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = modulate
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
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#ffffff"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	button.add_theme_color_override("font_disabled_color", Color("#ccd2e6"))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)

func _make_stat_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UI_TEXT_COLOR)
	label.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.custom_minimum_size = Vector2(140, 28)
	return label

func _start_level(index: int) -> void:
	_level_index = clampi(index, 0, _levels.size() - 1)
	var data := _levels[_level_index]
	_level_label.text = "Level: %d/%d" % [_level_index + 1, _levels.size()]
	_target_label.text = "Target: %d" % int(data.get("target_score", data.get("goal_count", 0)))
	_message_label.text = data.get("description", "")
	_message_label.modulate.a = 1.0
	_next_button.visible = false
	_board.start_level(data)

func _restart_level() -> void:
	_start_level(_level_index)

func _next_level() -> void:
	if _level_index < _levels.size() - 1:
		_start_level(_level_index + 1)

func _on_score_changed(score: int) -> void:
	_score_label.text = "Score: %d" % score

func _on_moves_changed(moves_remaining: int) -> void:
	_moves_label.text = "Moves: %d" % moves_remaining

func _on_goal_changed(text: String) -> void:
	_goal_label.text = "Goal: %s" % text

func _on_level_finished(success: bool) -> void:
	if success:
		if _level_index >= _levels.size() - 1:
			_message_label.text = "All levels complete!"
			_next_button.visible = false
		else:
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
