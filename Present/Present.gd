extends Node2D

const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")
const MiniJeuTuyauScene = preload("res://Scripts/MiniJeuTuyau.tscn")
const MiniJeuCablageScene = preload("res://Scripts/MiniJeuCablage.tscn")
const MiniJeuHackingScript = preload("res://Scripts/MiniJeuHacking.gd")

var time_aunote: CharacterBody2D
var pnj_secu
var pnj_secretaire
var pnj_pc_controle
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
var _hacking_minigame: CanvasLayer = null
var _hacking_done: bool = false
var _trapped_in_control: bool = false
var _thought_bubble_label: Label
var _thought_bubble_layer: CanvasLayer

# Audio ambient
var _ambient_player: AudioStreamPlayer
var _current_zone: String = ""
var _audio_buffers: Dictionary = {}

# Stage-based audio (Present: une musique par étape, pas par salle)
var _last_zone: String = ""
var _bgm_player: AudioStreamPlayer  # for minigames/cinematic overlay



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
	pnj_pc_controle = $"PnjPcControle"
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
	_setup_ambient_audio()


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

	var ret_pc = pc_controle.get_node_or_null("event")
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


func _setup_thought_bubble() -> void:
	_thought_bubble_layer = CanvasLayer.new()
	_thought_bubble_layer.layer = 55
	add_child(_thought_bubble_layer)

	_thought_bubble_label = Label.new()
	_thought_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thought_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thought_bubble_label.add_theme_font_size_override("font_size", 15)
	_thought_bubble_label.add_theme_color_override("font_color", Color(0.12, 0.12, 0.2))
	var tstyle := StyleBoxFlat.new()
	tstyle.bg_color = Color(0.82, 0.9, 1.0, 0.93)
	tstyle.corner_radius_top_left = 10
	tstyle.corner_radius_top_right = 10
	tstyle.corner_radius_bottom_left = 10
	tstyle.corner_radius_bottom_right = 10
	_thought_bubble_label.add_theme_stylebox_override("normal", tstyle)
	_thought_bubble_label.custom_minimum_size = Vector2(280, 0)
	_thought_bubble_label.visible = false
	_thought_bubble_layer.add_child(_thought_bubble_label)


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
	_set_zone("couloir")


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
	_set_zone("hall")


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

	if pnj_pc_controle:
		var pnj_marker = pc_controle.get_node_or_null("Node2D/pnj pc principal")
		if pnj_marker:
			pnj_pc_controle.apparition(pnj_marker.global_position)
			var zone = pnj_pc_controle.get_node_or_null("ZoneDialogue")
			if zone:
				zone.monitoring = true
		_update_pc_controle_state()

	time_aunote.global_position = pc_controle.get_node("Node2D/zone pop").global_position
	time_aunote.scale = Vector2(0.9555, 0.9555)

	tween_fade = create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
	await tween_fade.finished
	if not is_inside_tree():
		return

	_set_zone("pc_controle")
	can_move = true
	_hide_thought_bubble()


func _return_from_pc_controle() -> void:
	if not is_inside_tree() or couloir.visible:
		return
	if _trapped_in_control:
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

	if pnj_pc_controle:
		pnj_pc_controle.hide()
		var zone = pnj_pc_controle.get_node_or_null("ZoneDialogue")
		if zone:
			zone.monitoring = false

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

	_set_zone("couloir")
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

	_set_zone("vestiaire")
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

	_set_zone("couloir")
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

	_set_zone("salle_machine")
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

	_set_zone("couloir")
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

	_set_zone("salle_electricite")
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

	_set_zone("couloir")
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
	for area_name in ["retour_hall", "porte_pc_controle", "porte_machines", "porte_electricite", "porte_vestiaires"]:
		var area = couloir.get_node_or_null(area_name)
		if area:
			area.monitoring = enabled


