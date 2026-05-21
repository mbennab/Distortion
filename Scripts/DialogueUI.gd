extends CanvasLayer

enum State { HIDDEN, PROMPT, ACTIVE, WAITING }

var current_state: State = State.HIDDEN
var nearby_npc_id: String = ""
var nearby_npc_name: String = ""
var current_npc_name: String = ""
var current_pnj_node: Node = null

var root_control: Control
var prompt_label: Label

var chat_container: VBoxContainer
var scroll: ScrollContainer
var input_line: LineEdit
var send_button: Button
var close_button: Button
var status_label: Label
var normal_panel: Panel

var retro_mode: bool = false
var retro_container: Control
var retro_msg_scroll: ScrollContainer
var retro_portrait: TextureRect
var retro_name_label: Label
var retro_message_label: Label
var retro_input_line: LineEdit
var typewriter_timer: Timer
var typewriter_full_text: String = ""
var typewriter_char_index: int = 0
var is_animating: bool = false
var typewriter_callback: Callable = Callable()

var _generic_portrait: ImageTexture


func _ready() -> void:
	_setup_ui()
	_setup_retro_ui()
	_generic_portrait = _create_generic_portrait()
	hide_all()
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.dialogue_response.connect(_on_dialogue_response)
	DialogueSystem.dialogue_error.connect(_on_dialogue_error)


func _setup_ui() -> void:
	root_control = Control.new()
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	add_child(root_control)

	prompt_label = Label.new()
	prompt_label.text = "Appuyez sur E pour parler"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	pstyle.border_color = Color(0.6, 0.55, 0.3, 0.7)
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	prompt_label.add_theme_stylebox_override("normal", pstyle)
	prompt_label.custom_minimum_size = Vector2(340, 40)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.82
	prompt_label.anchor_bottom = 0.82
	prompt_label.offset_left = -170
	prompt_label.offset_right = 170
	prompt_label.offset_top = 0
	prompt_label.offset_bottom = 0
	prompt_label.visible = false
	root_control.add_child(prompt_label)

	normal_panel = Panel.new()
	normal_panel.anchor_left = 0.5
	normal_panel.anchor_right = 0.5
	normal_panel.anchor_top = 0.5
	normal_panel.anchor_bottom = 0.5
	normal_panel.offset_left = -320
	normal_panel.offset_right = 320
	normal_panel.offset_top = -220
	normal_panel.offset_bottom = 220
	normal_panel.visible = false
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.06, 0.12, 0.95)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0, 0.9, 1, 0.4)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	normal_panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(normal_panel)
	normal_panel.name = "DialoguePanel"

	close_button = Button.new()
	close_button.text = "X"
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -36
	close_button.offset_right = -8
	close_button.offset_top = 8
	close_button.offset_bottom = 36
	close_button.flat = true
	close_button.pressed.connect(_on_close_pressed)
	normal_panel.add_child(close_button)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0, 0.9, 1, 0.8))
	status_label.anchor_left = 0.0
	status_label.anchor_right = 1.0
	status_label.offset_left = 16
	status_label.offset_right = -48
	status_label.offset_top = 12
	status_label.offset_bottom = 32
	normal_panel.add_child(status_label)

	scroll = ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 40
	scroll.offset_bottom = -52
	normal_panel.add_child(scroll)

	chat_container = VBoxContainer.new()
	chat_container.size_flags_horizontal = Control.SIZE_FILL
	chat_container.custom_minimum_size = Vector2(600, 0)
	chat_container.add_theme_constant_override("separation", 8)
	scroll.add_child(chat_container)

	var input_container = HBoxContainer.new()
	input_container.anchor_left = 0.0
	input_container.anchor_right = 1.0
	input_container.anchor_top = 1.0
	input_container.anchor_bottom = 1.0
	input_container.offset_left = 12
	input_container.offset_right = -12
	input_container.offset_top = -46
	input_container.offset_bottom = -10
	input_container.add_theme_constant_override("separation", 8)
	normal_panel.add_child(input_container)

	input_line = LineEdit.new()
	input_line.placeholder_text = "Ecrivez votre message..."
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.text_submitted.connect(_on_text_submitted)
	input_container.add_child(input_line)

	send_button = Button.new()
	send_button.text = "Envoyer"
	send_button.pressed.connect(_on_send_pressed)
	input_container.add_child(send_button)


