extends CanvasLayer

signal game_finished

enum GameState { MENU, MORPION, PONG }
var current_state: GameState = GameState.MENU

var is_active: bool = false
var animation_time: float = 0.0

# UI Controls
var root_control: Control
var background_panel: Panel
var scope_control: Control
var label_status: Label
var label_score_info: Label
var btn_quit: Button

# Menu Controls
var menu_container: VBoxContainer
var btn_play_morpion: Button
var btn_play_pong: Button

# Tic-Tac-Toe (Morpion) Variables
var morpion_grid: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0] # 0: empty, 1: player (tennis ball), 2: dog (bone)
var is_player_turn: bool = true
var is_morpion_game_over: bool = false
var morpion_winner: int = 0 # 0: tie/none, 1: player, 2: dog
var morpion_ai_timer: float = 0.0
var is_morpion_ai_thinking: bool = false
var morpion_hovered_cell: int = -1

# Chien-Pong Variables
var p_paddle_y: float = 145.0
var d_paddle_y: float = 145.0
var paddle_h: float = 45.0
var paddle_w: float = 8.0

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_radius: float = 6.0
var base_ball_speed: float = 240.0
var ball_speed_multiplier: float = 1.0

var player_score: int = 0
var dog_score: int = 0
var is_pong_game_over: bool = false
var pong_winner: int = 0
var pong_particles: Array[Dictionary] = []

# Sound
var _audio_player: AudioStreamPlayer
var _bark_sounds: Array[AudioStream] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	layer = 100
	visible = false
	_rng.randomize()
	_setup_audio()
	_setup_ui()

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Master"
	add_child(_audio_player)

	# Load bark streams from res://audio/chien/
	var dir := DirAccess.open("res://audio/chien/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
				var stream := load("res://audio/chien/" + file_name) as AudioStream
				if stream:
					_bark_sounds.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()

func _setup_ui() -> void:
	# Root full screen Control to ensure exact centering
	root_control = Control.new()
	root_control.name = "RootControl"
	root_control.anchor_left = 0.0
	root_control.anchor_top = 0.0
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	root_control.offset_left = 0
	root_control.offset_top = 0
	root_control.offset_right = 0
	root_control.offset_bottom = 0
	add_child(root_control)

	background_panel = Panel.new()
	background_panel.name = "BackgroundPanel"
	background_panel.custom_minimum_size = Vector2(640, 500)
	background_panel.anchor_left = 0.5
	background_panel.anchor_right = 0.5
	background_panel.anchor_top = 0.5
	background_panel.anchor_bottom = 0.5
	background_panel.offset_left = -320
	background_panel.offset_right = 320
	background_panel.offset_top = -250
	background_panel.offset_bottom = 250
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.03, 0.1, 0.97)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.5, 1.0, 0.8) # Purple Neon
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(background_panel)

	# Title Bar
	var label_title := Label.new()
	label_title.text = "🐾 NEXUS DOG PLAYROOM - SALLE DE JEU DU CHIEN"
	label_title.position = Vector2(20, 15)
	label_title.add_theme_font_size_override("font_size", 16)
	label_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 1.0))
	background_panel.add_child(label_title)

	# Scope Play Screen (Main arcade viewport)
	scope_control = Control.new()
	scope_control.position = Vector2(20, 55)
	scope_control.custom_minimum_size = Vector2(600, 290)
	scope_control.draw.connect(_on_scope_draw)
	scope_control.gui_input.connect(_on_scope_gui_input)
	background_panel.add_child(scope_control)

	# Bottom Info Panel
	label_score_info = Label.new()
	label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER À JOUER AVEC LE CHIEN !"
	label_score_info.position = Vector2(20, 365)
	label_score_info.size = Vector2(600, 20)
	label_score_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_score_info.add_theme_font_size_override("font_size", 13)
	label_score_info.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 0.95))
	background_panel.add_child(label_score_info)

	label_status = Label.new()
	label_status.text = "🟢 PRÊT À AMUSER LE CHIEN"
	label_status.position = Vector2(20, 395)
	label_status.size = Vector2(600, 20)
	label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_status.add_theme_font_size_override("font_size", 12)
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	background_panel.add_child(label_status)

	# Main Menu Buttons Container
	menu_container = VBoxContainer.new()
	menu_container.position = Vector2(180, 105)
	menu_container.size = Vector2(240, 130)
	menu_container.add_theme_constant_override("separation", 15)
	background_panel.add_child(menu_container)

	btn_play_morpion = Button.new()
	btn_play_morpion.text = "🦴 MORPION DES OS"
	btn_play_morpion.focus_mode = Control.FOCUS_NONE
	btn_play_morpion.pressed.connect(_on_play_morpion_pressed)
	menu_container.add_child(btn_play_morpion)

	btn_play_pong = Button.new()
	btn_play_pong.text = "🏓 CHIEN-PONG"
	btn_play_pong.focus_mode = Control.FOCUS_NONE
	btn_play_pong.pressed.connect(_on_play_pong_pressed)
	menu_container.add_child(btn_play_pong)

	# Style standard buttons with glowing HSL borders
	_style_button(btn_play_morpion, Color(0.12, 0.08, 0.22, 1.0), Color(0.8, 0.5, 1.0, 0.8))
	_style_button(btn_play_pong, Color(0.12, 0.08, 0.22, 1.0), Color(0.8, 0.5, 1.0, 0.8))

	# Quit Button
	btn_quit = Button.new()
	btn_quit.text = "[ ÉCHAP ] RETOUR / QUITTER"
	btn_quit.position = Vector2(170, 440)
	btn_quit.size = Vector2(300, 36)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.pressed.connect(_on_quit_pressed)
	_style_button(btn_quit, Color(0.18, 0.06, 0.12, 1.0), Color(1.0, 0.2, 0.4, 0.8))
	background_panel.add_child(btn_quit)