func _input(event: InputEvent) -> void:
	if not started or not can_move:
		return
	if DialogueUI.is_dialogue_active():
		return
	if not event.is_action_pressed("interagir"):
		return
	if _trapped_in_control:
		get_viewport().set_input_as_handled()
		_escape_to_nexus()
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
	if body == time_aunote and can_move and $"fondPresent".visible:
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
	_set_zone("parking")
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
	_set_zone("exterieur")
	can_move = true


func _go_to_hall(skip_delay: bool = false) -> void:
	if _hall_transition_started or hall.visible:
		return
	_hall_transition_started = true
	can_move = false
	if not skip_delay:
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
	$"fondPresent/zone escape parking".monitoring = false
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
	_set_zone("hall")
	can_move = true

func _set_hall_collisions(enabled: bool) -> void:
	var limites = hall.get_node_or_null("Camera2D/limites")
	if limites:
		limites.collision_layer = 8 if enabled else 0
	var couloir_zone = hall.get_node_or_null("Camera2D/couloir")
	if couloir_zone:
		couloir_zone.monitoring = enabled


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
		_go_to_hall(true)


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
	elif _last_dialogue_npc_id == "npc_secretaire_present_maj":
		_update_objective("Aller en salle de contrôle")
	elif _last_dialogue_npc_id == "npc_pc_controle_maj":
		_update_objective("Skipper la mise à jour sur le laptop")
	elif _last_dialogue_npc_id == "npc_pc_controle_sauve":
		_trapped_in_control = true
		_update_objective("Retourner aux nexus")
	elif _last_dialogue_npc_id == "npc_secretaire_present_retabli":
		DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_fin")
		
	_update_secretaire_npc_id()
	_last_dialogue_npc_id = ""


func _update_secretaire_npc_id() -> void:
	if not pnj_secretaire:
		return
	if _hacking_done:
		pnj_secretaire.npc_id = "npc_secretaire_present_retabli"
	elif _disjoncteur_done:
		pnj_secretaire.npc_id = "npc_secretaire_present_maj"
	elif _salle_machine_done:
		pnj_secretaire.npc_id = "npc_secretaire_present_courtcircuit"
	elif TimeAunoteScript.disguised_present:
		pnj_secretaire.npc_id = "npc_secretaire_present_change"
	elif _player_has_changed_once:
		pnj_secretaire.npc_id = "npc_secretaire_present_undisguise"
	else:
		pnj_secretaire.npc_id = "npc_secretaire_present"


func _update_pc_controle_state() -> void:
	if not pc_controle:
		return
	var normal: Sprite2D = pc_controle.get_node_or_null("pc normal") as Sprite2D
	var maj: Sprite2D = pc_controle.get_node_or_null("pc maj") as Sprite2D
	var alerte: Sprite2D = pc_controle.get_node_or_null("pc alerte") as Sprite2D
	var secours: Sprite2D = pc_controle.get_node_or_null("pc generateur secours") as Sprite2D

	if normal: normal.visible = false
	if maj: maj.visible = false
	if alerte: alerte.visible = false
	if secours: secours.visible = false

	if _hacking_done:
		if alerte: alerte.visible = true
		if pnj_pc_controle:
			pnj_pc_controle.npc_id = "npc_pc_controle_sauve"
	elif _disjoncteur_done:
		if maj: maj.visible = true
		if pnj_pc_controle:
			pnj_pc_controle.npc_id = "npc_pc_controle_maj"
	elif _salle_machine_done:
		if secours: secours.visible = true
		if pnj_pc_controle:
			pnj_pc_controle.npc_id = "npc_pc_controle_secours"
	else:
		if normal: normal.visible = true
		if pnj_pc_controle:
			pnj_pc_controle.npc_id = "npc_pc_controle_normal"



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
	_update_thought_bubble_position()
	if _trapped_in_control:
		_pc_controle_retour_prompt.text = "Appuyez sur E pour retourner aux nexus"
		_pc_controle_retour_prompt.visible = true
		_update_portal_prompt_position(_pc_controle_retour_prompt)


