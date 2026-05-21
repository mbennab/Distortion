extends CharacterBody2D

static var disguised := false
static var disguised_present := false

var timeAunoteAnimation
var timeAunoteCollision
var timerAttente
var direction = "bas"

func _ready():
	hide()
	timeAunoteAnimation = $animation
	timeAunoteAnimation.flip_h = false
	timeAunoteAnimation.flip_v = false
	timeAunoteAnimation.animation = _anim_name("marche_face")
	timeAunoteAnimation.play()
	timeAunoteCollision = $collision
	timeAunoteCollision.disabled = true
	timerAttente = $timerAttente
	timerAttente.start()

func _process(_delta):
	pass

func _anim_name(base: String) -> String:
	if disguised_present:
		return base + "_P"
	if disguised:
		return base + "_MA"
	return base

func apparition(pos):
	modulate.a = 1.0
	timeAunoteAnimation.animation = _anim_name("idle_face")
	self.position = pos
	show()
	timeAunoteCollision.disabled = false

func apply_disguise() -> void:
	disguised = true
	animation(Vector2.ZERO)

func remove_disguise() -> void:
	disguised = false
	animation(Vector2.ZERO)

func apply_disguise_present() -> void:
	disguised_present = true
	animation(Vector2.ZERO)

func remove_disguise_present() -> void:
	disguised_present = false
	animation(Vector2.ZERO)

func fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.2)

func animation(mouvement):
	if mouvement == Vector2.ZERO:
		match direction:
			"bas":
				timeAunoteAnimation.animation = _anim_name("idle_face")
			"haut":
				timeAunoteAnimation.animation = _anim_name("idle_dos")
			"droite":
				timeAunoteAnimation.animation = _anim_name("idle_cote")
				timeAunoteAnimation.flip_h = false
			"gauche":
				timeAunoteAnimation.animation = _anim_name("idle_cote")
				timeAunoteAnimation.flip_h = true
	
	if mouvement.x != 0:
		timeAunoteAnimation.animation = _anim_name("marche_cote")
		if mouvement.x > 0:
			timeAunoteAnimation.flip_h = true
			direction = "gauche"
		else:
			timeAunoteAnimation.flip_h = false
			direction = "droite"
	elif mouvement.y != 0:
		if mouvement.y > 0:
			timeAunoteAnimation.animation = _anim_name("marche_face")
			direction = "bas"
		else:
			timeAunoteAnimation.animation = _anim_name("marche_dos")
			direction = "haut"
	timerAttente.start()
