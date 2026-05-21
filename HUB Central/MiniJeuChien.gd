extends CanvasLayer

signal game_finished

var is_active: bool = false
var best_time: float = 9999.0
var active_time: float = 0.0
var stable_time: float = 0.0
var stabilization_duration: float = 1.5 # seconds needed to win
var is_victory: bool = false

# Wave Parameters
var target_frequency: float = 0.02
var target_amplitude: float = 40.0
var player_frequency: float = 0.015
var player_amplitude: float = 30.0
var wave_phase: float = 0.0

# UI Controls
var root_control: Control
var background_panel: Panel
var scope_control: Control
var slider_freq: HSlider
var slider_amp: HSlider
var label_timer: Label
var label_best: Label
var label_status: Label
var progress_bar: ProgressBar
var btn_quit: Button

# Sound
var _audio_player: AudioStreamPlayer
var _bark_sounds: Array[AudioStream] = []
var _sound_timer: Timer
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
	
	_sound_timer = Timer.new()
	_sound_timer.one_shot = true
	_sound_timer.timeout.connect(_on_sound_timer_timeout)
	add_child(_sound_timer)

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
	root_control.anchors_preset = Control.PRESET_FULL_RECT
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
	add_child(root_control)

	background_panel = Panel.new()
	background_panel.name = "BackgroundPanel"
	background_panel.custom_minimum_size = Vector2(640, 560)
	background_panel.anchors_preset = Control.PRESET_CENTER
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	
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
	label_title.text = "📡 N.O.S.E - NEURAL OSCILLOSCOPE SIGNAL EXTRACTOR"
	label_title.position = Vector2(20, 15)
	label_title.add_theme_font_size_override("font_size", 16)
	label_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 1.0))
	background_panel.add_child(label_title)

	# Timer Label
	label_timer = Label.new()
	label_timer.text = "STABLE : 0.0s"
	label_timer.position = Vector2(480, 15)
	label_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_timer.add_theme_font_size_override("font_size", 16)
	label_timer.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	background_panel.add_child(label_timer)

	# Best Score Label
	label_best = Label.new()
	label_best.text = "BEST TIME: --"
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
	label_instr.text = "🎯 BUT : Alignez l'onde CYAN (la vôtre) sur l'onde ROUGE (cible du chien) !\n⌨️ Clavier : Q/D ou Flèches (Fréquence) • Z/S ou Flèches (Tension) | 🖱️ Souris : Glissez"
	label_instr.position = Vector2(10, 8)
	label_instr.size = Vector2(580, 34)
	label_instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_instr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_instr.add_theme_font_size_override("font_size", 12)
	label_instr.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1.0))
	panel_instr.add_child(label_instr)

	# Oscilloscope Screen
	scope_control = Control.new()
	scope_control.position = Vector2(20, 130)
	scope_control.custom_minimum_size = Vector2(600, 180)
	scope_control.draw.connect(_on_scope_draw)
	background_panel.add_child(scope_control)

	# Status Label below Screen
	label_status = Label.new()
	label_status.text = "⚠️ SIGNAL CORRUPT - ALIGN FREQUENCIES"
	label_status.position = Vector2(20, 320)
	label_status.add_theme_font_size_override("font_size", 12)
	label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
	background_panel.add_child(label_status)

	# Stabilization Progress Bar
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(20, 345)
	progress_bar.size = Vector2(600, 14)
	progress_bar.show_percentage = false
	var style_bg := StyleBoxFlat.new()
	style_bg.bg_color = Color(0.08, 0.06, 0.15, 1.0)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("background", style_bg)
	var style_fg := StyleBoxFlat.new()
	style_fg.bg_color = Color(0.24, 0.95, 0.79, 1.0)
	style_fg.corner_radius_top_left = 4
	style_fg.corner_radius_top_right = 4
	style_fg.corner_radius_bottom_left = 4
	style_fg.corner_radius_bottom_right = 4
	progress_bar.add_theme_stylebox_override("fill", style_fg)
	background_panel.add_child(progress_bar)

	# Frequency Slider Label
	var label_freq_title := Label.new()
	label_freq_title.text = "🎚️ FRÉQUENCE (PITCH / VITESSE)"
	label_freq_title.position = Vector2(20, 375)
	label_freq_title.add_theme_font_size_override("font_size", 14)
	label_freq_title.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 1.0))
	background_panel.add_child(label_freq_title)

	# Frequency Slider
	slider_freq = HSlider.new()
	slider_freq.position = Vector2(20, 400)
	slider_freq.size = Vector2(600, 20)
	slider_freq.min_value = 0.005
	slider_freq.max_value = 0.05
	slider_freq.step = 0.0001
	slider_freq.value = player_frequency
	slider_freq.focus_mode = Control.FOCUS_NONE
	slider_freq.value_changed.connect(_on_freq_changed)
	background_panel.add_child(slider_freq)

	# Amplitude/Tension Slider Label
	var label_amp_title := Label.new()
	label_amp_title.text = "⚡ TENSION (AMPLITUDE)"
	label_amp_title.position = Vector2(20, 435)
	label_amp_title.add_theme_font_size_override("font_size", 14)
	label_amp_title.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	background_panel.add_child(label_amp_title)

	# Amplitude/Tension Slider
	slider_amp = HSlider.new()
	slider_amp.position = Vector2(20, 460)
	slider_amp.size = Vector2(600, 20)
	slider_amp.min_value = 10.0
	slider_amp.max_value = 80.0
	slider_amp.step = 0.5
	slider_amp.value = player_amplitude
	slider_amp.focus_mode = Control.FOCUS_NONE
	slider_amp.value_changed.connect(_on_amp_changed)
	background_panel.add_child(slider_amp)

	# Quit Button
	btn_quit = Button.new()
	btn_quit.text = "[ ÉCHAP ] FERMER L'INTERACTION"
	btn_quit.position = Vector2(170, 505)
	btn_quit.size = Vector2(300, 36)
	btn_quit.focus_mode = Control.FOCUS_NONE
	btn_quit.pressed.connect(close_game)
	background_panel.add_child(btn_quit)

