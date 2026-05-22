extends Node2D

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")
const MiniJeuTuyauScene = preload("res://Scripts/MiniJeuTuyau.tscn")
const MiniJeuCablageScene = preload("res://Scripts/MiniJeuCablage.tscn")

var time_aunote: CharacterBody2D
var pnj_secu
var pnj_secretaire
var secu_pos: Vector2
var position_entree_principale: Vector2
var started: bool = false
var stopped: bool = true
var can_move: bool = false
var speed: float = 350.0
var spawn_particles: CPUParticles2D

var fade_layer: CanvasLayer
var fade_rect: ColorRect
var _objective_label: Label
var _parking_unlocked: bool = false

var hall
var couloir
var pc_controle
var vestiaire
var salle_machine
var salle_electricite
var _player_in_couloir: bool = false
var _couloir_unlocked: bool = false
var _couloir_prompt: Label
var _couloir_prompt_layer: CanvasLayer
var _hall_transition_started: bool = false

var _player_in_retour_hall: bool = false
var _retour_hall_prompt: Label
var _retour_hall_prompt_layer: CanvasLayer

var _player_at_porte_pc_controle: bool = false
var _player_at_porte_vestiaires: bool = false
var _player_at_porte_machines: bool = false
var _player_at_porte_electricite: bool = false
var _porte_pc_prompt: Label
var _porte_vestiaires_prompt: Label
var _porte_machines_prompt: Label
var _porte_electricite_prompt: Label
var _portes_prompt_layer: CanvasLayer

var _player_at_pc_controle_retour: bool = false
var _player_at_salle_machine_retour: bool = false
var _player_at_salle_electricite_retour: bool = false
var _pc_controle_retour_prompt: Label
var _salle_machine_retour_prompt: Label
var _salle_electricite_retour_prompt: Label
var _subroom_retour_prompt_layer: CanvasLayer

var _last_dialogue_npc_id: String = ""
var _player_at_machines_repair: bool = false
var _salle_machine_minigame: Node = null
var _machines_repair_prompt: Label
var _salle_machine_done: bool = false
var _darkness_layer: CanvasLayer
var _darkness_rect: ColorRect
var _darkness_active: bool = false

var _player_at_disjoncteur: bool = false
var _cablage_minigame: Node = null
var _disjoncteur_done: bool = false
var _disjoncteur_prompt: Label
var _disjoncteur_locked_prompt: Label
var _player_has_changed_once: bool = false



func _ready() -> void:
	process_mode = PROCESS_MODE_DISABLED
	position_entree_principale = $"fondPresent/Markers2D/entreePrincipale".position
	secu_pos = $"fondPresent/Markers2D/secuPos".position
	hide()
	_setup_spawn_particles()
	_setup_fade_overlay()
	_setup_darkness_overlay()
	pnj_secu = $"PnjSecurité"
	pnj_secretaire = $"PnjSecretaire"
	_connect_parking_signals()
	DialogueSystem.action_triggered.connect(_on_action_triggered)
	DialogueSystem.dialogue_started.connect(_on_dialogue_started)
	DialogueSystem.dialogue_ended.connect(_on_dialogue_ended)
	DialogueSystem.quest_updated.connect(_on_quest_updated)
	DialogueSystem.dialogue_response.connect(_on_dialogue_response)
	hall = $Hall
	couloir = $Couloir
	pc_controle = $"PcControle"
	vestiaire = $"Vestiaire"
	salle_machine = $SalleMachine
	salle_electricite = $SalleElectricite
	vestiaire.return_to_couloir_requested.connect(_return_from_vestiaire)
	_connect_couloir_signals()
	_setup_couloir_prompt()
	_setup_couloir_retour()
	_setup_couloir_portals()
	_setup_subroom_retours()


func _setup_fade_overlay() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 128
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.size = get_viewport_rect().size
	fade_layer.add_child(fade_rect)


func _setup_darkness_overlay() -> void:
	_darkness_layer = CanvasLayer.new()
	_darkness_layer.layer = 200
	add_child(_darkness_layer)

	_darkness_rect = ColorRect.new()
	_darkness_rect.color = Color(0, 0, 0, 0)
	_darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darkness_rect.size = get_viewport_rect().size
	_darkness_layer.add_child(_darkness_rect)
	_darkness_layer.hide()


func _show_darkness_overlay() -> void:
	if _darkness_active:
		return
	_darkness_active = true
	_darkness_layer.show()
	var tween := create_tween()
	tween.tween_property(_darkness_rect, "color:a", 0.55, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_start_darkness_pulse)


func _start_darkness_pulse() -> void:
	if not _darkness_active or not is_instance_valid(_darkness_rect):
		return
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(_darkness_rect, "color", Color(0.35, 0.02, 0.02, 0.55), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_darkness_rect, "color", Color(0.08, 0.01, 0.01, 0.65), 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _remove_darkness_overlay() -> void:
	if not _darkness_active:
		return
	_darkness_active = false
	var tween := create_tween()
	tween.tween_property(_darkness_rect, "color", Color(0, 0, 0, 0), 2.0).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		if is_instance_valid(_darkness_layer):
			_darkness_layer.hide()
	)


func _connect_parking_signals() -> void:
	var zone_parking = $"fondPresent/zone escape parking"
	zone_parking.body_entered.connect(_on_parking_entered)


func _connect_couloir_signals() -> void:
	var couloir = hall.get_node_or_null("Camera2D/couloir")
	if couloir:
		couloir.body_entered.connect(_on_couloir_entered)
		couloir.body_exited.connect(_on_couloir_exited)


func _setup_couloir_prompt() -> void:
	_couloir_prompt_layer = CanvasLayer.new()
	_couloir_prompt_layer.layer = 50
	add_child(_couloir_prompt_layer)

	_couloir_prompt = Label.new()
	_couloir_prompt.text = "Appuyez sur E pour continuer"
	_couloir_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_couloir_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_couloir_prompt.add_theme_font_size_override("font_size", 18)
	_couloir_prompt.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	pstyle.border_color = Color(0.6, 0.55, 0.3, 0.7)
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	_couloir_prompt.add_theme_stylebox_override("normal", pstyle)
	_couloir_prompt.custom_minimum_size = Vector2(340, 40)
	_couloir_prompt.visible = false
	_couloir_prompt_layer.add_child(_couloir_prompt)


func _on_couloir_entered(body: Node2D) -> void:
	if body == time_aunote and hall.visible:
		_player_in_couloir = true
		_couloir_prompt.visible = true
		_update_couloir_prompt_position()


