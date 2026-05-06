extends CharacterBody2D

var timeAunoteAnimation
var timeAunoteCollision
var timerAttente
var direction = "bas"

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

func _process(_delta):
	pass

func apparition(pos):
	modulate.a = 1.0
	timeAunoteAnimation.animation = "idle_face"
	self.position = pos
	show()
	timeAunoteCollision.disabled = false

func fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)

func animation(mouvement):
	if mouvement == Vector2.ZERO:
		match direction:
			"bas":
				timeAunoteAnimation.animation = "idle_face"
			"haut":
				timeAunoteAnimation.animation = "idle_dos"
			"droite":
				timeAunoteAnimation.animation = "idle_cote"
				timeAunoteAnimation.flip_h = false
			"gauche":
				timeAunoteAnimation.animation = "idle_cote"
				timeAunoteAnimation.flip_h = true
	
	if mouvement.x != 0:
		timeAunoteAnimation.animation = "marche_cote"
		if mouvement.x > 0:
			timeAunoteAnimation.flip_h = true
			direction = "gauche"
		else:
			timeAunoteAnimation.flip_h = false
			direction = "droite"
	elif mouvement.y != 0:
		if mouvement.y > 0:
			timeAunoteAnimation.animation = "marche_face"
			direction = "bas"
		else:
			timeAunoteAnimation.animation = "marche_dos"
			direction = "haut"
	timerAttente.start()
