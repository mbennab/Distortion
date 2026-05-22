extends Node2D

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var pnj_marchand
var player_near_habits := false
var minigame_running := false
var disguise_obtained := false
var prompt_layer: CanvasLayer
var prompt_label: Label
var _mg_instance: CanvasLayer
var _disguise_label: Label
var _active := false
var _merchant_talked := false
var _exclamation_sprite: Sprite2D


func _ready() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	pnj_marchand = $"pnj-marchand"
	if pnj_marchand:
		pnj_marchand.get_node("ZoneDialogue").monitoring = false
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	_setup_habits_zone()
	_setup_prompt()
	_setup_sortie_zone()
	$zoneHabits.monitoring = false
	_setup_exclamation()


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
	prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	prompt_label.modulate = Color(1, 1, 1, 0.85)
	prompt_label.visible = false
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

	var vp := get_viewport().get_visible_rect().size
	prompt_label.position = Vector2(vp.x / 2.0 - 170, vp.y - 160)
	prompt_label.size = Vector2(340, 40)
	prompt_layer.add_child(prompt_label)


func _setup_sortie_zone() -> void:
	var sortie := $areas2D/sortie
	if sortie:
		sortie.collision_mask = 1
		sortie.monitoring = false
		sortie.body_entered.connect(_on_sortie_entered)


func _on_sortie_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_magasin_exit"):
		parent._on_magasin_exit()


func _on_dialogue_started(npc_id: String, _npc_name: String) -> void:
	if npc_id == "npc_marchand_moyenage":
		_merchant_talked = true
		var bulle = $Markers2D/bulle/spr_bulle
		if bulle:
			bulle.hide()
		_update_prompt_visibility()
		_update_exclamation_visibility()
		if _active and not disguise_obtained:
			DialogueSystem.complete_step("quete_deguisement", "etape_parler_marchand")


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
	_update_exclamation_visibility()

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
		$areas2D/sortie.monitoring = true
		TimeAunoteScript.disguised = true
		var player = get_parent().get_node("TimeAunote")
		if player and player.has_method("apply_disguise"):
			player.apply_disguise()
		DialogueSystem.complete_step("quete_deguisement", "etape_marchander")
		DialogueSystem.mark_quest_done("quete_deguisement")
		_show_disguise_message()

	var parent = get_parent()
	if parent and parent.has_method("_on_shop_minigame_success"):
		parent._on_shop_minigame_success()
	_update_exclamation_visibility()


func _show_disguise_message() -> void:
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
	_disguise_label = label

	# Fade in
	var fade_in := create_tween()
	fade_in.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)

	# Utilise un SceneTreeTimer (indépendant du process_mode du nœud)
	var timer := get_tree().create_timer(4.5)
	timer.timeout.connect(func():
		if not is_instance_valid(label):
			return
		var fade_out := create_tween()
		fade_out.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.5)
		fade_out.tween_callback(func():
			if is_instance_valid(label):
				label.queue_free()
		)
	)


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
		if not disguise_obtained:
			zone.monitoring = true
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 4
	var marchand_pos: Vector2 = $Markers2D/marchandPos.position
	if pnj_marchand and pnj_marchand.has_method("apparition"):
		pnj_marchand.apparition(marchand_pos)
		pnj_marchand.get_node("ZoneDialogue").monitoring = true
	if disguise_obtained:
		$areas2D/sortie.monitoring = true
	show()
	_update_exclamation_visibility()


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
	$areas2D/sortie.monitoring = false
	if _disguise_label and is_instance_valid(_disguise_label):
		_disguise_label.queue_free()
		_disguise_label = null
	hide()
	_update_exclamation_visibility()


func _setup_exclamation() -> void:
	var excl_node: Marker2D = $Markers2D/exclamation as Marker2D
	if excl_node:
		_exclamation_sprite = Sprite2D.new()
		_exclamation_sprite.texture = load("res://art/exclamation.png")
		_exclamation_sprite.scale = Vector2(0.6, 0.6)
		_exclamation_sprite.visible = false
		excl_node.add_child(_exclamation_sprite)
		_start_exclamation_tween()


func _start_exclamation_tween() -> void:
	if not _exclamation_sprite:
		return
	_exclamation_sprite.position = Vector2(0, -10)
	var tween: Tween = create_tween().set_loops(-1)
	tween.tween_property(_exclamation_sprite, "position:y", 10.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_exclamation_sprite, "position:y", -10.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_exclamation_visibility() -> void:
	if _exclamation_sprite:
		_exclamation_sprite.visible = _active and _merchant_talked and not disguise_obtained and not minigame_running
