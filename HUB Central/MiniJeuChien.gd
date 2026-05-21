extends CanvasLayer

signal game_finished

var is_active: bool = false
var score: int = 0
var lives: int = 3
var best_score: int = 0
var is_game_over: bool = false

# Game Variables
var paddle_x: float = 300.0
var paddle_width: float = 80.0
var paddle_height: float = 8.0
var paddle_y: float = 215.0 # Placed near the bottom of scope_control

var treats: Array[Dictionary] = []
var spawn_timer: float = 0.0
var spawn_interval: float = 1.6 # seconds between spawns
var base_speed: float = 160.0 # pixels per second
var speed_multiplier: float = 1.0

var screen_width: float = 600.0
var screen_height: float = 240.0
var flash_duration: float = 0.0

# UI Controls
var root_control: Control
var background_panel: Panel
var scope_control: Control
var label_lives: Label
var label_best: Label
var label_score: Label
var label_status: Label
var btn_quit: Button

# Game Over Overlay
var overlay_panel: Panel
var label_over_title: Label
var label_over_score: Label
var label_over_hint: Label

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
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
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
	style.bg_color = Color(0.06, 0.04, 0.11, 0.96)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.8, 0.5, 1.0, 0.8) # Purple
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	background_panel.add_theme_stylebox_override("panel", style)
	root_control.add_child(background_panel)

	# Title Bar
	var label_title := Label.new()
	label_title.text = "🎮 CHASSE AU WOUF - CYBER-CATCH TOY"
	label_title.position = Vector2(20, 15)
	label_title.add_theme_font_size_override("font_size", 16)
	label_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 1.0))
	background_panel.add_child(label_title)

	# Lives Label (hearts)
	label_lives = Label.new()
	label_lives.text = "VIES : ❤️ ❤️ ❤️"
	label_lives.position = Vector2(480, 15)
	label_lives.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_lives.add_theme_font_size_override("font_size", 16)
	label_lives.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
	background_panel.add_child(label_lives)

	# Best Score Label
	label_best = Label.new()
	label_best.text = "MEILLEUR SCORE : 0"
	label_best.position = Vector2(480, 40)
	label_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_best.add_theme_font_size_override("font_size", 12)
	label_best.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7, 1.0))
	background_panel.add_child(label_best)

	# Instruction Banner Box
	var panel_instr := Panel.new()
	panel_instr.position = Vector2(20, 70)
	panel_instr.size = Vector2(600, 50)
	var instr_style := StyleBoxFlat.new()
	instr_style.bg_color = Color(0.12, 0.08, 0.22, 0.6)
	instr_style.border_width_left = 1
	instr_style.border_width_top = 1
	instr_style.border_width_right = 1
	instr_style.border_width_bottom = 1
	instr_style.border_color = Color(0.24, 0.95, 0.79, 0.3)
	instr_style.corner_radius_top_left = 4
	instr_style.corner_radius_top_right = 4
	instr_style.corner_radius_bottom_left = 4
	instr_style.corner_radius_bottom_right = 4
	panel_instr.add_theme_stylebox_override("panel", instr_style)
	background_panel.add_child(panel_instr)

	var label_instr := Label.new()
	label_instr.text = "🎯 BUT : Déplacez le panier pour rattraper les friandises énergétiques !\n⌨️ Clavier : Q/D ou Flèches Gauche/Droite | 🖱️ Souris : Glissez"
	label_instr.position = Vector2(10, 8)
	label_instr.size = Vector2(580, 34)
	label_instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_instr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_instr.add_theme_font_size_override("font_size", 12)
	label_instr.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1.0))
	panel_instr.add_child(label_instr)

	# Play Area Screen
	scope_control = Control.new()
	scope_control.position = Vector2(20, 130)
	scope_control.custom_minimum_size = Vector2(600, 240)
	scope_control.draw.connect(_on_scope_draw)
	scope_control.gui_input.connect(_on_scope_gui_input)
	background_panel.add_child(scope_control)

	# Score Label below screen
	label_score = Label.new()
	label_score.text = "SCORE : 0"
	label_score.position = Vector2(20, 385)
	label_score.add_theme_font_size_override("font_size", 16)
	label_score.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	background_panel.add_child(label_score)

	# Status Label below Screen
	label_status = Label.new()
	label_status.text = "🟢 TRANSMISSION STABLE - READY"
	label_status.position = Vector2(240, 385)
	label_status.add_theme_font_size_override("font_size", 14)
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	background_panel.add_child(label_status)

	# Quit Button
	btn_quit = Button.new()
	btn_quit.text = "[ ÉCHAP ] FERMER L'INTERACTION"
	btn_quit.position = Vector2(170, 440)
	btn_quit.size = Vector2(300, 36)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.pressed.connect(close_game)
	background_panel.add_child(btn_quit)

	# Setup Game Over Overlay Panel (Hidden initially)
	overlay_panel = Panel.new()
	overlay_panel.size = Vector2(600, 240)
	var style_over := StyleBoxFlat.new()
	style_over.bg_color = Color(0.04, 0.02, 0.08, 0.92)
	style_over.border_width_left = 2
	style_over.border_width_top = 2
	style_over.border_width_right = 2
	style_over.border_width_bottom = 2
	style_over.border_color = Color(1.0, 0.2, 0.4, 0.8)
	style_over.corner_radius_top_left = 6
	style_over.corner_radius_top_right = 6
	style_over.corner_radius_bottom_left = 6
	style_over.corner_radius_bottom_right = 6
	overlay_panel.add_theme_stylebox_override("panel", style_over)
	overlay_panel.visible = false
	scope_control.add_child(overlay_panel)

	label_over_title = Label.new()
	label_over_title.text = "❌ TRANSMISSION INTERROMPUE"
	label_over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_over_title.size = Vector2(600, 40)
	label_over_title.position = Vector2(0, 50)
	label_over_title.add_theme_font_size_override("font_size", 22)
	label_over_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
	overlay_panel.add_child(label_over_title)

	label_over_score = Label.new()
	label_over_score.text = "Friandises attrapées : 0 (Score: 0)"
	label_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_over_score.size = Vector2(600, 30)
	label_over_score.position = Vector2(0, 100)
	label_over_score.add_theme_font_size_override("font_size", 14)
	label_over_score.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0, 1.0))
	overlay_panel.add_child(label_over_score)

	label_over_hint = Label.new()
	label_over_hint.text = "Appuyez sur [ ESPACE ] pour rejouer\nou [ ÉCHAP ] pour quitter"
	label_over_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_over_hint.size = Vector2(600, 40)
	label_over_hint.position = Vector2(0, 150)
	label_over_hint.add_theme_font_size_override("font_size", 13)
	label_over_hint.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	overlay_panel.add_child(label_over_hint)

