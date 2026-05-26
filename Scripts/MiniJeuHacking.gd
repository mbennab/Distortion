extends CanvasLayer

signal done(success: bool)

static var _extra_time_bonus: float = 0.0

# Game variables
var _time_left: float = 60.0
var _progress: float = 0.0
var _current_command: String = ""
var _game_over: bool = false
var _hack_mode: bool = false
var _connecting: bool = false
var _hack_started: bool = false

# UI references
var _main_panel: Panel
var _login_container: VBoxContainer
var _hack_container: HBoxContainer
var _log_label: RichTextLabel
var _command_input: LineEdit
var _target_command_label: Label
var _timer_label: Label
var _progress_bar: ProgressBar
var _status_message_label: Label
var _btn_connect: Button
var _btn_hack: Button
var _instructions_vbox: VBoxContainer
var _gameplay_vbox: VBoxContainer
var _btn_start_hack: Button

# Desktop UI references
var _desktop_container: Panel
var _desktop_status_lbl: Label
var _btn_switch: Button
var _switch_style_on: StyleBoxFlat
var _switch_style_off: StyleBoxFlat
var _switch_toggled: bool = false

# Command list
var _commands: Array[String] = [
	"bypass_firewall --port=8080",
	"nmap -sV -O 192.168.1.50",
	"inject_payload --target=kernel",
	"exploit_buffer --stack=overflow",
	"decrypt_hash --algo=sha256 --salt=distort",
	"ssh root@10.0.0.4 -p 22",
	"kill_process --pid=4089 --force",
	"override_sysupdate --confirm",
	"clear_logs --all --verbose",
	"spoof_mac --interface=eth0 --random"
]

var _session_commands: Array[String] = []

