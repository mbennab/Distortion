extends Node2D

var time_aunote: CharacterBody2D
var pnjfutur
var pnjfuturPos
var position_entree_principale: Vector2
var started: bool = false
var stopped: bool = true
var can_move: bool = false
var speed: float = 350.0
var spawn_particles: CPUParticles2D

func _ready() -> void:
	position_entree_principale = $"fondFutur/Markers2D/entreePrincipale".position
	hide()
	_setup_spawn_particles()
	pnjfutur = $"pnj-futur"
	pnjfuturPos = $"fondFutur/Markers2D/pnjfuturPos".position


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

func start() -> void:
	show()
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 16
	pnjfutur = $"pnj-futur"
	pnjfutur.apparition(pnjfuturPos)
	time_aunote.position = position_entree_principale
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
	can_move = false
	started = false
	stopped = true
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
