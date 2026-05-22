extends CanvasLayer

const W := 1024
const H := 682

var music_list: Array[AudioStream] = []
var music: AudioStreamPlayer
var buttons: Array[Button] = []
var credits: Panel
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
	credits.size = Vector2(500, 360)
	credits.position = Vector2(W / 2 - 250, H / 2 - 170)
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
		"Game Design & Developpement",
		"Par les etudiants de CIR2",
		"",
		"Musique : Chronos par Alexander Nakarada (CC BY 4.0)",
		"Musique : Unsafe Roads par Alexander Nakarada (CC BY 4.0)",
		"Musique : Space Ambience par Alexander Nakarada (CC BY 4.0)",
		"Musique : Nightfall par Alexander Nakarada (CC BY 4.0)",
		"Musique : Sci-Fi-Buzzkiller par Alexander Nakarada (CC BY 4.0)",
		"Musique : NIGHTCLUB par Alexander Nakarada (CC BY 4.0)",
		"Musique : The Foreign Tale par Alexander Nakarada (CC BY 4.0)",
		"Musique : Adventure par Alexander Nakarada (CC BY 4.0)",
		"Musique : Chase par Alexander Nakarada (CC BY 4.0)",
		"Musique : The Replicant par Lyra Soundtracks (CC BY 4.0)",
		"",
		"Merci d'avoir joue !",
	]

	var vb := VBoxContainer.new()
	vb.position = Vector2(30, 16)
	vb.size = Vector2(440, 440)
	vb.add_theme_constant_override("separation", 8)
	credits.add_child(vb)

	var sizes := [0, 22, 0, 16, 0, 14, 14, 0, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 0, 16]
	var colors := [
		Color.WHITE,
		Color(0.9, 0.95, 1.0),
		Color.WHITE,
		Color(0.6, 0.7, 0.9),
		Color.WHITE,
		Color(0.5, 0.55, 0.65),
		Color(0.5, 0.55, 0.65),
		Color.WHITE,
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
		Color(0.4, 0.6, 0.8, 0.7),
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
			lb.custom_minimum_size = Vector2(0, 4)
		vb.add_child(lb)

	var cb := Button.new()
	cb.text = "Fermer"
	cb.custom_minimum_size = Vector2(120, 36)
	cb.position = Vector2(190, 300)
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
	credits.add_child(cb)

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
	get_tree().change_scene_to_file("res://Main.tscn")


func _on_load() -> void:
	if fading:
		return
	_show_stub("Charger — bientot disponible")


func _on_options() -> void:
	if fading:
		return
	_show_stub("Options — bientot disponible")


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
