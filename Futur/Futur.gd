extends Node2D

var time_aunote: CharacterBody2D
var pnjfutur
var pnjfuturPos
var pnjcheffe
var pnjcheffePos
var pnjkoiai2
var pnjkoiai2Pos
var position_entree_principale: Vector2
var position_entree_escalier: Vector2
var started: bool = false
var stopped: bool = true
var can_move: bool = false
var speed: float = 350.0
var spawn_particles: CPUParticles2D
var _car_minigame_active := false
var _car_minigame: Node2D
var _was_in_basement := false
var _player_near_car := false
var _car_prompt: Label

var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _objective_label: Label
var _combat_boss_instance: Node2D


func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	position_entree_principale = $"fondFutur/Markers2D/entreePrincipale".position
	position_entree_escalier = $"fondFutur/Markers2D/entreeEscalier".position
	hide()
	_setup_spawn_particles()
	_setup_fade_overlay()
	pnjfutur = $"pnj-futur"
	pnjfuturPos = $"fondFutur/Markers2D/pnjfuturPos".position
	pnjcheffe = $"pnj-cheffe"
	pnjcheffePos = $"fondFutur/Markers2D/pnjcheffePos".position
	pnjkoiai2Pos = $"SousSol/fondSousSol/Markers2D/pnjPos2".position
	pnjkoiai2 = $"SousSol/pnj-koiai-2"
	_connect_escalier_signals()
	_connect_metro_sortie_signal()


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


func _connect_escalier_signals() -> void:
	var zone_escalier = $"fondFutur/escalier/zone-escalier"
	zone_escalier.body_entered.connect(_on_escalier_entered)


func _on_escalier_entered(body: Node2D) -> void:
	if body == time_aunote and can_move:
		_go_to_basement()


func _connect_metro_sortie_signal() -> void:
	var sortie = $FondMetro/Sortie
	if sortie:
		sortie.collision_mask = 1
		sortie.body_entered.connect(_on_metro_sortie_entered)


func _on_metro_sortie_entered(body: Node2D) -> void:
	if body != time_aunote or not can_move:
		return

	can_move = false
	time_aunote.hide()
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	if collision_node:
		collision_node.disabled = true

	var vp := get_viewport().get_visible_rect().size
	var text_label := Label.new()
	text_label.text = "Vous arrivez devant la tour de Alfredo Sinko Nochez"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(600, 0)
	text_label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 60)
	text_label.size = Vector2(600, 120)
	fade_layer.add_child(text_label)

	$ObjectiveHUD.hide()

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	await get_tree().create_timer(3.0).timeout

	if is_instance_valid(text_label):
		text_label.queue_free()

	_play_cinematique_futur()


func _go_to_basement() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$fondFutur.hide()
	_set_upper_collisions(false)
	$"pnj-futur".hide()
	if pnjfutur:
		pnjfutur.get_node("ZoneDialogue").monitoring = false
	$"pnj-cheffe".hide()
	if pnjcheffe:
		pnjcheffe.get_node("ZoneDialogue").monitoring = false

	$SousSol.show()
	_set_basement_collisions(true)
	$"SousSol/pnj-futur".apparition($"SousSol/fondSousSol/Markers2D/pnjPos".position)
	$"SousSol/pnj-futur/ZoneDialogue".monitoring = true
	$"SousSol/pnj-koiai-2".apparition(pnjkoiai2Pos)
	if pnjkoiai2:
		pnjkoiai2.get_node("ZoneDialogue").monitoring = true

	time_aunote.global_position = $"SousSol/fondSousSol/Markers2D/entreeEscalier".global_position

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Parler aux personnes du sous-sol")
	can_move = true


func _return_from_basement() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	if pnjkoiai2:
		pnjkoiai2.get_node("ZoneDialogue").monitoring = false
	$"SousSol/pnj-futur/ZoneDialogue".monitoring = false
	$SousSol.hide()
	_set_basement_collisions(false)

	$fondFutur.show()
	_set_upper_collisions(true)
	$"pnj-futur".show()
	if pnjfutur:
		pnjfutur.get_node("ZoneDialogue").monitoring = true
	$"pnj-cheffe".show()
	if pnjcheffe:
		pnjcheffe.get_node("ZoneDialogue").monitoring = true
	var car_zone = $"fondFutur/zone-voiture"
	if car_zone:
		car_zone.monitoring = true
	time_aunote.global_position = $"fondFutur/Markers2D/entreeEscalier".global_position

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Parler à la cheffe")
	can_move = true