func _on_couloir_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_in_couloir = false
		_couloir_prompt.visible = false


func _update_couloir_prompt_position() -> void:
	if not _couloir_prompt or not _couloir_prompt.visible:
		return
	var vp_size := get_viewport().get_visible_rect().size
	_couloir_prompt.position = Vector2(vp_size.x / 2.0 - _couloir_prompt.size.x / 2.0, vp_size.y - 80.0)


func _show_couloir_locked_message() -> void:
	var label := Label.new()
	label.text = "Cette zone n'est pas encore accessible."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	label.z_index = 100
	label.modulate = Color(1, 1, 1, 0)
	add_child(label)
	label.global_position = time_aunote.global_position + Vector2(-250, -150)

	var text_tween := create_tween()
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)
	text_tween.tween_interval(1.5)
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.3)
	await text_tween.finished
	if is_instance_valid(label):
		label.queue_free()


func _show_disguise_locked_message() -> void:
	var label := Label.new()
	label.text = "Je devrais me changer avant de visiter"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.custom_minimum_size = Vector2(500, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", style)
	label.z_index = 100
	label.modulate = Color(1, 1, 1, 0)
	add_child(label)
	label.global_position = time_aunote.global_position + Vector2(-250, -150)

	var text_tween := create_tween()
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.3)
	text_tween.tween_interval(1.5)
	text_tween.tween_property(label, "modulate", Color(1, 1, 1, 0), 0.3)
	await text_tween.finished
	if is_instance_valid(label):
		label.queue_free()


func _setup_couloir_retour() -> void:
	_retour_hall_prompt_layer = CanvasLayer.new()
	_retour_hall_prompt_layer.layer = 50
	add_child(_retour_hall_prompt_layer)

	_retour_hall_prompt = _create_portal_prompt("Appuyez sur E pour retourner au hall")
	_retour_hall_prompt.visible = false
	_retour_hall_prompt_layer.add_child(_retour_hall_prompt)

	var retour = couloir.get_node_or_null("retour_hall")
	if retour:
		if not retour.body_entered.is_connected(_on_retour_hall_entered):
			retour.body_entered.connect(_on_retour_hall_entered)
		if not retour.body_exited.is_connected(_on_retour_hall_exited):
			retour.body_exited.connect(_on_retour_hall_exited)


func _create_portal_prompt(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	pstyle.border_color = Color(0.6, 0.55, 0.3, 0.7)
	pstyle.border_width_top = 2
	pstyle.border_width_bottom = 2
	pstyle.border_width_left = 2
	pstyle.border_width_right = 2
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	label.add_theme_stylebox_override("normal", pstyle)
	label.custom_minimum_size = Vector2(340, 40)
	return label


func _on_retour_hall_entered(body: Node2D) -> void:
	if body == time_aunote and couloir.visible:
		_player_in_retour_hall = true
		_retour_hall_prompt.visible = true
		_update_portal_prompt_position(_retour_hall_prompt)


func _on_retour_hall_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_in_retour_hall = false
		_retour_hall_prompt.visible = false


func _update_portal_prompt_position(prompt: Label) -> void:
	if not prompt or not prompt.visible:
		return
	var vp_size := get_viewport().get_visible_rect().size
	prompt.position = Vector2(vp_size.x / 2.0 - prompt.size.x / 2.0, vp_size.y - 80.0)


func _setup_couloir_portals() -> void:
	_portes_prompt_layer = CanvasLayer.new()
	_portes_prompt_layer.layer = 50
	add_child(_portes_prompt_layer)

	_porte_pc_prompt = _create_portal_prompt("Appuyez sur E — Salle de contrôle")
	_porte_pc_prompt.visible = false
	_portes_prompt_layer.add_child(_porte_pc_prompt)

	_porte_machines_prompt = _create_portal_prompt("Appuyez sur E — Salle des machines")
	_porte_machines_prompt.visible = false
	_portes_prompt_layer.add_child(_porte_machines_prompt)

	_porte_electricite_prompt = _create_portal_prompt("Appuyez sur E — Salle électrique")
	_porte_electricite_prompt.visible = false
	_portes_prompt_layer.add_child(_porte_electricite_prompt)

	_porte_vestiaires_prompt = _create_portal_prompt("Appuyez sur E — Vestiaires")
	_porte_vestiaires_prompt.visible = false
	_portes_prompt_layer.add_child(_porte_vestiaires_prompt)

	var porte_pc = couloir.get_node_or_null("porte_pc_controle")
	if porte_pc:
		porte_pc.body_entered.connect(_on_porte_pc_controle_entered)
		porte_pc.body_exited.connect(_on_porte_pc_controle_exited)

	var porte_mach = couloir.get_node_or_null("porte_machines")
	if porte_mach:
		porte_mach.body_entered.connect(_on_porte_machines_entered)
		porte_mach.body_exited.connect(_on_porte_machines_exited)

	var porte_elec = couloir.get_node_or_null("porte_electricite")
	if porte_elec:
		porte_elec.body_entered.connect(_on_porte_electricite_entered)
		porte_elec.body_exited.connect(_on_porte_electricite_exited)

	var porte_vest = couloir.get_node_or_null("porte_vestiaires")
	if porte_vest:
		porte_vest.body_entered.connect(_on_porte_vestiaires_entered)
		porte_vest.body_exited.connect(_on_porte_vestiaires_exited)


func _on_porte_pc_controle_entered(body: Node2D) -> void:
	if body == time_aunote and couloir.visible:
		_player_at_porte_pc_controle = true
		_porte_pc_prompt.visible = true
		_update_portal_prompt_position(_porte_pc_prompt)


func _on_porte_pc_controle_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_porte_pc_controle = false
		_porte_pc_prompt.visible = false


func _on_porte_vestiaires_entered(body: Node2D) -> void:
	if body == time_aunote and couloir.visible:
		_player_at_porte_vestiaires = true
		_porte_vestiaires_prompt.visible = true
		_update_portal_prompt_position(_porte_vestiaires_prompt)


func _on_porte_vestiaires_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_porte_vestiaires = false
		_porte_vestiaires_prompt.visible = false


func _on_porte_machines_entered(body: Node2D) -> void:
	if body == time_aunote and couloir.visible:
		_player_at_porte_machines = true
		_porte_machines_prompt.visible = true
		_update_portal_prompt_position(_porte_machines_prompt)


func _on_porte_machines_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_porte_machines = false
		_porte_machines_prompt.visible = false


func _on_porte_electricite_entered(body: Node2D) -> void:
	if body == time_aunote and couloir.visible:
		_player_at_porte_electricite = true
		_porte_electricite_prompt.visible = true
		_update_portal_prompt_position(_porte_electricite_prompt)


func _on_porte_electricite_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_porte_electricite = false
		_porte_electricite_prompt.visible = false


func _setup_subroom_retours() -> void:
	_subroom_retour_prompt_layer = CanvasLayer.new()
	_subroom_retour_prompt_layer.layer = 50
	add_child(_subroom_retour_prompt_layer)

	_pc_controle_retour_prompt = _create_portal_prompt("Appuyez sur E pour retourner au couloir")
	_pc_controle_retour_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_pc_controle_retour_prompt)

	_salle_machine_retour_prompt = _create_portal_prompt("Appuyez sur E pour retourner au couloir")
	_salle_machine_retour_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_salle_machine_retour_prompt)

	_salle_electricite_retour_prompt = _create_portal_prompt("Appuyez sur E pour retourner au couloir")
	_salle_electricite_retour_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_salle_electricite_retour_prompt)

	var ret_pc = pc_controle.get_node_or_null("couloir")
	if ret_pc:
		ret_pc.body_entered.connect(_on_pc_controle_retour_entered)
		ret_pc.body_exited.connect(_on_pc_controle_retour_exited)

	var ret_sm = salle_machine.get_node_or_null("event")
	if ret_sm:
		ret_sm.body_entered.connect(_on_salle_machine_retour_entered)
		ret_sm.body_exited.connect(_on_salle_machine_retour_exited)

	var ret_se = salle_electricite.get_node_or_null("retour_couloir")
	if ret_se:
		ret_se.body_entered.connect(_on_salle_electricite_retour_entered)
		ret_se.body_exited.connect(_on_salle_electricite_retour_exited)

	var event2 = salle_machine.get_node_or_null("event2")
	if event2:
		event2.body_entered.connect(_on_salle_machine_repair_entered)
		event2.body_exited.connect(_on_salle_machine_repair_exited)

	var event3 = salle_electricite.get_node_or_null("event3")
	if event3:
		event3.body_entered.connect(_on_disjoncteur_entered)
		event3.body_exited.connect(_on_disjoncteur_exited)

	_machines_repair_prompt = _create_portal_prompt("Appuyez sur E pour inspecter les machines")
	_machines_repair_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_machines_repair_prompt)

	_disjoncteur_prompt = _create_portal_prompt("Appuyez sur E pour ouvrir l'armoire electrique")
	_disjoncteur_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_disjoncteur_prompt)

	_disjoncteur_locked_prompt = _create_portal_prompt("L'armoire electrique fonctionne normalement")
	_disjoncteur_locked_prompt.visible = false
	_subroom_retour_prompt_layer.add_child(_disjoncteur_locked_prompt)


