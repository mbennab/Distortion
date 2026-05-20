extends CanvasLayer

signal done(success: bool)

const WIN_SCORE := 100

var score := 0
var _connected := false
var _won := false
var _is_typing := false

# Main UI references
var _screen_dimmer: ColorRect
var _main_panel: Panel
var _original_panel_pos: Vector2

# Left Column (Portrait & Mood)
var _portrait_rect: TextureRect
var _mood_label: Label
var _rank_label: Label

# Right Column (Chat & Input)
var _progress_fill: ColorRect
var _score_label: Label
var _chat_log: VBoxContainer
var _scroll_container: ScrollContainer
var _input_line: LineEdit
var _send_btn: Button
var _close_btn: Button

# Typewriter variables
var _typewriter_timer: Timer
var _typewriter_text: String = ""
var _typewriter_index: int = 0
var _current_chat_label: Label
var _typewriter_callback: Callable

# Shake effect variables
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.0

func _ready() -> void:
	_setup_ui()
	_setup_typewriter()


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_intensity
		_main_panel.position = _original_panel_pos + offset
		if _shake_timer <= 0.0:
			_main_panel.position = _original_panel_pos


func _setup_ui() -> void:
	# 1. Dimmer Background
	_screen_dimmer = ColorRect.new()
	_screen_dimmer.color = Color(0.02, 0.02, 0.03, 0.75)
	_screen_dimmer.anchor_right = 1.0
	_screen_dimmer.anchor_bottom = 1.0
	_screen_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen_dimmer)

	# 2. Main Gothic/Parchment Card
	_main_panel = Panel.new()
	_main_panel.custom_minimum_size = Vector2(820, 500)
	_main_panel.anchor_left = 0.5
	_main_panel.anchor_right = 0.5
	_main_panel.anchor_top = 0.5
	_main_panel.anchor_bottom = 0.5
	_main_panel.offset_left = -410
	_main_panel.offset_right = 410
	_main_panel.offset_top = -250
	_main_panel.offset_bottom = 250
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.07, 0.06, 0.96) # Dark parchment / sepia charcoal
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.85, 0.68, 0.35, 1.0) # Golden Amber
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.6)
	panel_style.shadow_size = 12
	_main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_main_panel)

	# 3. Close Button (Top-Right)
	_close_btn = Button.new()
	_close_btn.text = "✖"
	_close_btn.anchor_left = 1.0
	_close_btn.anchor_right = 1.0
	_close_btn.offset_left = -40
	_close_btn.offset_right = -10
	_close_btn.offset_top = 10
	_close_btn.offset_bottom = 40
	_close_btn.flat = true
	_close_btn.add_theme_color_override("font_color", Color(0.85, 0.68, 0.35, 0.8))
	_close_btn.add_theme_color_override("font_hover_color", Color(1, 0.2, 0.2, 1))
	_close_btn.add_theme_font_size_override("font_size", 18)
	_close_btn.pressed.connect(_on_close_pressed)
	_main_panel.add_child(_close_btn)

	# 4. HBox split for layout
	var main_hbox = HBoxContainer.new()
	main_hbox.anchor_left = 0.02
	main_hbox.anchor_right = 0.98
	main_hbox.anchor_top = 0.05
	main_hbox.anchor_bottom = 0.95
	main_hbox.add_theme_constant_override("separation", 24)
	_main_panel.add_child(main_hbox)

	# ==========================================
	# LEFT COLUMN: Portrait & Visual States
	# ==========================================
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(250, 0)
	left_vbox.size_flags_vertical = Control.SIZE_FILL
	left_vbox.add_theme_constant_override("separation", 12)
	main_hbox.add_child(left_vbox)

	# Portrait Frame Container
	var portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(250, 310)
	portrait_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	frame_style.border_width_left = 2
	frame_style.border_width_right = 2
	frame_style.border_width_top = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color(0.85, 0.68, 0.35, 0.6)
	frame_style.corner_radius_top_left = 8
	frame_style.corner_radius_top_right = 8
	frame_style.corner_radius_bottom_left = 8
	frame_style.corner_radius_bottom_right = 8
	portrait_frame.add_theme_stylebox_override("panel", frame_style)
	left_vbox.add_child(portrait_frame)

	# Crop portrait from atlas
	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(246, 306)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	
	var base_tex = load("res://art/MoyenAge/femme.png")
	if base_tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = base_tex
		atlas.region = Rect2(0, 0, 266, 400) # Framed nicely on her upper body
		_portrait_rect.texture = atlas
	portrait_frame.add_child(_portrait_rect)

	# Relation Rank Badge
	_rank_label = Label.new()
	_rank_label.text = "Relation : INCONNUE"
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 15)
	_rank_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.35, 0.95))
	var rank_style = StyleBoxFlat.new()
	rank_style.bg_color = Color(0.15, 0.12, 0.1, 1.0)
	rank_style.corner_radius_top_left = 4
	rank_style.corner_radius_top_right = 4
	rank_style.corner_radius_bottom_left = 4
	rank_style.corner_radius_bottom_right = 4
	rank_style.content_margin_top = 4
	rank_style.content_margin_bottom = 4
	_rank_label.add_theme_stylebox_override("normal", rank_style)
	left_vbox.add_child(_rank_label)

	# Mood Indicator
	_mood_label = Label.new()
	_mood_label.text = "Humeur : Calme et réservée"
	_mood_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mood_label.add_theme_font_size_override("font_size", 13)
	_mood_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 0.85))
	left_vbox.add_child(_mood_label)

	# ==========================================
	# RIGHT COLUMN: Progress, Log & Saisie
	# ==========================================
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_FILL
	right_vbox.add_theme_constant_override("separation", 16)
	main_hbox.add_child(right_vbox)

	# 1. Affinity Progress Bar with custom style
	var progress_container = Control.new()
	progress_container.custom_minimum_size = Vector2(0, 36)
	right_vbox.add_child(progress_container)

	var progress_bg = ColorRect.new()
	progress_bg.color = Color(0.06, 0.05, 0.05, 1.0)
	progress_bg.anchor_right = 1.0
	progress_bg.anchor_bottom = 1.0
	progress_container.add_child(progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.color = Color(0.85, 0.35, 0.35, 1.0) # Emerald green starting
	_progress_fill.anchor_left = 0.0
	_progress_fill.anchor_top = 0.0
	_progress_fill.anchor_bottom = 1.0
	_progress_fill.anchor_right = 0.0
	progress_container.add_child(_progress_fill)

	var progress_border = Panel.new()
	progress_border.anchor_right = 1.0
	progress_border.anchor_bottom = 1.0
	var pb_style = StyleBoxFlat.new()
	pb_style.bg_color = Color(0, 0, 0, 0)
	pb_style.border_width_left = 2
	pb_style.border_width_right = 2
	pb_style.border_width_top = 2
	pb_style.border_width_bottom = 2
	pb_style.border_color = Color(0.85, 0.68, 0.35, 0.5)
	progress_border.add_theme_stylebox_override("panel", pb_style)
	progress_container.add_child(progress_border)

	_score_label = Label.new()
	_score_label.text = "❤ Confiance mutuelle : 0%"
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.anchor_right = 1.0
	_score_label.anchor_bottom = 1.0
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", Color.WHITE)
	_score_label.add_theme_constant_override("outline_size", 2)
	_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_container.add_child(_score_label)

	# 2. Chat Log ScrollContainer
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.06, 0.05, 0.04, 0.7)
	scroll_style.border_width_left = 1
	scroll_style.border_width_right = 1
	scroll_style.border_width_top = 1
	scroll_style.border_width_bottom = 1
	scroll_style.border_color = Color(0.85, 0.68, 0.35, 0.25)
	scroll_style.corner_radius_top_left = 6
	scroll_style.corner_radius_top_right = 6
	scroll_style.corner_radius_bottom_left = 6
	scroll_style.corner_radius_bottom_right = 6
	scroll_style.content_margin_left = 12
	scroll_style.content_margin_right = 12
	scroll_style.content_margin_top = 8
	scroll_style.content_margin_bottom = 8
	_scroll_container.add_theme_stylebox_override("panel", scroll_style)
	right_vbox.add_child(_scroll_container)

	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_FILL
	_chat_log.add_theme_constant_override("separation", 10)
	_scroll_container.add_child(_chat_log)

	# 3. Input panel
	var input_hbox = HBoxContainer.new()
	input_hbox.custom_minimum_size = Vector2(0, 42)
	input_hbox.size_flags_horizontal = Control.SIZE_FILL
	input_hbox.add_theme_constant_override("separation", 12)
	right_vbox.add_child(input_hbox)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "Écrivez avec sincérité et politesse..."
	_input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_line.caret_blink = true
	_input_line.max_length = 120
	_input_line.text_submitted.connect(_on_text_submitted)
	
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.06, 0.05, 0.04, 0.9)
	input_style.border_width_left = 1
	input_style.border_width_right = 1
	input_style.border_width_top = 1
	input_style.border_width_bottom = 1
	input_style.border_color = Color(0.85, 0.68, 0.35, 0.5)
	input_style.corner_radius_top_left = 6
	input_style.corner_radius_top_right = 6
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	input_style.content_margin_left = 10
	_input_line.add_theme_stylebox_override("normal", input_style)
	_input_line.add_theme_stylebox_override("focus", input_style)
	_input_line.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1))
	input_hbox.add_child(_input_line)

	_send_btn = Button.new()
	_send_btn.text = "S'exprimer"
	_send_btn.custom_minimum_size = Vector2(120, 0)
	_send_btn.pressed.connect(_on_send_pressed)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.42, 0.28, 0.15, 1.0)
	btn_normal.border_width_left = 1
	btn_normal.border_width_right = 1
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.border_color = Color(0.85, 0.68, 0.35, 0.8)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	
	var btn_hover = btn_normal.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.55, 0.36, 0.18, 1.0)
	
	_send_btn.add_theme_stylebox_override("normal", btn_normal)
	_send_btn.add_theme_stylebox_override("hover", btn_hover)
	_send_btn.add_theme_stylebox_override("pressed", btn_normal)
	_send_btn.add_theme_color_override("font_color", Color.WHITE)
	_send_btn.add_theme_font_size_override("font_size", 14)
	input_hbox.add_child(_send_btn)