func _set_upper_collisions(enabled: bool) -> void:
	var limite = $fondFutur.get_node_or_null("limite-futur")
	if limite:
		limite.collision_layer = 32 if enabled else 0


func _set_basement_collisions(enabled: bool) -> void:
	var limite = $"SousSol/fondSousSol".get_node_or_null("limite-sous-sol")
	if limite:
		limite.collision_layer = 64 if enabled else 0


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
	spawn_particles.color_ramp = _create_color_ramp(Color(0.3, 0.8, 1.0))
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


func _show_superette_scene() -> void:
	var entree_pos = $FondSuperette/Markers2D/entree.position
	var cheffe_pos = $FondSuperette/Markers2D/cheffe.position

	time_aunote.global_position = entree_pos
	time_aunote.show()
	time_aunote.modulate.a = 1.0
	time_aunote.scale = Vector2(0.8, 0.8)
	time_aunote.rotation = 0.0
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	collision_node.disabled = false

	if pnjcheffe:
		pnjcheffe.apparition(cheffe_pos)
		pnjcheffe.show()
		var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = true

	_set_superette_collisions(true)

	$ObjectiveHUD.show()
	_update_objective("Explorer la supérette")
	can_move = true

	_auto_start_cheffe_dialogue()


func _auto_start_cheffe_dialogue() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if DialogueSystem.is_active:
		return
	var npcs = DialogueSystem.dimension.get("npcs", [])
	for npc in npcs:
		if npc.get("id") == "npc_cheffe_futur":
			npc["first_message"] = "Nous sommes enfin en sécurité, essayons de fouiller l'endroit à la recherche de... Attention aux tourelles va te cacher !!!"
			break
	DialogueSystem._spoken_to.erase("npc_cheffe_futur")
	if not DialogueSystem.dialogue_ended.is_connected(_on_superette_dialogue_ended):
		DialogueSystem.dialogue_ended.connect(_on_superette_dialogue_ended)
	DialogueSystem.start_dialogue("npc_cheffe_futur")


func _start_cheffe_post_tourelle_dialogue() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if DialogueSystem.is_active:
		return
	var npcs = DialogueSystem.dimension.get("npcs", [])
	for npc in npcs:
		if npc.get("id") == "npc_cheffe_futur":
			npc["first_message"] = "On a eu chaud, heureusement que les autres sont resté dans la voiture, maintenant trouvons un moyen de rejoindre la tour d'Alfredo Sinko Nochez"
			break
	DialogueSystem._spoken_to.erase("npc_cheffe_futur")
	DialogueSystem.start_dialogue("npc_cheffe_futur")


func _auto_start_boss_dialogue() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if DialogueSystem.is_active:
		return
	DialogueSystem._spoken_to.erase("npc_boss_futur")
	DialogueSystem.start_dialogue("npc_boss_futur")


func _on_boss_action_triggered(action: Dictionary) -> void:
	if action.get("type") == "trigger" and action.get("id") == "combat":
		if DialogueSystem.action_triggered.is_connected(_on_boss_action_triggered):
			DialogueSystem.action_triggered.disconnect(_on_boss_action_triggered)
		DialogueSystem.stop_dialogue()
		_start_combat_boss()


func _start_combat_boss() -> void:
	if _combat_boss_instance:
		return

	$FondBureau.hide()
	_set_bureau_collisions(false)
	time_aunote.hide()
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	if collision_node:
		collision_node.disabled = true
	can_move = false

	var CombatScene = preload("res://Futur/combat_boss_futur.tscn")
	_combat_boss_instance = CombatScene.instantiate()
	add_child(_combat_boss_instance)
	_combat_boss_instance.battle_won.connect(_on_combat_boss_won)
	_combat_boss_instance.battle_lost.connect(_on_combat_boss_lost)


func _on_combat_boss_won() -> void:
	if _combat_boss_instance:
		_combat_boss_instance.queue_free()
		_combat_boss_instance = null

	DialogueUI.hide_all()
	_show_combat_victory_message()


