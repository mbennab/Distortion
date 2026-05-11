extends Node2D

var pnj_futur
var pnj_pos: Vector2


func _ready() -> void:
	pnj_pos = $"fondSousSol/Markers2D/pnjPos".position
	hide()
	pnj_futur = $"pnj-futur"
	_connect_escalier_signals()


func _connect_escalier_signals() -> void:
	var zone_remontee = $"fondSousSol/escalier/zone_remontee"
	zone_remontee.body_entered.connect(_on_remontee_entered)


func _on_remontee_entered(body: Node2D) -> void:
	var parent = get_parent()
	if body == parent.time_aunote and parent.can_move:
		parent._return_from_basement()
