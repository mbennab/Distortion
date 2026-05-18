extends Node2D

var pnj_aubergiste
var _active := false

var _tables_done: Array = []
var _table_minigame_running := false
var _spoken_to_aubergiste := false
var _mg_instance: CanvasLayer = null
var _current_table_id := ""
var _near_tables: Dictionary = {}

var prompt_layer: CanvasLayer
var prompt_label: Label


func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	pnj_aubergiste = $"pnj-aubergiste"
	if pnj_aubergiste:
		pnj_aubergiste.get_node("ZoneDialogue").monitoring = false
	var sortie := $Sortie
	if sortie:
		sortie.collision_mask = 1
		sortie.monitoring = false
		sortie.body_entered.connect(_on_sortie_entered)

	DialogueSystem.dialogue_started.connect(_on_dialogue_started)

	_setup_tables()
	_setup_prompt()


func _setup_tables() -> void:
	for tid in ["table1", "table2", "table3"]:
		var area := get_node_or_null("areas_minijeu/" + tid)
		if area:
			area.body_entered.connect(_on_table_body_entered.bind(tid))
			area.body_exited.connect(_on_table_body_exited.bind(tid))


func _setup_prompt() -> void:
	prompt_layer = CanvasLayer.new()
	prompt_layer.layer = 100
	add_child(prompt_layer)

	prompt_label = Label.new()
	prompt_label.text = "Appuyez sur E pour écouter les conversations"
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
	if npc_id == "npc_aubergiste_moyenage":
		_spoken_to_aubergiste = true
		_update_prompt_visibility()


func _on_table_body_entered(_body: Node2D, table_id: String) -> void:
	_near_tables[table_id] = true
	_update_prompt_visibility()


func _on_table_body_exited(_body: Node2D, table_id: String) -> void:
	_near_tables[table_id] = false
	_update_prompt_visibility()


func _update_prompt_visibility() -> void:
	var show := false
	for tid in _near_tables:
		if _near_tables[tid] and _spoken_to_aubergiste \
				and not tid in _tables_done and not _table_minigame_running:
			show = true
			break
	prompt_label.visible = show


func _input(event: InputEvent) -> void:
	if not _active or not _spoken_to_aubergiste or _table_minigame_running:
		return
	if event.is_action_pressed("interagir"):
		for tid in _near_tables:
			if _near_tables[tid] and not tid in _tables_done:
				_current_table_id = tid
				_start_table_minigame()
				return


func _start_table_minigame() -> void:
	var round_num := _tables_done.size() + 1
	_table_minigame_running = true
	prompt_label.visible = false
	$Sortie.monitoring = false

	var parent = get_parent()
	if parent and parent.has_method("_on_auberge_table_minigame_started"):
		parent._on_auberge_table_minigame_started()

	var mg_scene = preload("res://Scripts/MiniJeuEcouteTables.tscn")
	_mg_instance = mg_scene.instantiate()
	_mg_instance.round = round_num
	_mg_instance.done.connect(_on_table_minigame_done)
	get_tree().root.add_child(_mg_instance)


func _on_table_minigame_done(success: bool) -> void:
	_table_minigame_running = false
	_mg_instance = null
	$Sortie.monitoring = true

	if success:
		_tables_done.append(_current_table_id)
		_current_table_id = ""

		if _tables_done.size() >= 3:
			_on_all_tables_done()
	else:
		_tables_done.clear()
		_current_table_id = ""

	_update_prompt_visibility()

	var parent = get_parent()
	if parent and parent.has_method("_on_auberge_table_minigame_success"):
		parent._on_auberge_table_minigame_success()


func _on_all_tables_done() -> void:
	var vp := get_viewport().get_visible_rect().size
	var label := Label.new()
	label.text = "D'après les rumeurs entendues,\nl'assassin portait une cape sombre\net s'est enfui vers la forêt au nord !"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	label.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	label.z_index = 100
	label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 80)
	label.size = Vector2(600, 160)
	label.modulate = Color(1, 1, 1, 0)
	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

	DialogueSystem.complete_step("quete_piste_assassin", "etape_enqueter_foret")

	var parent = get_parent()
	if parent and parent.has_method("_on_auberge_all_tables_done"):
		parent._on_auberge_all_tables_done()


func stop_table_minigame() -> void:
	if _mg_instance and is_instance_valid(_mg_instance):
		_mg_instance.queue_free()
		_mg_instance = null
	_table_minigame_running = false


func start() -> void:
	_active = true
	process_mode = PROCESS_MODE_INHERIT
	_tables_done.clear()
	_table_minigame_running = false
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 4
	$Sortie.monitoring = true
	var aubergiste_pos: Vector2 = $markers2D/pnj_aubergiste.position
	if pnj_aubergiste and pnj_aubergiste.has_method("apparition"):
		pnj_aubergiste.apparition(aubergiste_pos)
		pnj_aubergiste.get_node("ZoneDialogue").monitoring = true
	show()


func stop() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	stop_table_minigame()
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 0
	$Sortie.monitoring = false
	if pnj_aubergiste:
		pnj_aubergiste.get_node("ZoneDialogue").monitoring = false
		pnj_aubergiste.hide()
	hide()


func _on_sortie_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_auberge_exit"):
		parent._on_auberge_exit()
