extends Node2D

var timeAunote
var positionEntreePrincipale
var started = false
var stopped = true
var limites
var porteJaune
var porteBleue
var porteRouge
var porteGauche
var porteDroite
var timerSortie
var speed = 350

func _ready():
	hide()
	positionEntreePrincipale = $"fondHubCentral/Markers2D/entreePrincipale".position
	limites = $"fondHubCentral/limitesDeplacament"
	porteJaune = $"fondHubCentral/portesVoyageTemps/porteJaune"
	porteBleue = $"fondHubCentral/portesVoyageTemps/porteBleue"
	porteRouge = $"fondHubCentral/portesVoyageTemps/porteRouge"
	porteGauche = $"fondHubCentral/portesVoyageSalles/porteGauche"
	porteDroite = $"fondHubCentral/portesVoyageSalles/porteDroite"
	timerSortie = $timerSortie
	timeAunote = $TimeAunote

func _process(delta):
	deplacement(delta)

func start():
	show()
	timeAunote = $TimeAunote
	timeAunote.apparition(positionEntreePrincipale)
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

func _handle_porte_animation(porte_name, porte_animee_path):
	print(porte_name)
	var animationPorte = get_node(porte_animee_path + "/AnimationPlayer")
	var animationPlayer = $"TimeAunote/animationTimeAunote"
	var destination_pos = get_node(porte_animee_path).position
	var anim = animationPlayer.get_animation("animationPlayer")
	var track_id = anim.find_track(".:position", 0)
	anim.track_set_key_value(track_id, 0, timeAunote.position)
	anim.track_set_key_value(track_id, 1, destination_pos)
	animationPorte.play("animationPorte")
	animationPlayer.play("animationPlayer")
	timerSortie.start()

func avance(mouvement):
	var collision = timeAunote.move_and_collide(mouvement)
	if collision:
		var collisioneur = collision.get_collider()
		if collisioneur == limites:
			print("limites")
			return
		if collisioneur == porteJaune:
			_handle_porte_animation("porteJaune", "fondHubCentral/porteJauneAnimee")
			return
		if collisioneur == porteBleue:
			_handle_porte_animation("porteBleue", "fondHubCentral/porteBleueAnimee")
			return
		if collisioneur == porteRouge:
			_handle_porte_animation("porteRouge", "fondHubCentral/porteRougeAnimee")
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