func _show_combat_victory_message() -> void:
	var vp := get_viewport().get_visible_rect().size
	var text_label := Label.new()
	text_label.text = "Alfredo Sinko Nochez est vaincu ! La ville de Kadath est libérée !"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 28)
	text_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	text_label.add_theme_constant_override("outline_size", 2)
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(700, 0)
	text_label.position = Vector2(vp.x / 2.0 - 350, vp.y / 2.0 - 80)
	text_label.size = Vector2(700, 160)
	fade_layer.add_child(text_label)

	await get_tree().create_timer(4.0).timeout

	if is_instance_valid(text_label):
		text_label.queue_free()

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 1.0)
	await tween_fade.finished

	var main = get_tree().current_scene
	if main and main.has_method("warp_to_era"):
		main.warp_to_era("hub", "entree")


func _on_combat_boss_lost() -> void:
	if _combat_boss_instance:
		_combat_boss_instance.queue_free()
		_combat_boss_instance = null

	DialogueUI.hide_all()
	_show_combat_defeat_message()


func _show_combat_defeat_message() -> void:
	var vp := get_viewport().get_visible_rect().size
	var text_label := Label.new()
	text_label.text = "Vous avez succombé... Mais vous pouvez réessayer."
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	text_label.add_theme_constant_override("outline_size", 2)
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(600, 0)
	text_label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 60)
	text_label.size = Vector2(600, 120)
	fade_layer.add_child(text_label)

	await get_tree().create_timer(3.0).timeout

	if is_instance_valid(text_label):
		text_label.queue_free()

	var retry_label := Label.new()
	retry_label.text = "Appuyez sur Espace pour réessayer"
	retry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	retry_label.add_theme_font_size_override("font_size", 20)
	retry_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	retry_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry_label.position = Vector2(vp.x / 2.0 - 200, vp.y / 2.0 + 20)
	retry_label.size = Vector2(400, 50)
	fade_layer.add_child(retry_label)

	await get_tree().create_timer(1.0).timeout

	_start_combat_boss()


func _on_superette_dialogue_ended() -> void:
	if DialogueSystem.dialogue_ended.is_connected(_on_superette_dialogue_ended):
		DialogueSystem.dialogue_ended.disconnect(_on_superette_dialogue_ended)
	var minijeu = $FondSuperette/MiniJeuTourelles
	if minijeu and not minijeu.game_active:
		if not minijeu.finished.is_connected(_on_tourelle_minigame_done):
			minijeu.finished.connect(_on_tourelle_minigame_done)
		_update_objective("Survivez 30 secondes!")
		minijeu.start_game()
		if pnjcheffe:
			pnjcheffe.hide()
			var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
			if zone:
				zone.monitoring = false


func _on_tourelle_minigame_done(success: bool) -> void:
	var minijeu = $FondSuperette/MiniJeuTourelles
	if minijeu:
		if minijeu.finished.is_connected(_on_tourelle_minigame_done):
			minijeu.finished.disconnect(_on_tourelle_minigame_done)
		minijeu.stop_game()

	if success:
		_update_objective("Vous avez survécu !")
		if pnjcheffe:
			pnjcheffe.apparition($"FondSuperette/Markers2D/cheffe".position)
			var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
			if zone:
				zone.monitoring = true
		var label := Label.new()
		label.text = "Vous avez esquivé les tourelles !"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var vp := get_viewport().get_visible_rect().size
		label.position = Vector2(vp.x / 2.0 - 200, vp.y / 2.0 - 40)
		label.size = Vector2(400, 80)
		fade_layer.add_child(label)
		_show_superette_npcs()
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(label):
			label.queue_free()
		DialogueUI.close_dialogue()
		if DialogueSystem.dialogue_ended.is_connected(_on_superette_dialogue_ended):
			DialogueSystem.dialogue_ended.disconnect(_on_superette_dialogue_ended)
		_transition_to_metro()
	else:
		_update_objective("Touché ! Réessayez...")
		var label := Label.new()
		label.text = "TOUCHÉ"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		var vp := get_viewport().get_visible_rect().size
		label.position = Vector2(vp.x / 2.0 - 100, vp.y / 2.0 - 40)
		label.size = Vector2(200, 80)
		fade_layer.add_child(label)
		await get_tree().create_timer(3.0).timeout
		if is_instance_valid(label):
			label.queue_free()
		_auto_start_cheffe_dialogue()


func _set_superette_collisions(enabled: bool) -> void:
	var limite = $FondSuperette.get_node_or_null("limite-superette")
	if limite:
		limite.collision_layer = 128 if enabled else 0