func _process(delta: float) -> void:
	if not is_active or is_victory:
		return
	
	wave_phase += delta * 12.0
	active_time += delta
	scope_control.queue_redraw()
	
	# Evaluate match
	var freq_diff := absf(player_frequency - target_frequency) / 0.05
	var amp_diff := absf(player_amplitude - target_amplitude) / 80.0
	var error := freq_diff + amp_diff
	
	if error < 0.06: # 94%+ Match
		label_status.text = "✨ SIGNAL STABLE - ALIGNEMENT OK ✨"
		label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
		stable_time += delta
		if stable_time >= stabilization_duration:
			_on_victory()
	else:
		label_status.text = "⚠️ SIGNAL BRUITÉ - ERREUR : " + str(clampi((1.0 - error) * 100.0, 0, 99)) + "%"
		label_status.add_theme_color_override("font_color", Color(1.0, 0.2, 0.4, 1.0))
		stable_time = maxf(0.0, stable_time - delta * 0.5)
	
	progress_bar.value = (stable_time / stabilization_duration) * 100.0
	label_timer.text = "STABLE: " + ("%.2f" % stable_time) + "s"

func _on_scope_draw() -> void:
	# Draw scope grid
	var w: float = scope_control.custom_minimum_size.x
	var h: float = scope_control.custom_minimum_size.y
	
	# Dark background box
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.01, 0.04, 1.0))
	scope_control.draw_rect(Rect2(0, 0, w, h), Color(0.24, 0.95, 0.79, 0.4), false, 2.0)
	
	# Grid lines
	var step_x := 30.0
	var step_y := 30.0
	for gx in range(0, int(w), int(step_x)):
		scope_control.draw_line(Vector2(gx, 0), Vector2(gx, h), Color(0.24, 0.95, 0.79, 0.08))
	for gy in range(0, int(h), int(step_y)):
		scope_control.draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.24, 0.95, 0.79, 0.08))

	# Middle lines
	scope_control.draw_line(Vector2(0, h/2.0), Vector2(w, h/2.0), Color(0.24, 0.95, 0.79, 0.2), 1.5)
	scope_control.draw_line(Vector2(w/2.0, 0), Vector2(w/2.0, h), Color(0.24, 0.95, 0.79, 0.2), 1.5)

	# Math sampling for sine wave lines
	var points_target := PackedVector2Array()
	var points_player := PackedVector2Array()
	var points_count := int(w) / 3
	points_target.resize(points_count)
	points_player.resize(points_count)
	var idx := 0
	for sx in range(0, int(w), 3):
		var rad_t := sx * target_frequency + wave_phase
		var rad_p := sx * player_frequency + wave_phase
		var sy_target := sin(rad_t) * target_amplitude + (h / 2.0)
		var sy_player := sin(rad_p) * player_amplitude + (h / 2.0)
		points_target[idx] = Vector2(sx, sy_target)
		points_player[idx] = Vector2(sx, sy_player)
		idx += 1

	scope_control.draw_polyline(points_target, Color(1.0, 0.2, 0.4, 0.6), 1.5, true)
	scope_control.draw_polyline(points_player, Color(0.24, 0.95, 0.79, 0.95), 2.5, true)

