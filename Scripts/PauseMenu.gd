extends CanvasLayer

const W := 1024
const H := 682

var open := false
var container: Control
var options_panel: Panel

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS # Crucial to run while game is paused
	layer = 128
	hide()
	_setup_ui()
	_setup_options()


func _setup_ui() -> void:
	container = Control.new()
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	# Fullscreen dark tint overlay
	var overlay := ColorRect.new()
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0.02, 0.02, 0.04, 0.75)
	container.add_child(overlay)

	# Centered Menu Panel
	var panel := Panel.new()
	panel.size = Vector2(300, 360)
	panel.position = Vector2(W / 2 - 150, H / 2 - 180)
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
	panel.add_theme_stylebox_override("panel", st)
	container.add_child(panel)

	# VBoxContainer for buttons
	var vb := VBoxContainer.new()
	vb.position = Vector2(25, 20)
	vb.size = Vector2(250, 320)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	# Title
	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vb.add_child(spacer)

	# Buttons
	var btns_data := [
		{"t": "Reprendre", "fn": toggle},
		{"t": "Sauvegarder", "fn": _on_save},
		{"t": "Options", "fn": _on_options},
		{"t": "Menu Principal", "fn": _on_main_menu}
	]

	for b_info in btns_data:
		var btn := Button.new()
		btn.text = b_info["t"]
		btn.custom_minimum_size = Vector2(0, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.12, 0.12, 0.18, 0.8)
		bs.border_color = Color(0.3, 0.5, 0.7, 0.4)
		bs.border_width_left = 1
		bs.border_width_right = 1
		bs.border_width_top = 1
		bs.border_width_bottom = 1
		bs.corner_radius_top_left = 6
		bs.corner_radius_top_right = 6
		bs.corner_radius_bottom_left = 6
		bs.corner_radius_bottom_right = 6
		
		btn.add_theme_stylebox_override("normal", bs)
		btn.add_theme_stylebox_override("hover", bs)
		btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		btn.pressed.connect(b_info["fn"])
		vb.add_child(btn)


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

	# Close button
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

	container.add_child(options_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		var current_scene := get_tree().current_scene
		if current_scene and current_scene.name != "MainMenu":
			# Empêche l'activation du menu si un dialogue IA ou cinématique est actif pour éviter les bugs
			if has_node("/root/DialogueUI") and get_node("/root/DialogueUI").current_state != 0: # State.HIDDEN is 0
				return
			get_viewport().set_input_as_handled()
			toggle()


func toggle() -> void:
	open = not open
	if open:
		get_tree().paused = true
		show()
	else:
		get_tree().paused = false
		options_panel.hide()
		hide()


func _on_save() -> void:
	DialogueSystem.save_game_state()
	# Notification visuelle éphémère de confirmation de sauvegarde
	var notify := Label.new()
	notify.text = "Progression sauvegardee !"
	notify.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notify.add_theme_font_size_override("font_size", 14)
	notify.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	notify.position = Vector2(W / 2 - 150, H / 2 + 100) # Centered horizontally relative to W
	notify.size = Vector2(300, 30)
	container.add_child(notify)
	var t := create_tween()
	t.tween_property(notify, "modulate:a", 1.0, 1.0)
	t.tween_interval(1.5)
	t.tween_property(notify, "modulate:a", 0.0, 0.5)
	t.tween_callback(notify.queue_free)


func _on_options() -> void:
	options_panel.show()


func _on_main_menu() -> void:
	toggle() # Retirer la pause et masquer
	get_tree().change_scene_to_file("res://Menu/MainMenu.tscn")
