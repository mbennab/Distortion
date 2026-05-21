extends CanvasLayer

signal done(success: bool)

enum Phase { SHOWING, PLAYING, ROUND_TRANSITION, FAILURE, SUCCESS, EXITING }

const SWITCH_COUNT := 6
const SWITCH_WIDTH := 60.0
const SWITCH_HEIGHT := 120.0
const SWITCH_GAP := 20.0
const SEQUENCE_LENGTH := 4
const SHOW_SPEED := 0.7

var _phase: int = Phase.SHOWING
var _sequence: Array = []
var _player_index: int = 0
var _switch_nodes: Array = []
var _lever_nodes: Array = []
var _label_nodes: Array = []
var _current_flash: int = -1
var _round_number: int = 1
var _total_rounds: int = 3
var _dynamic_nodes: Array = []
var _bg: ColorRect
var _title_label: Label
var _status_label: Label
var _round_label: Label
var _retry_btn: Button
var _show_index: int = 0
var _show_timer: float = 0.0
var _lever_base_y: float = 0.0


func _ready() -> void:
	layer = 129
	_init_round(1)


func _init_round(round_num: int) -> void:
	_round_number = round_num
	_phase = Phase.SHOWING
	_current_flash = -1
	_player_index = 0
	_generate_sequence()
	_clear_dynamic_nodes()
	_build_ui()


func _generate_sequence() -> void:
	_sequence.clear()
	var seq_len := SEQUENCE_LENGTH + (_round_number - 1)
	for i in range(seq_len):
		var val := randi() % SWITCH_COUNT
		_sequence.append(val)


