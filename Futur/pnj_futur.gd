extends Node2D


var pnjfuturAnimation

func _ready():
	hide()
	pnjfuturAnimation = $pnjfuturAnimation
	pnjfuturAnimation.play()

func _process(delta):
	pass

func apparition(position):
	pnjfuturAnimation.animation = "idle-futur1"
	self.position = position
	show()
