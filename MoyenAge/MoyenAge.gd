extends Node2D

var time_aunote: CharacterBody2D
var pnj_roi
var roi_pos: Vector2
var position_entree_principale: Vector2
var started: bool = false
var stopped: bool = true
var can_move: bool = false
var speed: float = 350.0
var spawn_particles: CPUParticles2D

var knight_scene = preload("res://MoyenAge/chevalier.tscn")
var knights: Array = []
var _roi_adieu_triggered: bool = false

var prison
var magasin
var ville
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _sortie_triggered := false
var _objective_label: Label


func _ready() -> void:
	position_entree_principale = $"fondMoyenAge/Markers2D/entreePrincipale".position
	roi_pos = $"fondMoyenAge/Markers2D/roiPos".position
	hide()
	_setup_spawn_particles()
	DialogueSystem.action_triggered.connect(_on_action_triggered)
	prison = $prison_moyen_age
	var limites_prison = prison.get_node_or_null("limiteDeplacement")
	if limites_prison:
		limites_prison.collision_layer = 0
	var zone_porte = prison.get_node_or_null("ZonePorte")
	if zone_porte:
		zone_porte.monitoring = false
	var zone_sortie = prison.get_node_or_null("ZoneSortie")
	if zone_sortie:
		zone_sortie.monitoring = false
	magasin = $magasin_moyen_age
	if magasin:
		magasin.hide()
		var static_body = magasin.get_node_or_null("StaticBody2D")
		if static_body:
			static_body.collision_layer = 0
	var mg_zone_sortie = prison.get_node_or_null("ZoneSortie")
	if mg_zone_sortie:
		mg_zone_sortie.body_entered.connect(_on_prison_sortie_entered)
	ville = $ville_moyen_age
	if ville:
		ville.hide()
		var static_ville = ville.get_node_or_null("StaticBody2D")
		if static_ville:
			static_ville.collision_layer = 0
	_setup_fade_overlay()

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
	spawn_particles.color_ramp = _create_color_ramp(Color(1.0, 0.75, 0.3))
	spawn_particles.texture = _create_particle_texture()
	spawn_particles.z_index = 20
	add_child(spawn_particles)

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
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://MoyenAge/dimension_moyenage.json")
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 4
	pnj_roi = $"pnj-roi"
	pnj_roi.apparition(roi_pos)
	pnj_roi.get_node("ZoneDialogue").monitoring = true

	$fondMoyenAge.show()
	$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 4
	prison.hide()
	var limite_prison = prison.get_node_or_null("limiteDeplacement")
	if limite_prison:
		limite_prison.collision_layer = 0
	magasin.hide()
	var static_body = magasin.get_node_or_null("StaticBody2D")
	if static_body:
		static_body.collision_layer = 0

	_update_objective("Enquêter sur le roi")

	match spawn_id:
		"prison":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			prison.show()
			if limite_prison:
				limite_prison.collision_layer = 4
			prison.get_node("ZonePorte").monitoring = true
			var zone_sortie_prison = prison.get_node_or_null("ZoneSortie")
			if zone_sortie_prison:
				zone_sortie_prison.monitoring = true
			time_aunote.position = prison.get_node("markers2d/apparition").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.8, 0.8)
			time_aunote.rotation = 0.0
			can_move = true
			var collision_node := time_aunote.get_node("collision") as CollisionShape2D
			collision_node.disabled = false
			started = true
			stopped = false
			_update_objective("S'échapper de la prison")
			return

		"magasin":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			magasin.start()
			time_aunote.position = magasin.get_node("Markers2D/apparition").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.8, 0.8)
			time_aunote.rotation = 0.0
			can_move = true
			var col_node := time_aunote.get_node("collision") as CollisionShape2D
			col_node.disabled = false
			started = true
			stopped = false
			_update_objective("Marchander avec le marchand")
			return

		"ville":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			ville.start()
			time_aunote.position = ville.get_node("markers2D/chateau").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.4, 0.4)
			time_aunote.rotation = 0.0
			can_move = true
			var col_ville := time_aunote.get_node("collision") as CollisionShape2D
			col_ville.disabled = false
			started = true
			stopped = false
			_update_objective("Explorer la ville")
			return

		_:
			time_aunote.position = position_entree_principale
			if prison:
				var limites_prison = prison.get_node_or_null("limiteDeplacement")
				if limites_prison:
					limites_prison.collision_layer = 0

	time_aunote.hide()
	time_aunote.modulate.a = 0.0
	time_aunote.scale = Vector2.ZERO
	time_aunote.rotation = TAU
	_play_spawn_animation()

func _play_spawn_animation() -> void:
	spawn_particles.global_position = position_entree_principale + global_position
	spawn_particles.restart()

	await get_tree().create_timer(0.15).timeout

	time_aunote.show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(time_aunote, "scale", Vector2(0.8, 0.8), 1.0)\
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

func stop() -> void:
	hide()
	$ObjectiveHUD.hide()
	DialogueUI.close_dialogue()
	can_move = false
	started = false
	stopped = true
	_sortie_triggered = false
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if pnj_roi:
		pnj_roi.get_node("ZoneDialogue").monitoring = false
	if prison:
		var zone_porte = prison.get_node_or_null("ZonePorte")
		if zone_porte:
			zone_porte.monitoring = false
		var zone_sortie = prison.get_node_or_null("ZoneSortie")
		if zone_sortie:
			zone_sortie.monitoring = false
		if prison.has_method("stop_minigame"):
			prison.stop_minigame()
	if magasin:
		magasin.stop()
	if ville:
		ville.stop()
	_cleanup_knights()


