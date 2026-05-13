extends Node2D

var _active := false

func _ready() -> void:
	$areas2D/chateau.monitoring = false
	$areas2D/magasin.monitoring = false
	$areas2D/auberge.monitoring = false
	$areas2D/chateau.body_entered.connect(_on_chateau_entered)
	$areas2D/magasin.body_entered.connect(_on_magasin_entered)
	$areas2D/auberge.body_entered.connect(_on_auberge_entered)


func start() -> void:
	_active = true
	show()
	_set_collisions(true)
	$areas2D/chateau.monitoring = true
	$areas2D/magasin.monitoring = true
	$areas2D/auberge.monitoring = true


func stop() -> void:
	_active = false
	hide()
	_set_collisions(false)
	$areas2D/chateau.monitoring = false
	$areas2D/magasin.monitoring = false
	$areas2D/auberge.monitoring = false


func _set_collisions(enabled: bool) -> void:
	var static_body := $StaticBody2D
	if static_body:
		static_body.collision_layer = 4 if enabled else 0


func _on_chateau_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_ville_to_prison"):
		parent._on_ville_to_prison()


func _on_magasin_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_ville_to_magasin"):
		parent._on_ville_to_magasin()


func _on_auberge_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_ville_to_auberge"):
		parent._on_ville_to_auberge()