func _setup_typewriter() -> void:
	_typewriter_timer = Timer.new()
	_typewriter_timer.one_shot = false
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)


func start() -> void:
	if not is_node_ready():
		await ready
	
	score = 0
	_won = false
	_is_typing = false
	_update_bar()
	
	if not _connected:
		DialogueSystem.friendship_response_received.connect(_on_ai_response)
		DialogueSystem.dialogue_error.connect(_on_ai_error)
		_connected = true

	_chat_log.get_children().map(func(c): c.queue_free())
	
	# Start with woman's initial hook message
	var accroche := DialogueSystem.get_first_message()
	if accroche == "":
		accroche = "Oh, bonjour ! Je me promenais près de la fontaine. Personne ne vient jamais me parler… Tu as l'air bien différent des villageois. D'où viens-tu ?"
	
	_input_line.editable = false
	_send_btn.disabled = true
	
	await get_tree().create_timer(0.3).timeout
	_add_woman_message(accroche, func():
		_input_line.editable = true
		_send_btn.disabled = false
		_input_line.grab_focus()
	)


func stop() -> void:
	if _connected:
		if DialogueSystem.friendship_response_received.is_connected(_on_ai_response):
			DialogueSystem.friendship_response_received.disconnect(_on_ai_response)
		if DialogueSystem.dialogue_error.is_connected(_on_ai_error):
			DialogueSystem.dialogue_error.disconnect(_on_ai_error)
		_connected = false
	
	if _typewriter_timer and _typewriter_timer.is_inside_tree():
		_typewriter_timer.stop()


