extends Node2D


var pnjcheffeAnimation

func _ready():
	hide()
	pnjcheffeAnimation = $pnjcheffeAnimation
	pnjcheffeAnimation.play()

func _process(delta):
	pass

func apparition(position):
	pnjcheffeAnimation.animation = "idle-cheffe"
	self.position = position
	show()