func _transition_to_metro() -> void:
	can_move = false

	var vp := get_viewport().get_visible_rect().size
	var text_label := Label.new()
	text_label.text = "vous vous dirigez vers le QG d'Alfredo"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(600, 0)
	text_label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 60)
	text_label.size = Vector2(600, 120)
	fade_layer.add_child(text_label)

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 4.0)
	await tween_fade.finished

	if is_instance_valid(text_label):
		text_label.queue_free()

	$FondSuperette.hide()
	_set_superette_collisions(false)

	if pnjcheffe:
		pnjcheffe.hide()
		var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false

	$FondMetro.show()
	var metro_collision = $FondMetro.get_node("limite-metro")
	if metro_collision:
		metro_collision.collision_layer = 256
	time_aunote.global_position = $FondMetro/Marker/Entrée.global_position
	time_aunote.show()
	time_aunote.scale = Vector2(0.8, 0.8)
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	if collision_node:
		collision_node.disabled = false

	$ObjectiveHUD.show()
	_update_objective("Trouver le QG d'Alfredo")

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	can_move = true


func _play_cinematique_futur() -> void:
	var video_layer := CanvasLayer.new()
	video_layer.layer = 200
	add_child(video_layer)

	var video_player := VideoStreamPlayer.new()
	var stream := VideoStreamTheora.new()
	stream.file = "res://art/Futur/cinematique_futur.ogv"
	video_player.stream = stream
	video_player.expand = true
	video_player.anchor_left = 0.0
	video_player.anchor_right = 1.0
	video_player.anchor_top = 0.0
	video_player.anchor_bottom = 1.0
	video_layer.add_child(video_player)
	video_player.play()

	video_player.finished.connect(_on_cinematique_finished.bind(video_layer, video_player))


func _on_cinematique_finished(video_layer: CanvasLayer, video_player: VideoStreamPlayer) -> void:
	if is_instance_valid(video_player):
		video_player.queue_free()
	if is_instance_valid(video_layer):
		video_layer.queue_free()
	_transition_to_tower()


func _transition_to_tower() -> void:
	var zone_escalier = $"fondFutur/escalier/zone-escalier"
	if zone_escalier:
		zone_escalier.monitoring = false

	$FondMetro.hide()
	$FondTour.show()
	var tour_limite = $FondTour.get_node_or_null("limite-entree-tour")
	if tour_limite:
		tour_limite.collision_layer = 512

	time_aunote.global_position = $FondTour/Marker/Entrée.global_position
	time_aunote.show()
	time_aunote.modulate.a = 1.0
	time_aunote.scale = Vector2(0.35, 0.35)
	time_aunote.rotation = 0.0
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	if collision_node:
		collision_node.disabled = false

	$ObjectiveHUD.show()
	_update_objective("Entrer dans la tour d'Alfredo Sinko Nochez")

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	can_move = true


func _show_superette_npcs() -> void:
	if not is_inside_tree():
		return
	var koiai = $"FondSuperette/pnj-koiai-2"
	if koiai:
		koiai.apparition($"FondSuperette/Markers2D/koiai".position)
	var vukovi = $"FondSuperette/pnj-vukovi"
	if vukovi:
		vukovi.apparition($"FondSuperette/Markers2D/vukovi".position)
		vukovi.show_bubble("Nero est resté faire le guet dans la voiture")


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_label.custom_minimum_size = Vector2(240.0, 0.0)
		_objective_label.text = text
		_objective_label.reset_size()
		
		var panel = _objective_label.get_parent() as Panel
		if panel:
			panel.size.y = maxf(80.0, 36.0 + _objective_label.size.y + 16.0)


func _set_bureau_collisions(enabled: bool) -> void:
	var limite = $FondBureau.get_node_or_null("limite-bureau")
	if limite:
		limite.collision_layer = 1024 if enabled else 0


