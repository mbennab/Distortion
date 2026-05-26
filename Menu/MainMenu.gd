extends CanvasLayer

const W := 1024
const H := 682

var music_list: Array[AudioStream] = []
var music: AudioStreamPlayer
var buttons: Array[Button] = []
var credits: Panel
var options_panel: Panel
var distortion: ColorRect
var fading := false

var ui: Control


func _ready() -> void:
	ui = Control.new()
	ui.size = Vector2(W, H)
	ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ui)

	print("=== MainMenu._ready() ===")
	print("ui.size: ", ui.size)
	print("ui.get_global_rect(): ", ui.get_global_rect())
	print("get_window().size: ", get_window().size)

	_setup_bg()
	_setup_dark()
	_setup_title()
	_setup_btns()
	_setup_footer()
	_setup_credits()
	_setup_options()
	_setup_distortion()
	_setup_music()
	_play_intro()


func _setup_bg() -> void:
	var tex := load("res://art/fond_menu.png") as Texture2D
	if not tex:
		return

	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Calcul de la largeur proportionnelle pour maintenir le ratio à H = 682
	var tex_w := tex.get_width()
	var tex_h := tex.get_height()
	var scaled_w := float(tex_w) * (float(H) / float(tex_h))

	# Sécurité au cas où l'image ne serait pas plus large que la fenêtre
	if scaled_w < W:
		scaled_w = float(W) * 1.5

	t.size = Vector2(scaled_w, H)
	t.position = Vector2(0, 0)
	ui.add_child(t)
	ui.move_child(t, 0)

	# Animation de balayage (pan) infinie et fluide de droite à gauche puis gauche à droite
	var pan_distance := scaled_w - W
	if pan_distance > 0:
		var tween := create_tween()
		tween.set_loops()
		# Panning de gauche à droite (l'image se déplace vers la gauche)
		tween.tween_property(t, "position:x", -pan_distance, 22.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Panning de droite à gauche (l'image se déplace vers la droite)
		tween.tween_property(t, "position:x", 0.0, 22.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_dark() -> void:
	var d := ColorRect.new()
	d.size = Vector2(W, H)
	d.color = Color(0, 0, 0, 0.55)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(d)


func _setup_title() -> void:
	var t := Label.new()
	t.text = "DISTORTION"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	t.position = Vector2(0, 70)
	t.size = Vector2(W, 60)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = Color(1, 1, 1, 0)
	t.name = "TitleLabel"
	ui.add_child(t)

	var s := Label.new()
	s.text = "- timeOnaute -"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 22)
	s.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.7))
	s.position = Vector2(0, 132)
	s.size = Vector2(W, 30)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.modulate = Color(1, 1, 1, 0)
	s.name = "SubtitleLabel"
	ui.add_child(s)


func _setup_btns() -> void:
	var vb := VBoxContainer.new()
	vb.position = Vector2(W / 2 - 130, 240)
	vb.size = Vector2(260, 0)
	vb.add_theme_constant_override("separation", 10)
	ui.add_child(vb)

	var data: Array[Dictionary] = [
		{"t": "Nouvelle Partie", "fn": _on_new_game},
		{"t": "Charger", "fn": _on_load},
		{"t": "Options", "fn": _on_options},
		{"t": "Crédits", "fn": _on_credits},
		{"t": "Quitter", "fn": _on_quit},
	]

	for d: Dictionary in data:
		var b := Button.new()
		b.text = d["t"] as String
		b.custom_minimum_size = Vector2(260, 44)

		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.12, 0.12, 0.18, 0.7)
		n.border_color = Color(0.5, 0.8, 1.0, 0.25)
		n.border_width_left = 1
		n.border_width_right = 1
		n.border_width_top = 1
		n.border_width_bottom = 1
		n.corner_radius_top_left = 4
		n.corner_radius_top_right = 4
		n.corner_radius_bottom_left = 4
		n.corner_radius_bottom_right = 4

		var h: StyleBoxFlat = n.duplicate()
		h.bg_color = Color(0.22, 0.24, 0.34, 0.85)
		h.border_color = Color(0.5, 0.8, 1.0, 0.8)

		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", h)
		b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
		b.add_theme_font_size_override("font_size", 18)

		b.pressed.connect(d["fn"] as Callable)
		b.modulate = Color(1, 1, 1, 0)
		vb.add_child(b)
		buttons.append(b)