func _handle_movement(delta: float) -> void:
	if DialogueUI.is_dialogue_active():
		if is_instance_valid(time_aunote):
			time_aunote.animation(Vector2.ZERO)
		return
	if _trapped_in_control:
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


func _show_thought_bubble(text: String) -> void:
	if not _thought_bubble_label:
		return
	_thought_bubble_label.text = text
	_thought_bubble_label.visible = true
	_thought_bubble_label.reset_size()
	_update_thought_bubble_position()


func _hide_thought_bubble() -> void:
	if _thought_bubble_label:
		_thought_bubble_label.visible = false


func _update_thought_bubble_position() -> void:
	if not _thought_bubble_label or not _thought_bubble_label.visible:
		return
	if not is_instance_valid(time_aunote):
		return
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var player_global: Vector2 = time_aunote.global_position
	var screen: Vector2 = cam.get_screen_center_position()
	var zoom_val: Vector2 = cam.zoom
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var sx: float = (player_global.x - screen.x) * zoom_val.x + vp_size.x / 2.0
	var sy: float = (player_global.y - screen.y) * zoom_val.y + vp_size.y / 2.0
	_thought_bubble_label.position = Vector2(sx - _thought_bubble_label.size.x / 2.0, sy - 180.0)


func _typewriter_text(label: Label, target_text: String) -> void:
	label.text = ""
	for i in range(target_text.length()):
		if not is_inside_tree():
			return
		label.text += target_text[i]
		await get_tree().create_timer(0.04).timeout