func _on_close_pressed() -> void:
	DialogueSystem.stop_dialogue()
	done.emit(false)


func _on_send_pressed() -> void:
	_submit_current_message()


func _on_text_submitted(_text: String) -> void:
	_submit_current_message()


func _submit_current_message() -> void:
	if _is_typing or not _input_line.editable:
		return
	
	var text = _input_line.text.strip_edges()
	if text == "":
		return
		
	_input_line.text = ""
	_input_line.editable = false
	_send_btn.disabled = true
	
	# Show player message instantly in log
	_add_player_message(text)
	
	# Send to DialogueSystem (handles AI query)
	DialogueSystem.send_message(text)


func _on_ai_response(text: String, affinity_change: int, feeling: String) -> void:
	if _won:
		return

	# 1. Update score
	var previous_score = score
	score = clampi(score + affinity_change, 0, WIN_SCORE)
	
	# 2. Update visual elements
	_update_bar()
	_update_mood_and_portrait(feeling)
	
	# 3. Trigger feedback popups
	_show_floating_feedback(affinity_change)
	
	# 4. Trigger screen actions
	if affinity_change >= 15:
		_spawn_floating_particles(12, "❤", Color(1, 0.35, 0.45))
		_spawn_floating_particles(8, "✦", Color(1, 0.85, 0.3))
	elif affinity_change <= -10:
		_trigger_screen_shake(12.0, 0.4)
		_spawn_floating_particles(8, "💥", Color(1, 0.2, 0.2))

	# 5. Typewriter response
	_add_woman_message(text, func():
		if score >= WIN_SCORE:
			_won = true
			_trigger_win()
		else:
			_input_line.editable = true
			_send_btn.disabled = false
			_input_line.grab_focus()
	)