func _setup_footer() -> void:
	var f := Label.new()
	f.text = "Une creation ISEN CIR2"
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_theme_font_size_override("font_size", 11)
	f.add_theme_color_override("font_color", Color(0.4, 0.45, 0.55, 0.5))
	f.position = Vector2(0, H - 30)
	f.size = Vector2(W, 20)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(f)


func _setup_credits() -> void:
	credits = Panel.new()
	credits.size = Vector2(600, 500)
	credits.position = Vector2(W / 2 - 300, H / 2 - 250)
	credits.hide()
	credits.mouse_filter = Control.MOUSE_FILTER_STOP

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	st.border_color = Color(0.3, 0.5, 0.8, 0.55)
	st.border_width_left = 1
	st.border_width_right = 1
	st.border_width_top = 1
	st.border_width_bottom = 1
	st.corner_radius_top_left = 12
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 12
	credits.add_theme_stylebox_override("panel", st)

	var lines := [
		"",
		"DISTORTION — timeOnaute",
		"",
		"Projet etudiant CIR2 — ISEN",
		"",
		"Jeu cree par Cloud Company",
		"Avec Mathilde, Gaston, Rimbaud,",
		"Noa, Oscar & Alix",
		"",
		"Musiques par Alexander Nakarada (CC BY 4.0)",
		"Chronos, Unsafe Roads, Space Ambience, Nightfall, Sci-Fi-Buzzkiller,",
		"NIGHTCLUB, The Foreign Tale, Adventure, Chase",
		"",
		"The Replicant par Lyra Soundtracks (CC BY 4.0)",
		"",
		"Merci d'avoir joue !",
	]

	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 16)
	vb.size = Vector2(540, 460)
	vb.add_theme_constant_override("separation", 6)
	credits.add_child(vb)

	var sizes := [0, 22, 0, 16, 0, 15, 13, 13, 0, 13, 11, 11, 0, 12, 0, 15]
	var colors := [
		Color.WHITE,
		Color(0.9, 0.95, 1.0),
		Color.WHITE,
		Color(0.6, 0.7, 0.9),
		Color.WHITE,
		Color(0.5, 0.8, 1.0),
		Color(0.7, 0.75, 0.85),
		Color(0.7, 0.75, 0.85),
		Color.WHITE,
		Color(0.4, 0.6, 0.8, 0.9),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color.WHITE,
		Color(0.4, 0.6, 0.8, 0.9),
		Color.WHITE,
		Color(0.5, 0.8, 1.0),
	]

	for i in lines.size():
		var lb := Label.new()
		lb.text = lines[i]
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if sizes[i] > 0:
			lb.add_theme_font_size_override("font_size", sizes[i])
		lb.add_theme_color_override("font_color", colors[i])
		if lines[i] == "":
			lb.custom_minimum_size = Vector2(0, 2)
		vb.add_child(lb)

	# Espace de separation propre avant le bouton
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)

	var cb := Button.new()
	cb.text = "Fermer"
	cb.custom_minimum_size = Vector2(120, 36)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.15, 0.15, 0.22, 0.8)
	bs.border_color = Color(0.4, 0.6, 0.9, 0.5)
	bs.border_width_left = 1
	bs.border_width_right = 1
	bs.border_width_top = 1
	bs.border_width_bottom = 1
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	cb.add_theme_stylebox_override("normal", bs)
	cb.add_theme_stylebox_override("hover", bs)
	cb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	cb.pressed.connect(_close_credits)
	vb.add_child(cb)

	ui.add_child(credits)