func _escape_to_nexus() -> void:
	can_move = false
	_hide_thought_bubble()
	_pc_controle_retour_prompt.visible = false
	_remove_darkness_overlay()

	var tween_fade := create_tween()
	tween_fade.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	await tween_fade.finished
	if not is_inside_tree():
		return
	
	# Start cinematic music
	_stop_ambient()
	_play_bgm("cinematique")

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		viewport_size = Vector2(1024, 682)

	var cinematic_container := Control.new()
	cinematic_container.size = viewport_size
	cinematic_container.clip_contents = true
	fade_layer.add_child(cinematic_container)
	fade_layer.move_child(cinematic_container, 0)

	var bg_rect := ColorRect.new()
	bg_rect.color = Color.BLACK
	bg_rect.size = viewport_size
	cinematic_container.add_child(bg_rect)

	var image_clipper := Control.new()
	image_clipper.size = viewport_size
	image_clipper.clip_contents = true
	cinematic_container.add_child(image_clipper)

	var tex_rect1 := TextureRect.new()
	var tex1 := load("res://art/Present/image1.png") as Texture2D
	tex_rect1.texture = tex1
	tex_rect1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect1.stretch_mode = TextureRect.STRETCH_SCALE

	var aspect_ratio1 := float(tex1.get_width()) / float(tex1.get_height())
	var tex_height1 := viewport_size.y
	var tex_width1 := tex_height1 * aspect_ratio1
	tex_rect1.size = Vector2(tex_width1, tex_height1)

	var start_x1 := 0.0
	var end_x1 := -(tex_width1 - viewport_size.x)
	tex_rect1.position = Vector2(start_x1, 0.0)
	image_clipper.add_child(tex_rect1)

	var subtitles_bg := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0, 0.8, 1.0, 0.4)
	subtitles_bg.add_theme_stylebox_override("panel", style)

	var bg_width := viewport_size.x * 0.85
	var bg_height := 120.0
	subtitles_bg.size = Vector2(bg_width, bg_height)
	subtitles_bg.position = Vector2(
		(viewport_size.x - bg_width) / 2.0,
		viewport_size.y - bg_height - 40.0
	)
	subtitles_bg.modulate.a = 0.0
	cinematic_container.add_child(subtitles_bg)

	var subtitles_label := Label.new()
	subtitles_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitles_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitles_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitles_label.size = subtitles_bg.size - Vector2(40, 20)
	subtitles_label.position = Vector2(20, 10)
	subtitles_label.add_theme_font_override("font", SystemFont.new())
	subtitles_label.add_theme_font_size_override("font_size", 20)
	subtitles_label.add_theme_color_override("font_color", Color.WHITE)
	subtitles_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	subtitles_label.add_theme_constant_override("shadow_offset_x", 2)
	subtitles_label.add_theme_constant_override("shadow_offset_y", 2)
	subtitles_bg.add_child(subtitles_label)

	var tween_in1 := create_tween()
	tween_in1.tween_property(fade_rect, "modulate:a", 0.0, 1.5)

	var pan_tween1 := create_tween()
	pan_tween1.set_ease(Tween.EASE_IN_OUT)
	pan_tween1.set_trans(Tween.TRANS_SINE)
	pan_tween1.tween_property(tex_rect1, "position:x", end_x1, 9.0)

	var bg_tween1 := create_tween()
	bg_tween1.tween_property(subtitles_bg, "modulate:a", 1.0, 0.8)
	await bg_tween1.finished

	if not is_inside_tree():
		return

	await _typewriter_text(subtitles_label, "Vous avez stabilisé la centrale nucléaire. La ligne temporelle de cette époque est désormais hors de danger.")

	if not is_inside_tree():
		return

	await get_tree().create_timer(2.0).timeout
	if pan_tween1.is_running():
		await pan_tween1.finished

	if not is_inside_tree():
		return

	var bg_fadeout1 := create_tween()
	bg_fadeout1.tween_property(subtitles_bg, "modulate:a", 0.0, 0.6)
	await bg_fadeout1.finished

	if not is_inside_tree():
		return

	var tex_rect2 := TextureRect.new()
	var tex2 := load("res://art/Present/image2.png") as Texture2D
	tex_rect2.texture = tex2
	tex_rect2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect2.stretch_mode = TextureRect.STRETCH_SCALE

	var aspect_ratio2 := float(tex2.get_width()) / float(tex2.get_height())
	var tex_height2 := viewport_size.y
	var tex_width2 := tex_height2 * aspect_ratio2
	tex_rect2.size = Vector2(tex_width2, tex_height2)
	tex_rect2.modulate.a = 0.0

	var start_x2 := 0.0
	var end_x2 := -(tex_width2 - viewport_size.x)
	tex_rect2.position = Vector2(start_x2, 0.0)
	image_clipper.add_child(tex_rect2)

	var cross_fade_in := create_tween()
	cross_fade_in.tween_property(tex_rect2, "modulate:a", 1.0, 1.5)

	var cross_fade_out := create_tween()
	cross_fade_out.tween_property(tex_rect1, "modulate:a", 0.0, 1.5)

	var pan_tween2 := create_tween()
	pan_tween2.set_ease(Tween.EASE_IN_OUT)
	pan_tween2.set_trans(Tween.TRANS_SINE)
	pan_tween2.tween_property(tex_rect2, "position:x", end_x2, 9.0)

	await cross_fade_in.finished
	if not is_inside_tree():
		return

	tex_rect1.queue_free()

	subtitles_label.text = ""

	var bg_tween2 := create_tween()
	bg_tween2.tween_property(subtitles_bg, "modulate:a", 1.0, 0.8)
	await bg_tween2.finished

	if not is_inside_tree():
		return

	await _typewriter_text(subtitles_label, "La distorsion semble plus stable et nous pouvons retourner au nexus maintenant.")

	if not is_inside_tree():
		return

	await get_tree().create_timer(3.0).timeout

	if not is_inside_tree():
		return

	subtitles_bg.queue_free()
	image_clipper.queue_free()

	var chernobyl_label := Label.new()
	chernobyl_label.text = "TCHERNOBYL"
	chernobyl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chernobyl_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chernobyl_label.size = viewport_size
	chernobyl_label.position = Vector2(0, 0)
	var chernobyl_font := SystemFont.new()
	chernobyl_font.font_names = PackedStringArray(["Arial", "Helvetica", "DejaVu Sans", "Liberation Sans"])
	chernobyl_label.add_theme_font_override("font", chernobyl_font)
	chernobyl_label.add_theme_font_size_override("font_size", 96)
	chernobyl_label.add_theme_color_override("font_color", Color.WHITE)
	chernobyl_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	chernobyl_label.add_theme_constant_override("shadow_offset_x", 4)
	chernobyl_label.add_theme_constant_override("shadow_offset_y", 4)
	chernobyl_label.modulate.a = 0.0
	cinematic_container.add_child(chernobyl_label)

	var chernobyl_fade_in := create_tween()
	chernobyl_fade_in.tween_property(chernobyl_label, "modulate:a", 1.0, 2.0)
	await chernobyl_fade_in.finished

	if not is_inside_tree():
		return

	await get_tree().create_timer(3.0).timeout

	if not is_inside_tree():
		return

	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	await fade_out_tween.finished

	if not is_inside_tree():
		return

	cinematic_container.queue_free()
	fade_rect.modulate.a = 0.0

	TimeAunoteScript.disguised_present = false
	if is_instance_valid(time_aunote):
		time_aunote.remove_disguise_present()
	DialogueSystem.reset_quest("quete_acces_centrale")
	DialogueSystem.reset_quest("quete_preparation")

	var main = get_parent()
	if main and main.has_method("warp_to_era"):
		main.warp_to_era("hub", "entree")