func _on_pc_controle_retour_entered(body: Node2D) -> void:
	if body == time_aunote and pc_controle.visible:
		_player_at_pc_controle_retour = true
		_pc_controle_retour_prompt.visible = true
		_update_portal_prompt_position(_pc_controle_retour_prompt)


func _on_pc_controle_retour_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_pc_controle_retour = false
		_pc_controle_retour_prompt.visible = false


func _on_salle_machine_retour_entered(body: Node2D) -> void:
	if body == time_aunote and salle_machine.visible:
		_player_at_salle_machine_retour = true
		_salle_machine_retour_prompt.visible = true
		_update_portal_prompt_position(_salle_machine_retour_prompt)


func _on_salle_machine_retour_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_salle_machine_retour = false
		_salle_machine_retour_prompt.visible = false


func _on_salle_electricite_retour_entered(body: Node2D) -> void:
	if body == time_aunote and salle_electricite.visible:
		_player_at_salle_electricite_retour = true
		_salle_electricite_retour_prompt.visible = true
		_update_portal_prompt_position(_salle_electricite_retour_prompt)


func _on_salle_electricite_retour_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_salle_electricite_retour = false
		_salle_electricite_retour_prompt.visible = false


func _on_salle_machine_repair_entered(body: Node2D) -> void:
	if body == time_aunote and salle_machine.visible and not _salle_machine_done:
		_player_at_machines_repair = true
		_machines_repair_prompt.visible = true
		_update_portal_prompt_position(_machines_repair_prompt)


func _on_salle_machine_repair_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_machines_repair = false
		_machines_repair_prompt.visible = false


func _on_disjoncteur_entered(body: Node2D) -> void:
	if body == time_aunote and salle_electricite.visible:
		if _salle_machine_done and not _disjoncteur_done:
			_player_at_disjoncteur = true
			_disjoncteur_prompt.visible = true
			_update_portal_prompt_position(_disjoncteur_prompt)
		elif not _salle_machine_done:
			_disjoncteur_locked_prompt.visible = true
			_update_portal_prompt_position(_disjoncteur_locked_prompt)


func _on_disjoncteur_exited(body: Node2D) -> void:
	if body == time_aunote:
		_player_at_disjoncteur = false
		_disjoncteur_prompt.visible = false
		_disjoncteur_locked_prompt.visible = false