func _style_button(btn: Button, bg_color: Color, border_color: Color) -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = border_color
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	
	var style_hover := style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = bg_color.lightened(0.12)
	style_hover.border_color = Color(0.24, 0.95, 0.79, 1.0) # cyan neon
	
	var style_pressed := style_normal.duplicate() as StyleBoxFlat
	style_pressed.bg_color = bg_color.darkened(0.15)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(0.24, 0.95, 0.79, 1.0))
	btn.add_theme_font_size_override("font_size", 13)

func _process(delta: float) -> void:
	if not is_active:
		return
	
	animation_time += delta

	# Process active game state
	if current_state == GameState.MORPION and is_morpion_ai_thinking:
		morpion_ai_timer -= delta
		if morpion_ai_timer <= 0.0:
			_make_morpion_dog_move()
	elif current_state == GameState.PONG and not is_pong_game_over:
		_process_pong(delta)

	scope_control.queue_redraw()

func open_game() -> void:
	is_active = true
	current_state = GameState.MENU
	menu_container.visible = true
	label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER À JOUER AVEC LE CHIEN !"
	label_status.text = "🟢 PRÊT À AMUSER LE CHIEN"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	
	# Dynamically center the menu exactly on the PNJ's screen position
	var pnj_screen_pos := Vector2(1024 / 2.0, 682 / 2.0)
	var parent = get_parent()
	if parent and "pnjHub" in parent and is_instance_valid(parent.pnjHub):
		var pnj_node = parent.pnjHub as Node2D
		if pnj_node:
			pnj_screen_pos = pnj_node.get_global_transform_with_canvas().origin
	
	background_panel.global_position = pnj_screen_pos - Vector2(320, 250)
	
	visible = true
	_play_bark(1.0)

func close_game() -> void:
	is_active = false
	visible = false
	_audio_player.stop()
	game_finished.emit()

func _on_quit_pressed() -> void:
	if current_state == GameState.MENU:
		close_game()
	else:
		current_state = GameState.MENU
		menu_container.visible = true
		label_score_info.text = "CHOISISSEZ UN MINI-JEU POUR COMMENCER À JOUER AVEC LE CHIEN !"
		label_status.text = "🟢 DE RETOUR AU MENU"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
		_play_bark(1.05)

func _play_bark(pitch: float) -> void:
	if _bark_sounds.is_empty():
		return
	_audio_player.stream = _bark_sounds[_rng.randi_range(0, _bark_sounds.size() - 1)]
	_audio_player.pitch_scale = pitch
	_audio_player.volume_db = -1.5
	_audio_player.play()

func _on_scope_draw() -> void:
	var w := 600.0
	var h := 290.0
	
	# Draw main screen viewport background
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.05, 1.0))
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.5, 1.0, 0.35), false, 2.0)
	
	# Draw subtle background grid
	var step_x := 30.0
	var step_y := 29.0
	for gx in range(0, int(w), int(step_x)):
		scope_control.draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.8, 0.5, 1.0, 0.04))
	for gy in range(0, int(h), int(step_y)):
		scope_control.draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.8, 0.5, 1.0, 0.04))

	# State-specific drawing
	if current_state == GameState.MENU:
		_draw_menu_state(w, h)
	elif current_state == GameState.MORPION:
		_draw_morpion_state(w, h)
	elif current_state == GameState.PONG:
		_draw_pong_state(w, h)

func _draw_menu_state(w: float, h: float) -> void:
	# Draw a cute symmetric arcade design
	# Smiling dog face on the left side
	_draw_dog_face(Vector2(90.0, h / 2.0), 45.0, false, false)
	# Happy wagging tail on the right side
	_draw_wagging_tail(Vector2(490.0, h / 2.0 + 35.0), 65.0, false)