func _ready() -> void:
	_time_left = 60.0 + _extra_time_bonus
	# Blur/Dark overlay
	var bg_overlay := ColorRect.new()
	bg_overlay.color = Color(0.04, 0.04, 0.06, 0.85)
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_overlay)

	# Main Terminal Frame
	_main_panel = Panel.new()
	_main_panel.custom_minimum_size = Vector2(850, 520)
	_main_panel.size = Vector2(850, 520)
	
	# Glow & Cyberpunk styling
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.0, 0.94, 1.0, 0.9) # Neon Cyan
	panel_style.corner_radius_top_left = 16
	panel_style.corner_radius_top_right = 16
	panel_style.corner_radius_bottom_left = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.shadow_color = Color(0.0, 0.94, 1.0, 0.25)
	panel_style.shadow_size = 25
	_main_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Center it on viewport
	add_child(_main_panel)
	_center_panel()
	get_viewport().size_changed.connect(_center_panel)

	# Main layout inside the frame
	var margin_container := MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 24)
	margin_container.add_theme_constant_override("margin_bottom", 24)
	_main_panel.add_child(margin_container)

	var layout := VBoxContainer.new()
	margin_container.add_child(layout)

	# Terminal Header
	var header := HBoxContainer.new()
	layout.add_child(header)

	var header_title := Label.new()
	header_title.text = "📟 TERMINAL D'ADMINISTRATION - SYSTÈME CENTRAL CORE v4.6"
	header_title.add_theme_font_size_override("font_size", 16)
	header_title.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 0.9))
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_title)

	var header_led := ColorRect.new()
	header_led.custom_minimum_size = Vector2(12, 12)
	header_led.color = Color(0.0, 0.94, 1.0, 0.9)
	header.add_child(header_led)
	# Pulse header LED animation
	var led_tween = create_tween().set_loops()
	led_tween.tween_property(header_led, "color:a", 0.2, 0.6)
	led_tween.tween_property(header_led, "color:a", 1.0, 0.6)

	var h_line := ColorRect.new()
	h_line.custom_minimum_size = Vector2(0, 2)
	h_line.color = Color(0.0, 0.94, 1.0, 0.3)
	layout.add_child(h_line)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	layout.add_child(spacer)

	# Content Area
	var content_area := Control.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(content_area)

	# -------------------- SCREEN 1: LOGIN SCREEN --------------------
	_login_container = VBoxContainer.new()
	_login_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_login_container.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(_login_container)

	var login_title := Label.new()
	login_title.text = "CONNEXION SÉCURISÉE"
	login_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	login_title.add_theme_font_size_override("font_size", 22)
	login_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_login_container.add_child(login_title)

	var login_spacer1 := Control.new()
	login_spacer1.custom_minimum_size = Vector2(0, 12)
	_login_container.add_child(login_spacer1)

	var username_lbl := Label.new()
	username_lbl.text = "Nom d'utilisateur :"
	username_lbl.add_theme_font_size_override("font_size", 14)
	username_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_login_container.add_child(username_lbl)

	var username_input := LineEdit.new()
	username_input.placeholder_text = "Saisissez l'identifiant..."
	username_input.editable = true
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_input.custom_minimum_size = Vector2(320, 36)
	_login_container.add_child(username_input)

	var password_lbl := Label.new()
	password_lbl.text = "Mot de passe :"
	password_lbl.add_theme_font_size_override("font_size", 14)
	password_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_login_container.add_child(password_lbl)

	var password_input := LineEdit.new()
	password_input.secret = true
	password_input.placeholder_text = "Saisissez le mot de passe..."
	password_input.editable = true
	password_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	password_input.custom_minimum_size = Vector2(320, 36)
	_login_container.add_child(password_input)

	var login_spacer2 := Control.new()
	login_spacer2.custom_minimum_size = Vector2(0, 16)
	_login_container.add_child(login_spacer2)

	_status_message_label = Label.new()
	_status_message_label.text = ""
	_status_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_message_label.add_theme_font_size_override("font_size", 14)
	_status_message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_login_container.add_child(_status_message_label)

	var login_spacer3 := Control.new()
	login_spacer3.custom_minimum_size = Vector2(0, 10)
	_login_container.add_child(login_spacer3)

	_btn_connect = Button.new()
	_btn_connect.text = "SE CONNECTER"
	_btn_connect.custom_minimum_size = Vector2(240, 42)
	_btn_connect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_connect.focus_mode = Control.FOCUS_NONE
	_btn_connect.pressed.connect(_on_connect_pressed)
	_login_container.add_child(_btn_connect)

	# Cyberpunk Style connect button
	var btn_connect_style := StyleBoxFlat.new()
	btn_connect_style.bg_color = Color(0.0, 0.45, 0.7, 0.85)
	btn_connect_style.border_width_left = 2
	btn_connect_style.border_width_top = 2
	btn_connect_style.border_width_right = 2
	btn_connect_style.border_width_bottom = 2
	btn_connect_style.border_color = Color(0.0, 0.94, 1.0, 1.0)
	btn_connect_style.corner_radius_top_left = 8
	btn_connect_style.corner_radius_top_right = 8
	btn_connect_style.corner_radius_bottom_left = 8
	btn_connect_style.corner_radius_bottom_right = 8
	_btn_connect.add_theme_stylebox_override("normal", btn_connect_style)
	_btn_connect.add_theme_stylebox_override("hover", btn_connect_style)

	_btn_hack = Button.new()
	_btn_hack.text = "⚠️ PIRATER LE SYSTÈME"
	_btn_hack.custom_minimum_size = Vector2(240, 42)
	_btn_hack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_hack.focus_mode = Control.FOCUS_NONE
	_btn_hack.visible = false
	_btn_hack.pressed.connect(_on_hack_pressed)
	_login_container.add_child(_btn_hack)

	# Hack button styling
	var btn_hack_style := StyleBoxFlat.new()
	btn_hack_style.bg_color = Color(0.7, 0.08, 0.08, 0.95)
	btn_hack_style.border_width_left = 2
	btn_hack_style.border_width_top = 2
	btn_hack_style.border_width_right = 2
	btn_hack_style.border_width_bottom = 2
	btn_hack_style.border_color = Color(1.0, 0.2, 0.2, 1.0)
	btn_hack_style.corner_radius_top_left = 8
	btn_hack_style.corner_radius_top_right = 8
	btn_hack_style.corner_radius_bottom_left = 8
	btn_hack_style.corner_radius_bottom_right = 8
	_btn_hack.add_theme_stylebox_override("normal", btn_hack_style)
	_btn_hack.add_theme_stylebox_override("hover", btn_hack_style)

	# -------------------- SCREEN 2: HACK SCREEN --------------------
	_hack_container = HBoxContainer.new()
	_hack_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hack_container.visible = false
	content_area.add_child(_hack_container)

	# Left Column: Command prompt & input
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.3
	_hack_container.add_child(left_col)

	# Timer & Info
	var info_bar := HBoxContainer.new()
	left_col.add_child(info_bar)

	_timer_label = Label.new()
	_timer_label.text = "TEMPS RESTANT : %.1fs (Suspendu)" % _time_left
	_timer_label.add_theme_font_size_override("font_size", 15)
	_timer_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_bar.add_child(_timer_label)

	var target_label := Label.new()
	target_label.text = "Cible: core_central_node_4.adm"
	target_label.add_theme_font_size_override("font_size", 13)
	target_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info_bar.add_child(target_label)

	var left_spacer1 := Control.new()
	left_spacer1.custom_minimum_size = Vector2(0, 12)
	left_col.add_child(left_spacer1)

	# Progress Panel
	var progress_lbl := Label.new()
	progress_lbl.text = "Progression du Piratage :"
	progress_lbl.add_theme_font_size_override("font_size", 14)
	progress_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	left_col.add_child(progress_lbl)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 24)
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = true
	left_col.add_child(_progress_bar)

	var progress_style := StyleBoxFlat.new()
	progress_style.bg_color = Color(0.0, 0.94, 1.0, 0.8) # neon cyan
	_progress_bar.add_theme_stylebox_override("fill", progress_style)

	var left_spacer2 := Control.new()
	left_spacer2.custom_minimum_size = Vector2(0, 16)
	left_col.add_child(left_spacer2)

	# --- INSTRUCTIONS VBOX ---
	_instructions_vbox = VBoxContainer.new()
	_instructions_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instructions_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_child(_instructions_vbox)

	var inst_title := Label.new()
	inst_title.text = "📟 INSTRUCTIONS DE CONTOURNEMENT DE SÉCURITÉ"
	inst_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst_title.add_theme_font_size_override("font_size", 15)
	inst_title.add_theme_color_override("font_color", Color(0.0, 0.94, 1.0, 1.0))
	_instructions_vbox.add_child(inst_title)

	var inst_spacer1 := Control.new()
	inst_spacer1.custom_minimum_size = Vector2(0, 10)
	_instructions_vbox.add_child(inst_spacer1)

	var inst_text := Label.new()
	inst_text.text = "Vous devez contourner la sécurité de ce PC d'administration pour accéder à son système. Recopiez précisément les commandes présentées dans le terminal avant la fin du temps imparti.\n\n" + \
		"1. Recopiez précisément la commande affichée en vert.\n" + \
		"2. Appuyez sur ENTRÉE pour valider la saisie.\n" + \
		"3. Remplissez la jauge de progression à 100% (5 commandes).\n\n" + \
		"Temps de dérivation disponible : %d secondes." % int(_time_left)
	inst_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inst_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inst_text.add_theme_font_size_override("font_size", 13)
	inst_text.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	_instructions_vbox.add_child(inst_text)

	var inst_spacer2 := Control.new()
	inst_spacer2.custom_minimum_size = Vector2(0, 18)
	_instructions_vbox.add_child(inst_spacer2)

	_btn_start_hack = Button.new()
	_btn_start_hack.text = "⚡ DÉMARRER LE PROTOCOLE"
	_btn_start_hack.custom_minimum_size = Vector2(250, 42)
	_btn_start_hack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_start_hack.focus_mode = Control.FOCUS_NONE
	_btn_start_hack.pressed.connect(_on_start_hack_pressed)
	_instructions_vbox.add_child(_btn_start_hack)

	var btn_start_style := StyleBoxFlat.new()
	btn_start_style.bg_color = Color(0.0, 0.55, 0.35, 0.85)
	btn_start_style.border_width_left = 2
	btn_start_style.border_width_top = 2
	btn_start_style.border_width_right = 2
	btn_start_style.border_width_bottom = 2
	btn_start_style.border_color = Color(0.0, 0.98, 0.5, 1.0)
	btn_start_style.corner_radius_top_left = 8
	btn_start_style.corner_radius_top_right = 8
	btn_start_style.corner_radius_bottom_left = 8
	btn_start_style.corner_radius_bottom_right = 8
	_btn_start_hack.add_theme_stylebox_override("normal", btn_start_style)
	_btn_start_hack.add_theme_stylebox_override("hover", btn_start_style)

	# --- GAMEPLAY VBOX ---
	_gameplay_vbox = VBoxContainer.new()
	_gameplay_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_gameplay_vbox.visible = false
	left_col.add_child(_gameplay_vbox)

	# Command text to retype
	var cmd_instruct := Label.new()
	cmd_instruct.text = "Saisissez la commande terminal ci-dessous et appuyez sur ENTRÉE :"
	cmd_instruct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cmd_instruct.add_theme_font_size_override("font_size", 14)
	cmd_instruct.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	_gameplay_vbox.add_child(cmd_instruct)

	var left_spacer3 := Control.new()
	left_spacer3.custom_minimum_size = Vector2(0, 8)
	_gameplay_vbox.add_child(left_spacer3)

	_target_command_label = Label.new()
	_target_command_label.text = ""
	_target_command_label.add_theme_font_size_override("font_size", 20)
	_target_command_label.add_theme_color_override("font_color", Color(0.05, 0.98, 0.5, 1.0)) # matrix green
	_target_command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Glow effect for command label
	var cmd_box := PanelContainer.new()
	var cmd_box_style := StyleBoxFlat.new()
	cmd_box_style.bg_color = Color(0.02, 0.02, 0.03, 0.9)
	cmd_box_style.border_width_left = 1
	cmd_box_style.border_width_top = 1
	cmd_box_style.border_width_right = 1
	cmd_box_style.border_width_bottom = 1
	cmd_box_style.border_color = Color(0.05, 0.98, 0.5, 0.4)
	cmd_box_style.corner_radius_top_left = 6
	cmd_box_style.corner_radius_top_right = 6
	cmd_box_style.corner_radius_bottom_left = 6
	cmd_box_style.corner_radius_bottom_right = 6
	cmd_box.add_theme_stylebox_override("panel", cmd_box_style)
	cmd_box.custom_minimum_size = Vector2(0, 50)
	cmd_box.add_child(_target_command_label)
	_gameplay_vbox.add_child(cmd_box)

	var left_spacer4 := Control.new()
	left_spacer4.custom_minimum_size = Vector2(0, 16)
	_gameplay_vbox.add_child(left_spacer4)

	# Retype LineEdit Input
	_command_input = LineEdit.new()
	_command_input.placeholder_text = "> saisissez ici..."
	_command_input.custom_minimum_size = Vector2(0, 42)
	_command_input.add_theme_font_size_override("font_size", 16)
	_command_input.focus_mode = Control.FOCUS_ALL
	_command_input.caret_blink = true
	if "keep_editing_on_text_submit" in _command_input:
		_command_input.keep_editing_on_text_submit = true
	_command_input.text_submitted.connect(_on_command_submitted)
	_gameplay_vbox.add_child(_command_input)

	# Style input field
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.02, 0.02, 0.04, 0.9)
	input_style.border_width_left = 2
	input_style.border_width_top = 2
	input_style.border_width_right = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.0, 0.94, 1.0, 0.7)
	input_style.corner_radius_top_left = 6
	input_style.corner_radius_top_right = 6
	input_style.corner_radius_bottom_left = 6
	input_style.corner_radius_bottom_right = 6
	_command_input.add_theme_stylebox_override("normal", input_style)
	_command_input.add_theme_stylebox_override("focus", input_style)

	# Force LineEdit focus retention
	_command_input.focus_exited.connect(func():
		await get_tree().process_frame
		if _hack_mode and _hack_started and not _game_over and is_instance_valid(_command_input):
			_command_input.call_deferred("grab_focus")
	)

	var left_spacer5 := Control.new()
	left_spacer5.custom_minimum_size = Vector2(0, 12)
	_gameplay_vbox.add_child(left_spacer5)

	var cancel_lbl := Label.new()
	cancel_lbl.text = "[Échap] pour abandonner le piratage"
	cancel_lbl.add_theme_font_size_override("font_size", 12)
	cancel_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_gameplay_vbox.add_child(cancel_lbl)

	# Separator column spacer
	var col_spacer := Control.new()
	col_spacer.custom_minimum_size = Vector2(24, 0)
	_hack_container.add_child(col_spacer)

	# Right Column: scrolling terminal logs
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.0
	_hack_container.add_child(right_col)

	var log_title := Label.new()
	log_title.text = "CONSOLE DE LOGS D'INFILTRATION"
	log_title.add_theme_font_size_override("font_size", 12)
	log_title.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	right_col.add_child(log_title)

	# RichTextLabel for scrolling console logs
	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.bbcode_enabled = true
	_log_label.add_theme_font_size_override("normal_font_size", 12)
	_log_label.text = "[color=#00f0ff]SYSTEM INFILTRATION CONSOLE v4.6[/color]\n[color=#888899]En attente de commandes de dérivation...[/color]\n"
	right_col.add_child(_log_label)

	var log_panel_style := StyleBoxFlat.new()
	log_panel_style.bg_color = Color(0.02, 0.02, 0.04, 0.95)
	log_panel_style.border_width_left = 1
	log_panel_style.border_width_top = 1
	log_panel_style.border_width_right = 1
	log_panel_style.border_width_bottom = 1
	log_panel_style.border_color = Color(0.0, 0.94, 1.0, 0.25)
	log_panel_style.corner_radius_top_left = 6
	log_panel_style.corner_radius_top_right = 6
	log_panel_style.corner_radius_bottom_left = 6
	log_panel_style.corner_radius_bottom_right = 6
	_log_label.add_theme_stylebox_override("normal", log_panel_style)

	_build_desktop_ui(content_area)