func _setup_retro_ui() -> void:
	retro_container = Control.new()
	retro_container.anchor_left = 0.05
	retro_container.anchor_right = 0.95
	retro_container.anchor_top = 0.62
	retro_container.anchor_bottom = 0.90
	retro_container.visible = false
	root_control.add_child(retro_container)

	var outer_style = StyleBoxFlat.new()
	outer_style.bg_color = Color(0, 0, 0, 0.85)
	outer_style.border_width_left = 3
	outer_style.border_width_right = 3
	outer_style.border_width_top = 3
	outer_style.border_width_bottom = 3
	outer_style.border_color = Color.BLACK
	var outer_panel = Panel.new()
	outer_panel.anchor_left = 0.0
	outer_panel.anchor_right = 1.0
	outer_panel.anchor_top = 0.0
	outer_panel.anchor_bottom = 1.0
	outer_panel.add_theme_stylebox_override("panel", outer_style)
	retro_container.add_child(outer_panel)

	var inner_style = StyleBoxFlat.new()
	inner_style.bg_color = Color(0.05, 0.05, 0.08, 0.88)
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.border_color = Color(0.9, 0.9, 0.9, 1)
	var inner_panel = Panel.new()
	inner_panel.anchor_left = 0.0
	inner_panel.anchor_right = 1.0
	inner_panel.anchor_top = 0.0
	inner_panel.anchor_bottom = 1.0
	inner_panel.offset_left = 3
	inner_panel.offset_right = -3
	inner_panel.offset_top = 3
	inner_panel.offset_bottom = -3
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	retro_container.add_child(inner_panel)

	# Discrete retro escape key indicator in top right
	var escape_font = SystemFont.new()
	escape_font.font_names = ["Courier New", "monospace"]

	var retro_escape_label = Label.new()
	retro_escape_label.text = "[esc] pour fermer"
	retro_escape_label.add_theme_font_override("font", escape_font)
	retro_escape_label.add_theme_font_size_override("font_size", 10)
	retro_escape_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 0.6))
	retro_escape_label.anchor_left = 1.0
	retro_escape_label.anchor_right = 1.0
	retro_escape_label.anchor_top = 0.0
	retro_escape_label.anchor_bottom = 0.0
	retro_escape_label.offset_left = -200
	retro_escape_label.offset_right = -12
	retro_escape_label.offset_top = 6
	retro_escape_label.offset_bottom = 26
	retro_escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner_panel.add_child(retro_escape_label)

	var hbox = HBoxContainer.new()
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.anchor_top = 0.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.offset_top = 10
	hbox.offset_bottom = -10
	hbox.add_theme_constant_override("separation", 16)
	inner_panel.add_child(hbox)

	retro_portrait = TextureRect.new()
	retro_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	retro_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	retro_portrait.custom_minimum_size = Vector2(0, 0)
	retro_portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	retro_portrait.size_flags_vertical = Control.SIZE_FILL
	retro_portrait.size_flags_stretch_ratio = 1.0
	hbox.add_child(retro_portrait)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_FILL
	vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox)

	var retro_font = SystemFont.new()
	retro_font.font_names = ["Courier New", "monospace"]

	retro_name_label = Label.new()
	retro_name_label.text = ""
	retro_name_label.add_theme_font_override("font", retro_font)
	retro_name_label.add_theme_font_size_override("font_size", 20)
	retro_name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	retro_name_label.add_theme_constant_override("outline_size", 1)
	retro_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	retro_name_label.size_flags_horizontal = Control.SIZE_FILL
	retro_name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(retro_name_label)

	var msg_font = SystemFont.new()
	msg_font.font_names = ["Courier New", "monospace"]

	retro_msg_scroll = ScrollContainer.new()
	retro_msg_scroll.size_flags_horizontal = Control.SIZE_FILL
	retro_msg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	retro_msg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	retro_msg_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(retro_msg_scroll)

	retro_message_label = Label.new()
	retro_message_label.text = ""
	retro_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retro_message_label.add_theme_font_override("font", msg_font)
	retro_message_label.add_theme_font_size_override("font_size", 15)
	retro_message_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 1))
	retro_message_label.add_theme_constant_override("line_spacing", 4)
	retro_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retro_message_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	retro_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	retro_msg_scroll.add_child(retro_message_label)

	var input_font = SystemFont.new()
	input_font.font_names = ["Courier New", "monospace"]

	retro_input_line = LineEdit.new()
	retro_input_line.placeholder_text = "> Ecrivez votre message..."
	retro_input_line.add_theme_font_override("font", input_font)
	retro_input_line.add_theme_font_size_override("font_size", 14)
	retro_input_line.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 0.9))
	retro_input_line.add_theme_color_override("placeholder_color", Color(0.4, 0.4, 0.5, 0.5))
	retro_input_line.add_theme_color_override("background_color", Color(0.0, 0.0, 0.0, 0.0))
	var input_style = StyleBoxEmpty.new()
	retro_input_line.add_theme_stylebox_override("normal", input_style)
	retro_input_line.add_theme_stylebox_override("focus", input_style)
	retro_input_line.add_theme_stylebox_override("read_only", input_style)
	retro_input_line.size_flags_horizontal = Control.SIZE_FILL
	retro_input_line.size_flags_vertical = Control.SIZE_SHRINK_END
	retro_input_line.caret_blink = true
	retro_input_line.max_length = 120
	retro_input_line.text_submitted.connect(_on_retro_input_submitted)
	vbox.add_child(retro_input_line)

	typewriter_timer = Timer.new()
	typewriter_timer.one_shot = false
	typewriter_timer.timeout.connect(_on_typewriter_tick)
	typewriter_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(typewriter_timer)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if event.is_action_pressed("interagir"):
		match current_state:
			State.PROMPT:
				if nearby_npc_id != "":
					DialogueSystem.start_dialogue(nearby_npc_id)
					get_viewport().set_input_as_handled()
			State.ACTIVE, State.WAITING:
				pass
			State.HIDDEN:
				pass

	if event.is_action_pressed("ui_cancel"):
		if current_state == State.ACTIVE or current_state == State.WAITING:
			close_dialogue()
			get_viewport().set_input_as_handled()