func _draw_dog_face(center: Vector2, radius: float, is_crying: bool, is_happy: bool) -> void:
	# Main head shape
	scope_control.draw_circle(center, radius, Color(0.14, 0.08, 0.25, 0.8)) # deep filled
	scope_control.draw_circle(center, radius, Color(0.8, 0.5, 1.0, 0.9), false, 2.5) # glowing neon border
	
	# Ears (pill-shaped capsules on left and right sides)
	var ear_w := radius * 0.4
	var ear_h := radius * 0.95
	var left_ear_rect := Rect2(center.x - radius - ear_w * 0.6, center.y - radius * 0.4, ear_w, ear_h)
	var right_ear_rect := Rect2(center.x + radius - ear_w * 0.4, center.y - radius * 0.4, ear_w, ear_h)
	
	scope_control.draw_rect(left_ear_rect, Color(0.14, 0.08, 0.25, 0.85), true, -1.0)
	scope_control.draw_rect(left_ear_rect, Color(0.8, 0.5, 1.0, 0.9), false, 2.0)
	scope_control.draw_rect(right_ear_rect, Color(0.14, 0.08, 0.25, 0.85), true, -1.0)
	scope_control.draw_rect(right_ear_rect, Color(0.8, 0.5, 1.0, 0.9), false, 2.0)
	
	# Snout/Muzzle
	var snout_center := center + Vector2(0, radius * 0.3)
	var snout_r := radius * 0.42
	scope_control.draw_circle(snout_center, snout_r, Color(0.18, 0.12, 0.32, 0.9))
	scope_control.draw_circle(snout_center, snout_r, Color(0.8, 0.5, 1.0, 0.5), false, 1.5)
	
	# Cute cyan nose
	var nose_center := snout_center + Vector2(0, -snout_r * 0.3)
	scope_control.draw_circle(nose_center, snout_r * 0.35, Color(0.24, 0.95, 0.79, 1.0))
	
	# Smiling mouth lines
	var mouth_y := snout_center.y + snout_r * 0.2
	scope_control.draw_line(snout_center + Vector2(0, -2), Vector2(snout_center.x, mouth_y), Color(0.24, 0.95, 0.79, 1.0), 2.0)
	scope_control.draw_arc(snout_center + Vector2(-snout_r * 0.3, mouth_y), snout_r * 0.3, 0.0, PI, 10, Color(0.24, 0.95, 0.79, 1.0), 2.0)
	scope_control.draw_arc(snout_center + Vector2(snout_r * 0.3, mouth_y), snout_r * 0.3, 0.0, PI, 10, Color(0.24, 0.95, 0.79, 1.0), 2.0)
	
	# Eyes
	var eye_offset_x := radius * 0.35
	var eye_offset_y := -radius * 0.2
	var eye_l := center + Vector2(-eye_offset_x, eye_offset_y)
	var eye_r := center + Vector2(eye_offset_x, eye_offset_y)
	
	if is_crying:
		# Crying closed arcs
		scope_control.draw_arc(eye_l, 6.0, PI, TAU, 8, Color(0.24, 0.95, 0.79, 1.0), 2.5)
		scope_control.draw_arc(eye_r, 6.0, PI, TAU, 8, Color(0.24, 0.95, 0.79, 1.0), 2.5)
		
		# dripping teardrops
		var tear_flow := fmod(animation_time * 65.0, 30.0)
		var tear_l_pos := eye_l + Vector2(0, 4.0 + tear_flow)
		var tear_r_pos := eye_r + Vector2(0, 4.0 + tear_flow)
		
		scope_control.draw_circle(tear_l_pos, 3.5, Color(0.2, 0.6, 1.0, 0.85))
		scope_control.draw_circle(tear_r_pos, 3.5, Color(0.2, 0.6, 1.0, 0.85))
	elif is_happy:
		# Happy winking arcs
		scope_control.draw_arc(eye_l, 6.0, 0.0, PI, 8, Color(0.24, 0.95, 0.79, 1.0), 3.0)
		scope_control.draw_arc(eye_r, 6.0, 0.0, PI, 8, Color(0.24, 0.95, 0.79, 1.0), 3.0)
	else:
		# Large shining cyber eyes
		scope_control.draw_circle(eye_l, 8.0, Color(0.24, 0.95, 0.79, 1.0))
		scope_control.draw_circle(eye_r, 8.0, Color(0.24, 0.95, 0.79, 1.0))
		# Highlights
		scope_control.draw_circle(eye_l + Vector2(2, -2), 3.0, Color.WHITE)
		scope_control.draw_circle(eye_r + Vector2(2, -2), 3.0, Color.WHITE)