func _center_panel() -> void:
	if not _main_panel:
		return
	var vp_size := get_viewport().get_visible_rect().size
	_main_panel.position = (vp_size - _main_panel.size) / 2.0

func _on_connect_pressed() -> void:
	if _connecting:
		return
	_connecting = true
	_btn_connect.disabled = true
	_btn_connect.text = "CONNEXION EN COURS..."
	_status_message_label.text = "Vérification des informations d'identification..."
	_status_message_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))

	# Cyberpunk loading timer
	var load_timer = get_tree().create_timer(1.8)
	
	# Wait for loading
	await load_timer
	
	_connecting = false
	_status_message_label.text = "❌ ACCÈS REFUSÉ : SÉCURITÉ DU SYSTÈME ACTIVE. IDENTIFIANTS COMPROMIS."
	_status_message_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	
	# Pulsing alert sound
	_play_audio_fallback(false)
	
	_btn_connect.visible = false
	_btn_hack.visible = true

func _on_hack_pressed() -> void:
	_login_container.visible = false
	_hack_container.visible = true
	_hack_mode = true
	_hack_started = false
	_instructions_vbox.visible = true
	_gameplay_vbox.visible = false
	_timer_label.text = "TEMPS RESTANT : %.1fs (Suspendu)" % _time_left
	_timer_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_log_label.append_text("[color=#ff9900][ATTENTION] Mode dérivation de sécurité engagé...[/color]\n")
	_log_label.append_text("[color=#00ff66][OK] Détecteur de port actif: port 8080 ouvert.[/color]\n")
	_append_hacker_logs()