func _on_freq_changed(val: float) -> void:
	player_frequency = val

func _on_amp_changed(val: float) -> void:
	player_amplitude = val

func _on_sound_timer_timeout() -> void:
	if not is_active:
		return
	_play_bark()

func _play_bark() -> void:
	if _bark_sounds.is_empty():
		return
	
	# Determine modulation based on match closeness
	var freq_diff := absf(player_frequency - target_frequency) / 0.05
	var amp_diff := absf(player_amplitude - target_amplitude) / 80.0
	var error := freq_diff + amp_diff
	
	_audio_player.stream = _bark_sounds[_rng.randi_range(0, _bark_sounds.size() - 1)]
	
	# Real-time pitch modulation according to player frequency setting
	_audio_player.pitch_scale = lerpf(0.5, 2.5, (player_frequency - 0.005) / 0.045)
	
	# Tremolo or distortion modulation if error is high
	if error > 0.15:
		_audio_player.volume_db = -12.0
		# Apply a slight software-modulated glitch on volume if far off
		if _rng.randf() > 0.5:
			_audio_player.volume_db = -40.0
	else:
		_audio_player.volume_db = -3.0 # Clean full volume near alignment
		
	_audio_player.play()
	_sound_timer.start(_rng.randf_range(0.65, 0.85))

func _input(event: InputEvent) -> void:
	if not is_active or is_victory:
		return
	if event.is_action_pressed("ui_cancel"):
		close_game()
		get_viewport().set_input_as_handled()
		return
		
	# Keyboard adjustments support
	if event.is_action_pressed("marche_droite"):
		slider_freq.value = minf(slider_freq.max_value, slider_freq.value + 0.001)
	elif event.is_action_pressed("marche_gauche"):
		slider_freq.value = maxf(slider_freq.min_value, slider_freq.value - 0.001)
	elif event.is_action_pressed("marche_haut"):
		slider_amp.value = minf(slider_amp.max_value, slider_amp.value + 3.0)
	elif event.is_action_pressed("marche_bas"):
		slider_amp.value = maxf(slider_amp.min_value, slider_amp.value - 3.0)

func open_game() -> void:
	is_active = true
	is_victory = false
	active_time = 0.0
	stable_time = 0.0
	progress_bar.value = 0.0
	
	# Randomize new target signals
	target_frequency = _rng.randf_range(0.015, 0.045)
	target_amplitude = _rng.randf_range(20.0, 70.0)
	
	# Soft reset player positions
	player_frequency = 0.01
	player_amplitude = 15.0
	slider_freq.value = player_frequency
	slider_amp.value = player_amplitude
	
	visible = true
	_play_bark()

func close_game() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	_audio_player.stop()
	_sound_timer.stop()
	game_finished.emit()

func _on_victory() -> void:
	is_victory = true
	_audio_player.stop()
	_sound_timer.stop()
	
	if active_time < best_time:
		best_time = active_time
		label_best.text = "BEST TIME: " + ("%.2f" % best_time) + "s"
	
	# Play high pitch double victory bark
	_audio_player.pitch_scale = 1.3
	_audio_player.volume_db = 0.0
	if not _bark_sounds.is_empty():
		_audio_player.stream = _bark_sounds[0]
		_audio_player.play()
	
	label_status.text = "🏆 HARMONISATEUR STABILISÉ AVEC SUCCÈS !"
	label_status.add_theme_color_override("font_color", Color(0.24, 0.95, 0.79, 1.0))
	
	var parent_hub := get_parent()
	if parent_hub and parent_hub.has_method("declencher_particles_victoire"):
		parent_hub.declencher_particles_victoire()
	
	# Delay exit slightly to celebrate
	await get_tree().create_timer(1.8).timeout
	if is_inside_tree():
		close_game()
