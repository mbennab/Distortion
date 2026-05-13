extends Node2D

var _active := false

func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	var sortie := $Sortie
	if sortie:
		sortie.collision_mask = 1
		sortie.monitoring = false
		sortie.body_entered.connect(_on_sortie_entered)

func start() -> void:
	_active = true
	process_mode = PROCESS_MODE_INHERIT
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 4
	show()

func stop() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	var static_body = $StaticBody2D
	if static_body:
		static_body.collision_layer = 0
	$Sortie.monitoring = false
	hide()

func _on_sortie_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_auberge_exit"):
		parent._on_auberge_exit()