func _on_start_hack_pressed() -> void:
	if _game_over or not _hack_mode:
		return
	_hack_started = true
	_instructions_vbox.visible = false
	_gameplay_vbox.visible = true
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	
	_session_commands = _commands.duplicate()
	_session_commands.shuffle()
	
	_select_new_command()
	
	# Delay focus grabbing to ensure LineEdit is visible and fully interactive
	await get_tree().process_frame
	if is_instance_valid(_command_input):
		_command_input.call_deferred("grab_focus")
		
	_log_label.append_text("[color=#00ff66][OK] Compte à rebours de dérivation lancé ![/color]\n")
	_append_hacker_logs()

func _select_new_command() -> void:
	if _session_commands.is_empty():
		_session_commands = _commands.duplicate()
		_session_commands.shuffle()
	
	_current_command = _session_commands.pop_front()
	_target_command_label.text = _current_command
	_command_input.text = ""
	if is_instance_valid(_command_input):
		_command_input.call_deferred("grab_focus")

func _append_hacker_logs() -> void:
	var prefix_colors := [
		"#00f0ff", # Cyan
		"#00ff66", # Green
		"#ffcc00", # Warning Gold
		"#888899", # Gray
		"#ff33ff", # Purple/Magenta
	]
	
	var prefixes := [
		"SYS_LOG",
		"MEM_DUMP",
		"NET_SEC",
		"KERN_ERR",
		"ROOT_SHELL",
		"MALWARE_SHUNT",
		"GATEWAY",
		"CORRUPTION",
		"BYPASS",
		"PORT_SCAN",
		"INTRUSION",
	]
	
	var templates := [
		"OVERFLOW EXPLOIT SUCCESSFUL: Return address overwritten at 0x7FFF" + _get_hex_str(4),
		"Dumping registers: EAX=0x00000001 EBX=0x" + _get_hex_str(8) + " ECX=0x" + _get_hex_str(8),
		"Hijacking active TLS session handshake: bypass completed.",
		"Shunting signature check module: integrity override = TRUE.",
		"Spawned daemon process thread [PID: " + str(randi() % 9000 + 1000) + "] with UID 0.",
		"Tunneling raw TCP stream via compromised port 8080...",
		"Injecting custom payload (342 bytes) into instruction pointer EIP.",
		"Disabling kernel level audit daemon (auditd) successfully.",
		"Injecting decryption table into core memory matrix... done.",
		"Intrusive trace detected from 10.120." + str(randi() % 254 + 1) + "." + str(randi() % 254 + 1) + " -> routing shunted.",
		"Decrypting secure token: key=" + _get_hex_str(16) + " [OK]",
		"Establishing high-privilege shellcode wrapper around sub-process.",
		"Bypassing security token validation check on target gateway.",
		"Compromising stack frame structure to force arbitrary jump vector."
	]
	
	# Pick 2-3 random template lines
	var lines_count = randi() % 2 + 2 # 2 or 3 lines
	for i in range(lines_count):
		var pfx = prefixes[randi() % prefixes.size()]
		var col = prefix_colors[randi() % prefix_colors.size()]
		var body = templates[randi() % templates.size()]
		_log_label.append_text("[color=" + col + "][" + pfx + "][/color] " + body + "\n")

