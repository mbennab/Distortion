extends Node2D


var pnjHubAnimation

func _ready():
	hide()
	pnjHubAnimation = $animation_pnj_hub
	pnjHubAnimation.play()

func _process(delta):
	pass

func apparition(position):
	pnjHubAnimation.animation = "idle"
	self.position = position
	show()