func _on_action_triggered(action: Dictionary) -> void:
	if not started or _roi_adieu_triggered:
		return
	if action.get("type") == "trigger" and action.get("id") == "roi_adieu":
		_trigger_roi_adieu_sequence()


func _trigger_roi_adieu_sequence() -> void:
	_roi_adieu_triggered = true

	# Désactiver la zone de dialogue du roi pour éviter le popup
	if pnj_roi:
		pnj_roi.get_node("ZoneDialogue").monitoring = false

	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return

	DialogueUI.close_dialogue()
	can_move = false

	var pos1: Vector2 = $"fondMoyenAge/Markers2D/chevalier1".position
	var pos2: Vector2 = $"fondMoyenAge/Markers2D/chevalier2".position

	var knight1 = knight_scene.instantiate()
	knight1.position = pos1
	add_child(knight1)
	knight1.get_node("AnimatedSprite2D").play("default")
	knights.append(knight1)

	await get_tree().create_timer(1.0).timeout

	if not is_inside_tree():
		return

	var knight2 = knight_scene.instantiate()
	knight2.position = pos2
	add_child(knight2)
	knight2.get_node("AnimatedSprite2D").play("default")
	knights.append(knight2)

	var label := Label.new()
	label.text = "Le roi a été assassiné !\nPar cet homme c'est certain !\nATTRAPEZ-LE !"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	label.z_index = 100

	var center: Vector2 = (pos1 + pos2) / 2.0
	label.position = Vector2(center.x - 250, pos1.y - 280)
	add_child(label)
	knights.append(label)

	await get_tree().create_timer(5.0).timeout
	if not is_inside_tree():
		return

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	_cleanup_knights()

	$fondMoyenAge.hide()
	var limites_fond = $fondMoyenAge.get_node_or_null("limitesDeplacements")
	if limites_fond:
		limites_fond.collision_layer = 0

	prison.show()
	prison.get_node("ZonePorte").monitoring = true
	var limites_prison = prison.get_node_or_null("limiteDeplacement")
	if limites_prison:
		limites_prison.collision_layer = 4
	var zone_sortie = prison.get_node_or_null("ZoneSortie")
	if zone_sortie:
		zone_sortie.monitoring = true

	time_aunote.global_position = prison.get_node("markers2d/apparition").global_position

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("S'échapper de la prison")
	can_move = true


func _on_minigame_started() -> void:
	can_move = false


func _on_minigame_success() -> void:
	time_aunote.global_position = prison.get_node("markers2d/teleportation").global_position
	_update_objective("Trouver la sortie de la prison")
	can_move = true


func _on_shop_minigame_started() -> void:
	can_move = false


func _on_shop_minigame_success() -> void:
	_update_objective("Explorer le Moyen Âge")
	can_move = true


func _on_prison_sortie_entered(body: Node2D) -> void:
	if body != time_aunote or _sortie_triggered:
		return
	_sortie_triggered = true
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	prison.hide()
	var limites_prison = prison.get_node_or_null("limiteDeplacement")
	if limites_prison:
		limites_prison.collision_layer = 0
	var zone_porte = prison.get_node_or_null("ZonePorte")
	if zone_porte:
		zone_porte.monitoring = false
	var zone_sortie = prison.get_node_or_null("ZoneSortie")
	if zone_sortie:
		zone_sortie.monitoring = false

	ville.start()
	time_aunote.global_position = ville.get_node("markers2D/chateau").global_position
	time_aunote.scale = Vector2(0.4, 0.4)

	var text_label := Label.new()
	text_label.text = "Vous émergez dans les rues de la ville…"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 28)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.modulate = Color(1, 1, 1, 0)
	text_label.size = get_viewport_rect().size
	fade_layer.add_child(text_label)

	var text_tween := create_tween()
	text_tween.tween_property(text_label, "modulate", Color(1, 1, 1, 1), 0.4)
	text_tween.tween_interval(1.8)
	text_tween.tween_property(text_label, "modulate", Color(1, 1, 1, 0), 0.4)
	await text_tween.finished

	text_label.queue_free()

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Explorer la ville")
	can_move = true


func _on_ville_to_prison() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	ville.stop()

	prison.show()
	var limite_prison = prison.get_node_or_null("limiteDeplacement")
	if limite_prison:
		limite_prison.collision_layer = 4
	var zone_sortie = prison.get_node_or_null("ZoneSortie")
	if zone_sortie:
		zone_sortie.monitoring = true

	_sortie_triggered = false
	time_aunote.global_position = prison.get_node("markers2d/sortie").global_position
	time_aunote.scale = Vector2(0.8, 0.8)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("S'échapper de la prison")
	can_move = true


func _on_ville_to_magasin() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	ville.stop()
	magasin.start()
	time_aunote.global_position = magasin.get_node("Markers2D/apparition").global_position
	time_aunote.scale = Vector2(0.8, 0.8)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Marchander avec le marchand")
	can_move = true


func _on_magasin_exit() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	magasin.stop()
	ville.start()
	time_aunote.global_position = ville.get_node("markers2D/magasin").global_position
	time_aunote.scale = Vector2(0.4, 0.4)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Explorer la ville")
	can_move = true


func _cleanup_knights() -> void:
	for k in knights:
		if is_instance_valid(k):
			k.queue_free()
	knights.clear()
	_roi_adieu_triggered = false
