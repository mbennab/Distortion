extends CanvasLayer

# ========================
# DialogueUI - overlay
# ========================

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


func _ready() -> void:
	_setup_ui()
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

	# Prompt "Appuyez sur E"
	prompt_label = Label.new()
	prompt_label.text = "Appuyez sur E pour parler"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.modulate = Color(1, 1, 1, 0.85)
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 0.82
	prompt_label.anchor_bottom = 0.82
	prompt_label.offset_left = -200
	prompt_label.offset_right = 200
	prompt_label.offset_top = 0
	prompt_label.offset_bottom = 40
	prompt_label.visible = false
	root_control.add_child(prompt_label)

	# Main dialogue panel
	var panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -220
	panel.offset_bottom = 220
	panel.visible = false
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
	panel.add_theme_stylebox_override("panel", panel_style)
	root_control.add_child(panel)
	# Give panel a name so we can reference it
	panel.name = "DialoguePanel"

	# Close button (top right of panel)
	close_button = Button.new()
	close_button.text = "✕"
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -36
	close_button.offset_right = -8
	close_button.offset_top = 8
	close_button.offset_bottom = 36
	close_button.flat = true
	close_button.pressed.connect(_on_close_pressed)
	panel.add_child(close_button)

	# Status label (shows NPC name)
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
	panel.add_child(status_label)

	# Scroll area for chat history
	scroll = ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 40
	scroll.offset_bottom = -52
	panel.add_child(scroll)

	# Chat messages container
	chat_container = VBoxContainer.new()
	chat_container.size_flags_horizontal = Control.SIZE_FILL
	chat_container.custom_minimum_size = Vector2(600, 0)
	chat_container.add_theme_constant_override("separation", 8)
	scroll.add_child(chat_container)

	# Input container
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
	panel.add_child(input_container)

	# Text input
	input_line = LineEdit.new()
	input_line.placeholder_text = "Écrivez votre message..."
	input_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_line.text_submitted.connect(_on_text_submitted)
	input_container.add_child(input_line)

	# Send button
	send_button = Button.new()
	send_button.text = "Envoyer"
	send_button.pressed.connect(_on_send_pressed)
	input_container.add_child(send_button)


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
	prompt_label.text = "Appuyez sur E pour parler à %s" % npc_name


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
	var panel = root_control.get_node_or_null("DialoguePanel")
	if panel:
		panel.visible = false
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
	var panel = root_control.get_node_or_null("DialoguePanel")
	if panel:
		panel.visible = true
	status_label.text = npc_name
	clear_chat()
	input_line.text = ""
	input_line.editable = true
	input_line.grab_focus()
	# Find the PNJ node in the scene tree
	for node in get_tree().get_nodes_in_group("npc_dialogue"):
		if node.npc_id == npc_id:
			current_pnj_node = node
			break


func _on_dialogue_ended() -> void:
	if current_pnj_node and current_pnj_node.has_method("hide_bubble"):
		current_pnj_node.hide_bubble()
	current_pnj_node = null
	hide_all()


func _on_dialogue_response(npc_name: String, text: String) -> void:
	_add_message(npc_name, text, true)
	current_state = State.ACTIVE
	input_line.editable = true
	input_line.text = ""
	input_line.grab_focus()


func _on_dialogue_error(message: String) -> void:
	_add_message("Système", message, false, Color(1, 0.3, 0.3))
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

	# Scroll to bottom
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