func _on_ai_error(err_text: String) -> void:
	_add_system_message("Erreur de connexion temporelle: " + err_text)
	_input_line.editable = true
	_send_btn.disabled = false


# ==========================================
# UI UPDATES & LOGIC
# ==========================================

func _update_bar() -> void:
	var pct := float(score) / float(WIN_SCORE)
	
	var tween = create_tween()
	tween.tween_property(_progress_fill, "anchor_right", pct, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# Colors based on score
	var color := Color(0.8, 0.3, 0.3)
	if score >= 75:
		color = Color(0.2, 0.78, 0.4) # Bright Green
	elif score >= 40:
		color = Color(0.85, 0.65, 0.2) # Golden Amber
	elif score >= 20:
		color = Color(0.8, 0.45, 0.2) # Muted Orange
	
	tween.parallel().tween_property(_progress_fill, "color", Color(color, 1.0), 0.4)
	_score_label.text = "❤ Confiance mutuelle : %d%%" % score
	
	# Update Bond Rank Label
	var rank_text := "Relation : INCONNUE"
	if score >= 90:
		rank_text = "Relation : AMIE PROCHE ❤"
	elif score >= 65:
		rank_text = "Relation : CONFIDENTE ✦"
	elif score >= 40:
		rank_text = "Relation : AMICALE ♪"
	elif score >= 20:
		rank_text = "Relation : INTRIGUÉE ✉"
	_rank_label.text = rank_text


func _update_mood_and_portrait(feeling: String) -> void:
	var mood_text := "Humeur : Calme et réservée"
	var color := Color(0.65, 0.7, 0.8) # Default Blue-Gray
	
	var base_tex = load("res://art/MoyenAge/femme.png")
	var region_idx := 0
	
	match feeling:
		"happy":
			mood_text = "Humeur : Enjouée et souriante"
			color = Color(0.3, 0.8, 0.45)
			region_idx = 1 # Alternate frame in sprite atlas if happy
		"sad":
			mood_text = "Humeur : Songeuse et mélancolique"
			color = Color(0.4, 0.6, 0.85)
			region_idx = 0
		"angry":
			mood_text = "Humeur : Blessée et distante"
			color = Color(0.85, 0.25, 0.25)
			region_idx = 0
			
	_mood_label.text = mood_text
	_mood_label.add_theme_color_override("font_color", Color(color, 0.85))
	
	# Rotate texture atlas region based on mood
	if base_tex:
		var atlas = _portrait_rect.texture as AtlasTexture
		if atlas:
			atlas.region = Rect2(region_idx * 266, 0, 266, 400)

	# Pulse portrait slightly when mood changes
	var pulse = create_tween()
	pulse.tween_property(_portrait_rect, "modulate", Color(color, 1.2), 0.15)
	pulse.tween_property(_portrait_rect, "modulate", Color.WHITE, 0.3)


func _show_floating_feedback(delta: int) -> void:
	var label = Label.new()
	var sign_str = "+" if delta >= 0 else ""
	var color = Color(0.2, 0.8, 0.4) if delta >= 0 else Color(1, 0.25, 0.25)
	var prefix = "✨ Sympathie " if delta >= 15 else ("✅ Confiance " if delta > 0 else ("➖ Neutre" if delta == 0 else "❌ Malentendu "))
	
	label.text = "%s (%s%d)" % [prefix, sign_str, delta]
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.z_index = 200
	_main_panel.add_child(label)
	
	# Position at center of portrait
	label.position = Vector2(125 - 60, 150)
	
	# Animate float up and scale
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 60.0, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.25).from(Vector2(0.4, 0.4))\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.chain().tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)


