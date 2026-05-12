extends Node2D

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var timeAunote
var pnjHub
var chienHub
var positionEntreePrincipale
var pnjPos
var chienPos
var started = false
var stopped = true
var limites
var zonePorteJaune
var zonePorteBleue
var zonePorteRouge
var timerSortie
var speed = 350
var particles
var next_scene = ""


var _ambient_player: AudioStreamPlayer
var _ambient_streams: Array[AudioStream] = []
var _portal_glows: Array[Sprite2D] = []
var _glow_tweens: Array[Tween] = []
var _objective_label: Label

func _ready():
	hide()
	positionEntreePrincipale = $"fondHubCentral/Markers2D/entreePrincipale".position
	limites = $"fondHubCentral/limitesDeplacament"
	zonePorteJaune = $"fondHubCentral/portesVoyageTemps/zonePorteJaune"
	zonePorteBleue = $"fondHubCentral/portesVoyageTemps/zonePorteBleue"
	zonePorteRouge = $"fondHubCentral/portesVoyageTemps/zonePorteRouge"

	timerSortie = $timerSortie
	timeAunote = $TimeAunote
	pnjHub = $"pnj-hub"
	pnjPos = $"fondHubCentral/Markers2D/pnjPos".position
	chienHub = $"chien-hub"
	chienPos = $"fondHubCentral/Markers2D/chienPos".position
	_setup_particles()
	_setup_portal_glows()
	_setup_ambient_audio()
	_connect_portal_signals()

func _setup_particles():
	particles = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 50
	particles.lifetime = 0.7
	particles.explosiveness = 1.0
	particles.speed_scale = 1.5
	particles.texture = _create_particle_texture()
	particles.z_index = 20
	particles.spread = 60.0
	particles.gravity = Vector2(0, -50)
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 1.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	add_child(particles)

func _create_particle_texture():
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center = Vector2(16, 16)
	for y in range(32):
		for x in range(32):
			var dist = Vector2(x, y).distance_to(center) / 16.0
			var alpha = clamp(1.0 - dist, 0.0, 1.0)
			alpha = ease(alpha, 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _create_color_ramp(color):
	var gradient = Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient

func _setup_ambient_audio() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = -8.0
	add_child(_ambient_player)

	var dir := DirAccess.open("res://audio/hub/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
				var stream := load("res://audio/hub/" + file_name) as AudioStream
				if stream:
					_ambient_streams.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()

func _play_ambient() -> void:
	if not _ambient_streams.is_empty():
		var idx := randi() % _ambient_streams.size()
		_ambient_player.stream = _ambient_streams[idx]
		_ambient_player.play()

func _stop_ambient() -> void:
	_ambient_player.stop()

func _setup_portal_glows() -> void:
	var glow_texture := _create_glow_texture()
	var portals := [
		{"area": zonePorteRouge, "color": Color.GREEN},
		{"area": zonePorteBleue, "color": Color.PURPLE},
		{"area": zonePorteJaune, "color": Color.ORANGE},
	]
	for i in portals.size():
		var p: Dictionary = portals[i]
		var sprite := Sprite2D.new()
		sprite.texture = glow_texture
		sprite.modulate = p["color"]
		sprite.z_index = 5
		sprite.centered = true
		sprite.scale = Vector2(0.8, 0.8)
		sprite.visible = false
		sprite.position = to_local(p["area"].global_position)
		add_child(sprite)
		_portal_glows.append(sprite)

		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.15, 1.6)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.7, 0.7), 1.6)
		tween.tween_property(sprite, "modulate:a", 0.5, 1.6)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 1.6)
		tween.stop()
		_glow_tweens.append(tween)

