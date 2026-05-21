extends Node2D

var player_near_door := false
var player_near_sortie := false
var minigame_running := false
var _minigame: CanvasLayer = null
var prompt_label: Label


func _ready() -> void:
	_setup_prompt()
	var zone := $ZonePorte
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	var sortie := $ZoneSortie
	sortie.body_entered.connect(_on_body_entered_sortie)
	sortie.body_exited.connect(_on_body_exited_sortie)


func _setup_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.text = "Appuyez sur E pour crocheter la serrure"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	prompt_label.modulate = Color(1, 1, 1, 0.85)
	prompt_label.visible = false
	prompt_label.z_index = 100
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

	var porte_pos: Vector2 = $markers2d/porte.position
	prompt_label.position = Vector2(porte_pos.x - 170, porte_pos.y - 100)
	prompt_label.size = Vector2(340, 40)
	add_child(prompt_label)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_door = true
		if not minigame_running:
			prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_door = false
		prompt_label.visible = false


func _on_body_entered_sortie(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_sortie = true


func _on_body_exited_sortie(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_sortie = false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("interagir") and player_near_door and not minigame_running:
		get_viewport().set_input_as_handled()
		_start_minigame()


func _start_minigame() -> void:
	minigame_running = true
	prompt_label.visible = false

	var parent = get_parent()
	if parent.has_method("_on_minigame_started"):
		parent._on_minigame_started()

	var mg_scene = preload("res://Scripts/MiniJeuCrochetage.tscn")
	_minigame = mg_scene.instantiate()
	_minigame.done.connect(_on_minigame_done)
	get_tree().root.add_child(_minigame)


func stop_minigame() -> void:
	if _minigame and is_instance_valid(_minigame):
		_minigame.queue_free()
		_minigame = null
	minigame_running = false


func _on_minigame_done(success: bool) -> void:
	minigame_running = false
	_minigame = null
	if success:
		prompt_label.visible = false
		var parent = get_parent()
		if parent.has_method("_on_minigame_success"):
			parent._on_minigame_success()
	else:
		if player_near_door:
			prompt_label.visible = true