func _draw_wagging_tail(tail_base: Vector2, tail_length: float, is_super_fast: bool) -> void:
	# Base point anchor
	scope_control.draw_circle(tail_base, 8.0, Color(0.14, 0.08, 0.25, 0.8))
	scope_control.draw_circle(tail_base, 8.0, Color(0.8, 0.5, 1.0, 0.8), false, 2.0)
	
	# Multiline segmented waving curve to represent realistic dog tail wagging
	var segments := 8
	var points := PackedVector2Array()
	points.append(tail_base)
	
	var base_angle := -45.0
	var sway_amp := 38.0 if is_super_fast else 22.0
	var speed_mult := 26.0 if is_super_fast else 14.0
	
	for i in range(1, segments + 1):
		var ratio := float(i) / segments
		var wave_offset := sin(animation_time * speed_mult - ratio * 2.0) * sway_amp * ratio
		var angle_rad := deg_to_rad(base_angle + wave_offset)
		var seg_pos := tail_base + Vector2(cos(angle_rad), sin(angle_rad)) * (tail_length * ratio)
		points.append(seg_pos)
		
	# Draw glowing outer path
	scope_control.draw_polyline(points, Color(0.8, 0.5, 1.0, 0.3), 14.0, true)
	# Draw inner main tail line
	scope_control.draw_polyline(points, Color(0.8, 0.5, 1.0, 0.95), 5.0, true)
	
	# Fluffy white puff at tail tip
	var tip_pos := points[points.size() - 1]
	scope_control.draw_circle(tip_pos, 9.0, Color(0.24, 0.95, 0.79, 1.0))
	scope_control.draw_circle(tip_pos, 6.0, Color.WHITE)

# ----------------- MORPION CANIN (TIC-TAC-TOE) LOGIC -----------------

func _on_play_morpion_pressed() -> void:
	current_state = GameState.MORPION
	menu_container.visible = false
	morpion_grid = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	is_player_turn = true
	is_morpion_game_over = false
	morpion_winner = 0
	is_morpion_ai_thinking = false
	label_score_info.text = "CLIQUEZ SUR LE PLATEAU POUR POSER VOTRE BALLE 🎾 !"
	label_status.text = "🟢 À VOTUS DE JOUER !"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	_play_bark(1.22)

func _draw_morpion_state(w: float, h: float) -> void:
	var start_x := 180.0
	var start_y := 25.0
	var size := 240.0
	var step := 80.0

	# 3x3 outer boundary Box
	scope_control.draw_rect(Rect2(start_x, start_y, size, size), Color(0.8, 0.5, 1.0, 0.25), false, 2.0)
	
	# Grid Lines
	scope_control.draw_line(Vector2(start_x + step, start_y), Vector2(start_x + step, start_y + size), Color(0.8, 0.5, 1.0, 0.6), 2.0)
	scope_control.draw_line(Vector2(start_x + step * 2, start_y), Vector2(start_x + step * 2, start_y + size), Color(0.8, 0.5, 1.0, 0.6), 2.0)
	scope_control.draw_line(Vector2(start_x, start_y + step), Vector2(start_x + size, start_y + step), Color(0.8, 0.5, 1.0, 0.6), 2.0)
	scope_control.draw_line(Vector2(start_x, start_y + step * 2), Vector2(start_x + size, start_y + step * 2), Color(0.8, 0.5, 1.0, 0.6), 2.0)

	# Transparent green preview for hover position
	if not is_morpion_game_over and is_player_turn and not is_morpion_ai_thinking and morpion_hovered_cell != -1:
		if morpion_grid[morpion_hovered_cell] == 0:
			var gx := morpion_hovered_cell % 3
			var gy := morpion_hovered_cell / 3
			var cell_center := Vector2(start_x + gx * step + step / 2.0, start_y + gy * step + step / 2.0)
			scope_control.draw_circle(cell_center, 22.0, Color(0.24, 0.95, 0.79, 0.25))
			scope_control.draw_circle(cell_center, 22.0, Color(0.24, 0.95, 0.79, 0.4), false, 1.5)

	# Render Cells Content
	for i in range(9):
		var gx := i % 3
		var gy := i / 3
		var cell_center := Vector2(start_x + gx * step + step / 2.0, start_y + gy * step + step / 2.0)
		var cell_val := morpion_grid[i]
		
		if cell_val == 1: # Player Tennis Ball 🎾
			# Neon-green tennis ball
			scope_control.draw_circle(cell_center, 22.0, Color(0.24, 0.95, 0.79, 1.0))
			scope_control.draw_circle(cell_center, 22.0, Color(0.9, 1.0, 0.9, 0.8), false, 2.0)
			# Tennis ball seams
			scope_control.draw_arc(cell_center + Vector2(-22.0, 0), 22.0, -PI/3.0, PI/3.0, 8, Color(0.95, 0.95, 0.7, 0.75), 1.8)
			scope_control.draw_arc(cell_center + Vector2(22.0, 0), 22.0, PI - PI/3.0, PI + PI/3.0, 8, Color(0.95, 0.95, 0.7, 0.75), 1.8)
			
		elif cell_val == 2: # Dog Bone 🦴
			var angle := PI / 4.0
			var bone_len := 17.0
			var offset_vec := Vector2(cos(angle), sin(angle)) * bone_len
			var pt1 := cell_center - offset_vec
			var pt2 := cell_center + offset_vec
			
			# Glow behind bone
			scope_control.draw_line(pt1, pt2, Color(1.0, 1.0, 1.0, 0.35), 12.0)
			# Main white shaft
			scope_control.draw_line(pt1, pt2, Color.WHITE, 5.0)
			# Double ball heads on end points
			var perp := Vector2(-sin(angle), cos(angle)) * 5.0
			scope_control.draw_circle(pt1 + perp, 6.0, Color.WHITE)
			scope_control.draw_circle(pt1 - perp, 6.0, Color.WHITE)
			scope_control.draw_circle(pt2 + perp, 6.0, Color.WHITE)
			scope_control.draw_circle(pt2 - perp, 6.0, Color.WHITE)

	# Left dog head emotional states
	var face_pos := Vector2(90.0, h / 2.0)
	if is_morpion_game_over:
		if morpion_winner == 1:
			_draw_dog_face(face_pos, 40.0, true, false) # Dog cries!
		elif morpion_winner == 2:
			_draw_dog_face(face_pos, 40.0, false, true) # Dog winks happily!
		else:
			_draw_dog_face(face_pos, 40.0, false, false) # Normal
	else:
		_draw_dog_face(face_pos, 40.0, false, is_morpion_ai_thinking)

	# Right dog tail wags
	var tail_pos := Vector2(490.0, h / 2.0 + 30.0)
	var is_super_fast := is_morpion_game_over and morpion_winner == 2
	_draw_wagging_tail(tail_pos, 55.0, is_super_fast)

