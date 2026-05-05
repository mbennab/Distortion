extends Node2D

var timeAunote
var positionEntreePrincipale
var started = false
var stopped = true

func _ready():
	positionEntreePrincipale = $"fondPrehistoire/Markers2D/entreePrincipale".position
	hide()

func _process(_delta):
	pass

func start():
	show()
	timeAunote = $TimeOnautePrehistoire
	timeAunote.apparition(positionEntreePrincipale)
	started = true
	stopped = false

func stop():
	hide()
	started = false
	stopped = true