func _spawn_floating_particles(count: int, symbol: String, color: Color) -> void:
	for i in count:
		var p_label = Label.new()
		p_label.text = symbol
		p_label.add_theme_font_size_override("font_size", int(randf_range(16, 28)))
		p_label.add_theme_color_override("font_color", color)
		p_label.add_theme_constant_override("outline_size", 2)
		p_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_main_panel.add_child(p_label)
		
		# Center around portrait
		p_label.position = Vector2(125 + randf_range(-60, 60), 160 + randf_range(-80, 80))
		p_label.modulate.a = 0.0
		
		var angle = randf_range(0, TAU)
		var dist = randf_range(60, 180)
		var dest = p_label.position + Vector2(cos(angle), sin(angle)) * dist
		
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(p_label, "position", dest, randf_range(0.8, 1.5)).set_ease(Tween.EASE_OUT)
		tween.tween_property(p_label, "modulate:a", 1.0, 0.2)
		tween.tween_property(p_label, "modulate:a", 0.0, 0.5).set_delay(randf_range(0.4, 0.8))
		tween.tween_property(p_label, "rotation", randf_range(-PI, PI), 1.2)
		
		tween.chain().tween_callback(func():
			if is_instance_valid(p_label):
				p_label.queue_free()
		)


func _trigger_screen_shake(intensity: float, duration: float) -> void:
	if _shake_timer <= 0.0:
		_original_panel_pos = _main_panel.position
	_shake_intensity = intensity
	_shake_timer = duration


# ==========================================
# CHAT LOG WRITING
# ==========================================

func _add_player_message(text: String) -> void:
	var label = Label.new()
	label.text = "> Vous : %s" % text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.42, 1.0)) # Warm Amber
	_chat_log.add_child(label)
	
	_scroll_to_bottom()