func _process(delta: float) -> void:
	if not is_active or is_game_over:
		return

	# Handle visual red hit flash fade
	if flash_duration > 0.0:
		flash_duration = maxf(0.0, flash_duration - delta)

	# Keyboard smooth continuous movement
	if Input.is_action_pressed("marche_droite"):
		paddle_x = clampf(paddle_x + 450.0 * delta, paddle_width / 2.0, screen_width - paddle_width / 2.0)
	elif Input.is_action_pressed("marche_gauche"):
		paddle_x = clampf(paddle_x - 450.0 * delta, paddle_width / 2.0, screen_width - paddle_width / 2.0)

	# Dynamic difficulty / speed scaling
	speed_multiplier = 1.0 + (float(score) / 120.0)

	# Spawn Treats
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_treat()
		spawn_timer = spawn_interval / speed_multiplier

	# Update Treats Position & Collisions
	var i := treats.size() - 1
	while i >= 0:
		var treat: Dictionary = treats[i]
		treat.pos.y += treat.speed * speed_multiplier * delta

		# Check paddle collision (Catch)
		if treat.pos.y >= (paddle_y - 8.0) and treat.pos.y <= (paddle_y + 8.0):
			if treat.pos.x >= (paddle_x - paddle_width / 2.0) and treat.pos.x <= (paddle_x + paddle_width / 2.0):
				_on_catch_treat(i)
				i -= 1
				continue

		# Check floor collision (Miss)
		if treat.pos.y > screen_height:
			_on_miss_treat(i)
		
		i -= 1

	scope_control.queue_redraw()

func _spawn_treat() -> void:
	var treat := {
		"pos": Vector2(_rng.randf_range(30.0, screen_width - 30.0), -15.0),
		"speed": _rng.randf_range(base_speed * 0.9, base_speed * 1.25),
		"radius": 8.0,
		"color": Color(0.24, 0.95, 0.79, 1.0) if _rng.randf() > 0.35 else Color(1.0, 0.75, 0.2, 1.0)
	}
	treats.append(treat)

func _on_catch_treat(index: int) -> void:
	treats.remove_at(index)
	score += 10
	label_score.text = "SCORE : " + str(score)
	
	# Happy high pitch bark
	_play_happy_bark()

	# Emit victory particles from the dog!
	var parent_hub := get_parent()
	if parent_hub and parent_hub.has_method("declencher_particles_victoire"):
		parent_hub.call("declencher_particles_victoire")

	label_status.text = "🎯 CAPTURE ! +10 PTS"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))

