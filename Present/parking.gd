extends Node2D

func _ready() -> void:
	_connect_retour_signal()

func _connect_retour_signal() -> void:
	var zone_retour = get_node_or_null("zone retour parking")
	if zone_retour:
		zone_retour.body_entered.connect(_on_retour_parking_entered)

func _on_retour_parking_entered(body: Node2D) -> void:
	var parent = get_parent()
	if body == parent.time_aunote and parent.can_move:
		parent._return_from_parking()