func _create_glow_texture() -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var max_dist := size / 2.0
	for y in range(size):
		for x in range(size):
			var dist := Vector2(x, y).distance_to(center)
			if dist > max_dist:
				image.set_pixel(x, y, Color.TRANSPARENT)
				continue
			var alpha := 1.0 - dist / max_dist
			alpha = ease(alpha, 4.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _start_portal_glows() -> void:
	for i in _portal_glows.size():
		_portal_glows[i].visible = true
		_portal_glows[i].position = to_local(
			[zonePorteRouge, zonePorteBleue, zonePorteJaune][i].global_position
		)
		_glow_tweens[i].play()

func _stop_portal_glows() -> void:
	for i in _glow_tweens.size():
		_glow_tweens[i].stop()
	for glow in _portal_glows:
		glow.visible = false

func _connect_portal_signals():
	zonePorteJaune.body_entered.connect(_on_porte_jaune_entered)
	zonePorteBleue.body_entered.connect(_on_porte_bleue_entered)
	zonePorteRouge.body_entered.connect(_on_porte_rouge_entered)

func _on_porte_jaune_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "MoyenAge"
		_trigger_portal("jaune", zonePorteJaune.global_position, Color.ORANGE)

func _on_porte_bleue_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "Present"
		_trigger_portal("bleue", zonePorteBleue.global_position, Color.PURPLE)

func _on_porte_rouge_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "Futur"
		_trigger_portal("rouge", zonePorteRouge.global_position, Color.GREEN)

func _trigger_portal(porte_name, pos, color):
	print(porte_name)
	particles.global_position = pos
	particles.color_ramp = _create_color_ramp(color)
	particles.restart()
	timeAunote.fade_out()
	timerSortie.start()

func _process(_delta):
	deplacement(_delta)

func _update_objective(text: String) -> void:
	_objective_label.text = text

func start(spawn_id: String = "entree"):
	TimeAunoteScript.disguised = false
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	_objective_label.text = "Parler au Gardien du Nexus"
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://HUB Central/dimension_hub.json")
	timeAunote = $TimeAunote
	timeAunote.collision_mask = 2
	match spawn_id:
		"gauche":
			timeAunote.apparition($"fondHubCentral/Markers2D/retourGauche".position)
		"droite":
			timeAunote.apparition($"fondHubCentral/Markers2D/retourDroite".position)
		_:
			timeAunote.apparition(positionEntreePrincipale)
	pnjHub.apparition(pnjPos)
	chienHub.apparition(chienPos)
	_set_collisions_enabled(true)
	_start_portal_glows()
	_play_ambient()
	started = true
	stopped = false

func stop():
	hide()
	$ObjectiveHUD.hide()
	DialogueUI.close_dialogue()
	_stop_portal_glows()
	_stop_ambient()
	_set_collisions_enabled(false)
	chienHub.stop_idle()
	pnjHub.stop_idle()
	started = false
	stopped = true

func _set_collisions_enabled(enable: bool) -> void:
	limites.collision_layer = 2 if enable else 0

	zonePorteJaune.monitoring = enable
	zonePorteBleue.monitoring = enable
	zonePorteRouge.monitoring = enable
	pnjHub.get_node("ZoneDialogue").monitoring = enable
	chienHub.get_node("Area2D").monitoring = enable
	timeAunote.get_node("collision").disabled = not enable

func _on_timer_sortie_timeout():
	print("stop")
	hide()
	started = false

func deplacement(delta):
	if not started or DialogueUI.is_dialogue_active():
		timeAunote.animation(Vector2.ZERO)
		return
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("marche_haut"):
		velocity.y -= 1
	if Input.is_action_pressed("marche_bas"):
		velocity.y += 1
	if Input.is_action_pressed("marche_droite"):
		velocity.x += 1
	if Input.is_action_pressed("marche_gauche"):
		velocity.x -= 1
	timeAunote.animation(velocity.normalized())
	avance(velocity.normalized() * speed * delta)

func avance(mouvement):
	var collision = timeAunote.move_and_collide(mouvement)
	if collision:
		var collisioneur = collision.get_collider()
		if collisioneur == limites:
			print("limites")
			return
