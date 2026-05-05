extends CharacterBody2D

var timeAunoteAnimation
var timeAunoteCollision
var timerAttente

func _ready():
	hide()
	timeAunoteAnimation = $animation
	timeAunoteAnimation.flip_h = false
	timeAunoteAnimation.flip_v = false
	timeAunoteAnimation.play()
	timeAunoteCollision = $collision
	timeAunoteCollision.disabled = true
	timerAttente = $timerAttente
	timerAttente.start()

func _process(delta):
	pass

func apparition(position):
	timeAunoteAnimation.animation = "repos"
	self.position = position
	show()
	timeAunoteCollision.disabled = false

func animation(mouvement):
	if mouvement == Vector2.ZERO:
		if timerAttente.is_stopped():
			timeAunoteAnimation.animation = "attente"
		else:
			timeAunoteAnimation.animation = "repos"
		return
	if mouvement.x != 0:
		timeAunoteAnimation.animation = "marche_droite"
		if mouvement.x > 0:
			timeAunoteAnimation.flip_h = false
		else:
			timeAunoteAnimation.flip_h = true
	if mouvement.y != 0:
		if mouvement.y > 0:
			timeAunoteAnimation.animation = "marche_bas"
		else:
			timeAunoteAnimation.animation = "marche_haut"
	timerAttente.start()
