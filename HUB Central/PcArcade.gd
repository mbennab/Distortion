extends Node2D

var _player_nearby := false
var _prompt_label: Label

func _ready() -> void:
	var area := Area2D.new()
	area.name = "Area2D"
	area.collision_mask = 1
	add_child(area)

	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(200, 200)
	area.add_child(shape)

	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	_setup_prompt()

func _setup_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "Appuyez sur E pour l'Arcade"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_prompt_label.visible = false
	_prompt_label.z_index = 100
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.06, 0.12, 0.06, 0.85)
	pstyle.border_color = Color(0.2, 0.8, 0.3, 0.7)
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	_prompt_label.add_theme_stylebox_override("normal", pstyle)
	_prompt_label.custom_minimum_size = Vector2(300, 40)
	add_child(_prompt_label)
	queue_redraw()

func _draw() -> void:
	var mw := 50.0
	var mh := 60.0
	var mx := -mw / 2.0
	var my := -mh / 2.0 - 20.0
	draw_rect(Rect2(mx, my, mw, mh), Color(0.15, 0.15, 0.18))
	draw_rect(Rect2(mx + 4, my + 4, mw - 8, mh - 12), Color(0.02, 0.12, 0.06))
	draw_rect(Rect2(mx + 8, my + 16, 12, 3), Color(0.0, 0.7, 0.25))
	draw_rect(Rect2(mx + 8, my + 22, 16, 3), Color(0.0, 0.7, 0.25))
	draw_rect(Rect2(mx + 8, my + 28, 8, 3), Color(0.0, 0.7, 0.25))
	var stand_w := 8.0
	var stand_h := 16.0
	draw_rect(Rect2(-stand_w / 2.0, my + mh, stand_w, stand_h), Color(0.12, 0.12, 0.15))
	var base_w := 32.0
	var base_h := 4.0
	draw_rect(Rect2(-base_w / 2.0, my + mh + stand_h, base_w, base_h), Color(0.1, 0.1, 0.12))
	draw_rect(Rect2(mx, my, mw, mh), Color(0.15, 0.15, 0.18), false, 2.0)

func _update_prompt_position() -> void:
	_prompt_label.position = Vector2(-_prompt_label.size.x / 2.0, -120)

func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(body) and body.name == "TimeAunote":
		_player_nearby = true
		_prompt_label.visible = true
		await get_tree().process_frame
		if not is_inside_tree():
			return
		_update_prompt_position()

func _on_body_exited(body: Node2D) -> void:
	if is_instance_valid(body) and body.name == "TimeAunote":
		_player_nearby = false
		_prompt_label.visible = false

func _input(event: InputEvent) -> void:
	if event.is_echo() or not _player_nearby:
		return
	if event.is_action_pressed("interagir"):
		var hub := get_parent()
		if hub and hub.has_method("_open_arcade_menu"):
			_prompt_label.visible = false
			hub.call("_open_arcade_menu")
			get_viewport().set_input_as_handled()