func _setup_distortion() -> void:
	distortion = ColorRect.new()
	distortion.size = Vector2(W, H)
	distortion.color = Color.BLACK
	distortion.modulate = Color(1, 1, 1, 0)
	distortion.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Menu/distortion_transition.gdshader")
	mat.set_shader_parameter("intensity", 0.0)
	mat.set_shader_parameter("speed", 5.0)
	distortion.material = mat

	ui.add_child(distortion)


func _setup_music() -> void:
	music = AudioStreamPlayer.new()
	music.bus = "Master"
	music.volume_db = -10.0
	add_child(music)

	var dir := DirAccess.open("res://audio/menu/")
	if not dir:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.get_extension() in ["mp3", "ogg", "wav"]:
			var s := load("res://audio/menu/" + f) as AudioStream
			if s:
				music_list.append(s)
		f = dir.get_next()
	dir.list_dir_end()

	if not music_list.is_empty():
		music.stream = music_list[randi() % music_list.size()]
		music.play()


func _play_intro() -> void:
	var tl := ui.get_node("TitleLabel") as Label
	var sl := ui.get_node("SubtitleLabel") as Label

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(tl, "modulate", Color(1, 1, 1, 1), 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(sl, "modulate", Color(1, 1, 1, 1), 1.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE).set_delay(0.3)

	for i in buttons.size():
		var b := buttons[i]
		var bt := create_tween()
		bt.tween_property(b, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE).set_delay(1.2 + i * 0.1)

	var ft := create_tween()
	ft.set_loops()
	ft.tween_property(tl, "position:y", 68.0, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	ft.tween_property(tl, "position:y", 72.0, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _play_outro() -> void:
	fading = true
	distortion.mouse_filter = Control.MOUSE_FILTER_STOP

	var mat := distortion.material as ShaderMaterial
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v): mat.set_shader_parameter("intensity", v), 0.0, 1.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(distortion, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_property(music, "volume_db", -40.0, 0.6)
	await tw.finished
	await get_tree().create_timer(0.3).timeout


func _on_new_game() -> void:
	if fading:
		return
	await _play_outro()
	_start_async_load("res://Main.tscn")


func _on_load() -> void:
	if fading:
		return
	if not FileAccess.file_exists("user://save_game.json"):
		_show_stub("Aucune sauvegarde trouvee")
		return

	DialogueSystem.should_load_save = true
	fading = true
	await _play_outro()
	_start_async_load("res://Main.tscn")


func _start_async_load(scene_path: String) -> void:
	var err := ResourceLoader.load_threaded_request(scene_path)
	if err != OK:
		push_error("Failed to start threaded loading for " + scene_path)
		get_tree().change_scene_to_file(scene_path)
		return

	var panel := Panel.new()
	panel.size = Vector2(500, 70)
	panel.position = Vector2((W - 500) / 2.0, (H - 70) / 2.0)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.05, 0.85)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.8, 1.0, 0.5)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var loading_label := Label.new()
	loading_label.text = "SYNCHRONISATION TEMPORELLE... 0%"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 16)
	loading_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	loading_label.size = panel.size
	
	panel.add_child(loading_label)
	ui.add_child(panel)
	panel.modulate.a = 0.0
	
	var fade_in := create_tween()
	fade_in.tween_property(panel, "modulate:a", 1.0, 0.3)

	var progress: Array = []
	var loaded := false
	while not loaded:
		await get_tree().create_timer(0.05).timeout
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			loaded = true
			loading_label.text = "DISTORSION OK ! CHARGEMENT..."
			await get_tree().create_timer(0.15).timeout
			var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
			if packed_scene:
				get_tree().change_scene_to_packed(packed_scene)
			else:
				get_tree().change_scene_to_file(scene_path)
			break
		elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				var pct: int = int((progress[0] as float) * 100.0)
				loading_label.text = "SYNCHRONISATION TEMPORELLE... %d%%" % pct
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Asynchronous loading failed!")
			get_tree().change_scene_to_file(scene_path)
			break



func _on_options() -> void:
	if fading:
		return
	options_panel.show()


func _on_credits() -> void:
	if fading:
		return
	credits.show()


func _close_credits() -> void:
	credits.hide()