func _disable_all_collisions() -> void:
	$fondFutur.hide()
	$SousSol.hide()
	$FondSuperette.hide()
	$FondMetro.hide()
	$FondTour.hide()
	$FondBureau.hide()
	$"pnj-futur".hide()
	$"pnj-cheffe".hide()
	$"SousSol/pnj-futur".hide()
	$"SousSol/pnj-koiai-2".hide()
	_set_upper_collisions(false)
	_set_basement_collisions(false)
	_set_superette_collisions(false)
	var metro_limite = $FondMetro.get_node_or_null("limite-metro")
	if metro_limite:
		metro_limite.collision_layer = 0
	var tour_limite = $FondTour.get_node_or_null("limite-entree-tour")
	if tour_limite:
		tour_limite.collision_layer = 0
	_set_bureau_collisions(false)
	if pnjfutur:
		var zone = pnjfutur.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	if pnjcheffe:
		var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	var boss = $FondBureau.get_node_or_null("pnj-boss")
	if boss:
		boss.hide()
		var zone = boss.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	var ssol_pnj = $"SousSol/pnj-futur"
	if ssol_pnj:
		var zone = ssol_pnj.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	var ssol_koiai = $"SousSol/pnj-koiai-2"
	if ssol_koiai:
		var zone = ssol_koiai.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false


func start(spawn_id: String = "entree") -> void:
	process_mode = PROCESS_MODE_INHERIT
	show()
	_disable_all_collisions()
	_objective_label = $ObjectiveHUD/Panel/Objective
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://Futur/dimension_futur.json")
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 2016
	pnjfutur = $"pnj-futur"
	pnjcheffe = $"pnj-cheffe"

	if spawn_id == "superette":
		$FondSuperette.show()
		_set_superette_collisions(true)
		time_aunote.global_position = $FondSuperette/Markers2D/entree.position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.8, 0.8)
		time_aunote.rotation = 0.0
		var collision_node_super := time_aunote.get_node("collision") as CollisionShape2D
		collision_node_super.disabled = false
		if pnjcheffe:
			pnjcheffe.apparition($FondSuperette/Markers2D/cheffe.position)
			pnjcheffe.show()
			var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
			if zone:
				zone.monitoring = true
		_update_objective("Explorer la supérette")
		can_move = true
		started = true
		stopped = false
		_auto_start_cheffe_dialogue()
		return

	if spawn_id == "soussol":
		$SousSol.show()
		_set_basement_collisions(true)
		$"SousSol/pnj-futur".apparition($"SousSol/fondSousSol/Markers2D/pnjPos".position)
		$"SousSol/pnj-futur/ZoneDialogue".monitoring = true
		$"SousSol/pnj-koiai-2".apparition(pnjkoiai2Pos)
		$"SousSol/pnj-koiai-2/ZoneDialogue".monitoring = true
		time_aunote.position = $"SousSol/fondSousSol/Markers2D/entreeEscalier".position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.8, 0.8)
		time_aunote.rotation = 0.0
		can_move = true
		var collision_node_sol := time_aunote.get_node("collision") as CollisionShape2D
		collision_node_sol.disabled = false
		started = true
		stopped = false
		_update_objective("Parler aux personnes du sous-sol")
		_setup_car_minigame()
		return

	if spawn_id == "metro":
		var zone_escalier = $"fondFutur/escalier/zone-escalier"
		if zone_escalier:
			zone_escalier.monitoring = false
		$FondMetro.show()
		var metro_collision = $FondMetro.get_node("limite-metro")
		if metro_collision:
			metro_collision.collision_layer = 256
		time_aunote.global_position = $FondMetro/Marker/Entrée.global_position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.8, 0.8)
		time_aunote.rotation = 0.0
		var collision_node_metro := time_aunote.get_node("collision") as CollisionShape2D
		collision_node_metro.disabled = false
		can_move = true
		started = true
		stopped = false
		$ObjectiveHUD.show()
		_update_objective("Trouver le QG d'Alfredo")
		return

	if spawn_id == "tour":
		var zone_escalier = $"fondFutur/escalier/zone-escalier"
		if zone_escalier:
			zone_escalier.monitoring = false
		$FondTour.show()
		var tour_limite = $FondTour.get_node_or_null("limite-entree-tour")
		if tour_limite:
			tour_limite.collision_layer = 512
		time_aunote.global_position = $FondTour/Marker/Entrée.global_position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.35, 0.35)
		time_aunote.rotation = 0.0
		var collision_node_tour := time_aunote.get_node("collision") as CollisionShape2D
		collision_node_tour.disabled = false
		can_move = true
		started = true
		stopped = false
		$ObjectiveHUD.show()
		_update_objective("Entrer dans la tour d'Alfredo Sinko Nochez")
		return

	if spawn_id == "bureau":
		$FondBureau.show()
		_set_bureau_collisions(true)
		DialogueSystem.load_dimension("res://Futur/dimension_futur.json")
		var boss = $FondBureau.get_node("pnj-boss")
		if boss:
			boss.apparition($FondBureau/Marker/bossPos.position)
			boss.get_node("ZoneDialogue").monitoring = true
		time_aunote.global_position = $FondBureau/Marker/Entrée.global_position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.8, 0.8)
		time_aunote.rotation = 0.0
		var collision_node_bureau := time_aunote.get_node("collision") as CollisionShape2D
		collision_node_bureau.disabled = false
		can_move = false
		started = true
		stopped = false
		$ObjectiveHUD.show()
		_update_objective("Explorer le bureau")
		if not DialogueSystem.action_triggered.is_connected(_on_boss_action_triggered):
			DialogueSystem.action_triggered.connect(_on_boss_action_triggered)
		_auto_start_boss_dialogue()
		return

	if spawn_id == "entree":
		$fondFutur.show()
		_set_upper_collisions(true)
		$"pnj-futur".show()
		$"pnj-cheffe".show()
		pnjfutur.apparition(pnjfuturPos)
		pnjfutur.get_node("ZoneDialogue").monitoring = true
		pnjcheffe.apparition(pnjcheffePos)
		pnjcheffe.get_node("ZoneDialogue").monitoring = true
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
	_setup_car_minigame()
	var car_zone = $"fondFutur/zone-voiture"
	if car_zone:
		car_zone.monitoring = true


