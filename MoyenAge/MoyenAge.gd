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

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var knight_scene = preload("res://MoyenAge/chevalier.tscn")
var knights: Array = []
var _roi_adieu_triggered: bool = false

var prison
var magasin
var ville
var auberge
var parc
var foret
var _auberge_tables_done := false
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _sortie_triggered := false
var _objective_label: Label
var campement


# Audio ambient
var _ambient_player: AudioStreamPlayer
var _current_zone: String = ""
var _audio_buffers: Dictionary = {}


func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	position_entree_principale = $"fondMoyenAge/Markers2D/entreePrincipale".position
	roi_pos = $"fondMoyenAge/Markers2D/roiPos".position
	hide()
	_setup_spawn_particles()
	DialogueSystem.action_triggered.connect(_on_action_triggered)
	DialogueSystem.quest_updated.connect(_on_quest_updated)
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
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
	auberge = $auberge_moyen_age
	if auberge:
		auberge.hide()
		var static_auberge = auberge.get_node_or_null("StaticBody2D")
		if static_auberge:
			static_auberge.collision_layer = 0
	parc = $parc_moyen_age
	if parc:
		parc.hide()
		var static_parc = parc.get_node_or_null("collisions")
		if static_parc:
			static_parc.collision_layer = 0
	foret = $foret
	if foret:
		foret.process_mode = PROCESS_MODE_DISABLED
		foret.hide()
		var static_foret = foret.get_node_or_null("StaticBody2D")
		if static_foret:
			static_foret.collision_layer = 0
	campement = $campement
	if campement:
		campement.hide()
	_setup_fade_overlay()
	_setup_ambient_audio()

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


func _setup_ambient_audio() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = -8.0
	add_child(_ambient_player)


func _load_zone_audio(zone: String) -> void:
	var target_zone := zone
	if zone == "foret":
		target_zone = "parc"
	elif zone == "campement":
		target_zone = "minijeu_crochetage"

	if target_zone in _audio_buffers and not _audio_buffers[target_zone].is_empty():
		return
	var dir := DirAccess.open("res://audio/moyen_age/" + target_zone + "/")
	if not dir:
		return
	var streams: Array[AudioStream] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
			var stream := load("res://audio/moyen_age/" + target_zone + "/" + file_name) as AudioStream
			if stream:
				streams.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	_audio_buffers[target_zone] = streams


func _play_zone_audio(zone: String) -> void:
	if zone == _current_zone:
		return
	_stop_ambient()
	_load_zone_audio(zone)
	
	var target_zone := zone
	if zone == "foret":
		target_zone = "parc"
	elif zone == "campement":
		target_zone = "minijeu_crochetage"

	var streams: Array = _audio_buffers.get(target_zone, [])
	if streams.is_empty():
		_current_zone = zone
		return
	var idx := randi() % streams.size()
	_ambient_player.stream = streams[idx]
	_ambient_player.play()
	_current_zone = zone


func _stop_ambient() -> void:
	_ambient_player.stop()
	_current_zone = ""


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
		_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_label.custom_minimum_size = Vector2(240.0, 0.0)
		_objective_label.text = text
		_objective_label.reset_size()
		
		var panel = _objective_label.get_parent() as Panel
		if panel:
			panel.size.y = maxf(80.0, 36.0 + _objective_label.size.y + 16.0)