func _get_hex_str(length: int) -> String:
	var chars = "0123456789ABCDEF"
	var res = ""
	for i in range(length):
		res += chars[randi() % 16]
	return res

func _on_command_submitted(text: String) -> void:
	if _game_over or not _hack_mode or not _hack_started:
		return
		
	if text.strip_edges() == _current_command:
		_progress += 20.0
		_progress_bar.value = _progress
		
		# Play typing click sound
		_play_audio_fallback(true)
		
		# Log terminal lines scrolling
		_log_label.append_text("> " + _current_command + " [color=#00ff66][REUSSI][/color]\n")
		_append_hacker_logs()
		
		if _progress >= 100.0:
			_trigger_win()
		else:
			_select_new_command()
	else:
		# Incorrect command feedback
		_log_label.append_text("> " + text + " [color=#ff3333][ERREUR: Echec de dérivation][/color]\n")
		_command_input.text = ""
		# Blink input container red
		var flash_tween = create_tween()
		flash_tween.tween_property(_command_input, "modulate", Color(1.0, 0.4, 0.4), 0.1)
		flash_tween.tween_property(_command_input, "modulate", Color(1.0, 1.0, 1.0), 0.1)
		_play_audio_fallback(false)

	# Keep focus so player can type immediately
	if not _game_over:
		if is_instance_valid(_command_input):
			_command_input.call_deferred("grab_focus")