func _handle_morpion_click(mpos: Vector2) -> void:
	if is_morpion_game_over or not is_player_turn or is_morpion_ai_thinking:
		return
		
	var start_x := 180.0
	var start_y := 25.0
	var step := 80.0
	
	if mpos.x >= start_x and mpos.x < start_x + 240.0 and mpos.y >= start_y and mpos.y < start_y + 240.0:
		var gx := int((mpos.x - start_x) / step)
		var gy := int((mpos.y - start_y) / step)
		var idx := gy * 3 + gx
		
		if morpion_grid[idx] == 0:
			morpion_grid[idx] = 1 # Place tennis ball
			_play_bark(1.35)
			_check_morpion_game_state()
			
			if not is_morpion_game_over:
				is_player_turn = false
				is_morpion_ai_thinking = true
				morpion_ai_timer = 0.7
				label_score_info.text = "🐾 LE CHIEN FLAIRE LE PLATEAU..."
				label_status.text = "🟡 AU CHIEN DE JOUER"
				label_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))

func _make_morpion_dog_move() -> void:
	is_morpion_ai_thinking = false
	is_player_turn = true
	
	var chosen_cell := -1
	
	# 1. Attaque: Le chien peut-il gagner ce tour ?
	chosen_cell = _find_morpion_winning_cell(2)
	
	# 2. Défense: Le chien doit-il bloquer le joueur ?
	if chosen_cell == -1:
		chosen_cell = _find_morpion_winning_cell(1)
		
	# 3. Prendre le centre
	if chosen_cell == -1 and morpion_grid[4] == 0:
		chosen_cell = 4
		
	# 4. Prendre un coin au hasard
	if chosen_cell == -1:
		var corners: Array[int] = [0, 2, 6, 8]
		corners.shuffle()
		for c in corners:
			if morpion_grid[c] == 0:
				chosen_cell = c
				break
				
	# 5. Prendre une case libre aléatoire
	if chosen_cell == -1:
		var free_cells: Array[int] = []
		for i in range(9):
			if morpion_grid[i] == 0:
				free_cells.append(i)
		if not free_cells.is_empty():
			chosen_cell = free_cells[_rng.randi_range(0, free_cells.size() - 1)]
			
	if chosen_cell != -1:
		morpion_grid[chosen_cell] = 2 # Place dog bone
		_play_bark(0.95)
		
	_check_morpion_game_state()
	if not is_morpion_game_over:
		label_score_info.text = "À VOUS ! POSITIONNEZ LA BALLE 🎾 !"
		label_status.text = "🟢 À VOUS DE JOUER !"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))

func _find_morpion_winning_cell(side: int) -> int:
	var wins: Array[Array] = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8], # lines
		[0, 3, 6], [1, 4, 7], [2, 5, 8], # cols
		[0, 4, 8], [2, 4, 6]             # diags
	]
	for combo in wins:
		var c0: int = combo[0]
		var c1: int = combo[1]
		var c2: int = combo[2]
		
		var grid_c0: int = morpion_grid[c0]
		var grid_c1: int = morpion_grid[c1]
		var grid_c2: int = morpion_grid[c2]
		
		if grid_c0 == side and grid_c1 == side and grid_c2 == 0:
			return c2
		if grid_c0 == side and grid_c2 == side and grid_c1 == 0:
			return c1
		if grid_c1 == side and grid_c2 == side and grid_c0 == 0:
			return c0
	return -1

