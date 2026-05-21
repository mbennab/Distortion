extends Node2D

var _active := false
var _mg_instance: CanvasLayer = null


func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	var sortie := $areas2D/sortieGauche
	if sortie:
		sortie.collision_mask = 1
		sortie.monitoring = false
		sortie.body_entered.connect(_on_sortie_entered)

	if $femme:
		$femme.get_node("ZoneDialogue").monitoring = false

	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)


func start() -> void:
	_active = true
	process_mode = PROCESS_MODE_INHERIT
	var static_body = $collisions
	if static_body:
		static_body.collision_layer = 4
	$areas2D/sortieGauche.monitoring = true
	if $femme:
		var pos: Vector2 = $markers2D/femme.position
		$femme.apparition(pos)
		$femme.get_node("ZoneDialogue").monitoring = true
	show()


func stop() -> void:
	_active = false
	process_mode = PROCESS_MODE_DISABLED
	var static_body = $collisions
	if static_body:
		static_body.collision_layer = 0
	$areas2D/sortieGauche.monitoring = false
	_cleanup_minigame()
	if $femme:
		$femme.get_node("ZoneDialogue").monitoring = false
		$femme.hide()
	hide()


func _on_sortie_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_parc_exit"):
		parent._on_parc_exit()


func _on_dialogue_started(npc_id: String, _npc_name: String) -> void:
	if npc_id == "npc_femme_parc":
		var bulle = $markers2D/bulle/spr_bulle
		if bulle:
			bulle.hide()
		_start_minigame()


func _on_dialogue_ended() -> void:
	if _mg_instance and is_instance_valid(_mg_instance) and _mg_instance._won:
		return
	_cleanup_minigame()


func _start_minigame() -> void:
	if _mg_instance != null:
		return
	var mg_scene = preload("res://Scripts/MiniJeuAmitie.tscn")
	_mg_instance = mg_scene.instantiate()
	_mg_instance.done.connect(_on_minigame_done)
	get_tree().root.add_child(_mg_instance)
	_mg_instance.start()


func _cleanup_minigame() -> void:
	if _mg_instance and is_instance_valid(_mg_instance):
		_mg_instance.stop()
		_mg_instance.queue_free()
		_mg_instance = null


func _on_minigame_done(success: bool) -> void:
	_cleanup_minigame()
	if success:
		DialogueSystem.complete_step("quete_piste_assassin", "etape_trouver_assassin")
		DialogueUI.close_dialogue()
		var parent = get_parent()
		if parent and parent.has_method("_on_femme_friendship_done"):
			parent._on_femme_friendship_done()