func _process(delta: float) -> void:
	if _game_over or not _hack_mode or not _hack_started:
		return
		
	# Force focus bulletproofly every frame during gameplay
	if is_instance_valid(_command_input) and not _command_input.has_focus():
		_command_input.call_deferred("grab_focus")
		
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_trigger_fail()
		
	_timer_label.text = "TEMPS RESTANT : %.1fs" % _time_left

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# User pressed ESC
		get_viewport().set_input_as_handled()
		_trigger_fail()

func _trigger_win() -> void:
	_game_over = true
	_command_input.editable = false
	_timer_label.text = "ACCÈS ACCORDÉ"
	_timer_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	_target_command_label.text = "ACCÈS ACCORDÉ - SESSION ADMINISTRATEUR OUVERTE"
	_target_command_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0))
	_log_label.append_text("\n[color=#00ff00][SUCCÈS] Session d'administration établie ![/color]\n")
	_log_label.append_text("[color=#00ff00][SYS] Lancement du serveur d'affichage...[/color]\n")
	_log_label.append_text("[color=#00ff00][SYS] Chargement du bureau DistortionOS...[/color]\n")
	
	# Win visual feedback flashing
	var flash_panel = create_tween().set_loops(2)
	flash_panel.tween_property(_main_panel, "theme_override_styles/panel:border_color", Color(0.0, 1.0, 0.0, 1.0), 0.15)
	flash_panel.tween_property(_main_panel, "theme_override_styles/panel:border_color", Color(0.0, 0.94, 1.0, 0.9), 0.15)

	await get_tree().create_timer(1.2).timeout
	
	# Transition to desktop
	_hack_container.visible = false
	_desktop_container.visible = true

