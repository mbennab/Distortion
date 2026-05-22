extends Node2D

var _active := false
var _exclamation_sprite: Sprite2D

func _ready() -> void:
	$areas2D/chateau.monitoring = false
	$areas2D/magasin.monitoring = false
	$areas2D/auberge.monitoring = false
	$areas2D/parc.monitoring = false
	$areas2D/chateau.body_entered.connect(_on_chateau_entered)
	$areas2D/magasin.body_entered.connect(_on_magasin_entered)
	$areas2D/auberge.body_entered.connect(_on_auberge_entered)
	$areas2D/parc.body_entered.connect(_on_parc_entered)
	_setup_exclamation()


func start() -> void:
	_active = true
	show()
	_set_collisions(true)
	$areas2D/chateau.monitoring = true
	$areas2D/magasin.monitoring = true
	$areas2D/auberge.monitoring = true
	$areas2D/parc.monitoring = true
	_update_exclamation_visibility()


func stop() -> void:
	_active = false
	hide()
	_set_collisions(false)
	$areas2D/chateau.monitoring = false
	$areas2D/magasin.monitoring = false
	$areas2D/auberge.monitoring = false
	$areas2D/parc.monitoring = false
	_update_exclamation_visibility()


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


func _on_parc_entered(body: Node2D) -> void:
	if not _active or body.name != "TimeAunote":
		return
	var parent = get_parent()
	if parent and parent.has_method("_on_ville_to_parc"):
		parent._on_ville_to_parc()


func _setup_exclamation() -> void:
	var excl_node: Marker2D = $markers2D/exclamation as Marker2D
	if excl_node:
		_exclamation_sprite = Sprite2D.new()
		_exclamation_sprite.texture = load("res://art/exclamation.png")
		_exclamation_sprite.scale = Vector2(0.6, 0.6)
		_exclamation_sprite.visible = false
		excl_node.add_child(_exclamation_sprite)
		_start_exclamation_tween()


func _start_exclamation_tween() -> void:
	if not _exclamation_sprite:
		return
	_exclamation_sprite.position = Vector2(0, -10)
	var tween: Tween = create_tween().set_loops(-1)
	tween.tween_property(_exclamation_sprite, "position:y", 10.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_exclamation_sprite, "position:y", -10.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _update_exclamation_visibility() -> void:
	if _exclamation_sprite:
		var parent = get_parent()
		var can_use_parc = false
		if parent and "_auberge_tables_done" in parent:
			can_use_parc = parent._auberge_tables_done
		_exclamation_sprite.visible = _active and can_use_parc