func start(spawn_id: String = "entree") -> void:
	process_mode = PROCESS_MODE_INHERIT
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
	ville.hide()
	var static_ville = ville.get_node_or_null("StaticBody2D")
	if static_ville:
		static_ville.collision_layer = 0
	auberge.hide()
	var static_auberge = auberge.get_node_or_null("StaticBody2D")
	if static_auberge:
		static_auberge.collision_layer = 0
	parc.hide()
	var static_parc = parc.get_node_or_null("collisions")
	if static_parc:
		static_parc.collision_layer = 0

	_update_objective("Enquêter sur le roi")
	_play_zone_audio("fond")

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
			_play_zone_audio("prison")
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
			_play_zone_audio("magasin")
			return

		"auberge":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			auberge.start()
			time_aunote.position = auberge.get_node("markers2D/apparition").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.8, 0.8)
			time_aunote.rotation = 0.0
			can_move = true
			var col_auberge := time_aunote.get_node("collision") as CollisionShape2D
			col_auberge.disabled = false
			started = true
			stopped = false
			_update_objective("Explorer l'auberge")
			_play_zone_audio("auberge")
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
			_play_zone_audio("ville")
			return

		"parc":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			parc.start()
			time_aunote.position = parc.get_node("markers2D/apparition").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.8, 0.8)
			time_aunote.rotation = 0.0
			can_move = true
			var col_parc := time_aunote.get_node("collision") as CollisionShape2D
			col_parc.disabled = false
			started = true
			stopped = false
			_update_objective("Enquêter dans la forêt")
			_play_zone_audio("parc")
			return

		"foret":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			parc.stop()
			ville.stop()
			auberge.stop()
			magasin.stop()
			prison.hide()
			var limite_prison_f = prison.get_node_or_null("limiteDeplacement")
			if limite_prison_f:
				limite_prison_f.collision_layer = 0
			foret.process_mode = PROCESS_MODE_INHERIT
			foret.show()
			var static_foret = foret.get_node_or_null("StaticBody2D")
			if static_foret:
				static_foret.collision_layer = 4
			var sortie_foret = foret.get_node_or_null("area2D/sortie")
			if sortie_foret:
				sortie_foret.collision_mask = 1
				sortie_foret.monitoring = true
				if not sortie_foret.body_entered.is_connected(_on_foret_sortie_entered):
					sortie_foret.body_entered.connect(_on_foret_sortie_entered)
			time_aunote.position = foret.get_node("markers2D/apparition").position
			time_aunote.show()
			time_aunote.modulate.a = 1.0
			time_aunote.scale = Vector2(0.8, 0.8)
			time_aunote.rotation = 0.0
			can_move = true
			var col_foret := time_aunote.get_node("collision") as CollisionShape2D
			col_foret.disabled = false
			started = true
			stopped = false
			_update_objective("Trouver l'assassin dans la forêt")
			_play_zone_audio("foret")
			return

		"campement":
			$fondMoyenAge.hide()
			$fondMoyenAge.get_node_or_null("limitesDeplacements").collision_layer = 0
			pnj_roi.hide()
			pnj_roi.get_node("ZoneDialogue").monitoring = false
			foret.process_mode = PROCESS_MODE_DISABLED
			foret.hide()
			var static_foret = foret.get_node_or_null("StaticBody2D")
			if static_foret:
				static_foret.collision_layer = 0
			var forest_assassin = foret.get_node_or_null("markers2D/assassin/assassin")
			if forest_assassin and forest_assassin.has_node("ZoneDialogue"):
				forest_assassin.get_node("ZoneDialogue").monitoring = false
			time_aunote.hide()
			var col_node := time_aunote.get_node("collision") as CollisionShape2D
			if col_node:
				col_node.disabled = true
			campement.start_combat()
			_play_zone_audio("campement")
			can_move = false
			started = true
			stopped = false
			_update_objective("Vaincre l'assassin !")
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
	process_mode = PROCESS_MODE_DISABLED
	hide()
	$ObjectiveHUD.hide()
	DialogueUI.hide_prompt()
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
	if auberge:
		auberge.stop()
	if parc:
		parc.stop()
	if foret:
		foret.process_mode = PROCESS_MODE_DISABLED
		foret.hide()
		var static_foret = foret.get_node_or_null("StaticBody2D")
		if static_foret:
			static_foret.collision_layer = 0
		var sortie_foret = foret.get_node_or_null("area2D/sortie")
		if sortie_foret:
			sortie_foret.monitoring = false
	if campement:
		campement.hide()
		campement.is_combat_active = false
		if campement.combat_ui:
			campement.combat_ui.hide()
	var fond_limites = $fondMoyenAge.get_node_or_null("limitesDeplacements")
	if fond_limites:
		fond_limites.collision_layer = 0
	if prison:
		var prison_limite = prison.get_node_or_null("limiteDeplacement")
		if prison_limite:
			prison_limite.collision_layer = 0
	_cleanup_knights()
	_stop_ambient()


func _on_dialogue_started(npc_id: String, _npc_name: String) -> void:
	match npc_id:
		"npc_roi_moyenage":
			var bulle = $fondMoyenAge.get_node_or_null("Markers2D/bulle/spr_bulle")
			if bulle:
				bulle.hide()
		"npc_assassin":
			var foret_bulle = foret.get_node_or_null("markers2D/bulle/spr_bulle")
			if foret_bulle:
				foret_bulle.hide()


func _on_action_triggered(action: Dictionary) -> void:
	if not started:
		return
	if action.get("type") == "trigger" and action.get("id") == "roi_adieu":
		if not _roi_adieu_triggered:
			_trigger_roi_adieu_sequence()
	elif action.get("type") == "trigger" and action.get("id") == "assassin_combat":
		_start_assassin_combat()


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
	label.position = Vector2(center.x - 250, pos1.y - 150)
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
	_play_zone_audio("prison")
	can_move = true


func _on_minigame_started() -> void:
	can_move = false
	_stop_ambient()


func _on_minigame_success() -> void:
	if is_instance_valid(time_aunote) and is_instance_valid(prison):
		var marker = prison.get_node_or_null("markers2d/teleportation")
		if marker:
			time_aunote.global_position = marker.global_position
	_update_objective("Trouver la sortie de la prison")
	_play_zone_audio("prison")
	can_move = true


func _on_shop_minigame_started() -> void:
	can_move = false
	_stop_ambient()


func _on_shop_minigame_success() -> void:
	_update_objective("Se rendre à la taverne du village")
	_play_zone_audio("magasin")
	can_move = true


func _on_auberge_table_minigame_started() -> void:
	can_move = false
	# Ne pas couper la musique de l'auberge, les voix du mini-jeu se superposeront


func _on_auberge_table_minigame_success() -> void:
	_play_zone_audio("auberge")
	can_move = true


