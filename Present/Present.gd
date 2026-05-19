extends Node2D

var time_aunote: CharacterBody2D
var pnj_secu
var secu_pos: Vector2
var position_entree_principale: Vector2
var started: bool = false
var stopped: bool = true
var can_move: bool = false
var speed: float = 350.0
var spawn_particles: CPUParticles2D

var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _objective_label: Label
var _parking_unlocked: bool = false

var hall
var _player_in_couloir: bool = false
var _couloir_prompt: Label
var _couloir_prompt_layer: CanvasLayer
var _hall_transition_started: bool = false


func _ready() -> void:
	position_entree_principale = $"fondPresent/Markers2D/entreePrincipale".position
	secu_pos = $"fondPresent/Markers2D/secuPos".position
	hide()
	_setup_spawn_particles()
	_setup_fade_overlay()
	pnj_secu = $"PnjSecurité"
	_connect_parking_signals()
	DialogueSystem.action_triggered.connect(_on_action_triggered)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.quest_updated.connect(_on_quest_updated)
	DialogueSystem.dialogue_response.connect(_on_dialogue_response)
	hall = $Hall
	_connect_couloir_signals()
	_setup_couloir_prompt()


func _setup_fade_overlay() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 128
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.size = get_viewport_rect().size
	fade_layer.add_child(fade_rect)


func _connect_parking_signals() -> void:
	var zone_parking = $"fondPresent/zone escape parking"
	zone_parking.body_entered.connect(_on_parking_entered)


func _connect_couloir_signals() -> void:
	var couloir = hall.get_node_or_null("Camera2D/couloir")
	if couloir:
		couloir.body_entered.connect(_on_couloir_entered)
		couloir.body_exited.connect(_on_couloir_exited)


func _setup_couloir_prompt() -> void:
	_couloir_prompt_layer = CanvasLayer.new()
	_couloir_prompt_layer.layer = 50
	add_child(_couloir_prompt_layer)

	_couloir_prompt = Label.new()
	_couloir_prompt.text = "Appuyez sur E pour continuer"
	_couloir_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_couloir_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_couloir_prompt.add_theme_font_size_override("font_size", 18)
	_couloir_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
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
	_couloir_prompt.add_theme_stylebox_override("normal", pstyle)
	_couloir_prompt.custom_minimum_size = Vector2(340, 40)
	_couloir_prompt.visible = false
	_couloir_prompt_layer.add_child(_couloir_prompt)


func _on_couloir_entered(body: Node2D) -> void:
	if body == time_aunote and hall.visible:
		_player_in_couloir = true
		_couloir_prompt.visible = true
		_update_couloir_prompt_position()


func _on_couloir_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_in_couloir = false
		_couloir_prompt.visible = false


func _update_couloir_prompt_position() -> void:
	if not _couloir_prompt or not _couloir_prompt.visible:
		return
	var vp_size := get_viewport().get_visible_rect().size
	_couloir_prompt.position = Vector2(vp_size.x / 2.0 - _couloir_prompt.size.x / 2.0, vp_size.y - 80.0)


func _show_couloir_locked_message() -> void:
	var label := Label.new()
	label.text = "Cette zone n'est pas encore accessible."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	label.z_index = 100
	label.modulate = Color(1, 1, 1, 0)
	add_child(label)
	label.global_position = time_aunote.global_position + Vector2(-250, -150)

	var text_tween := create_tween()
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)
	text_tween.tween_interval(1.5)
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.3)
	await text_tween.finished
	if is_instance_valid(label):
		label.queue_free()


func _input(event: InputEvent) -> void:
	if not started or not can_move:
		return
	if DialogueUI.is_dialogue_active():
		return
	if not event.is_action_pressed("interagir"):
		return
	if _player_in_couloir and hall.visible:
		get_viewport().set_input_as_handled()
		_show_couloir_locked_message()


func _on_parking_entered(body: Node2D) -> void:
	if body == time_aunote and can_move:
		_go_to_parking()


func _go_to_parking() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$fondPresent.hide()
	_set_fond_collisions(false)
	if pnj_secu:
		pnj_secu.hide()
		pnj_secu.get_node("ZoneDialogue").monitoring = false

	$Parking.show()
	_set_parking_collisions(true)
	$Parking.set_interactive(true)
	_set_zone_camera("parking")

	time_aunote.global_position = $"Parking/Node2D/zone pop".global_position
	time_aunote.scale = Vector2(0.65, 0.65)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Fouiller le parking")
	can_move = true