func _clear_dynamic_nodes() -> void:
	for node in _dynamic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_dynamic_nodes.clear()
	_switch_nodes.clear()
	_lever_nodes.clear()
	_label_nodes.clear()


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.02, 0.04, 0.98)
	_bg.size = vp
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_dynamic_nodes.append(_bg)

	var title_bg := ColorRect.new()
	title_bg.color = Color(0.03, 0.04, 0.07, 0.95)
	title_bg.position = Vector2(0, 0)
	title_bg.size = Vector2(vp.x, 80)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)
	_dynamic_nodes.append(title_bg)

	_round_label = Label.new()
	_round_label.text = "PANNEAU " + str(_round_number) + " / " + str(_total_rounds)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 13)
	_round_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_round_label.position = Vector2(0, 6)
	_round_label.size = Vector2(vp.x, 20)
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_round_label)
	_dynamic_nodes.append(_round_label)

	_title_label = Label.new()
	_title_label.text = "Reenclenchez les disjoncteurs"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_title_label.position = Vector2(0, 28)
	_title_label.size = Vector2(vp.x, 40)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)
	_dynamic_nodes.append(_title_label)

	_status_label = Label.new()
	_status_label.text = "Observez la sequence..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_status_label.position = Vector2(0, vp.y - 80)
	_status_label.size = Vector2(vp.x, 30)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	_dynamic_nodes.append(_status_label)

	var total_switch_w := SWITCH_COUNT * SWITCH_WIDTH + (SWITCH_COUNT - 1) * SWITCH_GAP
	var start_x := (vp.x - total_switch_w) / 2.0
	var switch_y := vp.y / 2.0 - 40.0

	var panel_margin := 16.0
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	panel_style.border_color = Color(0.2, 0.3, 0.4, 0.5)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(start_x - panel_margin - 10, switch_y - panel_margin - 30)
	panel.size = Vector2(total_switch_w + panel_margin * 2 + 20, SWITCH_HEIGHT + panel_margin * 2 + 80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_dynamic_nodes.append(panel)

	_switch_nodes.clear()
	_lever_nodes.clear()
	_label_nodes.clear()
	_switch_nodes.resize(SWITCH_COUNT)
	_lever_nodes.resize(SWITCH_COUNT)
	_label_nodes.resize(SWITCH_COUNT)
	_lever_base_y = switch_y + SWITCH_HEIGHT - 24

	for i in range(SWITCH_COUNT):
		var x := start_x + i * (SWITCH_WIDTH + SWITCH_GAP)
		var switch_bg := ColorRect.new()
		switch_bg.color = Color(0.1, 0.12, 0.16)
		switch_bg.position = Vector2(x, switch_y)
		switch_bg.size = Vector2(SWITCH_WIDTH, SWITCH_HEIGHT)
		switch_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(switch_bg)
		_dynamic_nodes.append(switch_bg)
		_switch_nodes[i] = switch_bg

		var border := ColorRect.new()
		border.color = Color(0.25, 0.3, 0.35, 0.5)
		border.position = Vector2(x - 1, switch_y - 1)
		border.size = Vector2(SWITCH_WIDTH + 2, SWITCH_HEIGHT + 2)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(border)
		border.z_index = -1
		_dynamic_nodes.append(border)

		var slot_top := ColorRect.new()
		slot_top.color = Color(0.05, 0.06, 0.08)
		slot_top.position = Vector2(x + 8, switch_y + 8)
		slot_top.size = Vector2(SWITCH_WIDTH - 16, SWITCH_HEIGHT - 16)
		slot_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot_top)
		_dynamic_nodes.append(slot_top)

		var lever := ColorRect.new()
		lever.color = Color(0.5, 0.15, 0.1)
		lever.position = Vector2(x + 8, switch_y + SWITCH_HEIGHT - 24)
		lever.size = Vector2(SWITCH_WIDTH - 16, 16)
		lever.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lever)
		_dynamic_nodes.append(lever)
		_lever_nodes[i] = lever

		var num_label := Label.new()
		num_label.text = str(i + 1)
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 14)
		num_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		num_label.position = Vector2(x, switch_y + SWITCH_HEIGHT + 4)
		num_label.size = Vector2(SWITCH_WIDTH, 22)
		num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(num_label)
		_dynamic_nodes.append(num_label)
		_label_nodes[i] = num_label

	var hint_label := Label.new()
	hint_label.text = "Cliquez sur les disjoncteurs dans l'ordre  |  ESC : quitter"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.35, 0.4, 0.45))
	hint_label.position = Vector2(0, vp.y - 30)
	hint_label.size = Vector2(vp.x, 18)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_label)
	_dynamic_nodes.append(hint_label)

	_retry_btn = Button.new()
	_retry_btn.text = ">>  Reessayer"
	_retry_btn.position = Vector2(vp.x / 2.0 - 120, vp.y - 80)
	_retry_btn.size = Vector2(240, 48)
	_retry_btn.add_theme_font_size_override("font_size", 17)
	var retry_style := StyleBoxFlat.new()
	retry_style.bg_color = Color(0.55, 0.18, 0.08)
	retry_style.border_color = Color(0.8, 0.35, 0.15)
	retry_style.set_border_width_all(2)
	retry_style.set_corner_radius_all(10)
	_retry_btn.add_theme_stylebox_override("normal", retry_style)
	var retry_hover := retry_style.duplicate()
	retry_hover.bg_color = Color(0.65, 0.25, 0.1)
	_retry_btn.add_theme_stylebox_override("hover", retry_hover)
	var retry_pressed := retry_style.duplicate()
	retry_pressed.bg_color = Color(0.4, 0.12, 0.05)
	_retry_btn.add_theme_stylebox_override("pressed", retry_pressed)
	_retry_btn.pressed.connect(_on_retry)
	_retry_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_retry_btn.visible = false
	add_child(_retry_btn)
	_dynamic_nodes.append(_retry_btn)

	_phase = Phase.SHOWING
	_show_index = 0
	_show_timer = 0.0


func _process(delta: float) -> void:
	if _phase == Phase.SHOWING:
		_process_showing(delta)


func _process_showing(delta: float) -> void:
	_show_timer += delta

	if _current_flash >= 0 and _show_timer > SHOW_SPEED * 0.6:
		_deactivate_switch(_current_flash)
		_current_flash = -1

	if _current_flash < 0 and _show_timer >= SHOW_SPEED:
		if _show_index < _sequence.size():
			_current_flash = _sequence[_show_index]
			_activate_switch(_current_flash)
			_show_timer = 0.0
			_show_index += 1
		else:
			_phase = Phase.PLAYING
			_player_index = 0
			_status_label.text = "A vous ! Reproduisez la sequence"
			_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
			for i in range(SWITCH_COUNT):
				var lbl: Label = _label_nodes[i]
				lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))


func _activate_switch(index: int) -> void:
	if index < 0 or index >= SWITCH_COUNT:
		return
	var bg: ColorRect = _switch_nodes[index]
	bg.color = Color(0.15, 0.65, 0.3)
	var lever: ColorRect = _lever_nodes[index]
	lever.color = Color(0.2, 0.9, 0.4)
	lever.position.y = _lever_base_y - 50
	var lbl: Label = _label_nodes[index]
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))