func start(spawn_id: String = "entree") -> void:
	process_mode = PROCESS_MODE_INHERIT
	_hall_transition_started = false
	_player_has_changed_once = false
	_salle_machine_done = false
	_disjoncteur_done = false
	_hacking_done = false
	_couloir_unlocked = false
	_trapped_in_control = false
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
	if pnj_pc_controle:
		pnj_pc_controle.hide()
		var zone_pc = pnj_pc_controle.get_node_or_null("ZoneDialogue")
		if zone_pc:
			zone_pc.monitoring = false
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
	_update_pc_controle_state()

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
		_set_zone("parking")
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
		_hacking_done = false
		_couloir_unlocked = false
		_update_secretaire_npc_id()
		_update_objective("Parler à la secrétaire")
		_set_zone("hall")
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
		_set_zone("couloir")
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
		_set_zone("vestiaire")
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
		_set_zone("salle_machine")
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
		_set_zone("salle_electricite")
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
		_set_zone("pc_controle")
		return



	_update_objective("Parler à l'agent de sécurité")
	_set_zone("exterieur")
	time_aunote.position = position_entree_principale
	time_aunote.hide()
	time_aunote.modulate.a = 0.0
	time_aunote.scale = Vector2.ZERO
	time_aunote.rotation = TAU
	_play_spawn_animation()


# ===== Audio Ambient System =====

func _setup_ambient_audio() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	_ambient_player.volume_db = -8.0
	add_child(_ambient_player)
	
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -8.0
	add_child(_bgm_player)


# ===== Stage-based Audio System (Present) =====
# Étapes : exterieur → interieur → alarme → speed → alarme_finale

func _load_stage_audio(stage: String) -> void:
	if stage in _audio_buffers and not _audio_buffers[stage].is_empty():
		return
	var dir := DirAccess.open("res://audio/present/" + stage + "/")
	if not dir:
		return
	var streams: Array[AudioStream] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
			var stream := load("res://audio/present/" + stage + "/" + file_name) as AudioStream
			if stream:
				streams.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	_audio_buffers[stage] = streams


func _play_stage_audio(stage: String) -> void:
	if stage == _current_zone:
		return
	_stop_ambient()
	_load_stage_audio(stage)
	var streams: Array = _audio_buffers.get(stage, [])
	if streams.is_empty():
		_current_zone = stage
		return
	var idx := randi() % streams.size()
	_ambient_player.stream = streams[idx]
	_ambient_player.play()
	_current_zone = stage


func _stop_ambient() -> void:
	_ambient_player.stop()
	_current_zone = ""