func _add_woman_message(text: String, callback: Callable = Callable()) -> void:
	_is_typing = true
	
	var speaker_lbl = Label.new()
	speaker_lbl.text = "La Femme du Parc :"
	speaker_lbl.add_theme_font_size_override("font_size", 14)
	speaker_lbl.add_theme_color_override("font_color", Color(0.85, 0.68, 0.35, 1.0))
	speaker_lbl.add_theme_constant_override("outline_size", 1)
	_chat_log.add_child(speaker_lbl)
	
	_current_chat_label = Label.new()
	_current_chat_label.text = ""
	_current_chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_current_chat_label.size_flags_horizontal = Control.SIZE_FILL
	_current_chat_label.add_theme_font_size_override("font_size", 14)
	_current_chat_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.88, 1.0))
	_chat_log.add_child(_current_chat_label)
	
	_typewriter_text = text
	_typewriter_index = 0
	_typewriter_callback = callback
	
	_typewriter_timer.start(0.02)
	_scroll_to_bottom()


func _add_system_message(text: String) -> void:
	var label = Label.new()
	label.text = "[SYSTEM] %s" % text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.25, 0.8))
	_chat_log.add_child(label)
	_scroll_to_bottom()


func _on_typewriter_tick() -> void:
	if _typewriter_index < _typewriter_text.length():
		_current_chat_label.text += _typewriter_text[_typewriter_index]
		_typewriter_index += 1
		if _typewriter_index % 3 == 0:
			_scroll_to_bottom()
	else:
		_typewriter_timer.stop()
		_is_typing = false
		_scroll_to_bottom()
		if _typewriter_callback.is_valid():
			var cb = _typewriter_callback
			_typewriter_callback = Callable()
			cb.call()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _trigger_win() -> void:
	_input_line.editable = false
	_send_btn.disabled = true
	
	# Show gorgeous fullscreen parchment transition for quest completion
	var win_overlay = ColorRect.new()
	win_overlay.color = Color(0, 0, 0, 0)
	win_overlay.anchor_right = 1.0
	win_overlay.anchor_bottom = 1.0
	win_overlay.z_index = 300
	add_child(win_overlay)
	
	var win_card = Panel.new()
	win_card.custom_minimum_size = Vector2(650, 180)
	win_card.anchor_left = 0.5
	win_card.anchor_right = 0.5
	win_card.anchor_top = 0.5
	win_card.anchor_bottom = 0.5
	win_card.offset_left = -325
	win_card.offset_right = 325
	win_card.offset_top = -90
	win_card.offset_bottom = 90
	
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.09, 0.07, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.2, 0.8, 0.4, 0.8) # Vibrant green border for victory!
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.shadow_size = 10
	win_card.add_theme_stylebox_override("panel", card_style)
	win_card.modulate.a = 0.0
	win_overlay.add_child(win_card)
	
	var win_lbl = Label.new()
	win_lbl.text = "La femme du parc est profondément touchée par votre sincérité.\nElle vous sourit tendrement et vous murmure :\n\n« Viens, suis-moi, je te montre par où il s'est enfui... »"
	win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_lbl.anchor_right = 1.0
	win_lbl.anchor_bottom = 1.0
	win_lbl.add_theme_font_size_override("font_size", 18)
	win_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 1.0))
	win_card.add_child(win_lbl)
	
	# Animate card appearance
	var tween = create_tween()
	tween.tween_property(win_overlay, "color", Color(0, 0, 0, 0.6), 0.5)
	tween.parallel().tween_property(win_card, "modulate:a", 1.0, 0.5)
	
	# Spawn spectacular stars/hearts all over the victory screen
	for i in 25:
		tween.parallel().tween_callback(func():
			_spawn_floating_particles(1, "❤" if randf() > 0.5 else "✦", Color(randf(), randf() + 0.5, randf() + 0.5))
		).set_delay(randf_range(0.1, 2.0))

	tween.chain().tween_interval(3.8)
	tween.tween_property(win_overlay, "color:a", 0.0, 0.6)
	tween.parallel().tween_property(win_card, "modulate:a", 0.0, 0.6)
	
	tween.chain().tween_callback(func():
		done.emit(true)
	)


func _on_tree_exiting() -> void:
	stop()
