extends Node2D

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var pnj_marchand
var player_near_habits := false
var minigame_running := false
var disguise_obtained := false
var prompt_layer: CanvasLayer
var prompt_label: Label
var _mg_instance: CanvasLayer
var _active := false
var _merchant_talked := false


func _ready() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	pnj_marchand = $"pnj-marchand"
	if pnj_marchand:
		pnj_marchand.get_node("ZoneDialogue").monitoring = false
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	_setup_habits_zone()
	_setup_prompt()
	$zoneHabits.monitoring = false


func _setup_habits_zone() -> void:
	var zone := $zoneHabits
	if zone:
		zone.body_entered.connect(_on_habits_entered)
		zone.body_exited.connect(_on_habits_exited)


func _setup_prompt() -> void:
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = 100
	add_child(prompt_layer)

	prompt_label = Label.new()
	prompt_label.text = "Appuyez sur E pour marchander des habits"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.modulate = Color(1, 1, 1, 0.85)
	prompt_label.visible = false

	var vp := get_viewport().get_visible_rect().size
	prompt_label.position = Vector2(vp.x / 2.0 - 200, vp.y - 160)
	prompt_label.size = Vector2(400, 50)
	prompt_layer.add_child(prompt_label)


func _on_dialogue_started(npc_id: String, _npc_name: String) -> void:
	if npc_id == "npc_marchand_moyenage":
		_merchant_talked = true
		_update_prompt_visibility()


func _update_prompt_visibility() -> void:
	prompt_label.visible = _active and _merchant_talked and player_near_habits and not disguise_obtained


func _on_habits_entered(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_habits = true
		if _merchant_talked:
			prompt_label.visible = true


func _on_habits_exited(body: Node2D) -> void:
	if body.name == "TimeAunote":
		player_near_habits = false
		prompt_label.visible = false


func _input(event: InputEvent) -> void:
	if not _active or not _merchant_talked:
		return
	if event.is_action_pressed("interagir") and player_near_habits and not minigame_running and not disguise_obtained:
		get_viewport().set_input_as_handled()
		_start_minigame()


func _start_minigame() -> void:
	minigame_running = true
	prompt_label.visible = false

	var parent = get_parent()
	if parent and parent.has_method("_on_shop_minigame_started"):
		parent._on_shop_minigame_started()

	var mg_scene = preload("res://Scripts/MiniJeuMarchandage.tscn")
	_mg_instance = mg_scene.instantiate()
	_mg_instance.done.connect(_on_minigame_done)
	get_tree().root.add_child(_mg_instance)


func _on_minigame_done(success: bool) -> void:
	minigame_running = false
	_mg_instance = null

	if success:
		disguise_obtained = true
		$zoneHabits.monitoring = false
		TimeAunoteScript.disguised = true
		var player = get_parent().get_node("TimeAunote")
		if player and player.has_method("apply_disguise"):
			player.apply_disguise()
		var label := Label.new()
		label.text = "Déguisement obtenu !"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		label.modulate = Color(1, 1, 1, 0)
		var vp := get_viewport().get_visible_rect().size
		label.position = Vector2(vp.x / 2.0 - 150, vp.y / 2.0 - 120)
		label.size = Vector2(300, 40)
		prompt_layer.add_child(label)
		var tween := create_tween()
		tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.5)
		tween.tween_interval(1.5)
		tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.8)
		tween.tween_callback(label.queue_free)

	var parent = get_parent()
	if parent and parent.has_method("_on_shop_minigame_success"):
		parent._on_shop_minigame_success()


func _cleanup_minigame() -> void:
	if _mg_instance and is_instance_valid(_mg_instance):
		_mg_instance.queue_free()
		_mg_instance = null
	minigame_running = false


func start() -> void:
	_active = true
	process_mode = PROCESS_MODE_INHERIT
	var zone := $zoneHabits
	if zone:
		zone.monitoring = true
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 4
	var marchand_pos: Vector2 = $Markers2D/marchandPos.position
	if pnj_marchand and pnj_marchand.has_method("apparition"):
		pnj_marchand.apparition(marchand_pos)
		pnj_marchand.get_node("ZoneDialogue").monitoring = true
	show()


func stop() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	_cleanup_minigame()
	player_near_habits = false
	if prompt_label:
		prompt_label.visible = false
	var zone := $zoneHabits
	if zone:
		zone.monitoring = false
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 0
	if pnj_marchand:
		pnj_marchand.get_node("ZoneDialogue").monitoring = false
		pnj_marchand.hide()
	hide()