func show_prompt(npc_id: String, npc_name: String) -> void:
	nearby_npc_id = npc_id
	nearby_npc_name = npc_name
	if current_state == State.ACTIVE or current_state == State.WAITING:
		return
	current_state = State.PROMPT
	prompt_label.visible = true
	prompt_label.text = "Appuyez sur E pour parler a %s" % npc_name


func hide_prompt() -> void:
	if current_state != State.PROMPT:
		return
	current_state = State.HIDDEN
	nearby_npc_id = ""
	nearby_npc_name = ""
	prompt_label.visible = false


func close_dialogue() -> void:
	DialogueSystem.stop_dialogue()


func is_dialogue_active() -> bool:
	return current_state == State.ACTIVE or current_state == State.WAITING


func hide_all() -> void:
	if typewriter_timer and typewriter_timer.is_inside_tree():
		typewriter_timer.stop()
	is_animating = false
	typewriter_full_text = ""

	normal_panel = root_control.get_node_or_null("DialoguePanel")
	if normal_panel:
		normal_panel.visible = false

	if retro_container:
		retro_container.visible = false

	prompt_label.visible = false
	current_state = State.HIDDEN
	nearby_npc_id = ""
	nearby_npc_name = ""


func clear_chat() -> void:
	for child in chat_container.get_children():
		child.queue_free()


func _on_dialogue_started(npc_id: String, npc_name: String) -> void:
	current_state = State.ACTIVE
	current_npc_name = npc_name
	prompt_label.visible = false

	for node in get_tree().get_nodes_in_group("npc_dialogue"):
		if node.npc_id == npc_id:
			current_pnj_node = node
			break

	retro_mode = true

	if npc_id == "npc_femme_parc":
		normal_panel.visible = false
		retro_container.visible = false
		return

	normal_panel.visible = false
	retro_container.visible = true
	retro_name_label.text = npc_name
	retro_message_label.text = ""
	retro_input_line.text = ""
	retro_input_line.editable = true

	var portrait_loaded := false
	if current_pnj_node != null:
		var pp: String = current_pnj_node.get("portrait_path") if current_pnj_node.get("portrait_path") != null else ""
		if pp != "" and ResourceLoader.exists(pp):
			retro_portrait.texture = load(pp)
			portrait_loaded = true
	if not portrait_loaded:
		retro_portrait.texture = _generic_portrait

	_set_portrait_size_from_container()

	var accroche: String = DialogueSystem.get_first_message()
	if accroche != "":
		_display_accroche(accroche)
	else:
		retro_input_line.grab_focus()


func _set_portrait_size_from_container() -> void:
	await get_tree().process_frame
	if not retro_container or not retro_container.visible:
		return
	var container_h = retro_container.size.y
	var portrait_size = int(container_h * 0.85)
	if portrait_size < 80:
		portrait_size = 80
	retro_portrait.custom_minimum_size = Vector2(portrait_size, portrait_size)


func _display_accroche(message: String) -> void:
	retro_input_line.editable = false
	retro_message_label.text = ""
	retro_input_line.grab_focus()
	_start_typewriter(message, _on_accroche_finished)


func _on_accroche_finished() -> void:
	retro_input_line.editable = true
	retro_input_line.grab_focus()


func _on_dialogue_ended() -> void:
	if typewriter_timer and typewriter_timer.is_inside_tree():
		typewriter_timer.stop()
	is_animating = false
	if current_pnj_node and current_pnj_node.has_method("hide_bubble"):
		current_pnj_node.hide_bubble()
	current_pnj_node = null
	hide_all()


func _on_dialogue_response(npc_name: String, text: String) -> void:
	if retro_mode:
		current_state = State.ACTIVE
		retro_input_line.editable = true
		retro_input_line.text = ""
		retro_input_line.grab_focus()
		_start_typewriter(text)
	else:
		_add_message(npc_name, text, true)
		current_state = State.ACTIVE
		input_line.editable = true
		input_line.text = ""
		input_line.grab_focus()


