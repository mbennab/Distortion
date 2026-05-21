extends Node2D

signal return_to_couloir_requested

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var _active: bool = false
var _player_near_vetements: bool = false
var _player_near_couloir: bool = false
var _disguised: bool = false
var _prompt_layer: CanvasLayer
var _prompt_label: Label
var _couloir_prompt_label: Label
var _message_labels: Array[Label] = []


func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	_setup_prompts()
	_connect_zone_couloir()


func _setup_prompts() -> void:
	_prompt_layer = CanvasLayer.new()
	_prompt_layer.layer = 100
	add_child(_prompt_layer)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_prompt_label.modulate = Color(1, 1, 1, 0.85)
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	prompt_style.border_color = Color(0.6, 0.55, 0.3, 0.7)
	prompt_style.border_width_top = 2
	prompt_style.border_width_bottom = 2
	prompt_style.border_width_left = 2
	prompt_style.border_width_right = 2
	prompt_style.corner_radius_top_left = 8
	prompt_style.corner_radius_top_right = 8
	prompt_style.corner_radius_bottom_left = 8
	prompt_style.corner_radius_bottom_right = 8
	_prompt_label.add_theme_stylebox_override("normal", prompt_style)
	_prompt_label.custom_minimum_size = Vector2(340, 40)
	_prompt_label.visible = false
	_prompt_layer.add_child(_prompt_label)

	_couloir_prompt_label = Label.new()
	_couloir_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_couloir_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_couloir_prompt_label.add_theme_font_size_override("font_size", 18)
	_couloir_prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_couloir_prompt_label.modulate = Color(1, 1, 1, 0.85)
	_couloir_prompt_label.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	style.border_color = Color(0.6, 0.55, 0.3, 0.7)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_couloir_prompt_label.add_theme_stylebox_override("normal", style)
	_couloir_prompt_label.custom_minimum_size = Vector2(340, 40)
	_prompt_layer.add_child(_couloir_prompt_label)


func _connect_zone_couloir() -> void:
	var zone_couloir = $event as Area2D
	if zone_couloir:
		zone_couloir.body_entered.connect(_on_zone_couloir_entered)
		zone_couloir.body_exited.connect(_on_zone_couloir_exited)


func _on_zone_couloir_entered(body: Node2D) -> void:
	if not _active:
		return
	if body.name == "TimeAunote":
		_player_near_couloir = true
		_update_couloir_prompt()


func _on_zone_couloir_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		_player_near_couloir = false
		_update_couloir_prompt()


func _update_couloir_prompt() -> void:
	_couloir_prompt_label.text = "Appuyez sur E — Retour au couloir"
	_couloir_prompt_label.visible = _player_near_couloir and _active
	_update_couloir_prompt_position()


func _update_couloir_prompt_position() -> void:
	if not _couloir_prompt_label or not _couloir_prompt_label.visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_couloir_prompt_label.position = Vector2(vp.x / 2.0 - 170, vp.y - 80)


func _update_prompt_position() -> void:
	if not _prompt_label or not _prompt_label.visible:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_prompt_label.position = Vector2(vp.x / 2.0 - 250, vp.y - 100)
	_prompt_label.size = Vector2(500, 50)


func _input(event: InputEvent) -> void:
	if not _active or not event.is_action_pressed("interagir"):
		return
	if DialogueUI.is_dialogue_active():
		return
	if _player_near_vetements:
		get_viewport().set_input_as_handled()
		_toggle_disguise()
	elif _player_near_couloir:
		get_viewport().set_input_as_handled()
		return_to_couloir_requested.emit()


func _process(_delta: float) -> void:
	if not _active:
		return
	var parent = get_parent()
	if not parent:
		return
	var time_aunote = parent.get_node_or_null("TimeAunote")
	if not time_aunote:
		return

	var vetements_shape: CollisionShape2D = get_node_or_null("event2/vetements")
	if not vetements_shape:
		return
	var shape_rect: RectangleShape2D = vetements_shape.shape
	if not shape_rect:
		return

	var vet_global_pos: Vector2 = vetements_shape.global_position - shape_rect.size / 2.0
	var vet_global_rect: Rect2 = Rect2(vet_global_pos, shape_rect.size)
	var was_near: bool = _player_near_vetements
	_player_near_vetements = vet_global_rect.has_point(time_aunote.global_position)

	if _player_near_vetements != was_near:
		_update_prompt()
		_update_prompt_position()


func _update_prompt() -> void:
	if _disguised:
		_prompt_label.text = "Appuyez sur E pour retirer la tenue de maintenance"
	else:
		_prompt_label.text = "Appuyez sur E pour enfiler une tenue de maintenance"
	_prompt_label.visible = _player_near_vetements


func _toggle_disguise() -> void:
	_disguised = not _disguised

	var parent = get_parent()
	if not parent:
		return
	var time_aunote = parent.get_node_or_null("TimeAunote")
	if not time_aunote:
		return

	if _disguised:
		TimeAunoteScript.disguised_present = true
		if time_aunote.has_method("apply_disguise_present"):
			time_aunote.apply_disguise_present()
	else:
		TimeAunoteScript.disguised_present = false
		if time_aunote.has_method("remove_disguise_present"):
			time_aunote.remove_disguise_present()

	_update_prompt()
	_show_message("Tenue de maintenance enfilee !" if _disguised else "Tenue de maintenance retiree.", Color(0.3, 1.0, 0.3) if _disguised else Color(1.0, 0.9, 0.3))


func _show_message(text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.modulate = Color(1, 1, 1, 0)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x / 2.0 - 200, vp.y / 2.0 - 120)
	label.size = Vector2(400, 40)
	_prompt_layer.add_child(label)
	_message_labels.append(label)

	var fade_in: Tween = create_tween()
	fade_in.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)

	var timer: SceneTreeTimer = get_tree().create_timer(3.0)
	timer.timeout.connect(func():
		if not is_instance_valid(label):
			_message_labels.erase(label)
			return
		var fade_out: Tween = create_tween()
		fade_out.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
		fade_out.tween_callback(func():
			if is_instance_valid(label):
				label.queue_free()
			_message_labels.erase(label)
		)
	)


func is_near_vetements() -> bool:
	return _player_near_vetements


func start() -> void:
	_active = true
	process_mode = PROCESS_MODE_INHERIT
	_disguised = TimeAunoteScript.disguised_present
	_player_near_vetements = false
	_player_near_couloir = false
	if _prompt_label:
		_prompt_label.visible = false
	if _couloir_prompt_label:
		_couloir_prompt_label.visible = false
	var event_area: Area2D = $event as Area2D
	if event_area:
		event_area.collision_layer = 8
		event_area.monitoring = true
	var event2_area: Area2D = $event2 as Area2D
	if event2_area:
		event2_area.collision_layer = 8
		event2_area.monitoring = true
	show()


func stop() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	_player_near_vetements = false
	_player_near_couloir = false
	if _prompt_label:
		_prompt_label.visible = false
	if _couloir_prompt_label:
		_couloir_prompt_label.visible = false
	for lbl in _message_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_message_labels.clear()
	var event_area: Area2D = $event as Area2D
	if event_area:
		event_area.collision_layer = 0
		event_area.monitoring = false
	var event2_area: Area2D = $event2 as Area2D
	if event2_area:
		event2_area.collision_layer = 0
		event2_area.monitoring = false
	hide()