func _go_to_couloir() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	can_move = false
	_couloir_prompt.visible = false
	_player_in_couloir = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	hall.hide()
	_set_hall_collisions(false)
	if pnj_secretaire:
		pnj_secretaire.hide()
		var zone_s = pnj_secretaire.get_node_or_null("ZoneDialogue")
		if zone_s:
			zone_s.monitoring = false

	couloir.show()
	_set_couloir_collisions(true)
	_set_zone_camera("couloir")

	time_aunote.global_position = couloir.get_node("Node2D/pop hall").global_position
	time_aunote.scale = Vector2(1.58, 1.58)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _return_from_couloir() -> void:
	if not is_inside_tree() or hall.visible:
		return
	can_move = false
	_retour_hall_prompt.visible = false
	_player_in_retour_hall = false
	_porte_pc_prompt.visible = false
	_player_at_porte_pc_controle = false
	_porte_vestiaires_prompt.visible = false
	_player_at_porte_vestiaires = false
	_porte_machines_prompt.visible = false
	_player_at_porte_machines = false
	_porte_electricite_prompt.visible = false
	_player_at_porte_electricite = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	couloir.hide()
	_set_couloir_collisions(false)

	hall.show()
	_set_hall_collisions(true)
	_set_zone_camera("hall")

	var r_marker = hall.get_node_or_null("Camera2D/Node2D/retour couloir")
	if r_marker:
		time_aunote.global_position = r_marker.global_position
	else:
		time_aunote.global_position = hall.get_node("Camera2D/Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.924, 0.924)


	var secretaire_marker = hall.get_node_or_null("Camera2D/Node2D/secretairePos")
	if pnj_secretaire and secretaire_marker:
		pnj_secretaire.apparition(secretaire_marker.global_position)
		pnj_secretaire.get_node("ZoneDialogue").monitoring = true

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _go_to_pc_controle() -> void:
	if not is_inside_tree() or pc_controle.visible:
		return
	can_move = false
	_retour_hall_prompt.visible = false
	_porte_pc_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	couloir.hide()
	_set_couloir_collisions(false)

	pc_controle.show()
	_set_pc_controle_collisions(true)
	_set_zone_camera("pc_controle")

	time_aunote.global_position = pc_controle.get_node("Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.9555, 0.9555)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _return_from_pc_controle() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	can_move = false
	_pc_controle_retour_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	pc_controle.hide()
	_set_pc_controle_collisions(false)

	couloir.show()
	_set_couloir_collisions(true)
	_set_zone_camera("couloir")

	time_aunote.global_position = couloir.get_node("Node2D/pop pc controle").global_position
	time_aunote.scale = Vector2(1.58, 1.58)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _go_to_vestiaire() -> void:
	if not is_inside_tree() or vestiaire.visible:
		return
	can_move = false
	_retour_hall_prompt.visible = false
	_porte_vestiaires_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	couloir.hide()
	_set_couloir_collisions(false)

	vestiaire.start()
	_set_vestiaire_collisions(true)
	_set_zone_camera("vestiaire")

	time_aunote.global_position = vestiaire.get_node("Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.9555, 0.9555)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _return_from_vestiaire() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	vestiaire.stop()
	_set_vestiaire_collisions(false)

	couloir.show()
	_set_couloir_collisions(true)
	_set_zone_camera("couloir")

	time_aunote.global_position = couloir.get_node("Node2D/pop vestiaires").global_position
	time_aunote.scale = Vector2(1.58, 1.58)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true
	if TimeAunoteScript.disguised_present:
		_player_has_changed_once = true
		var qp = DialogueSystem.game_state.get("quete_preparation")
		if qp is Dictionary and qp.get("current_step", "") == "etape_aller_vestiaires":
			DialogueSystem.complete_step("quete_preparation", "etape_aller_vestiaires")
	_update_secretaire_npc_id()


func _go_to_salle_machine() -> void:
	if not is_inside_tree() or salle_machine.visible:
		return
	can_move = false
	_porte_machines_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	couloir.hide()
	_set_couloir_collisions(false)

	salle_machine.show()
	_set_salle_machine_collisions(true)
	_set_zone_camera("salle_machine")

	time_aunote.global_position = salle_machine.get_node("Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.9555, 0.9555)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _return_from_salle_machine() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	can_move = false
	_salle_machine_retour_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	salle_machine.hide()
	_set_salle_machine_collisions(false)

	couloir.show()
	_set_couloir_collisions(true)
	_set_zone_camera("couloir")

	time_aunote.global_position = couloir.get_node("Node2D/pop machine").global_position
	time_aunote.scale = Vector2(1.58, 1.58)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _go_to_salle_electricite() -> void:
	if not is_inside_tree() or salle_electricite.visible:
		return
	can_move = false
	_porte_electricite_prompt.visible = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	couloir.hide()
	_set_couloir_collisions(false)

	salle_electricite.show()
	_set_salle_electricite_collisions(true)
	_set_zone_camera("salle_electricite")

	time_aunote.global_position = salle_electricite.get_node("Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.9555, 0.9555)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _return_from_salle_electricite() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	can_move = false
	_salle_electricite_retour_prompt.visible = false
	_disjoncteur_prompt.visible = false
	_disjoncteur_locked_prompt.visible = false
	_player_at_disjoncteur = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	salle_electricite.hide()
	_set_salle_electricite_collisions(false)

	couloir.show()
	_set_couloir_collisions(true)
	_set_zone_camera("couloir")

	time_aunote.global_position = couloir.get_node("Node2D/pop electricite").global_position
	time_aunote.scale = Vector2(1.58, 1.58)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	can_move = true


func _set_pc_controle_collisions(enabled: bool) -> void:
	var limites = pc_controle.get_node_or_null("limiteParking")
	if limites:
		limites.collision_layer = 8 if enabled else 0


func _set_vestiaire_collisions(enabled: bool) -> void:
	var limites = vestiaire.get_node_or_null("limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0


func _set_salle_machine_collisions(enabled: bool) -> void:
	var limites = salle_machine.get_node_or_null("limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0
	var event = salle_machine.get_node_or_null("event")
	if event:
		event.monitoring = enabled
	var event2 = salle_machine.get_node_or_null("event2")
	if event2:
		event2.monitoring = enabled


func _set_salle_electricite_collisions(enabled: bool) -> void:
	var limites = salle_electricite.get_node_or_null("limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0
	var event3 = salle_electricite.get_node_or_null("event3")
	if event3:
		event3.monitoring = enabled


func _set_couloir_collisions(enabled: bool) -> void:
	var limites = couloir.get_node_or_null("limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0


func _input(event: InputEvent) -> void:
	if not started or not can_move:
		return
	if DialogueUI.is_dialogue_active():
		return
	if not event.is_action_pressed("interagir"):
		return
	if _player_in_couloir and hall.visible:
		get_viewport().set_input_as_handled()
		if _couloir_unlocked:
			_go_to_couloir()
		else:
			_show_couloir_locked_message()
	elif _player_in_retour_hall and couloir.visible:
		get_viewport().set_input_as_handled()
		_return_from_couloir()
	elif _player_at_porte_pc_controle and couloir.visible:
		get_viewport().set_input_as_handled()
		if TimeAunoteScript.disguised_present:
			_go_to_pc_controle()
		else:
			_show_disguise_locked_message()
	elif _player_at_porte_machines and couloir.visible:
		get_viewport().set_input_as_handled()
		if TimeAunoteScript.disguised_present:
			_go_to_salle_machine()
		else:
			_show_disguise_locked_message()
	elif _player_at_porte_electricite and couloir.visible:
		get_viewport().set_input_as_handled()
		if TimeAunoteScript.disguised_present:
			_go_to_salle_electricite()
		else:
			_show_disguise_locked_message()
	elif _player_at_porte_vestiaires and couloir.visible:
		get_viewport().set_input_as_handled()
		_go_to_vestiaire()
	elif _player_at_pc_controle_retour and pc_controle.visible:
		get_viewport().set_input_as_handled()
		_return_from_pc_controle()
	elif _player_at_salle_machine_retour and salle_machine.visible and _salle_machine_minigame == null:
		get_viewport().set_input_as_handled()
		_return_from_salle_machine()
	elif _player_at_machines_repair and salle_machine.visible:
		get_viewport().set_input_as_handled()
		_start_salle_machine_minigame()
	elif _player_at_salle_electricite_retour and salle_electricite.visible and _cablage_minigame == null:
		get_viewport().set_input_as_handled()
		_return_from_salle_electricite()
	elif _player_at_disjoncteur and salle_electricite.visible:
		get_viewport().set_input_as_handled()
		_start_disjoncteur_minigame()


func _on_parking_entered(body: Node2D) -> void:
	if body == time_aunote and can_move:
		_go_to_parking()


func _go_to_parking() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$fondPresent.hide()
	_set_fond_collisions(false)
	if pnj_secu:
		pnj_secu.hide()
		pnj_secu.get_node("ZoneDialogue").monitoring = false

	$Parking.show()
	_set_parking_collisions(true)
	$Parking.set_interactive(true)
	_set_zone_camera("parking")

	time_aunote.global_position = $"Parking/Node2D/zone pop".global_position
	time_aunote.scale = Vector2(0.6, 0.6)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	_update_objective("Fouiller le parking")
	can_move = true


func _return_from_parking() -> void:
	can_move = false

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished

	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)

	$fondPresent.show()
	_set_fond_collisions(true)
	_set_zone_camera("fond")
	if pnj_secu:
		pnj_secu.show()
		pnj_secu.apparition(secu_pos)
		pnj_secu.get_node("ZoneDialogue").monitoring = true

	time_aunote.global_position = $"fondPresent/Markers2D/retourParking".global_position
	time_aunote.scale = Vector2(0.5, 0.5)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished

	var parking = $Parking
	if parking and parking._badge_obtained:
		_update_objective("Retourner voir l'agent de sécurité avec la carte")
	can_move = true


func _go_to_hall() -> void:
	if _hall_transition_started or hall.visible:
		return
	_hall_transition_started = true
	can_move = false
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree():
		return
	DialogueUI.close_dialogue()

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	$fondPresent.hide()
	_set_fond_collisions(false)
	if pnj_secu:
		pnj_secu.hide()
		var zone = pnj_secu.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false

	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)

	hall.show()
	_set_hall_collisions(true)
	_set_zone_camera("hall")

	time_aunote.global_position = hall.get_node("Camera2D/Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.924, 0.924)

	var secretaire_marker = hall.get_node_or_null("Camera2D/Node2D/secretairePos")
	if pnj_secretaire and secretaire_marker:
		pnj_secretaire.apparition(secretaire_marker.global_position)
		pnj_secretaire.get_node("ZoneDialogue").monitoring = true

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	DialogueSystem.complete_step("quete_acces_centrale", "etape_retour_gardien")
	var qp = DialogueSystem.game_state.get("quete_preparation")
	if qp is Dictionary and qp.get("status", "") == "not_started":
		qp["status"] = "active"
		qp["current_step"] = "etape_parler_secretaire"
	_update_objective("Parler à la secrétaire")
	can_move = true


func _set_hall_collisions(enabled: bool) -> void:
	var limites = hall.get_node_or_null("Camera2D/limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0


func _set_zone_camera(zone_name: String) -> void:
	var fond_cam = $fondPresent.get_node_or_null("Camera2D")
	var parking_cam = $Parking.get_node_or_null("Camera2D")
	var hall_cam = hall.get_node_or_null("Camera2D")
	var couloir_cam = couloir.get_node_or_null("Camera2D")
	var pc_controle_cam = pc_controle.get_node_or_null("Camera2D")
	var vestiaire_cam = vestiaire.get_node_or_null("Camera2D")
	var salle_machine_cam = salle_machine.get_node_or_null("Camera2D")
	var salle_electricite_cam = salle_electricite.get_node_or_null("Camera2D")
	if fond_cam:
		fond_cam.enabled = (zone_name == "fond")
	if parking_cam:
		parking_cam.enabled = (zone_name == "parking")
	if hall_cam:
		hall_cam.enabled = (zone_name == "hall")
	if couloir_cam:
		couloir_cam.enabled = (zone_name == "couloir")
	if pc_controle_cam:
		pc_controle_cam.enabled = (zone_name == "pc_controle")
	if vestiaire_cam:
		vestiaire_cam.enabled = (zone_name == "vestiaire")
	if salle_machine_cam:
		salle_machine_cam.enabled = (zone_name == "salle_machine")
	if salle_electricite_cam:
		salle_electricite_cam.enabled = (zone_name == "salle_electricite")


func _on_dialogue_started(npc_id: String, npc_name: String) -> void:
	_last_dialogue_npc_id = npc_id


func _on_action_triggered(action: Dictionary) -> void:
	if not started:
		return
	var act_type = action.get("type", "")
	var act_id = action.get("id", "")
	if act_type == "trigger" and act_id == "secu_quete_avance":
		_try_unlock_parking()
	elif act_type == "trigger" and act_id == "secu_acces_hall":
		var parking = $Parking
		if parking and parking._badge_obtained:
			_go_to_hall()
	elif act_type == "trigger" and act_id == "secretaire_accueil":
		DialogueSystem.complete_step("quete_preparation", "etape_parler_secretaire")
		_couloir_unlocked = true
	elif act_type == "trigger" and act_id == "secretaire_fin":
		DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_fin")



func _on_quest_updated(quest_id: String, status: String, current_step: String) -> void:
	if not started:
		return
	if status == "done":
		return
	if current_step != "":
		var quest = DialogueSystem._find_quest(quest_id)
		if not quest.is_empty():
			for step in quest.get("steps", []):
				if step.get("id") == current_step:
					_update_objective(step.get("description", ""))
					return
	_update_objective(DialogueSystem._find_quest(quest_id).get("title", ""))


func _on_dialogue_response(npc_name: String, text: String) -> void:
	if not started:
		return
	if DialogueSystem.current_npc_id != "npc_securite_present_retour":
		return
	if hall.visible or _hall_transition_started:
		return
	# Forcer le TP mécanique post-minijeu : le joueur a forcément le badge
	# mais l'IA peut ne pas émettre l'action JSON. On laisse 3s de lecture.
	await get_tree().create_timer(3.0).timeout
	if started and not hall.visible and not _hall_transition_started:
		_go_to_hall()


func _on_dialogue_ended() -> void:
	if not started:
		return
	# Ne déverrouiller le parking que si on vient de parler au garde
	if _last_dialogue_npc_id == "npc_securite_present" or _last_dialogue_npc_id == "npc_securite_present_retour":
		_try_unlock_parking()
	# Déverrouiller le couloir après la première conversation avec Sophie
	if not _couloir_unlocked and _last_dialogue_npc_id == "npc_secretaire_present":
		_couloir_unlocked = true
		DialogueSystem.complete_step("quete_preparation", "etape_parler_secretaire")
	
	if _last_dialogue_npc_id == "npc_secretaire_present_courtcircuit":
		DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_panique")
	elif _last_dialogue_npc_id == "npc_secretaire_present_retabli":
		DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_fin")
		
	_update_secretaire_npc_id()
	_last_dialogue_npc_id = ""


func _update_secretaire_npc_id() -> void:
	if not pnj_secretaire:
		return
	if _disjoncteur_done:
		pnj_secretaire.npc_id = "npc_secretaire_present_retabli"
	elif _salle_machine_done:
		pnj_secretaire.npc_id = "npc_secretaire_present_courtcircuit"
	elif TimeAunoteScript.disguised_present:
		pnj_secretaire.npc_id = "npc_secretaire_present_change"
	elif _player_has_changed_once:
		pnj_secretaire.npc_id = "npc_secretaire_present_undisguise"
	else:
		pnj_secretaire.npc_id = "npc_secretaire_present"



func _ensure_hall_quest_done() -> void:
	var q_secu = DialogueSystem.game_state.get("quete_acces_centrale", {})
	if q_secu is Dictionary:
		q_secu["status"] = "done"
		q_secu["completed_steps"] = ["etape_parler_gardien", "etape_chercher_carte", "etape_retour_gardien"]
		q_secu["current_step"] = ""
	var q_prep = DialogueSystem.game_state.get("quete_preparation", {})
	if q_prep is Dictionary:
		q_prep["status"] = "active"
		if q_prep.get("current_step", "") == "":
			q_prep["current_step"] = "etape_parler_secretaire"
		if q_prep.get("completed_steps") == null:
			q_prep["completed_steps"] = []
	_couloir_unlocked = true



func _try_unlock_parking() -> void:
	if _parking_unlocked:
		return
	_parking_unlocked = true
	$"fondPresent/zone escape parking".monitoring = true
	DialogueSystem.complete_step("quete_acces_centrale", "etape_parler_gardien")
	_update_objective("Chercher une carte d'accès dans le parking")


func _set_fond_collisions(enabled: bool) -> void:
	var colision = $fondPresent.get_node_or_null("limitesDeplacements")
	if colision:
		colision.collision_layer = 8 if enabled else 0


func _set_parking_collisions(enabled: bool) -> void:
	var limite = $Parking.get_node_or_null("limiteParking")
	if limite:
		limite.collision_layer = 8 if enabled else 0


func _setup_spawn_particles() -> void:
	spawn_particles = CPUParticles2D.new()
	spawn_particles.emitting = false
	spawn_particles.one_shot = true
	spawn_particles.amount = 50
	spawn_particles.lifetime = 0.8
	spawn_particles.explosiveness = 1.0
	spawn_particles.speed_scale = 2.5
	spawn_particles.spread = 90.0
	spawn_particles.gravity = Vector2(0, -40)
	spawn_particles.initial_velocity_min = 50.0
	spawn_particles.initial_velocity_max = 160.0
	spawn_particles.scale_amount_min = 0.15
	spawn_particles.scale_amount_max = 1.2
	spawn_particles.angular_velocity_min = -540.0
	spawn_particles.angular_velocity_max = 540.0
	spawn_particles.color_ramp = _create_color_ramp(Color(0.3, 1.0, 0.4))
	spawn_particles.texture = _create_particle_texture()
	spawn_particles.z_index = 20
	add_child(spawn_particles)


func _create_particle_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var center := Vector2(16, 16)
	for y in range(32):
		for x in range(32):
			var dist := Vector2(x, y).distance_to(center) / 16.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			alpha = ease(alpha, 2.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


func _create_color_ramp(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient


func _process(delta: float) -> void:
	if not can_move:
		return
	_handle_movement(delta)


func _handle_movement(delta: float) -> void:
	if DialogueUI.is_dialogue_active():
		if is_instance_valid(time_aunote):
			time_aunote.animation(Vector2.ZERO)
		return
	var current_speed := 700.0 if (couloir != null and couloir.visible) else speed
	var velocity := Vector2.ZERO
	if Input.is_action_pressed("marche_haut"):
		velocity.y -= 1
	if Input.is_action_pressed("marche_bas"):
		velocity.y += 1
	if Input.is_action_pressed("marche_droite"):
		velocity.x += 1
	if Input.is_action_pressed("marche_gauche"):
		velocity.x -= 1
	var direction := velocity.normalized()
	time_aunote.animation(direction)
	time_aunote.move_and_collide(direction * current_speed * delta)


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_objective_label.custom_minimum_size = Vector2(240.0, 0.0)
		_objective_label.text = text
		_objective_label.reset_size()
		
		var panel = _objective_label.get_parent() as Panel
		if panel:
			panel.size.y = maxf(80.0, 36.0 + _objective_label.size.y + 16.0)



func start(spawn_id: String = "entree") -> void:
	process_mode = PROCESS_MODE_INHERIT
	_hall_transition_started = false
	_player_has_changed_once = false
	_salle_machine_done = false
	_disjoncteur_done = false
	_couloir_unlocked = false
	show()
	_objective_label = $ObjectiveHUD/Panel/Objective
	$ObjectiveHUD.show()
	DialogueSystem.load_dimension("res://Present/dimension_present.json")
	var parking = $Parking

	if parking and parking._badge_obtained:
		var qs = DialogueSystem.game_state.get("quete_acces_centrale", {})
		if qs is Dictionary:
			var completed: Array = qs.get("completed_steps", [])
			if "etape_parler_gardien" not in completed:
				completed.append("etape_parler_gardien")
			if "etape_chercher_carte" not in completed:
				completed.append("etape_chercher_carte")
			qs["completed_steps"] = completed
			qs["current_step"] = "etape_retour_gardien"
	$fondPresent.show()
	_set_fond_collisions(true)
	_set_zone_camera("fond")
	$Parking.hide()
	_set_parking_collisions(false)
	$Parking.set_interactive(false)
	hall.hide()
	_set_hall_collisions(false)
	couloir.hide()
	_set_couloir_collisions(false)
	pc_controle.hide()
	_set_pc_controle_collisions(false)
	vestiaire.hide()
	_set_vestiaire_collisions(false)
	salle_machine.hide()
	_set_salle_machine_collisions(false)
	salle_electricite.hide()
	_set_salle_electricite_collisions(false)
	if pnj_secretaire:
		pnj_secretaire.hide()
		var zone_s = pnj_secretaire.get_node_or_null("ZoneDialogue")
		if zone_s:
			zone_s.monitoring = false
	time_aunote = $TimeAunote
	time_aunote.collision_mask = 8
	pnj_secu = $"PnjSecurité"
	pnj_secu.npc_id = "npc_securite_present"
	if parking and parking._badge_obtained:
		pnj_secu.npc_id = "npc_securite_present_retour"
	pnj_secu.apparition(secu_pos)
	pnj_secu.get_node("ZoneDialogue").monitoring = true
	_parking_unlocked = false
	$"fondPresent/zone escape parking".monitoring = false
	_couloir_unlocked = false
	_update_secretaire_npc_id()

	if spawn_id == "parking":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.show()
		_set_parking_collisions(true)
		$Parking.set_interactive(true)
		_set_zone_camera("parking")
		time_aunote.position = $"Parking/Node2D/zone pop".position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.65, 0.65)
		time_aunote.rotation = 0.0
		can_move = true
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = false
		started = true
		stopped = false
		_update_objective("Fouiller le parking")
		return

	if spawn_id == "hall":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		hall.show()
		_set_hall_collisions(true)
		_set_zone_camera("hall")
		time_aunote.position = hall.get_node("Camera2D/Node2D/zone pop").position
		var secretaire_marker = hall.get_node_or_null("Camera2D/Node2D/secretairePos")
		if pnj_secretaire and secretaire_marker:
			pnj_secretaire.apparition(secretaire_marker.global_position)
			pnj_secretaire.get_node("ZoneDialogue").monitoring = true
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.924, 0.924)
		time_aunote.rotation = 0.0
		can_move = true
		var col_hall := time_aunote.get_node("collision") as CollisionShape2D
		col_hall.disabled = false
		started = true
		stopped = false
		
		var q_secu = DialogueSystem.game_state.get("quete_acces_centrale", {})
		if q_secu is Dictionary:
			q_secu["status"] = "done"
			q_secu["completed_steps"] = ["etape_parler_gardien", "etape_chercher_carte", "etape_retour_gardien"]
			q_secu["current_step"] = ""
		var q_prep = DialogueSystem.game_state.get("quete_preparation", {})
		if q_prep is Dictionary:
			q_prep["status"] = "active"
			q_prep["current_step"] = "etape_parler_secretaire"
			q_prep["completed_steps"] = []
		_player_has_changed_once = false
		_salle_machine_done = false
		_disjoncteur_done = false
		_couloir_unlocked = false
		_update_secretaire_npc_id()
		_update_objective("Parler à la secrétaire")
		return

	if spawn_id == "couloir":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		
		couloir.show()
		_set_couloir_collisions(true)
		_set_zone_camera("couloir")
		time_aunote.position = couloir.get_node("Node2D/pop hall").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(1.58, 1.58)
		time_aunote.rotation = 0.0
		can_move = true
		var col_couloir := time_aunote.get_node("collision") as CollisionShape2D
		col_couloir.disabled = false
		started = true
		stopped = false
		
		_ensure_hall_quest_done()
		_update_secretaire_npc_id()
		_update_objective("Aller se changer")
		return

	if spawn_id == "vestiaire":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		
		vestiaire.start()
		_set_vestiaire_collisions(true)
		_set_zone_camera("vestiaire")
		time_aunote.position = vestiaire.get_node("Node2D/zone pop").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.9555, 0.9555)
		time_aunote.rotation = 0.0
		can_move = true
		var col_vestiaire := time_aunote.get_node("collision") as CollisionShape2D
		col_vestiaire.disabled = false
		started = true
		stopped = false
		
		_ensure_hall_quest_done()
		_update_secretaire_npc_id()
		_update_objective("Aller se changer")
		return

	if spawn_id == "salle_machine":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		
		salle_machine.show()
		_set_salle_machine_collisions(true)
		_set_zone_camera("salle_machine")
		time_aunote.position = salle_machine.get_node("Node2D/zone pop").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.9555, 0.9555)
		time_aunote.rotation = 0.0
		can_move = true
		var col_salle_machine := time_aunote.get_node("collision") as CollisionShape2D
		col_salle_machine.disabled = false
		started = true
		stopped = false
		
		_ensure_hall_quest_done()
		var q_prep = DialogueSystem.game_state.get("quete_preparation", {})
		if q_prep is Dictionary:
			q_prep["completed_steps"] = ["etape_parler_secretaire", "etape_aller_vestiaires"]
			q_prep["current_step"] = "etape_reparer_machines"
		TimeAunoteScript.disguised_present = true
		_player_has_changed_once = true
		if time_aunote.has_method("apply_disguise"):
			time_aunote.apply_disguise()
		_update_secretaire_npc_id()
		_update_objective("Aller réparer la salle des machines")
		return

	if spawn_id == "salle_electricite":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		
		salle_electricite.show()
		_set_salle_electricite_collisions(true)
		_set_zone_camera("salle_electricite")
		time_aunote.position = salle_electricite.get_node("Node2D/zone pop").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.9555, 0.9555)
		time_aunote.rotation = 0.0
		can_move = true
		var col_salle_electricite := time_aunote.get_node("collision") as CollisionShape2D
		col_salle_electricite.disabled = false
		started = true
		stopped = false
		
		_ensure_hall_quest_done()
		var q_prep = DialogueSystem.game_state.get("quete_preparation", {})
		if q_prep is Dictionary:
			q_prep["completed_steps"] = ["etape_parler_secretaire", "etape_aller_vestiaires", "etape_reparer_machines", "etape_retour_secretaire_panique"]
			q_prep["current_step"] = "etape_reparer_electricite"
		TimeAunoteScript.disguised_present = true
		_player_has_changed_once = true
		_salle_machine_done = true
		if time_aunote.has_method("apply_disguise"):
			time_aunote.apply_disguise()
		_show_darkness_overlay()
		_update_secretaire_npc_id()
		_update_objective("Remettre le disjoncteur")
		return

	if spawn_id == "pc_controle":
		$fondPresent.hide()
		_set_fond_collisions(false)
		if pnj_secu:
			pnj_secu.hide()
			pnj_secu.get_node("ZoneDialogue").monitoring = false
		$Parking.hide()
		_set_parking_collisions(false)
		$Parking.set_interactive(false)
		
		pc_controle.show()
		_set_pc_controle_collisions(true)
		_set_zone_camera("pc_controle")
		time_aunote.position = pc_controle.get_node("Node2D/zone pop").position
		time_aunote.show()
		time_aunote.modulate.a = 1.0
		time_aunote.scale = Vector2(0.9555, 0.9555)
		time_aunote.rotation = 0.0
		can_move = true
		var col_pc_controle := time_aunote.get_node("collision") as CollisionShape2D
		col_pc_controle.disabled = false
		started = true
		stopped = false
		
		_ensure_hall_quest_done()
		_update_secretaire_npc_id()
		_update_objective("Prendre son service de maintenance")
		return



	_update_objective("Parler à l'agent de sécurité")
	time_aunote.position = position_entree_principale
	time_aunote.hide()
	time_aunote.modulate.a = 0.0
	time_aunote.scale = Vector2.ZERO
	time_aunote.rotation = TAU
	_play_spawn_animation()


func _play_spawn_animation(spawn_position: Vector2 = position_entree_principale) -> void:
	spawn_particles.global_position = spawn_position + global_position
	spawn_particles.restart()

	await get_tree().create_timer(0.15).timeout

	time_aunote.show()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(time_aunote, "scale", Vector2(0.5, 0.5), 1.0)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(time_aunote, "rotation", 0.0, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(time_aunote, "modulate:a", 1.0, 0.5)\
		.set_ease(Tween.EASE_IN)

	await tween.finished

	can_move = true
	var collision_node := time_aunote.get_node("collision") as CollisionShape2D
	collision_node.disabled = false
	started = true
	stopped = false


func _on_parking_minigame_won() -> void:
	DialogueSystem.complete_step("quete_acces_centrale", "etape_chercher_carte")
	if pnj_secu:
		pnj_secu.npc_id = "npc_securite_present_retour"
	if is_instance_valid(time_aunote):
		var marker = get_node_or_null("Parking/Node2D/zone pop after jeux")
		if marker:
			time_aunote.global_position = marker.global_position
	_update_objective("Retourner voir l'agent de securite")
	can_move = true


func _start_salle_machine_minigame() -> void:
	if _salle_machine_minigame != null or _salle_machine_done:
		return
	can_move = false
	time_aunote.hide()
	_machines_repair_prompt.visible = false
	_salle_machine_minigame = MiniJeuTuyauScene.instantiate()
	_salle_machine_minigame.done.connect(_on_salle_machine_minigame_done)
	get_tree().root.add_child(_salle_machine_minigame)


func _on_salle_machine_minigame_done(success: bool) -> void:
	_salle_machine_minigame = null
	_salle_machine_done = true
	if _machines_repair_prompt:
		_machines_repair_prompt.visible = false
	_player_at_machines_repair = false
	if is_instance_valid(time_aunote):
		time_aunote.show()
	can_move = true
	if success:
		DialogueSystem.complete_step("quete_preparation", "etape_reparer_machines")
		_show_darkness_overlay()
		_update_secretaire_npc_id()


func _start_disjoncteur_minigame() -> void:
	if _cablage_minigame != null or _disjoncteur_done:
		return
	can_move = false
	time_aunote.hide()
	_disjoncteur_prompt.visible = false
	if _darkness_layer:
		_darkness_layer.hide()
	_cablage_minigame = MiniJeuCablageScene.instantiate()
	_cablage_minigame.done.connect(_on_disjoncteur_minigame_done)
	get_tree().root.add_child(_cablage_minigame)


func _on_disjoncteur_minigame_done(success: bool) -> void:
	_cablage_minigame = null
	_disjoncteur_done = success
	if is_instance_valid(time_aunote):
		time_aunote.show()
	can_move = true
	_player_at_disjoncteur = false
	if _disjoncteur_prompt:
		_disjoncteur_prompt.visible = false
	if success:
		var q_prep = DialogueSystem.game_state.get("quete_preparation", {})
		if q_prep is Dictionary:
			var completed: Array = q_prep.get("completed_steps", [])
			if "etape_retour_secretaire_panique" not in completed:
				DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_panique")
		DialogueSystem.complete_step("quete_preparation", "etape_reparer_electricite")
		_remove_darkness_overlay()
		_update_secretaire_npc_id()
	else:
		if _darkness_active and _darkness_layer:
			_darkness_layer.show()
		_disjoncteur_done = false



func stop() -> void:
	process_mode = PROCESS_MODE_DISABLED
	hide()
	$ObjectiveHUD.hide()
	can_move = false
	started = false
	stopped = true
	$Parking.stop_minigame()
	$Parking.set_interactive(false)
	if time_aunote:
		var collision_node := time_aunote.get_node("collision") as CollisionShape2D
		collision_node.disabled = true
	if pnj_secu:
		var zone = pnj_secu.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false
	if pnj_secretaire:
		var zone_s = pnj_secretaire.get_node_or_null("ZoneDialogue")
		if zone_s:
			zone_s.monitoring = false
	$fondPresent.hide()
	_set_fond_collisions(false)
	$Parking.hide()
	_set_parking_collisions(false)
	hall.hide()
	_set_hall_collisions(false)
	couloir.hide()
	_set_couloir_collisions(false)
	pc_controle.hide()
	_set_pc_controle_collisions(false)
	vestiaire.stop()
	_set_vestiaire_collisions(false)
	salle_machine.hide()
	_set_salle_machine_collisions(false)
	salle_electricite.hide()
	_set_salle_electricite_collisions(false)
	_player_in_couloir = false
	_player_in_retour_hall = false
	_player_at_porte_pc_controle = false
	_player_at_porte_vestiaires = false
	_player_at_porte_machines = false
	_player_at_porte_electricite = false
	_player_at_pc_controle_retour = false
	_player_at_salle_machine_retour = false
	_player_at_salle_electricite_retour = false
	_hall_transition_started = false
	_player_at_machines_repair = false
	_player_at_disjoncteur = false
	if _machines_repair_prompt:
		_machines_repair_prompt.visible = false
	if _disjoncteur_prompt:
		_disjoncteur_prompt.visible = false
	if _disjoncteur_locked_prompt:
		_disjoncteur_locked_prompt.visible = false
	if _salle_machine_minigame and is_instance_valid(_salle_machine_minigame):
		_salle_machine_minigame.queue_free()
		_salle_machine_minigame = null
	if _cablage_minigame and is_instance_valid(_cablage_minigame):
		_cablage_minigame.queue_free()
		_cablage_minigame = null
	if _darkness_layer:
		_darkness_layer.hide()