func _check_morpion_game_state() -> void:
	var wins: Array[Array] = [
		[0, 1, 2], [3, 4, 5], [6, 7, 8],
		[0, 3, 6], [1, 4, 7], [2, 5, 8],
		[0, 4, 8], [2, 4, 6]
	]
	for combo in wins:
		var c0: int = combo[0]
		var c1: int = combo[1]
		var c2: int = combo[2]
		
		var grid_c0: int = morpion_grid[c0]
		var grid_c1: int = morpion_grid[c1]
		var grid_c2: int = morpion_grid[c2]
		
		if grid_c0 != 0 and grid_c0 == grid_c1 and grid_c0 == grid_c2:
			is_morpion_game_over = true
			morpion_winner = grid_c0
			_announce_morpion_winner()
			return
			
	# Tie verification
	if not morpion_grid.has(0):
		is_morpion_game_over = true
		morpion_winner = 0
		_announce_morpion_winner()

func _announce_morpion_winner() -> void:
	if morpion_winner == 1:
		label_score_info.text = "🏆 VICTOIRE ! LE CHIEN EST ÉTOURDI ! (Cliquez pour relancer)"
		label_status.text = "✨ VOUS AVEZ BATTU LE CHIEN AU MORPION ! ✨"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
		_play_bark(1.6)
		# Trigger parent's era particles
		var parent := get_parent()
		if parent and parent.has_method("declencher_particles_victoire"):
			parent.call("declencher_particles_victoire")
	elif morpion_winner == 2:
		label_score_info.text = "🐶 LE CHIEN GAGNE ! IL FAIT LA FÊTE ! (Cliquez pour relancer)"
		label_status.text = "💥 LE CHIEN A REMPORTÉ LE MORPION DES OS !"
		label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
		_play_bark(0.55)
	else:
		label_score_info.text = "🤝 MATCH NUL ! QUEL COMBAT D'ESPRIT ! (Cliquez pour relancer)"
		label_status.text = "⚪ ÉGALITÉ !"
		label_status.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1.0))
		_play_bark(1.0)

# ----------------- CHIEN-PONG LOGIC -----------------

func _on_play_pong_pressed() -> void:
	current_state = GameState.PONG
	menu_container.visible = false
	player_score = 0
	dog_score = 0
	is_pong_game_over = false
	pong_winner = 0
	pong_particles.clear()
	_reset_pong_ball(1.0)
	_play_bark(1.1)

func _reset_pong_ball(dir_val: float) -> void:
	ball_pos = Vector2(300.0, 145.0)
	ball_speed_multiplier = 1.0
	var angle := _rng.randf_range(-0.35, 0.35)
	ball_vel = Vector2(dir_val * base_ball_speed, sin(angle) * base_ball_speed)
	p_paddle_y = 145.0
	d_paddle_y = 145.0
	
	if not is_pong_game_over:
		label_score_info.text = "SCORE - VOUS: " + str(player_score) + " | CHIEN: " + str(dog_score)
		label_status.text = "🟢 TENEZ BON ! BATTEZ SA QUEUE-RAQUETTE !"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))