func start_from_escalier() -> void:
	$SousSol.hide()
	$fondFutur.show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	_update_objective("Parler à la cheffe")
	$ObjectiveHUD.show()
	$TimeAunote.show()
	$"pnj-futur".show()
	$"pnj-cheffe".show()
	_set_upper_collisions(true)
	_set_basement_collisions(false)
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 2016
	pnjfutur = $"pnj-futur"
	pnjfutur.apparition(pnjfuturPos)
	pnjfutur.get_node("ZoneDialogue").monitoring = true
	pnjcheffe = $"pnj-cheffe"
	pnjcheffe.apparition(pnjcheffePos)
	pnjcheffe.get_node("ZoneDialogue").monitoring = true
	time_aunote.position = position_entree_escalier
	time_aunote.hide()
	time_aunote.modulate.a = 0.0
	time_aunote.scale = Vector2.ZERO
	time_aunote.rotation = TAU
	_play_spawn_animation(position_entree_escalier)


func stop() -> void:
	process_mode = PROCESS_MODE_DISABLED
	hide()
	$ObjectiveHUD.hide()
	can_move = false
	started = false
	stopped = true
	_car_minigame_active = false
	_player_near_car = false
	if _car_prompt:
		_car_prompt.visible = false
	if _car_minigame:
		_car_minigame.stop_game()
	var car_zone = $"fondFutur/zone-voiture"
	if car_zone:
		car_zone.monitoring = false
	_disable_all_collisions()
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if DialogueSystem.action_triggered.is_connected(_on_boss_action_triggered):
		DialogueSystem.action_triggered.disconnect(_on_boss_action_triggered)
	if DialogueSystem.dialogue_ended.is_connected(_on_superette_dialogue_ended):
		DialogueSystem.dialogue_ended.disconnect(_on_superette_dialogue_ended)
	var minijeu = $FondSuperette/MiniJeuTourelles
	if minijeu:
		if minijeu.finished.is_connected(_on_tourelle_minigame_done):
			minijeu.finished.disconnect(_on_tourelle_minigame_done)
		minijeu.stop_game()
	if _combat_boss_instance:
		_combat_boss_instance.queue_free()
		_combat_boss_instance = null


func _setup_car_minigame() -> void:
	if _car_minigame:
		return
	_car_minigame = $car_minigame
	if _car_minigame:
		_car_minigame.finished.connect(_on_car_minigame_done)

	var zone = $"fondFutur/zone-voiture"
	if zone:
		zone.body_entered.connect(_on_car_zone_entered)
		zone.body_exited.connect(_on_car_zone_exited)

	_setup_car_prompt()