func _on_auberge_all_tables_done() -> void:
	_auberge_tables_done = true
	_update_objective("Enquêter dans la forêt")
	can_move = true


func _on_femme_friendship_done() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	parc.stop()
	ville.stop()
	auberge.stop()
	magasin.stop()
	prison.hide()
	var limite_p = prison.get_node_or_null("limiteDeplacement")
	if limite_p:
		limite_p.collision_layer = 0

	foret.process_mode = PROCESS_MODE_INHERIT
	foret.show()
	var static_foret = foret.get_node_or_null("StaticBody2D")
	if static_foret:
		static_foret.collision_layer = 4
	var sortie_foret = foret.get_node_or_null("area2D/sortie")
	if sortie_foret:
		sortie_foret.collision_mask = 1
		sortie_foret.monitoring = true
		if not sortie_foret.body_entered.is_connected(_on_foret_sortie_entered):
			sortie_foret.body_entered.connect(_on_foret_sortie_entered)

	time_aunote.global_position = foret.get_node("markers2D/apparition").global_position
	time_aunote.scale = Vector2(0.8, 0.8)

	var text_label := Label.new()
	text_label.text = "La femme du parc te guide jusqu'à la forêt…"
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

	_update_objective("Trouver l'assassin dans la forêt")
	_play_zone_audio("foret")
	can_move = true


func _on_foret_sortie_entered(body: Node2D) -> void:
	if body != time_aunote:
		return
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	foret.process_mode = PROCESS_MODE_DISABLED
	foret.hide()
	var static_foret = foret.get_node_or_null("StaticBody2D")
	if static_foret:
		static_foret.collision_layer = 0
	var sf = foret.get_node_or_null("area2D/sortie")
	if sf:
		sf.monitoring = false

	var main = get_tree().current_scene
	if main and main.has_method("warp_to_era"):
		main.warp_to_era("hub", "entree")
		return

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
	_play_zone_audio("ville")
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
	_play_zone_audio("prison")
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
	_play_zone_audio("magasin")
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
	_play_zone_audio("ville")
	can_move = true


func _on_ville_to_auberge() -> void:
	if not TimeAunoteScript.disguised:
		can_move = false
		var label := Label.new()
		label.text = "Je devrais me déguiser avant"
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
		label.position = time_aunote.global_position + Vector2(-250, -200)
		add_child(label)

		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(label):
			label.queue_free()
		can_move = true
		return

	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	ville.stop()
	auberge.start()
	time_aunote.global_position = auberge.get_node("markers2D/apparition").global_position
	time_aunote.scale = Vector2(0.8, 0.8)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Explorer la ville")
	_play_zone_audio("auberge")
	can_move = true


func _on_auberge_exit() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	auberge.stop()
	ville.start()
	time_aunote.global_position = ville.get_node("markers2D/auberge").global_position
	time_aunote.scale = Vector2(0.4, 0.4)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Explorer la ville")
	_play_zone_audio("ville")
	can_move = true


func _on_ville_to_parc() -> void:
	if not _auberge_tables_done:
		can_move = false
		var label := Label.new()
		label.text = "Je devrais d'abord enquêter à l'auberge"
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
		label.position = time_aunote.global_position + Vector2(-250, -200)
		add_child(label)

		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(label):
			label.queue_free()
		can_move = true
		return

	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	ville.stop()
	parc.start()
	time_aunote.global_position = parc.get_node("markers2D/apparition").global_position
	time_aunote.scale = Vector2(0.8, 0.8)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Enquêter dans la forêt")
	_play_zone_audio("parc")
	can_move = true


func _on_parc_exit() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	parc.stop()
	ville.start()
	time_aunote.global_position = ville.get_node("markers2D/parc").global_position
	time_aunote.scale = Vector2(0.4, 0.4)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Explorer la ville")
	_play_zone_audio("ville")
	can_move = true


func _cleanup_knights() -> void:
	for k in knights:
		if is_instance_valid(k):
			k.queue_free()
	knights.clear()
	_roi_adieu_triggered = false


func _start_assassin_combat() -> void:
	can_move = false
	DialogueUI.hide_prompt()
	DialogueUI.close_dialogue()
	_stop_ambient()
	
	# Transition fade out
	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return
		
	# Hide the forest zone and disable movement
	foret.process_mode = PROCESS_MODE_DISABLED
	foret.hide()
	var static_foret = foret.get_node_or_null("StaticBody2D")
	if static_foret:
		static_foret.collision_layer = 0
		
	# Désactiver la zone d'interaction du PNJ assassin pendant le combat
	var forest_assassin = foret.get_node_or_null("markers2D/assassin/assassin")
	if forest_assassin and forest_assassin.has_node("ZoneDialogue"):
		forest_assassin.get_node("ZoneDialogue").monitoring = false
		
	time_aunote.hide()
	var col_node := time_aunote.get_node("collision") as CollisionShape2D
	if col_node:
		col_node.disabled = true
		
	# Display and trigger combat at the campement
	campement.start_combat()
	_play_zone_audio("campement")

	# Fade back in
	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