func _on_miss_treat(index: int) -> void:
	treats.remove_at(index)
	lives -= 1
	flash_duration = 0.22
	
	# Update hearts text representation
	var hearts := ""
	for h in range(3):
		if h < lives:
			hearts += "❤️ "
		else:
			hearts += "💔 "
	label_lives.text = "VIES : " + hearts

	# Glitch low bark sound
	_play_miss_sound()

	label_status.text = "💥 RATÉ ! ATTENTION !"
	label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))

	if lives <= 0:
		_on_game_over()

func _on_game_over() -> void:
	is_game_over = true
	_audio_player.stop()
	treats.clear()
	
	# Save high score
	if score > best_score:
		best_score = score
		label_best.text = "MEILLEUR SCORE : " + str(best_score)

	# Play low pitch tragic bark sequence
	_audio_player.pitch_scale = 0.55
	_audio_player.volume_db = 0.0
	if not _bark_sounds.is_empty():
		_audio_player.stream = _bark_sounds[0]
		_audio_player.play()

	label_over_score.text = "Friandises attrapées : " + str(score / 10) + " (Score Final: " + str(score) + ")"
	overlay_panel.visible = true

func _on_scope_gui_input(event: InputEvent) -> void:
	if not is_active or is_game_over:
		return
	if event is InputEventMouseMotion:
		paddle_x = clampf(event.position.x, paddle_width / 2.0, screen_width - paddle_width / 2.0)

func _on_scope_draw() -> void:
	# Draw play screen background box
	var w: float = screen_width
	var h: float = screen_height
	
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.04, 1.0))
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.5, 1.0, 0.35), false, 2.0)
	
	# Grid Lines
	var step_x := 30.0
	var step_y := 30.0
	for gx in range(0, int(w), int(step_x)):
		scope_control.draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.8, 0.5, 1.0, 0.04))
	for gy in range(0, int(h), int(step_y)):
		scope_control.draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.8, 0.5, 1.0, 0.04))

	# Catch paddle drawing (neon glowing cyan line)
	var paddle_left := paddle_x - paddle_width / 2.0
	var paddle_right := paddle_x + paddle_width / 2.0
	
	# Glowing under shadow
	scope_control.draw_line(Vector2(paddle_left, paddle_y), Vector2(paddle_right, paddle_y), Color(0.24, 0.95, 0.79, 0.3), 10.0)
	# Solid front bar
	scope_control.draw_line(Vector2(paddle_left, paddle_y), Vector2(paddle_right, paddle_y), Color(0.24, 0.95, 0.79, 1.0), 4.0)

	# Drawing falling treats
	for treat in treats:
		var pos: Vector2 = treat.pos
		var radius: float = treat.radius
		var color: Color = treat.color

		# Inner solid circle
		scope_control.draw_circle(pos, radius, color)
		# Outer target ring
		scope_control.draw_arc(pos, radius + 5.0, 0.0, TAU, 16, Color(color, 0.45), 1.5)

	# Screen damage flash
	if flash_duration > 0.0:
		scope_control.draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.1, 0.2, 0.26 * (flash_duration / 0.22)))

func _play_happy_bark() -> void:
	if _bark_sounds.is_empty():
		return
	_audio_player.stream = _bark_sounds[_rng.randi_range(0, _bark_sounds.size() - 1)]
	_audio_player.pitch_scale = _rng.randf_range(1.22, 1.55)
	_audio_player.volume_db = 0.0
	_audio_player.play()

func _play_miss_sound() -> void:
	if _bark_sounds.is_empty():
		return
	_audio_player.stream = _bark_sounds[0]
	_audio_player.pitch_scale = 0.65
	_audio_player.volume_db = -4.0
	_audio_player.play()

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	if event.is_action_pressed("ui_cancel"):
		close_game()
		get_viewport().set_input_as_handled()
		return
		
	if is_game_over:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			restart_game()
			get_viewport().set_input_as_handled()

func open_game() -> void:
	is_active = true
	is_game_over = false
	score = 0
	lives = 3
	speed_multiplier = 1.0
	treats.clear()
	spawn_timer = 0.5
	paddle_x = 300.0
	
	label_score.text = "SCORE : 0"
	label_lives.text = "VIES : ❤️ ❤️ ❤️"
	label_status.text = "🟢 TRANSMISSION STABLE - READY"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	
	overlay_panel.visible = false
	visible = true
	_play_happy_bark()

func restart_game() -> void:
	is_game_over = false
	score = 0
	lives = 3
	speed_multiplier = 1.0
	treats.clear()
	spawn_timer = 0.5
	paddle_x = 300.0
	
	label_score.text = "SCORE : 0"
	label_lives.text = "VIES : ❤️ ❤️ ❤️"
	label_status.text = "🟢 PARTIE RELANCÉE - C'EST PARTI !"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	
	overlay_panel.visible = false
	_play_happy_bark()

func close_game() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	_audio_player.stop()
	treats.clear()
	game_finished.emit()
