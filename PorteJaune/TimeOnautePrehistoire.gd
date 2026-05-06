extends CharacterBody2D

var timeAunoteAnimation
var timeAunoteCollision
var timerAttente
var speed = 200
var screenSize

func _ready():
	screenSize = get_viewport_rect().size
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
	deplacement(_delta)

func apparition(pos):
	timeAunoteAnimation.animation = "repos"
	position = pos
	var animationPorte = $"../fondPrehistoire/porteJauneAnimee/AnimationPlayer"
	var animationPlayer = $animationTimeOnaute
	show()
	animationPorte.play("animationPorte")
	animationPlayer.play("animationPlayer")
	timeAunoteCollision.disabled = false

func deplacement(delta):
	var vel = Vector2.ZERO
	if Input.is_action_pressed("ui_up"):
		vel.y -= 1
	if Input.is_action_pressed("ui_down"):
		vel.y += 1
	if Input.is_action_pressed("ui_right"):
		vel.x += 1
	if Input.is_action_pressed("ui_left"):
		vel.x -= 1
	avance(vel.normalized() * speed * delta)

func avance(mouvement):
	if mouvement == Vector2.ZERO:
		if timerAttente.is_stopped():
			timeAunoteAnimation.animation = "attente"
		else:
			timeAunoteAnimation.animation = "repos"
		return
	if mouvement.x != 0:
		timeAunoteAnimation.animation = "marche_droite"
		timeAunoteAnimation.flip_h = mouvement.x < 0
	if mouvement.y != 0:
		if mouvement.y > 0:
			timeAunoteAnimation.animation = "marche_bas"
		else:
			timeAunoteAnimation.animation = "marche_haut"
	move_and_collide(mouvement)
	timerAttente.start()
