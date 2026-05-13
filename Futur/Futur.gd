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


func _ready() -> void:
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
		limite.collision_layer = 16 if enabled else 0


func _set_basement_collisions(enabled: bool) -> void:
	var limite = $"SousSol/fondSousSol".get_node_or_null("limite-sous-sol")
	if limite:
		limite.collision_layer = 16 if enabled else 0


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


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = text

func start(spawn_id: String = "entree") -> void:
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	_update_objective("Parler à la cheffe")
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://Futur/dimension_futur.json")
	$fondFutur.show()
	$"pnj-futur".show()
	$"pnj-cheffe".show()
	$SousSol.hide()
	_set_upper_collisions(true)
	_set_basement_collisions(false)
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 16
	pnjfutur = $"pnj-futur"
	pnjfutur.apparition(pnjfuturPos)
	pnjfutur.get_node("ZoneDialogue").monitoring = true
	pnjcheffe = $"pnj-cheffe"
	pnjcheffe.apparition(pnjcheffePos)
	pnjcheffe.get_node("ZoneDialogue").monitoring = true

	if spawn_id == "soussol":
		$fondFutur.hide()
		_set_upper_collisions(false)
		$"pnj-futur".hide()
		$"pnj-cheffe".hide()
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
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = false
		started = true
		stopped = false
		_update_objective("Parler aux personnes du sous-sol")
		_setup_car_minigame()
		return

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
	time_aunote.collision_mask = 16
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
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if pnjfutur:
		var zone = pnjfutur.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	if pnjcheffe:
		var zone = pnjcheffe.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false


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
	_car_prompt.add_theme_color_override("font_color", Color.WHITE)
	_car_prompt.modulate = Color(1, 1, 1, 0.85)
	_car_prompt.visible = false
	var vp := get_viewport().get_visible_rect().size
	_car_prompt.position = Vector2(vp.x / 2.0 - 200, vp.y - 100)
	_car_prompt.size = Vector2(400, 50)
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
	if event.is_action_pressed("interagir") and _player_near_car:
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
