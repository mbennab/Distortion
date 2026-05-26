extends Node2D

var sceneHUB
var sceneMoyenAge
var scenePresent
var sceneFutur
var current_zone: String = "hub"

func _ready():
	sceneHUB = $TimeAunoteDansHUBCentral
	sceneMoyenAge = $MoyenAge
	scenePresent = $Present
	sceneFutur = $Futur

	if DialogueSystem.should_load_save:
		DialogueSystem.should_load_save = false
		var ok = DialogueSystem.load_game_state()
		if not ok:
			sceneHUB.start()
	else:
		sceneHUB.start()

func _process(_delta):
	if sceneHUB == null:
		return
	if not sceneHUB.started and not sceneHUB.stopped:
		sceneHUB.stop()
		match sceneHUB.next_scene:
			"MoyenAge":
				sceneMoyenAge.start()
				current_zone = "moyenage"
			"Present":
				scenePresent.start()
				current_zone = "present"
			"Futur":
				sceneFutur.start()
				current_zone = "futur"
			_:
				pass


func warp_to_era(zone: String, spawn_id: String) -> void:
	match current_zone:
		"hub": sceneHUB.stop()
		"moyenage": sceneMoyenAge.stop()
		"present": scenePresent.stop()
		"futur": sceneFutur.stop()

	match zone:
		"hub":
			sceneHUB.start(spawn_id)
			current_zone = "hub"
		"moyenage":
			sceneMoyenAge.start(spawn_id)
			current_zone = "moyenage"
		"present":
			scenePresent.start(spawn_id)
			current_zone = "present"
		"futur":
			sceneFutur.start(spawn_id)
			current_zone = "futur"
