extends Node2D

var pnj_marchand


func _ready() -> void:
	pnj_marchand = $"pnj-marchand"
	if pnj_marchand:
		pnj_marchand.get_node("ZoneDialogue").monitoring = false


func start() -> void:
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 4
	var marchand_pos: Vector2 = $Markers2D/marchandPos.position
	if pnj_marchand and pnj_marchand.has_method("apparition"):
		pnj_marchand.apparition(marchand_pos)
		pnj_marchand.get_node("ZoneDialogue").monitoring = true
	show()


func stop() -> void:
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 0
	if pnj_marchand:
		pnj_marchand.get_node("ZoneDialogue").monitoring = false
		pnj_marchand.hide()
	hide()
