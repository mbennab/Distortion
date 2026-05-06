extends Node2D

var sceneHUB
var sceneMoyenAge
var scenePresent
var sceneFutur

func _ready():
	sceneHUB = $TimeAunoteDansHUBCentral
	sceneHUB.start()
	sceneMoyenAge = $MoyenAge
	scenePresent = $Present
	sceneFutur = $Futur

func _process(_delta):
	if sceneHUB == null:
		return
	if not sceneHUB.started and not sceneHUB.stopped:
		sceneHUB.stop()
		match sceneHUB.next_scene:
			"MoyenAge":
				sceneMoyenAge.start()
			"Present":
				scenePresent.start()
			"Futur":
				sceneFutur.start()
			_:
				pass