func _return_from_parking() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)

	$fondPresent.show()
	_set_fond_collisions(true)
	_set_zone_camera("fond")
	if pnj_secu:
		pnj_secu.show()
		pnj_secu.apparition(secu_pos)
		pnj_secu.get_node("ZoneDialogue").monitoring = true

	time_aunote.global_position = $"fondPresent/Markers2D/retourParking".global_position
	time_aunote.scale = Vector2(0.5, 0.5)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	var parking = $Parking
	if parking and parking._badge_obtained:
		_update_objective("Retourner voir l'agent de sécurité avec la carte")
	can_move = true


func _go_to_hall() -> void:
	if _hall_transition_started or hall.visible:
		return
	_hall_transition_started = true
	can_move = false
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	DialogueUI.close_dialogue()

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	$fondPresent.hide()
	_set_fond_collisions(false)
	if pnj_secu:
		pnj_secu.hide()
		var zone = pnj_secu.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false

	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)

	hall.show()
	_set_hall_collisions(true)
	_set_zone_camera("hall")

	time_aunote.global_position = hall.get_node("Camera2D/Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.65, 0.65)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	DialogueSystem.complete_step("quete_acces_centrale", "etape_retour_gardien")
	_update_objective("Explorer le hall")
	can_move = true


func _set_hall_collisions(enabled: bool) -> void:
	var limites = hall.get_node_or_null("Camera2D/limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0


func _set_zone_camera(zone_name: String) -> void:
	var fond_cam = $fondPresent.get_node_or_null("Camera2D")
	var parking_cam = $Parking.get_node_or_null("Camera2D")
	var hall_cam = hall.get_node_or_null("Camera2D")
	if fond_cam:
		fond_cam.enabled = (zone_name == "fond")
	if parking_cam:
		parking_cam.enabled = (zone_name == "parking")
	if hall_cam:
		hall_cam.enabled = (zone_name == "hall")


func _on_action_triggered(action: Dictionary) -> void:
	if not started:
		return
	var act_type = action.get("type", "")
	var act_id = action.get("id", "")
	if act_type == "trigger" and act_id == "secu_quete_avance":
		_try_unlock_parking()
	elif act_type == "trigger" and act_id == "secu_acces_hall":
		var parking = $Parking
		if parking and parking._badge_obtained:
			_go_to_hall()


func _on_quest_updated(quest_id: String, status: String, current_step: String) -> void:
	if not started:
		return
	if status == "done":
		return
	if current_step != "":
		var quest = DialogueSystem._find_quest(quest_id)
		if not quest.is_empty():
			for step in quest.get("steps", []):
				if step.get("id") == current_step:
					_update_objective(step.get("description", ""))
					return
	_update_objective(DialogueSystem._find_quest(quest_id).get("title", ""))


func _on_dialogue_response(npc_name: String, text: String) -> void:
	if not started:
		return
	if DialogueSystem.current_npc_id != "npc_securite_present_retour":
		return
	if hall.visible or _hall_transition_started:
		return
	# Forcer le TP mécanique post-minijeu : le joueur a forcément le badge
	# mais l'IA peut ne pas émettre l'action JSON. On laisse 3s de lecture.
	await get_tree().create_timer(3.0).timeout
	if started and not hall.visible and not _hall_transition_started:
		_go_to_hall()


func _on_dialogue_ended() -> void:
	if not started:
		return
	_try_unlock_parking()


func _try_unlock_parking() -> void:
	if _parking_unlocked:
		return
	_parking_unlocked = true
	$"fondPresent/zone escape parking".monitoring = true
	DialogueSystem.complete_step("quete_acces_centrale", "etape_parler_gardien")
	_update_objective("Chercher une carte d'accès dans le parking")


func _set_fond_collisions(enabled: bool) -> void:
	var colision = $fondPresent.get_node_or_null("limitesDeplacements")
	if colision:
		colision.collision_layer = 8 if enabled else 0


func _set_parking_collisions(enabled: bool) -> void:
	var limite = $Parking.get_node_or_null("limiteParking")
	if limite:
		limite.collision_layer = 8 if enabled else 0


func _setup_spawn_particles() -> void:
	spawn_particles = CPUParticles2D.new()
	spawn_particles.emitting = false
	spawn_particles.one_shot = true
	spawn_particles.amount = 50
	spawn_particles.lifetime = 0.8
	spawn_particles.explosiveness = 1.0
	spawn_particles.speed_scale = 2.5
	spawn_particles.spread = 90.0
	spawn_particles.gravity = Vector2(0, -40)
	spawn_particles.initial_velocity_min = 50.0
	spawn_particles.initial_velocity_max = 160.0
	spawn_particles.scale_amount_min = 0.15
	spawn_particles.scale_amount_max = 1.2
	spawn_particles.angular_velocity_min = -540.0
	spawn_particles.angular_velocity_max = 540.0
	spawn_particles.color_ramp = _create_color_ramp(Color(0.3, 1.0, 0.4))
	spawn_particles.texture = _create_particle_texture()
	spawn_particles.z_index = 20
	add_child(spawn_particles)


func _create_particle_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	for y in range(32):
		for x in range(32):
			var dist := Vector2(x, y).distance_to(center) / 16.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = ease(alpha, 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _create_color_ramp(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient


func _process(delta: float) -> void:
	if not can_move:
		return
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
	if DialogueUI.is_dialogue_active():
		time_aunote.animation(Vector2.ZERO)
		return
	var velocity := Vector2.ZERO
	if Input.is_action_pressed("marche_haut"):
		velocity.y -= 1
	if Input.is_action_pressed("marche_bas"):
		velocity.y += 1
	if Input.is_action_pressed("marche_droite"):
		velocity.x += 1
	if Input.is_action_pressed("marche_gauche"):
		velocity.x -= 1
	var direction := velocity.normalized()
	time_aunote.animation(direction)
	time_aunote.move_and_collide(direction * speed * delta)


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = text


func start(spawn_id: String = "entree") -> void:
	_hall_transition_started = false
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://Present/dimension_present.json")
	var parking = $Parking
	if parking and parking._badge_obtained:
		var qs = DialogueSystem.game_state.get("quete_acces_centrale", {})
		if qs is Dictionary:
			var completed: Array = qs.get("completed_steps", [])
			if "etape_parler_gardien" not in completed:
				completed.append("etape_parler_gardien")
			if "etape_chercher_carte" not in completed:
				completed.append("etape_chercher_carte")
			qs["completed_steps"] = completed
			qs["current_step"] = "etape_retour_gardien"
	$fondPresent.show()
	_set_fond_collisions(true)
	_set_zone_camera("fond")
	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)
	hall.hide()
	_set_hall_collisions(false)
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 8
	pnj_secu = $"PnjSecurité"
	pnj_secu.npc_id = "npc_securite_present"
	if parking and parking._badge_obtained:
		pnj_secu.npc_id = "npc_securite_present_retour"
	pnj_secu.apparition(secu_pos)
	pnj_secu.get_node("ZoneDialogue").monitoring = true
	_parking_unlocked = false
	$"fondPresent/zone escape parking".monitoring = false

	if spawn_id == "parking":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.show()
		_set_parking_collisions(true)
		$Parking.set_interactive(true)
		_set_zone_camera("parking")
		time_aunote.position = $"Parking/Node2D/zone pop".position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.65, 0.65)
		time_aunote.rotation = 0.0
		can_move = true
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = false
		started = true
		stopped = false
		_update_objective("Fouiller le parking")
		return

	if spawn_id == "hall":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		hall.show()
		_set_hall_collisions(true)
		_set_zone_camera("hall")
		time_aunote.position = hall.get_node("Camera2D/Node2D/zone pop").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.65, 0.65)
		time_aunote.rotation = 0.0
		can_move = true
		var col_hall := time_aunote.get_node("collision") as CollisionShape2D
		col_hall.disabled = false
		started = true
		stopped = false
		_update_objective("Explorer le hall")
		return

	_update_objective("Parler à l'agent de sécurité")
	time_aunote.position = position_entree_principale
	time_aunote.hide()
	time_aunote.modulate.a = 0.0
	time_aunote.scale = Vector2.ZERO
	time_aunote.rotation = TAU
	_play_spawn_animation()


func _play_spawn_animation(spawn_position: Vector2 = position_entree_principale) -> void:
	spawn_particles.global_position = spawn_position + global_position
	spawn_particles.restart()

	await get_tree().create_timer(0.15).timeout

	time_aunote.show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(time_aunote, "scale", Vector2(0.5, 0.5), 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(time_aunote, "rotation", 0.0, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(time_aunote, "modulate:a", 1.0, 0.5)\
		.set_ease(Tween.EASE_IN)

	await tween.finished

	can_move = true
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	collision_node.disabled = false
	started = true
	stopped = false


func _on_parking_minigame_won() -> void:
	DialogueSystem.complete_step("quete_acces_centrale", "etape_chercher_carte")
	# Bascule vers le PNJ "retour" qui valide le badge
	if pnj_secu:
		pnj_secu.npc_id = "npc_securite_present_retour"
	time_aunote.global_position = $"Parking/Node2D/zone pop after jeux".global_position
	_update_objective("Retourner voir l'agent de sécurité")
	can_move = true


func stop() -> void:
	hide()
	$ObjectiveHUD.hide()
	can_move = false
	started = false
	stopped = true
	$Parking.stop_minigame()
	$Parking.set_interactive(false)
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if pnj_secu:
		var zone = pnj_secu.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	$Parking.hide()
	_set_parking_collisions(false)
	hall.hide()
	_set_hall_collisions(false)
	_player_in_couloir = false
	_hall_transition_started = false
	if _couloir_prompt:
		_couloir_prompt.visible = false