func _on_dialogue_error(message: String) -> void:
	if retro_mode:
		current_state = State.ACTIVE
		retro_input_line.editable = true
		retro_input_line.text = ""
		retro_input_line.grab_focus()
		_start_typewriter("[ERREUR] " + message)
	else:
		_add_message("Systeme", message, false, Color(1, 0.3, 0.3))
		current_state = State.ACTIVE
		input_line.editable = true
		input_line.text = ""
		input_line.grab_focus()


func _on_text_submitted(text: String) -> void:
	_send_message(text)


func _on_send_pressed() -> void:
	_send_message(input_line.text)


func _on_close_pressed() -> void:
	close_dialogue()


func _on_retro_input_submitted(text: String) -> void:
	var trimmed = text.strip_edges()

	if is_animating:
		_skip_typewriter()
		if is_animating:
			return

	if trimmed == "":
		return

	if current_state != State.ACTIVE:
		return

	retro_input_line.text = ""
	retro_input_line.editable = false
	current_state = State.WAITING

	if current_pnj_node and current_pnj_node.has_method("hide_bubble"):
		current_pnj_node.hide_bubble()

	_show_player_message(trimmed)


func _show_player_message(text: String) -> void:
	var wrapped = "> %s" % text
	var sent_text = text
	_start_typewriter(wrapped, func():
		retro_message_label.text = wrapped
		_scroll_retro_to_bottom()
		DialogueSystem.send_message(sent_text)
	)


func _send_message(text: String) -> void:
	var trimmed = text.strip_edges()
	if trimmed == "":
		return
	if current_state != State.ACTIVE:
		return

	if current_pnj_node and current_pnj_node.has_method("hide_bubble"):
		current_pnj_node.hide_bubble()
	_add_message("Vous", trimmed, false)
	current_state = State.WAITING
	input_line.editable = false
	input_line.text = ""
	status_label.text = "En attente..."
	DialogueSystem.send_message(trimmed)


func _add_message(speaker: String, text: String, is_npc: bool, override_color: Color = Color.TRANSPARENT) -> void:
	var label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_FILL
	label.add_theme_font_size_override("font_size", 14)

	var color: Color
	if override_color != Color.TRANSPARENT:
		color = override_color
	elif is_npc:
		color = Color(0.3, 0.9, 1)
	else:
		color = Color(0.95, 0.95, 0.95)

	label.add_theme_color_override("font_color", color)
	label.text = "[%s] %s" % [speaker, text]
	chat_container.add_child(label)

	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _start_typewriter(text: String, callback: Callable = Callable()) -> void:
	if is_animating:
		typewriter_timer.stop()

	is_animating = true
	typewriter_full_text = text
	typewriter_char_index = 0
	typewriter_callback = callback
	retro_message_label.text = ""
	typewriter_timer.start(0.025)


func _on_typewriter_tick() -> void:
	if not retro_mode or not is_inside_tree():
		_skip_typewriter()
		return

	if typewriter_char_index < typewriter_full_text.length():
		var c = typewriter_full_text[typewriter_char_index]
		if c == "\n":
			var lines = retro_message_label.text.split("\n")
			retro_message_label.text = "\n".join(lines) + "\n"
		else:
			retro_message_label.text += c
		typewriter_char_index += 1
		_scroll_retro_to_bottom()
	else:
		typewriter_timer.stop()
		is_animating = false
		if typewriter_callback.is_valid():
			var cb = typewriter_callback
			typewriter_callback = Callable()
			cb.call()


func _skip_typewriter() -> void:
	if not is_animating:
		return
	typewriter_timer.stop()
	is_animating = false
	retro_message_label.text = typewriter_full_text
	_scroll_retro_to_bottom()
	if typewriter_callback.is_valid():
		var cb = typewriter_callback
		typewriter_callback = Callable()
		cb.call()


func _scroll_retro_to_bottom() -> void:
	if not retro_msg_scroll or not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(retro_msg_scroll):
		retro_msg_scroll.scroll_vertical = int(retro_msg_scroll.get_v_scroll_bar().max_value)


func _create_generic_portrait() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.12, 0.12, 0.18, 1))
	for y in range(15, 45):
		for x in range(44, 84):
			var dx := x - 64.0
			var dy := y - 30.0
			if dx * dx + dy * dy <= 14.0 * 14.0:
				img.set_pixel(x, y, Color(0.35, 0.35, 0.48, 1))
	for y in range(45, 110):
		var hw := int(26.0 - (y - 45) * 0.04)
		for x in range(64 - hw, 64 + hw):
			img.set_pixel(x, y, Color(0.3, 0.3, 0.42, 1))
	return ImageTexture.create_from_image(img)
