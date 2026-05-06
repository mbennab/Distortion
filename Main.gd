extends Node2D

var sceneHUB
var scenePrehistoire

func _ready():
	sceneHUB = $TimeAunoteDansHUBCentral
	sceneHUB.start()
	scenePrehistoire = $TimeOnauteDansPrehistoire

func _process(_delta):
	if not sceneHUB.started and not sceneHUB.stopped:
		sceneHUB.stop()
		scenePrehistoire.start()
