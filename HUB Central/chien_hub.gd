extends Node2D


var chienHubAnimation

func _ready():
	hide()
	chienHubAnimation = $animation_chien_hub
	chienHubAnimation.play()

func _process(delta):
	pass

func apparition(position):
	chienHubAnimation.animation = "idle-dog"
	self.position = position
	show()
