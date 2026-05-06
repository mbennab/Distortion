extends Node2D

var timeAunote
var pnjHub
var positionEntreePrincipale
var pnjPos
var started = false
var stopped = true
var limites
var zonePorteJaune
var zonePorteBleue
var zonePorteRouge
var porteGauche
var porteDroite
var timerSortie
var speed = 350
var particles
var next_scene = ""


func _ready():
	hide()
	positionEntreePrincipale = $"fondHubCentral/Markers2D/entreePrincipale".position
	limites = $"fondHubCentral/limitesDeplacament"
	zonePorteJaune = $"fondHubCentral/portesVoyageTemps/zonePorteJaune"
	zonePorteBleue = $"fondHubCentral/portesVoyageTemps/zonePorteBleue"
	zonePorteRouge = $"fondHubCentral/portesVoyageTemps/zonePorteRouge"
	porteGauche = $"fondHubCentral/portesVoyageSalles/porteGauche"
	porteDroite = $"fondHubCentral/portesVoyageSalles/porteDroite"
	timerSortie = $timerSortie
	timeAunote = $TimeAunote
	pnjHub = $"pnj-hub"
	pnjPos = $"fondHubCentral/Markers2D/pnjPos".position
	_setup_particles()
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

func _connect_portal_signals():
	zonePorteJaune.body_entered.connect(_on_porte_jaune_entered)
	zonePorteBleue.body_entered.connect(_on_porte_bleue_entered)
	zonePorteRouge.body_entered.connect(_on_porte_rouge_entered)

func _on_porte_jaune_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "MoyenAge"
		_trigger_portal("jaune", zonePorteJaune.global_position, Color.YELLOW)

func _on_porte_bleue_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "Present"
		_trigger_portal("bleue", zonePorteBleue.global_position, Color.DODGER_BLUE)

func _on_porte_rouge_entered(body):
	if body == timeAunote and not timerSortie.time_left > 0:
		next_scene = "Futur"
		_trigger_portal("rouge", zonePorteRouge.global_position, Color.RED)

func _trigger_portal(porte_name, pos, color):
	print(porte_name)
	particles.global_position = pos
	particles.color_ramp = _create_color_ramp(color)
	particles.restart()
	timeAunote.fade_out()
	timerSortie.start()

func _process(_delta):
	deplacement(_delta)

func start():
	show()
	timeAunote = $TimeAunote
	timeAunote.apparition(positionEntreePrincipale)
	pnjHub.apparition(pnjPos)
	started = true
	stopped = false

func stop():
	hide()
	started = false
	stopped = true

func _on_timer_sortie_timeout():
	print("stop")
	hide()
	started = false

func deplacement(delta):
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
		if collisioneur == porteGauche:
			print("porteGauche")
			var retour = $"fondHubCentral/Markers2D/retourDroite"
			timeAunote.position = retour.global_position
			return
		if collisioneur == porteDroite:
			print("porteDroite")
			var retour = $"fondHubCentral/Markers2D/retourGauche"
			timeAunote.position = retour.global_position
			return
