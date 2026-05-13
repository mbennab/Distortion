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

	time_aunote.global_position = $"Parking/Node2D/zone pop".global_position
	time_aunote.scale = Vector2(0.65, 0.65)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	DialogueSystem.complete_step("quete_acces_centrale", "etape_chercher_carte")
	_update_objective("Fouiller le parking")
	can_move = true


func _return_from_parking() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$Parking.hide()
	_set_parking_collisions(false)

	$fondPresent.show()
	_set_fond_collisions(true)
	if pnj_secu:
		pnj_secu.show()
		pnj_secu.apparition(secu_pos)
		pnj_secu.get_node("ZoneDialogue").monitoring = true

	time_aunote.global_position = $"fondPresent/Markers2D/retourParking".global_position
	time_aunote.scale = Vector2(0.5, 0.5)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Retourner voir l'agent de sécurité")
	can_move = true


func _on_action_triggered(action: Dictionary) -> void:
	if not started:
		return
	if action.get("type") == "trigger" and action.get("id") == "secu_quete_avance":
		_try_unlock_parking()


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
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://Present/dimension_present.json")
	$fondPresent.show()
	_set_fond_collisions(true)
	$Parking.hide()
	_set_parking_collisions(false)
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 8
	pnj_secu = $"PnjSecurité"
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


func stop() -> void:
	hide()
	$ObjectiveHUD.hide()
	can_move = false
	started = false
	stopped = true
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if pnj_secu:
		var zone = pnj_secu.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	$Parking.hide()
	_set_parking_collisions(false)