func _setup_car_prompt() -> void:
	var prompt_layer := CanvasLayer.new()
	prompt_layer.layer = 100
	add_child(prompt_layer)
	_car_prompt = Label.new()
	_car_prompt.text = "Appuyez sur E pour conduire la voiture"
	_car_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_car_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_car_prompt.add_theme_font_size_override("font_size", 18)
	_car_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_car_prompt.modulate = Color(1, 1, 1, 0.85)
	_car_prompt.visible = false
	var pstyle_car := StyleBoxFlat.new()
	pstyle_car.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	pstyle_car.border_color = Color(0.6, 0.55, 0.3, 0.7)
	pstyle_car.border_width_top = 2
	pstyle_car.border_width_bottom = 2
	pstyle_car.border_width_left = 2
	pstyle_car.border_width_right = 2
	pstyle_car.corner_radius_top_left = 8
	pstyle_car.corner_radius_top_right = 8
	pstyle_car.corner_radius_bottom_left = 8
	pstyle_car.corner_radius_bottom_right = 8
	_car_prompt.add_theme_stylebox_override("normal", pstyle_car)
	_car_prompt.custom_minimum_size = Vector2(340, 40)
	var vp := get_viewport().get_visible_rect().size
	_car_prompt.position = Vector2(vp.x / 2.0 - 170, vp.y - 100)
	_car_prompt.size = Vector2(340, 40)
	prompt_layer.add_child(_car_prompt)


func _on_car_zone_entered(body: Node2D) -> void:
	if body == time_aunote:
		_player_near_car = true
		_car_prompt.visible = true


func _on_car_zone_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_near_car = false
		_car_prompt.visible = false


func _input(event: InputEvent) -> void:
	if not can_move or not started or _car_minigame_active:
		return
	if event.is_action_pressed("interagir") and _player_near_car and $fondFutur.visible:
		get_viewport().set_input_as_handled()
		_start_car_minigame()


func _start_car_minigame() -> void:
	_car_minigame_active = true
	can_move = false
	_was_in_basement = $SousSol.visible
	_car_prompt.visible = false
	_player_near_car = false

	$fondFutur.hide()
	$SousSol.hide()
	_set_upper_collisions(false)
	_set_basement_collisions(false)
	$"pnj-futur".hide()
	$"pnj-cheffe".hide()
	$"SousSol/pnj-futur".hide()
	time_aunote.hide()
	$ObjectiveHUD.hide()

	if _car_minigame:
		_car_minigame.start_game()


func _on_car_minigame_done(success: bool) -> void:
	_car_minigame_active = false
	_car_prompt.visible = false
	_player_near_car = false

	if not success:
		if _was_in_basement:
			$SousSol.show()
			_set_basement_collisions(true)
			$"SousSol/pnj-futur".show()
			$"pnj-futur".hide()
			$"pnj-cheffe".hide()
		else:
			$fondFutur.show()
			_set_upper_collisions(true)
			$"pnj-futur".show()
			$"pnj-cheffe".show()

		time_aunote.show()
		$ObjectiveHUD.show()
		can_move = true

		if pnjfutur and not _was_in_basement:
			pnjfutur.get_node("ZoneDialogue").monitoring = true
		if pnjcheffe and not _was_in_basement:
			pnjcheffe.get_node("ZoneDialogue").monitoring = true

		_update_objective(_objective_label.text if _objective_label else "Parler à la cheffe")
		if pnjkoiai2:
			var zone = pnjkoiai2.get_node_or_null("ZoneDialogue")
			if zone:
				zone.monitoring = false
		var zone_vukovi = $"SousSol/pnj-futur/ZoneDialogue"
		if zone_vukovi:
			zone_vukovi.monitoring = false
		return

	can_move = false
	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	var vp := get_viewport().get_visible_rect().size
	var text_label := Label.new()
	text_label.text = "L'inébranlable groupe se refugie dans une supérette abandonnée"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(600, 0)
	text_label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 60)
	text_label.size = Vector2(600, 120)
	fade_layer.add_child(text_label)

	await get_tree().create_timer(3.0).timeout

	$fondFutur.hide()
	$SousSol.hide()
	$"pnj-futur".hide()
	$"pnj-cheffe".hide()
	$"SousSol/pnj-futur".hide()
	time_aunote.hide()
	$ObjectiveHUD.hide()
	_set_upper_collisions(false)
	_set_basement_collisions(false)
	if pnjfutur:
		var zone = pnjfutur.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	if pnjcheffe:
		var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false

	$FondSuperette.show()

	text_label.queue_free()

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_show_superette_scene()