func _update_audio_stage() -> void:
	# Determine stage based on game progression flags
	if _hacking_done:
		_play_stage_audio("alarme_finale")
	elif _disjoncteur_done:
		_play_stage_audio("speed")
	elif _salle_machine_done:
		_play_stage_audio("alarme")
	elif _last_zone == "parking":
		_play_stage_audio("parking")
	elif _last_zone == "exterieur" or _last_zone == "fond" or _last_zone == "":
		_play_stage_audio("exterieur")
	else:
		_play_stage_audio("interieur")


func _set_zone(zone: String) -> void:
	_last_zone = zone
	_update_audio_stage()


func _play_bgm(folder: String) -> void:
	_stop_bgm()
	var dir := DirAccess.open("res://audio/present/" + folder + "/")
	if not dir:
		return
	var streams: Array[AudioStream] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
			var stream := load("res://audio/present/" + folder + "/" + file_name) as AudioStream
			if stream:
				streams.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	if streams.is_empty():
		return
	var idx := randi() % streams.size()
	_bgm_player.stream = streams[idx]
	_bgm_player.play()


func _stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()


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
	_stop_ambient()
	_play_bgm("minijeu_tuyau")


func _on_salle_machine_minigame_done(success: bool) -> void:
	_stop_bgm()
	_salle_machine_minigame = null
	_salle_machine_done = true
	if _machines_repair_prompt:
		_machines_repair_prompt.visible = false
	_player_at_machines_repair = false
	if is_instance_valid(time_aunote):
		time_aunote.show()
	can_move = true
	_update_audio_stage()
	if success:
		DialogueSystem.complete_step("quete_preparation", "etape_reparer_machines")
		_show_darkness_overlay()
		_update_secretaire_npc_id()
		_update_pc_controle_state()


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
	_stop_ambient()
	_play_bgm("minijeu_cablage")


func _on_disjoncteur_minigame_done(success: bool) -> void:
	_stop_bgm()
	_cablage_minigame = null
	_disjoncteur_done = success
	if is_instance_valid(time_aunote):
		time_aunote.show()
	can_move = true
	_player_at_disjoncteur = false
	_update_audio_stage()
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
		_update_pc_controle_state()
		_update_objective("Aller voir Sophie")
	else:
		if _darkness_active and _darkness_layer:
			_darkness_layer.show()
		_disjoncteur_done = false


func _start_hacking_minigame() -> void:
	if _hacking_minigame != null or _hacking_done:
		return
	can_move = false
	time_aunote.hide()
	if vestiaire:
		vestiaire._player_near_ordi = false
		vestiaire._update_ordi_prompt()
	_hacking_minigame = MiniJeuHackingScript.new()
	_hacking_minigame.done.connect(_on_hacking_minigame_done)
	get_tree().root.add_child(_hacking_minigame)
	_stop_ambient()
	_play_bgm("minijeu_hacking")


func _on_hacking_minigame_done(success: bool) -> void:
	_stop_bgm()
	_hacking_minigame = null
	_hacking_done = success
	if is_instance_valid(time_aunote):
		time_aunote.show()
	can_move = true
	_update_audio_stage()
	if success:
		DialogueSystem.complete_step("quete_preparation", "etape_retour_secretaire_fin")
		_show_darkness_overlay()
		_update_secretaire_npc_id()
		_update_pc_controle_state()
		_update_objective("Retourner en salle de contrôle")
		_show_thought_bubble("Hmm, je devrais voir si j'ai résolu le problème")



func stop() -> void:
	_stop_ambient()
	_stop_bgm()
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
	if pnj_pc_controle:
		var zone_pc = pnj_pc_controle.get_node_or_null("ZoneDialogue")
		if zone_pc:
			zone_pc.monitoring = false
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
	_trapped_in_control = false
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
	if _hacking_minigame and is_instance_valid(_hacking_minigame):
		_hacking_minigame.queue_free()
		_hacking_minigame = null
	_hide_thought_bubble()
	if _darkness_layer:
		_darkness_layer.hide()