func _deactivate_switch(index: int) -> void:
	if index < 0 or index >= SWITCH_COUNT:
		return
	var bg: ColorRect = _switch_nodes[index]
	bg.color = Color(0.1, 0.12, 0.16)
	var lever: ColorRect = _lever_nodes[index]
	lever.color = Color(0.5, 0.15, 0.1)
	lever.position.y = _lever_base_y
	var lbl: Label = _label_nodes[index]
	lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _phase == Phase.EXITING:
			return
		get_viewport().set_input_as_handled()
		_phase = Phase.EXITING
		done.emit(false)
		queue_free()
		return

	if _phase != Phase.PLAYING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var vp := get_viewport().get_visible_rect().size
		var total_sw_w := SWITCH_COUNT * SWITCH_WIDTH + (SWITCH_COUNT - 1) * SWITCH_GAP
		var start_x := (vp.x - total_sw_w) / 2.0
		var sw_y := vp.y / 2.0 - 40.0

		for i in range(SWITCH_COUNT):
			var sx := start_x + i * (SWITCH_WIDTH + SWITCH_GAP)
			if event.position.x >= sx and event.position.x <= sx + SWITCH_WIDTH \
				and event.position.y >= sw_y and event.position.y <= sw_y + SWITCH_HEIGHT:
				get_viewport().set_input_as_handled()
				_on_switch_clicked(i)
				break


func _on_switch_clicked(index: int) -> void:
	if _player_index >= _sequence.size():
		return

	var expected: int = _sequence[_player_index]
	if index == expected:
		_player_index += 1
		_flash_correct(index)
		if _player_index >= _sequence.size():
			_on_round_complete()
	else:
		_flash_error(index)


func _flash_correct(index: int) -> void:
	var bg: ColorRect = _switch_nodes[index]
	bg.color = Color(0.1, 0.55, 0.25)
	var lever: ColorRect = _lever_nodes[index]
	lever.color = Color(0.2, 0.85, 0.35)

	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.08, 0.35, 0.18), 0.4)
	var lever_tween := create_tween()
	lever_tween.tween_property(lever, "color", Color(0.15, 0.55, 0.2), 0.4)


func _flash_error(index: int) -> void:
	_phase = Phase.FAILURE
	_status_label.text = "Mauvais disjoncteur !"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	var bg: ColorRect = _switch_nodes[index]
	var orig_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.7, 0.05, 0.05), 0.1)
	tween.tween_property(bg, "color", orig_color, 0.1)
	tween.tween_property(bg, "color", Color(0.7, 0.05, 0.05), 0.1)
	tween.tween_property(bg, "color", orig_color, 0.1)

	var bg_tween := create_tween()
	bg_tween.tween_property(_bg, "color", Color(0.15, 0.02, 0.02, 0.98), 0.15)
	bg_tween.tween_property(_bg, "color", Color(0.02, 0.02, 0.04, 0.98), 0.15)
	bg_tween.tween_property(_bg, "color", Color(0.15, 0.02, 0.02, 0.98), 0.15)
	bg_tween.tween_property(_bg, "color", Color(0.02, 0.02, 0.04, 0.98), 0.15)

	_retry_btn.visible = true


func _on_retry() -> void:
	if _phase != Phase.FAILURE:
		return
	_retry_btn.visible = false
	_bg.color = Color(0.02, 0.02, 0.04, 0.98)
	_init_round(_round_number)


func _on_round_complete() -> void:
	if _round_number >= _total_rounds:
		_on_all_complete()
		return

	_phase = Phase.ROUND_TRANSITION
	_status_label.text = "Panneau " + str(_round_number) + " reenclenche !"
	_status_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(_next_round)


func _next_round() -> void:
	_init_round(_round_number + 1)


func _on_all_complete() -> void:
	_phase = Phase.SUCCESS
	_status_label.text = "Electricite retablie !"
	_status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

	var vp := get_viewport().get_visible_rect().size
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.95, 1.0, 0.0)
	flash.size = vp
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_dynamic_nodes.append(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.8, 0.3).set_trans(Tween.TRANS_SINE)
	flash_tween.tween_property(flash, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)

	for i in range(SWITCH_COUNT):
		var bg: ColorRect = _switch_nodes[i]
		bg.color = Color(0.15, 0.6, 0.3)
		var lbl: Label = _label_nodes[i]
		lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

	var success_tween := create_tween()
	success_tween.tween_interval(2.5)
	success_tween.tween_callback(_finish)


func _finish() -> void:
	_phase = Phase.EXITING
	done.emit(true)
	queue_free()