func _on_quit() -> void:
	if fading:
		return
	await _play_outro()
	get_tree().quit()


func _show_stub(msg: String) -> void:
	var lb := Label.new()
	lb.text = msg
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 16)
	lb.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	lb.position = Vector2(262, 300)
	lb.size = Vector2(500, 40)
	lb.modulate = Color(1, 1, 1, 0)
	ui.add_child(lb)

	var tw := create_tween()
	tw.tween_property(lb, "modulate", Color(1, 1, 1, 1), 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(lb, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.tween_callback(lb.queue_free)


func _setup_options() -> void:
	options_panel = Panel.new()
	options_panel.size = Vector2(400, 300)
	options_panel.position = Vector2(W / 2 - 200, H / 2 - 150)
	options_panel.hide()
	options_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	st.border_color = Color(0.3, 0.5, 0.8, 0.55)
	st.border_width_left = 1
	st.border_width_right = 1
	st.border_width_top = 1
	st.border_width_bottom = 1
	st.corner_radius_top_left = 12
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 12
	options_panel.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 20)
	vb.size = Vector2(340, 260)
	vb.add_theme_constant_override("separation", 12)
	options_panel.add_child(vb)

	# Titre
	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb.add_child(title)

	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer1)

	# Option Volume Master
	var bus_idx := AudioServer.get_bus_index("Master")
	var current_vol := 100
	if bus_idx != -1:
		current_vol = int(db_to_linear(AudioServer.get_bus_volume_db(bus_idx)) * 100.0)

	var vol_label := Label.new()
	vol_label.text = "Volume Master : " + str(current_vol) + "%"
	vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_label.add_theme_font_size_override("font_size", 14)
	vol_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vb.add_child(vol_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = float(current_vol)
	slider.custom_minimum_size = Vector2(200, 20)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float):
		var db := linear_to_db(value / 100.0)
		if value <= 0.0:
			db = -80.0
		if bus_idx != -1:
			AudioServer.set_bus_volume_db(bus_idx, db)
		vol_label.text = "Volume Master : " + str(int(value)) + "%"
	)
	vb.add_child(slider)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer2)

	# Option Mode Ecran
	var is_fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var mode_btn := Button.new()
	mode_btn.text = "Mode : Plein Ecran" if is_fullscreen else "Mode : Fenetre"
	mode_btn.custom_minimum_size = Vector2(180, 30)
	mode_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var btn_st := StyleBoxFlat.new()
	btn_st.bg_color = Color(0.12, 0.12, 0.18, 0.8)
	btn_st.border_color = Color(0.3, 0.5, 0.7, 0.4)
	btn_st.border_width_left = 1
	btn_st.border_width_right = 1
	btn_st.border_width_top = 1
	btn_st.border_width_bottom = 1
	btn_st.corner_radius_top_left = 4
	btn_st.corner_radius_top_right = 4
	btn_st.corner_radius_bottom_left = 4
	btn_st.corner_radius_bottom_right = 4
	mode_btn.add_theme_stylebox_override("normal", btn_st)
	mode_btn.add_theme_stylebox_override("hover", btn_st)
	mode_btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	
	mode_btn.pressed.connect(func():
		var is_fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			mode_btn.text = "Mode : Fenetre"
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			mode_btn.text = "Mode : Plein Ecran"
	)
	vb.add_child(mode_btn)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer3)

	# Bouton Fermer
	var cb := Button.new()
	cb.text = "Fermer"
	cb.custom_minimum_size = Vector2(120, 32)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.15, 0.15, 0.22, 0.8)
	bs.border_color = Color(0.4, 0.6, 0.9, 0.5)
	bs.border_width_left = 1
	bs.border_width_right = 1
	bs.border_width_top = 1
	bs.border_width_bottom = 1
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	cb.add_theme_stylebox_override("normal", bs)
	cb.add_theme_stylebox_override("hover", bs)
	cb.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
	cb.pressed.connect(func():
		options_panel.hide()
	)
	vb.add_child(cb)

	ui.add_child(options_panel)