func _trigger_fail() -> void:
	_extra_time_bonus += 20.0 # increase bonus time on failure
	_game_over = true
	_command_input.editable = false
	_timer_label.text = "TEMPS RESTANT : 0.0s"
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	_target_command_label.text = "SÉCURITÉ DU SYSTÈME ACTIVÉE - ACCÈS VERROUILLÉ"
	_target_command_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
	_log_label.append_text("\n[color=#ff0000][ÉCHEC] Détection d'infiltration. Déconnexion forcée.[/color]\n")
	_log_label.append_text("[color=#ff0000][CRITIQUE] Clé de chiffrement perdue.[/color]\n")
	
	# Fail visual feedback flashing
	var flash_panel = create_tween().set_loops(3)
	flash_panel.tween_property(_main_panel, "theme_override_styles/panel:border_color", Color(1.0, 0.0, 0.0, 1.0), 0.2)
	flash_panel.tween_property(_main_panel, "theme_override_styles/panel:border_color", Color(0.5, 0.0, 0.0, 1.0), 0.2)

	await get_tree().create_timer(2.2).timeout
	done.emit(false)
	queue_free()

func _build_desktop_ui(content_area: Control) -> void:
	# -------------------- SCREEN 3: DESKTOP SCREEN --------------------
	_desktop_container = Panel.new()
	_desktop_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_container.visible = false
	content_area.add_child(_desktop_container)

	var desktop_style := StyleBoxFlat.new()
	desktop_style.bg_color = Color(0.04, 0.08, 0.15, 0.95) # Classic OS blue background
	desktop_style.corner_radius_top_left = 12
	desktop_style.corner_radius_top_right = 12
	desktop_style.corner_radius_bottom_left = 12
	desktop_style.corner_radius_bottom_right = 12
	_desktop_container.add_theme_stylebox_override("panel", desktop_style)

	var desktop_layout := VBoxContainer.new()
	desktop_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_container.add_child(desktop_layout)

	# Desktop Header (top bar)
	var top_bar := PanelContainer.new()
	var top_bar_style := StyleBoxFlat.new()
	top_bar_style.bg_color = Color(0.02, 0.04, 0.08, 0.9)
	top_bar.add_theme_stylebox_override("panel", top_bar_style)
	top_bar.custom_minimum_size = Vector2(0, 30)
	desktop_layout.add_child(top_bar)

	var top_bar_layout := HBoxContainer.new()
	top_bar.add_child(top_bar_layout)
	
	var os_title := Label.new()
	os_title.text = "   💻 DistortionOS v1.0 - Bureau d'administration"
	os_title.add_theme_font_size_override("font_size", 12)
	os_title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	top_bar_layout.add_child(os_title)

	var desktop_main := Control.new()
	desktop_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desktop_layout.add_child(desktop_main)

	var desktop_center := CenterContainer.new()
	desktop_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desktop_main.add_child(desktop_center)

	# Admin window inside the CenterContainer
	var admin_window := PanelContainer.new()
	admin_window.custom_minimum_size = Vector2(480, 260)
	
	var win_style := StyleBoxFlat.new()
	win_style.bg_color = Color(0.08, 0.1, 0.18, 0.98)
	win_style.border_width_left = 2
	win_style.border_width_top = 2
	win_style.border_width_right = 2
	win_style.border_width_bottom = 2
	win_style.border_color = Color(0.0, 0.5, 0.8, 1.0)
	win_style.corner_radius_top_left = 6
	win_style.corner_radius_top_right = 6
	win_style.corner_radius_bottom_left = 6
	win_style.corner_radius_bottom_right = 6
	admin_window.add_theme_stylebox_override("panel", win_style)
	desktop_center.add_child(admin_window)

	var win_layout := VBoxContainer.new()
	admin_window.add_child(win_layout)

	var win_header := PanelContainer.new()
	var win_header_style := StyleBoxFlat.new()
	win_header_style.bg_color = Color(0.0, 0.5, 0.8, 1.0)
	win_header_style.corner_radius_top_left = 4
	win_header_style.corner_radius_top_right = 4
	win_header.add_theme_stylebox_override("panel", win_header_style)
	win_header.custom_minimum_size = Vector2(0, 32)
	win_layout.add_child(win_header)

	var win_header_title := Label.new()
	win_header_title.text = "   CONTRÔLE DES MISES À JOUR"
	win_header_title.add_theme_font_size_override("font_size", 13)
	win_header_title.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	win_header.add_child(win_header_title)

	var win_body := MarginContainer.new()
	win_body.add_theme_constant_override("margin_left", 24)
	win_body.add_theme_constant_override("margin_right", 24)
	win_body.add_theme_constant_override("margin_top", 20)
	win_body.add_theme_constant_override("margin_bottom", 20)
	win_layout.add_child(win_body)

	var win_body_layout := VBoxContainer.new()
	win_body_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	win_body.add_child(win_body_layout)

	_desktop_status_lbl = Label.new()
	_desktop_status_lbl.text = "Mise à jour globale du système : EN COURS"
	_desktop_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desktop_status_lbl.add_theme_font_size_override("font_size", 14)
	_desktop_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	win_body_layout.add_child(_desktop_status_lbl)

	var body_spacer := Control.new()
	body_spacer.custom_minimum_size = Vector2(0, 20)
	win_body_layout.add_child(body_spacer)

	_btn_switch = Button.new()
	_btn_switch.text = "🔴  DÉSACTIVER LA MISE A JOUR"
	_btn_switch.custom_minimum_size = Vector2(300, 50)
	_btn_switch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_btn_switch.focus_mode = Control.FOCUS_NONE
	_btn_switch.pressed.connect(_on_switch_pressed)
	win_body_layout.add_child(_btn_switch)

	_switch_style_on = StyleBoxFlat.new()
	_switch_style_on.bg_color = Color(0.7, 0.1, 0.1, 1.0)
	_switch_style_on.border_width_left = 2
	_switch_style_on.border_width_top = 2
	_switch_style_on.border_width_right = 2
	_switch_style_on.border_width_bottom = 2
	_switch_style_on.border_color = Color(1.0, 0.3, 0.3, 1.0)
	_switch_style_on.corner_radius_top_left = 25
	_switch_style_on.corner_radius_top_right = 25
	_switch_style_on.corner_radius_bottom_left = 25
	_switch_style_on.corner_radius_bottom_right = 25

	_switch_style_off = StyleBoxFlat.new()
	_switch_style_off.bg_color = Color(0.1, 0.6, 0.2, 1.0)
	_switch_style_off.border_width_left = 2
	_switch_style_off.border_width_top = 2
	_switch_style_off.border_width_right = 2
	_switch_style_off.border_width_bottom = 2
	_switch_style_off.border_color = Color(0.3, 1.0, 0.5, 1.0)
	_switch_style_off.corner_radius_top_left = 25
	_switch_style_off.corner_radius_top_right = 25
	_switch_style_off.corner_radius_bottom_left = 25
	_switch_style_off.corner_radius_bottom_right = 25

	_btn_switch.add_theme_stylebox_override("normal", _switch_style_on)
	_btn_switch.add_theme_stylebox_override("hover", _switch_style_on)

