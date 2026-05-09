extends Node2D

var player_near_door := false
var player_near_sortie := false
var minigame_running := false
var prompt_label: Label
var sortie_label: Label


func _ready() -> void:
	_setup_prompt()
	_setup_sortie_prompt()
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
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.modulate = Color(1, 1, 1, 0.85)
	prompt_label.visible = false
	prompt_label.z_index = 100

	var porte_pos: Vector2 = $markers2d/porte.position
	prompt_label.position = Vector2(porte_pos.x - 200, porte_pos.y - 100)
	prompt_label.size = Vector2(400, 50)
	add_child(prompt_label)


func _setup_sortie_prompt() -> void:
	sortie_label = Label.new()
	sortie_label.text = "Verrouillé… accès futur"
	sortie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sortie_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sortie_label.add_theme_font_size_override("font_size", 18)
	sortie_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	sortie_label.modulate = Color(1, 1, 1, 0.85)
	sortie_label.visible = false
	sortie_label.z_index = 100

	var sortie_pos: Vector2 = $ZoneSortie/CollisionShape2D.position
	sortie_label.position = Vector2(sortie_pos.x - 150, sortie_pos.y - 80)
	sortie_label.size = Vector2(300, 50)
	add_child(sortie_label)


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
		sortie_label.visible = true


func _on_body_exited_sortie(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_sortie = false
		sortie_label.visible = false


func _input(event: InputEvent) -> void:
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
	var mg = mg_scene.instantiate()
	mg.done.connect(_on_minigame_done)
	get_tree().root.add_child(mg)


func _on_minigame_done(success: bool) -> void:
	minigame_running = false
	if success:
		prompt_label.visible = false
		var parent = get_parent()
		if parent.has_method("_on_minigame_success"):
			parent._on_minigame_success()
	else:
		if player_near_door:
			prompt_label.visible = true