func _process_pong(delta: float) -> void:
	# 1. Keyboard movements for player
	if Input.is_action_pressed("marche_bas"):
		p_paddle_y = clampf(p_paddle_y + 320.0 * delta, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
	elif Input.is_action_pressed("marche_haut"):
		p_paddle_y = clampf(p_paddle_y - 320.0 * delta, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
		
	# 2. Dog tail AI tracking vertical limiter
	var dog_ai_speed := 185.0 + (float(player_score) * 15.0) + (ball_speed_multiplier * 28.0)
	d_paddle_y = move_toward(d_paddle_y, ball_pos.y, dog_ai_speed * delta)
	d_paddle_y = clampf(d_paddle_y, paddle_h / 2.0, 290.0 - paddle_h / 2.0)
	
	# 3. Ball translations
	ball_pos += ball_vel * ball_speed_multiplier * delta
	
	# 4. Ceiling & Floor bounces
	if ball_pos.y <= ball_radius:
		ball_pos.y = ball_radius
		ball_vel.y = -ball_vel.y
		_add_pong_particles(ball_pos, Color(0.8, 0.5, 1.0, 0.8))
	elif ball_pos.y >= 290.0 - ball_radius:
		ball_pos.y = 290.0 - ball_radius
		ball_vel.y = -ball_vel.y
		_add_pong_particles(ball_pos, Color(0.8, 0.5, 1.0, 0.8))
		
	# 5. Collision checks
	# Left Paddle (Player - Cyan)
	if ball_pos.x - ball_radius <= 33.0 and ball_pos.x + ball_radius >= 25.0:
		if ball_pos.y >= p_paddle_y - paddle_h / 2.0 and ball_pos.y <= p_paddle_y + paddle_h / 2.0:
			ball_pos.x = 33.0 + ball_radius
			ball_vel.x = -ball_vel.x
			# Adjust bounce angle based on hit location
			var offset := (ball_pos.y - p_paddle_y) / (paddle_h / 2.0)
			ball_vel.y = offset * base_ball_speed * 0.95
			ball_speed_multiplier = minf(2.6, ball_speed_multiplier + 0.08)
			_play_bark(_rng.randf_range(1.22, 1.45))
			_add_pong_particles(ball_pos, Color(0.24, 0.95, 0.79, 1.0))
			
	# Right Paddle (Dog Tail - Pink/Purple)
	if ball_pos.x + ball_radius >= 567.0 and ball_pos.x - ball_radius <= 575.0:
		if ball_pos.y >= d_paddle_y - paddle_h / 2.0 and ball_pos.y <= d_paddle_y + paddle_h / 2.0:
			ball_pos.x = 567.0 - ball_radius
			ball_vel.x = -ball_vel.x
			# Adjust bounce angle based on hit location
			var offset := (ball_pos.y - d_paddle_y) / (paddle_h / 2.0)
			ball_vel.y = offset * base_ball_speed * 0.95
			ball_speed_multiplier = minf(2.6, ball_speed_multiplier + 0.08)
			_play_bark(_rng.randf_range(0.85, 1.05))
			_add_pong_particles(ball_pos, Color(0.8, 0.5, 1.0, 1.0))
			
	# Goal verification
	if ball_pos.x < 0.0:
		# Dog scores!
		dog_score += 1
		_check_pong_score(1.0)
	elif ball_pos.x > 600.0:
		# Player scores!
		player_score += 1
		var parent := get_parent()
		if parent and parent.has_method("declencher_particles_victoire"):
			parent.call("declencher_particles_victoire")
		_check_pong_score(-1.0)

	# Process procedural particles
	var p_idx := pong_particles.size() - 1
	while p_idx >= 0:
		var part := pong_particles[p_idx]
		part.pos += part.vel * delta
		part.life -= delta
		if part.life <= 0.0:
			pong_particles.remove_at(p_idx)
		p_idx -= 1

func _check_pong_score(next_dir: float) -> void:
	if player_score >= 5:
		is_pong_game_over = true
		pong_winner = 1
		label_score_info.text = "🏆 VICTOIRE PONG ! SCORE FINAL: " + str(player_score) + " - " + str(dog_score) + " (Cliquez pour rejouer)"
		label_status.text = "✨ VOUS AVEZ REMPORTÉ LE CHIEN-PONG ! ✨"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
		_play_bark(1.6)
	elif dog_score >= 5:
		is_pong_game_over = true
		pong_winner = 2
		label_score_info.text = "🐶 LE CHIEN GAGNE ! SCORE FINAL: " + str(player_score) + " - " + str(dog_score) + " (Cliquez pour rejouer)"
		label_status.text = "💥 LE CHIEN A GAGNÉ LE COMBAT DE RAQUETTES !"
		label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
		_play_bark(0.55)
	else:
		_reset_pong_ball(next_dir)

func _add_pong_particles(pos: Vector2, color: Color) -> void:
	for k in range(12):
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(70.0, 190.0)
		var part := {
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": _rng.randf_range(0.3, 0.6),
			"max_life": 0.6,
			"color": color,
			"size": _rng.randf_range(2.0, 4.5)
		}
		pong_particles.append(part)

func _draw_pong_state(w: float, h: float) -> void:
	# Draw center dotted divider
	var dot_y := 8.0
	while dot_y < h:
		scope_control.draw_rect(Rect2(w / 2.0 - 2.0, dot_y, 4.0, 10.0), Color(0.8, 0.5, 1.0, 0.16))
		dot_y += 20.0
		
	# Draw player paddle (Cyan)
	scope_control.draw_rect(Rect2(25.0, p_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.24, 0.95, 0.79, 1.0))
	scope_control.draw_rect(Rect2(25.0, p_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.24, 0.95, 0.79, 0.35), false, 1.5)
	
	# Draw dog paddle (Pink/purple)
	scope_control.draw_rect(Rect2(575.0 - paddle_w, d_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.8, 0.5, 1.0, 1.0))
	scope_control.draw_rect(Rect2(575.0 - paddle_w, d_paddle_y - paddle_h / 2.0, paddle_w, paddle_h), Color(0.8, 0.5, 1.0, 0.35), false, 1.5)
	
	# Draw tail movement indicator lines next to dog paddle!
	var tail_line_x := 585.0
	var tail_sway := sin(animation_time * 24.0) * 10.0
	scope_control.draw_line(Vector2(tail_line_x, d_paddle_y - 12), Vector2(tail_line_x + 8.0, d_paddle_y - 12 + tail_sway), Color(0.8, 0.5, 1.0, 0.65), 1.8)
	scope_control.draw_line(Vector2(tail_line_x, d_paddle_y + 12), Vector2(tail_line_x + 8.0, d_paddle_y + 12 - tail_sway), Color(0.8, 0.5, 1.0, 0.65), 1.8)

	# Draw giant background score digits
	# Left Score
	var score_color := Color(0.8, 0.5, 1.0, 0.08)
	_draw_giant_digit(Vector2(w / 4.0, h / 2.0), player_score, score_color)
	# Right Score
	_draw_giant_digit(Vector2(3.0 * w / 4.0, h / 2.0), dog_score, score_color)

	# Draw Ball
	if not is_pong_game_over:
		scope_control.draw_circle(ball_pos, ball_radius, Color(0.24, 0.95, 0.79, 1.0))
		scope_control.draw_circle(ball_pos, ball_radius + 4.0, Color(0.24, 0.95, 0.79, 0.35), false, 1.5)
		
	# Draw particles
	for part in pong_particles:
		var alpha: float = part.life / part.max_life
		var c: Color = part.color
		scope_control.draw_circle(part.pos, part.size, Color(c.r, c.g, c.b, alpha))

	# Game Over elements
	if is_pong_game_over:
		# Draw smiling or crying dog head
		var face_pos := Vector2(90.0, h / 2.0)
		if pong_winner == 1:
			_draw_dog_face(face_pos, 40.0, true, false) # Crying
		else:
			_draw_dog_face(face_pos, 40.0, false, true) # Happy
		
		# Draw happy tail on the right
		var tail_pos := Vector2(490.0, h / 2.0 + 30.0)
		_draw_wagging_tail(tail_pos, 55.0, pong_winner == 2)

func _draw_giant_digit(center: Vector2, digit: int, color: Color) -> void:
	# Draw basic robust block-style digital digits using lines
	var size := Vector2(40.0, 70.0)
	var half_w := size.x / 2.0
	var half_h := size.y / 2.0
	
	# Vertices: top-left, top-right, bottom-right, bottom-left
	var tl := center + Vector2(-half_w, -half_h)
	var tr := center + Vector2(half_w, -half_h)
	var br := center + Vector2(half_w, half_h)
	var bl := center + Vector2(-half_w, half_h)
	var ml := center + Vector2(-half_w, 0.0)
	var mr := center + Vector2(half_w, 0.0)
	
	# Segment states for digits 0 to 9
	var segments := []
	match digit:
		0: segments = [ [tl, tr], [tr, br], [br, bl], [bl, tl] ]
		1: segments = [ [tr, br] ]
		2: segments = [ [tl, tr], [tr, mr], [mr, ml], [ml, bl], [bl, br] ]
		3: segments = [ [tl, tr], [tr, br], [br, bl], [ml, mr] ]
		4: segments = [ [tl, ml], [ml, mr], [tr, br] ]
		5: segments = [ [tr, tl], [tl, ml], [ml, mr], [mr, br], [br, bl] ]
		6: segments = [ [tr, tl], [tl, bl], [bl, br], [br, mr], [mr, ml] ]
		7: segments = [ [tl, tr], [tr, br] ]
		8: segments = [ [tl, tr], [tr, br], [br, bl], [bl, tl], [ml, mr] ]
		9: segments = [ [ml, tl], [tl, tr], [tr, br], [br, bl], [ml, mr] ]
		
	for seg in segments:
		var p1: Vector2 = seg[0]
		var p2: Vector2 = seg[1]
		scope_control.draw_line(p1, p2, color, 8.0)

# ----------------- GENERAL VIEWPORT INPUTS -----------------

func _on_scope_gui_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	if current_state == GameState.MORPION:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion:
			var start_x := 180.0
			var start_y := 25.0
			var step := 80.0
			var mpos := mouse_motion.position
			if mpos.x >= start_x and mpos.x < start_x + 240.0 and mpos.y >= start_y and mpos.y < start_y + 240.0:
				var gx := int((mpos.x - start_x) / step)
				var gy := int((mpos.y - start_y) / step)
				morpion_hovered_cell = gy * 3 + gx
			else:
				morpion_hovered_cell = -1
				
		var mouse_button := event as InputEventMouseButton
		if mouse_button and mouse_button.pressed:
			if is_morpion_game_over:
				# Click to restart Morpion
				_on_play_morpion_pressed()
				get_viewport().set_input_as_handled()
			elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
				_handle_morpion_click(mouse_button.position)
				get_viewport().set_input_as_handled()

	elif current_state == GameState.PONG:
		if is_pong_game_over:
			var mouse_button := event as InputEventMouseButton
			if mouse_button and mouse_button.pressed:
				_on_play_pong_pressed()
				get_viewport().set_input_as_handled()
		else:
			var mouse_motion := event as InputEventMouseMotion
			if mouse_motion:
				p_paddle_y = clampf(mouse_motion.position.y, paddle_h / 2.0, 290.0 - paddle_h / 2.0)

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()
		get_viewport().set_input_as_handled()
		return
		
	if current_state == GameState.MORPION and is_morpion_game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_on_play_morpion_pressed()
			get_viewport().set_input_as_handled()
			
	elif current_state == GameState.PONG and is_pong_game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_on_play_pong_pressed()
			get_viewport().set_input_as_handled()