func _on_switch_pressed() -> void:
	if _switch_toggled:
		return
	_switch_toggled = true
	
	_btn_switch.text = "🟢  MISE A JOUR DESACTIVEE"
	_btn_switch.add_theme_stylebox_override("normal", _switch_style_off)
	_btn_switch.add_theme_stylebox_override("hover", _switch_style_off)
	_btn_switch.disabled = true
	
	_desktop_status_lbl.text = "Mise à jour globale du système : ARRÊTÉE ET DÉSACTIVÉE"
	_desktop_status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	
	# Play success beep sound
	_play_audio_fallback(true)
	
	# Flashing success borders on the window
	var flash_win = create_tween().set_loops(3)
	flash_win.tween_property(_btn_switch.get_parent().get_parent(), "theme_override_styles/panel:border_color", Color(0.3, 1.0, 0.5, 1.0), 0.2)
	flash_win.tween_property(_btn_switch.get_parent().get_parent(), "theme_override_styles/panel:border_color", Color(0.0, 0.5, 0.8, 1.0), 0.2)
	
	await get_tree().create_timer(1.8).timeout
	_trigger_win_desktop()

func _trigger_win_desktop() -> void:
	_extra_time_bonus = 0.0 # reset bonus time on success
	done.emit(true)
	queue_free()

func _play_audio_fallback(success: bool) -> void:
	# Load crochetage or simple system beep sounds as substitutes if they exist
	var audio_path = "res://audio/mini_jeux/crochetage_success.wav" if success else "res://audio/mini_jeux/crochetage_fail.wav"
	if not FileAccess.file_exists(audio_path):
		audio_path = "res://audio/mini_jeux/marchandage_negocier.wav"
		if not FileAccess.file_exists(audio_path):
			return # No fallbacks available

	var player = AudioStreamPlayer.new()
	var stream = load(audio_path)
	if stream:
		player.stream = stream
		player.bus = "SFX"
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
