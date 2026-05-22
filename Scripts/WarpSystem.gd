extends CanvasLayer

const TOGGLE_KEY = KEY_F2
const TimeAunoteScript = preload("res://Personnage/TimeAunote.gd")

var destinations := {
	"hub_entree":	{"zone": "hub", "name": "HUB — Entrée principale", "id": "entree"},
	"moyenage_entree":	{"zone": "moyenage", "name": "Moyen Âge — Entrée château", "id": "entree"},
	"moyenage_prison":	{"zone": "moyenage", "name": "Moyen Âge — Prison", "id": "prison"},
	"moyenage_magasin":	{"zone": "moyenage", "name": "Moyen Âge — Magasin", "id": "magasin"},
	"moyenage_ville":	{"zone": "moyenage", "name": "Moyen Âge — Ville", "id": "ville"},
	"moyenage_auberge":	{"zone": "moyenage", "name": "Moyen Âge — Auberge", "id": "auberge"},
	"moyenage_parc":	{"zone": "moyenage", "name": "Moyen Âge — Parc", "id": "parc"},
	"moyenage_foret":	{"zone": "moyenage", "name": "Moyen Âge — Forêt", "id": "foret"},
	"moyenage_campement":	{"zone": "moyenage", "name": "Moyen Âge — Combat Assassin", "id": "campement"},
	"present_entree":	{"zone": "present", "name": "Present — Entrée", "id": "entree"},
	"present_parking":	{"zone": "present", "name": "Present — Parking", "id": "parking"},
	"present_hall":		{"zone": "present", "name": "Present — Hall", "id": "hall"},
	"present_couloir":	{"zone": "present", "name": "Present — Couloir", "id": "couloir"},
	"present_pc_controle":	{"zone": "present", "name": "Present — PC Contrôle", "id": "pc_controle"},
	"present_vestiaire":	{"zone": "present", "name": "Present — Vestiaire", "id": "vestiaire"},
	"present_salle_machine":{"zone": "present", "name": "Present — Salle Machine", "id": "salle_machine"},
	"present_salle_electricite":{"zone": "present", "name": "Present — Salle Électricité", "id": "salle_electricite"},
	"futur_entree":		{"zone": "futur", "name": "Futur — Entrée", "id": "entree"},
	"futur_soussol":	{"zone": "futur", "name": "Futur — Sous-sol", "id": "soussol"},
	"futur_superette":	{"zone": "futur", "name": "Futur — Supérette", "id": "superette"},
	"futur_metro":		{"zone": "futur", "name": "Futur — Métro (QG Alfredo)", "id": "metro"},
	"futur_tour":		{"zone": "futur", "name": "Futur — Tour Alfredo", "id": "tour"},
	"futur_bureau":		{"zone": "futur", "name": "Futur — Bureau", "id": "bureau"},
}

var zone_order := ["hub", "moyenage", "present", "futur"]
var zone_labels := {
	"hub": "HUB Central",
	"moyenage": "Moyen Âge",
	"present": "Present",
	"futur": "Futur",
}

var open: bool = false
var container: Control
var buttons: Array[Button] = []

var minigames_status := {
	"crochetage": false,
	"marchandage": false,
	"ecoute_tables": false,
	"combat_assassin": false,
	"infiltration": false,
	"tuyaux": false,
	"cablage": false,
	"conduite": false,
	"lasers": false,
	"boss_rpg": false
}

var minigames_list := [
	{"key": "crochetage", "name": "🔒 Crochetage", "zone": "moyenage"},
	{"key": "marchandage", "name": "👗 Marchandage", "zone": "moyenage"},
	{"key": "ecoute_tables", "name": "🍻 Écoute Tables", "zone": "moyenage"},
	{"key": "combat_assassin", "name": "⚔️ Combat Assassin", "zone": "moyenage"},
	{"key": "infiltration", "name": "☀️ Infiltration", "zone": "present"},
	{"key": "tuyaux", "name": "🔧 Tuyaux", "zone": "present"},
	{"key": "cablage", "name": "⚡ Câblage", "zone": "present"},
	{"key": "conduite", "name": "🚗 Conduite", "zone": "futur"},
	{"key": "lasers", "name": "🔴 Lasers", "zone": "futur"},
	{"key": "boss_rpg", "name": "👑 Boss RPG", "zone": "futur"},
]

var minigame_buttons := {}

var quests_list := [
	{"id": "quete_enquete_roi", "name": "👑 Enquête Roi Mourant", "zone": "moyenage"},
	{"id": "quete_evasion", "name": "🔓 Évasion de la Prison", "zone": "moyenage"},
	{"id": "quete_deguisement", "name": "👗 Obtenir le Déguisement", "zone": "moyenage"},
	{"id": "quete_piste_assassin", "name": "⚔️ Piste de l'Assassin", "zone": "moyenage"},
	{"id": "quete_acces_centrale", "name": "🪪 Accès à la Centrale", "zone": "present"},
	{"id": "quete_preparation", "name": "🔧 Préparation Service", "zone": "present"}
]

var quest_buttons := {}


func _ready() -> void:
	layer = 256
	hide()
	_setup_ui()


func _setup_ui() -> void:
	container = Control.new()
	container.anchor_right = 1.0
	container.anchor_bottom = 1.0
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)

	# Sleek obsidian dark background panel with fine sci-fi border
	var bg_panel := Panel.new()
	bg_panel.anchor_right = 1.0
	bg_panel.anchor_bottom = 1.0
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 0.92) # Deep rich obsidian
	bg_style.border_color = Color(0.2, 0.25, 0.35, 0.25)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	container.add_child(bg_panel)

	# Bold, glowing HUD title
	var title := Label.new()
	title.text = "CHRONO-WARP SYSTEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	title.anchor_right = 1.0
	title.offset_top = 20
	title.offset_bottom = 60
	container.add_child(title)

	# Clean elegant subtitle
	var hint := Label.new()
	hint.text = "[F2] Fermer l'interface  •  Sélectionnez une faille temporelle pour transiter"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	hint.anchor_right = 1.0
	hint.offset_top = 58
	hint.offset_bottom = 78
	container.add_child(hint)

	# Main horizontal grid layout (944px width, perfectly centered and stretched)
	var columns_hbox := HBoxContainer.new()
	columns_hbox.anchor_right = 1.0
	columns_hbox.anchor_bottom = 1.0
	columns_hbox.offset_left = 40
	columns_hbox.offset_top = 90
	columns_hbox.offset_right = -40
	columns_hbox.offset_bottom = -295 # Shrunk slightly to leave 280px at the bottom
	columns_hbox.add_theme_constant_override("separation", 20)
	container.add_child(columns_hbox)

	var mp_style := StyleBoxFlat.new()
	mp_style.bg_color = Color(0.08, 0.08, 0.12, 0.75) # Sleek glassmorphic dark-gray tint
	mp_style.border_color = Color(0.25, 0.3, 0.45, 0.3)
	mp_style.border_width_left = 1
	mp_style.border_width_right = 1
	mp_style.border_width_top = 1
	mp_style.border_width_bottom = 1
	mp_style.corner_radius_top_left = 10
	mp_style.corner_radius_top_right = 10
	mp_style.corner_radius_bottom_left = 10
	mp_style.corner_radius_bottom_right = 10
	mp_style.content_margin_left = 15
	mp_style.content_margin_right = 15
	mp_style.content_margin_top = 10
	mp_style.content_margin_bottom = 10

	var mp_style_left := mp_style
	var mp_style_right := mp_style.duplicate() as StyleBoxFlat

	# Bottom split container for dual list format
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.anchor_left = 0.0
	bottom_hbox.anchor_right = 1.0
	bottom_hbox.anchor_top = 1.0
	bottom_hbox.anchor_bottom = 1.0
	bottom_hbox.offset_left = 40
	bottom_hbox.offset_top = -280
	bottom_hbox.offset_right = -40
	bottom_hbox.offset_bottom = -15
	bottom_hbox.add_theme_constant_override("separation", 20)
	container.add_child(bottom_hbox)

	# Left panel for mini-games
	var minigames_panel := PanelContainer.new()
	minigames_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minigames_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minigames_panel.add_theme_stylebox_override("panel", mp_style_left)
	bottom_hbox.add_child(minigames_panel)

	var mg_vbox := VBoxContainer.new()
	mg_vbox.add_theme_constant_override("separation", 6)
	mg_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	minigames_panel.add_child(mg_vbox)
	
	var mg_title := Label.new()
	mg_title.text = "ÉVALUATION DES MINI-JEUX TEMPORELS"
	mg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mg_title.add_theme_font_size_override("font_size", 11)
	mg_title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0, 0.8)) # Glowing cyan hint
	mg_vbox.add_child(mg_title)

	var mg_scroll := ScrollContainer.new()
	mg_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mg_vbox.add_child(mg_scroll)

	var mg_list_vbox := VBoxContainer.new()
	mg_list_vbox.add_theme_constant_override("separation", 4)
	mg_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg_scroll.add_child(mg_list_vbox)

	for i in range(minigames_list.size()):
		var mg_info: Dictionary = minigames_list[i]
		var key: String = mg_info.key
		var display_name: String = mg_info.name
		
		var btn := Button.new()
		btn.text = display_name
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mg_list_vbox.add_child(btn)
		
		minigame_buttons[key] = btn
		btn.toggled.connect(func(toggled_on: bool): _on_minigame_toggled(toggled_on, key))

	# Right panel for quests
	var quests_panel := PanelContainer.new()
	quests_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quests_panel.add_theme_stylebox_override("panel", mp_style_right)
	bottom_hbox.add_child(quests_panel)

	var q_vbox := VBoxContainer.new()
	q_vbox.add_theme_constant_override("separation", 6)
	q_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quests_panel.add_child(q_vbox)

	var q_title := Label.new()
	q_title.text = "VALIDATION DES QUÊTES ACTIVES"
	q_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_title.add_theme_font_size_override("font_size", 11)
	q_title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4, 0.8)) # Glowing amber hint
	q_vbox.add_child(q_title)

	var q_scroll := ScrollContainer.new()
	q_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	q_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	q_vbox.add_child(q_scroll)

	var q_list_vbox := VBoxContainer.new()
	q_list_vbox.add_theme_constant_override("separation", 4)
	q_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_scroll.add_child(q_list_vbox)

	for i in range(quests_list.size()):
		var quest: Dictionary = quests_list[i]
		var qid: String = quest.id

		var btn := Button.new()
		btn.text = quest.name
		btn.custom_minimum_size = Vector2(0, 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_list_vbox.add_child(btn)

		quest_buttons[qid] = btn
		btn.pressed.connect(_on_quest_clicked.bind(qid))

	for zone in zone_order:
		var zone_dests := []
		for key in destinations:
			if destinations[key].zone == zone:
				zone_dests.append(key)
		if zone_dests.is_empty():
			continue

		var z_color := _zone_color(zone)

		# Dimension Card Container for clear, elegant visual separation
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.08, 0.08, 0.12, 0.5)
		card_style.border_color = Color(0.2, 0.25, 0.35, 0.15)
		card_style.border_width_left = 1
		card_style.border_width_right = 1
		card_style.border_width_top = 1
		card_style.border_width_bottom = 1
		card_style.corner_radius_top_left = 8
		card_style.corner_radius_top_right = 8
		card_style.corner_radius_bottom_left = 8
		card_style.corner_radius_bottom_right = 8
		card_style.content_margin_left = 12
		card_style.content_margin_right = 12
		card_style.content_margin_top = 12
		card_style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", card_style)
		columns_hbox.add_child(card)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(col)

		var section := Label.new()
		section.text = zone_labels.get(zone, zone).to_upper()
		section.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		section.add_theme_font_size_override("font_size", 16)
		section.add_theme_color_override("font_color", z_color)
		section.custom_minimum_size = Vector2(0, 24)
		col.add_child(section)

		# Custom separator underline themed with the dimension color
		var sep := ColorRect.new()
		sep.color = Color(z_color.r, z_color.g, z_color.b, 0.3)
		sep.custom_minimum_size = Vector2(0, 2)
		col.add_child(sep)

		# Wrap the buttons list in a ScrollContainer inside the card to prevent vertical overflows
		var btn_scroll := ScrollContainer.new()
		btn_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		col.add_child(btn_scroll)

		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 6)
		btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_scroll.add_child(btn_vbox)

		for key in zone_dests:
			var dest := destinations[key] as Dictionary
			var btn := Button.new()
			
			var display_name: String = dest.name
			var parts := display_name.split(" — ")
			if parts.size() > 1:
				display_name = parts[1]
				
			btn.text = display_name
			btn.custom_minimum_size = Vector2(0, 36)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Highly premium, reactive buttons with custom hover glows matching the dimension color
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0.12, 0.12, 0.18, 0.7)
			normal_style.border_color = Color(0.25, 0.25, 0.35, 0.4)
			normal_style.border_width_left = 1
			normal_style.border_width_right = 1
			normal_style.border_width_top = 1
			normal_style.border_width_bottom = 1
			normal_style.corner_radius_top_left = 6
			normal_style.corner_radius_top_right = 6
			normal_style.corner_radius_bottom_left = 6
			normal_style.corner_radius_bottom_right = 6
			
			var hover_style := normal_style.duplicate() as StyleBoxFlat
			hover_style.bg_color = Color(0.18, 0.18, 0.26, 0.8)
			hover_style.border_color = Color(z_color.r, z_color.g, z_color.b, 0.8)
			
			var pressed_style := normal_style.duplicate() as StyleBoxFlat
			pressed_style.bg_color = Color(z_color.r * 0.4, z_color.g * 0.4, z_color.b * 0.4, 0.9)
			pressed_style.border_color = Color(z_color.r, z_color.g, z_color.b, 1.0)
			
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_stylebox_override("hover", hover_style)
			btn.add_theme_stylebox_override("pressed", pressed_style)
			btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.98))
			btn.add_theme_color_override("font_hover_color", Color.WHITE)
			btn.add_theme_color_override("font_pressed_color", Color.WHITE)
			
			btn.pressed.connect(_on_warp.bind(key))
			btn_vbox.add_child(btn)
			buttons.append(btn)


func _zone_color(zone: String) -> Color:
	match zone:
		"hub": return Color(0.5, 0.8, 1.0)
		"moyenage": return Color(1.0, 0.8, 0.3)
		"present": return Color(0.3, 1.0, 0.4)
		"futur": return Color(1.0, 0.3, 0.3)
		_: return Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == TOGGLE_KEY and event.pressed and not event.echo:
		toggle()


func toggle() -> void:
	open = not open
	if open:
		update_minigames_status_from_game()
		_update_minigame_button_styles()
		update_quests_status_from_game()
		show()
	else:
		hide()


func _on_warp(dest_key: String) -> void:
	var dest := destinations.get(dest_key) as Dictionary
	if dest == null:
		return

	toggle()
	WarpSystem._do_warp(dest.zone, dest.id)


func _add_btn_style(btn: Button, color: Color) -> void:
	var s_normal := StyleBoxFlat.new()
	s_normal.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.6)
	s_normal.border_color = Color(color.r, color.g, color.b, 0.4)
	s_normal.border_width_left = 1
	s_normal.border_width_right = 1
	s_normal.border_width_top = 1
	s_normal.border_width_bottom = 1
	s_normal.corner_radius_top_left = 6
	s_normal.corner_radius_top_right = 6
	s_normal.corner_radius_bottom_left = 6
	s_normal.corner_radius_bottom_right = 6

	var s_hover := s_normal.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.8)
	s_hover.border_color = Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.8)

	var s_pressed := s_normal.duplicate() as StyleBoxFlat
	s_pressed.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.95)
	s_pressed.border_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)

	btn.add_theme_stylebox_override("normal", s_normal)
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_stylebox_override("pressed", s_pressed)
	btn.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)


func update_minigames_status_from_game() -> void:
	# Moyen Âge (if MoyenAge is active/loaded)
	var ma_qs_evasion = DialogueSystem.game_state.get("quete_evasion")
	if ma_qs_evasion is Dictionary:
		var completed_evasion: Array = ma_qs_evasion.get("completed_steps", [])
		minigames_status["crochetage"] = "etape_crocheter" in completed_evasion

	var ma_qs_deg = DialogueSystem.game_state.get("quete_deguisement")
	if ma_qs_deg is Dictionary:
		var completed_deg: Array = ma_qs_deg.get("completed_steps", [])
		minigames_status["marchandage"] = "etape_marchander" in completed_deg

	var ma_qs_piste = DialogueSystem.game_state.get("quete_piste_assassin")
	if ma_qs_piste is Dictionary:
		var completed_piste: Array = ma_qs_piste.get("completed_steps", [])
		minigames_status["ecoute_tables"] = "etape_enqueter_foret" in completed_piste
		minigames_status["combat_assassin"] = "etape_trouver_assassin" in completed_piste

	# Present (if Present is active/loaded)
	var pr_qs_acc = DialogueSystem.game_state.get("quete_acces_centrale")
	if pr_qs_acc is Dictionary:
		var completed_acc: Array = pr_qs_acc.get("completed_steps", [])
		minigames_status["infiltration"] = "etape_chercher_carte" in completed_acc

	var pr_qs_prep = DialogueSystem.game_state.get("quete_preparation")
	if pr_qs_prep is Dictionary:
		var completed_prep: Array = pr_qs_prep.get("completed_steps", [])
		minigames_status["tuyaux"] = "etape_reparer_machines" in completed_prep
		minigames_status["cablage"] = "etape_reparer_electricite" in completed_prep


func _update_minigame_button_styles() -> void:
	for i in range(minigames_list.size()):
		var mg_info: Dictionary = minigames_list[i]
		var key: String = mg_info.key
		var btn: Button = minigame_buttons.get(key)
		if btn == null:
			continue
			
		var is_completed: bool = minigames_status[key]
		var zone_color: Color = _zone_color(mg_info.zone)
		
		var style_normal := StyleBoxFlat.new()
		style_normal.border_width_left = 1
		style_normal.border_width_right = 1
		style_normal.border_width_top = 1
		style_normal.border_width_bottom = 1
		style_normal.corner_radius_top_left = 6
		style_normal.corner_radius_top_right = 6
		style_normal.corner_radius_bottom_left = 6
		style_normal.corner_radius_bottom_right = 6
		
		if is_completed:
			# Glowing completed style (emerald neon theme)
			style_normal.bg_color = Color(0.1, 0.35, 0.18, 0.8) # Rich emerald green
			style_normal.border_color = Color(0.2, 0.9, 0.45, 0.9) # Bright glowing green border
			btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
		else:
			# Sleek inactive style matching the era's theme but dimmed
			style_normal.bg_color = Color(0.09, 0.09, 0.11, 0.6)
			style_normal.border_color = Color(zone_color.r * 0.35, zone_color.g * 0.35, zone_color.b * 0.35, 0.4)
			btn.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
			
		# Hover style
		var style_hover := style_normal.duplicate() as StyleBoxFlat
		if is_completed:
			style_hover.bg_color = Color(0.12, 0.42, 0.22, 0.9)
			style_hover.border_color = Color(0.3, 1.0, 0.55, 1.0)
		else:
			style_hover.bg_color = Color(0.14, 0.14, 0.18, 0.8)
			style_hover.border_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.8)
			
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)
		
		# Avoid firing triggers recursively when setting programmatically
		btn.set_block_signals(true)
		btn.button_pressed = is_completed
		btn.set_block_signals(false)


func _on_minigame_toggled(toggled_on: bool, key: String) -> void:
	minigames_status[key] = toggled_on
	print("[WarpSystem] Minigame %s toggled: %s" % [key, toggled_on])
	
	# Apply immediately to DialogueSystem.game_state if loaded
	_apply_single_override_to_dialogue_system(key, toggled_on)
	
	# Apply active scene reactions
	_apply_active_scene_reactions(key, toggled_on)
	
	# Refresh UI display of all buttons to show correct status styling
	_update_minigame_button_styles()


func _apply_single_override_to_dialogue_system(key: String, toggled_on: bool) -> void:
	match key:
		"crochetage":
			_set_step_state("quete_evasion", "etape_crocheter", toggled_on)
		"marchandage":
			_set_step_state("quete_deguisement", "etape_parler_marchand", toggled_on)
			_set_step_state("quete_deguisement", "etape_marchander", toggled_on)
		"ecoute_tables":
			_set_step_state("quete_piste_assassin", "etape_enqueter_foret", toggled_on)
		"combat_assassin":
			_set_step_state("quete_piste_assassin", "etape_enqueter_foret", toggled_on)
			_set_step_state("quete_piste_assassin", "etape_trouver_assassin", toggled_on)
		"infiltration":
			_set_step_state("quete_acces_centrale", "etape_parler_gardien", toggled_on)
			_set_step_state("quete_acces_centrale", "etape_chercher_carte", toggled_on)
		"tuyaux":
			_set_step_state("quete_preparation", "etape_parler_secretaire", toggled_on)
			_set_step_state("quete_preparation", "etape_aller_vestiaires", toggled_on)
			_set_step_state("quete_preparation", "etape_reparer_machines", toggled_on)
		"cablage":
			_set_step_state("quete_preparation", "etape_parler_secretaire", toggled_on)
			_set_step_state("quete_preparation", "etape_aller_vestiaires", toggled_on)
			_set_step_state("quete_preparation", "etape_reparer_machines", toggled_on)
			_set_step_state("quete_preparation", "etape_reparer_electricite", toggled_on)


func _set_step_state(quest_id: String, step_id: String, completed: bool) -> void:
	var qs = DialogueSystem.game_state.get(quest_id)
	if qs == null:
		return
	var completed_list: Array = qs.get("completed_steps", [])
	if completed:
		if step_id not in completed_list:
			completed_list.append(step_id)
	else:
		if step_id in completed_list:
			completed_list.erase(step_id)
	
	qs["completed_steps"] = completed_list
	
	var quest = DialogueSystem._find_quest(quest_id)
	var next_step = ""
	if not quest.is_empty():
		for s in quest.get("steps", []):
			if s.get("id", "") not in completed_list:
				next_step = s.get("id", "")
				break
	qs["current_step"] = next_step
	if next_step == "":
		qs["status"] = "done"
	else:
		qs["status"] = "active"
		
	DialogueSystem.quest_updated.emit(quest_id, qs["status"], next_step)


func _apply_active_scene_reactions(key: String, toggled_on: bool) -> void:
	var main = get_tree().current_scene
	if main == null or not main.has_method("warp_to_era"):
		return
	var current_zone = main.get("current_zone")

	# --- Moyen Âge ---
	if current_zone == "moyenage":
		var moyenage = main.get_node_or_null("MoyenAge")
		if moyenage and moyenage.get("started") == true:
			match key:
				"crochetage":
					if toggled_on:
						moyenage._on_minigame_success()
				"marchandage":
					if toggled_on:
						moyenage._on_shop_minigame_success()
						var shop = moyenage.get_node_or_null("magasin_moyen_age")
						if shop:
							shop.disguise_obtained = true
						TimeAunoteScript.disguised = true
						var player = moyenage.find_child("TimeAunote", true, false)
						if player and player.has_method("apply_disguise"):
							player.apply_disguise()
					else:
						var shop = moyenage.get_node_or_null("magasin_moyen_age")
						if shop:
							shop.disguise_obtained = false
						TimeAunoteScript.disguised = false
						var player = moyenage.find_child("TimeAunote", true, false)
						if player and player.has_method("remove_disguise"):
							player.remove_disguise()
				"ecoute_tables":
					if toggled_on:
						moyenage._on_auberge_all_tables_done()
				"combat_assassin":
					if toggled_on:
						var campement = moyenage.get_node_or_null("campement")
						if campement and campement.has_method("_victory"):
							campement._victory()

	# --- Present ---
	elif current_zone == "present":
		var present = main.get_node_or_null("Present")
		if present and present.get("started") == true:
			match key:
				"infiltration":
					_set_parking_badge(toggled_on)
					if toggled_on:
						present._on_parking_minigame_won()
				"tuyaux":
					if toggled_on:
						present._on_salle_machine_minigame_done(true)
				"cablage":
					if toggled_on:
						present._on_disjoncteur_minigame_done(true)

	# --- Futur ---
	elif current_zone == "futur":
		var futur = main.get_node_or_null("Futur")
		if futur and futur.get("started") == true:
			match key:
				"conduite":
					if toggled_on:
						futur._on_car_minigame_done(true)
				"lasers":
					if toggled_on:
						futur._on_tourelle_minigame_done(true)
				"boss_rpg":
					if toggled_on:
						futur._on_combat_boss_won()


func _set_parking_badge(done: bool) -> void:
	var main = get_tree().current_scene
	if main == null or not main.has_method("warp_to_era"):
		return
	if main.get("current_zone") != "present":
		return
	var present = main.get_node_or_null("Present")
	if not present or present.get("started") != true:
		return
	var parking = present.get_node_or_null("Parking")
	if parking:
		parking._badge_obtained = done
	var pnj = present.get_node_or_null("PnjSecurité")
	if pnj:
		pnj.npc_id = "npc_securite_present_retour" if done else "npc_securite_present"
	print("[WarpSystem] Badge %s" % ("FAIT" if done else "PAS FAIT"))


func _on_quest_clicked(quest_id: String) -> void:
	var qs = DialogueSystem.game_state.get(quest_id)
	var current_status := "not_started"
	if qs is Dictionary:
		current_status = qs.get("status", "not_started")

	print("[WarpSystem] Quest clicked: %s (current status: %s)" % [quest_id, current_status])

	if current_status == "done":
		DialogueSystem.reset_quest(quest_id)
		_apply_quest_reversal_reactions(quest_id)
	else:
		var qs_dict = DialogueSystem.game_state.get(quest_id)
		if qs_dict is Dictionary:
			var quest = DialogueSystem._find_quest(quest_id)
			var completed_list: Array = qs_dict.get("completed_steps", [])
			if not quest.is_empty():
				for s in quest.get("steps", []):
					var step_id: String = s.get("id", "")
					if step_id not in completed_list:
						completed_list.append(step_id)
			qs_dict["completed_steps"] = completed_list
			qs_dict["status"] = "done"
			qs_dict["current_step"] = ""
			DialogueSystem.quest_updated.emit(quest_id, "done", "")
		_apply_quest_validation_reactions(quest_id)

	# Synchronize state and styles
	update_minigames_status_from_game()
	_update_minigame_button_styles()
	update_quests_status_from_game()


func _apply_quest_validation_reactions(quest_id: String) -> void:
	match quest_id:
		"quete_evasion":
			_apply_active_scene_reactions("crochetage", true)
		"quete_deguisement":
			_apply_active_scene_reactions("marchandage", true)
		"quete_piste_assassin":
			_apply_active_scene_reactions("ecoute_tables", true)
			_apply_active_scene_reactions("combat_assassin", true)
		"quete_acces_centrale":
			_apply_active_scene_reactions("infiltration", true)
		"quete_preparation":
			_apply_active_scene_reactions("tuyaux", true)
			_apply_active_scene_reactions("cablage", true)


func _apply_quest_reversal_reactions(quest_id: String) -> void:
	var main = get_tree().current_scene
	if main == null or not main.has_method("warp_to_era"):
		return
	var current_zone = main.get("current_zone")

	match quest_id:
		"quete_evasion":
			_apply_active_scene_reactions("crochetage", false)
		"quete_deguisement":
			_apply_active_scene_reactions("marchandage", false)
		"quete_piste_assassin":
			_apply_active_scene_reactions("ecoute_tables", false)
			_apply_active_scene_reactions("combat_assassin", false)
		"quete_acces_centrale":
			_apply_active_scene_reactions("infiltration", false)
			if current_zone == "present":
				var present = main.get_node_or_null("Present")
				if present and present.get("started") == true:
					present._parking_unlocked = false
		"quete_preparation":
			_apply_active_scene_reactions("tuyaux", false)
			_apply_active_scene_reactions("cablage", false)
			if current_zone == "present":
				var present = main.get_node_or_null("Present")
				if present and present.get("started") == true:
					present._salle_machine_done = false
					present._disjoncteur_done = false
					present._player_has_changed_once = false
					present._show_darkness_overlay() # Restore darkness overlay since breaker is reset
					present._update_secretaire_npc_id()
					present._update_pc_controle_state()


func update_quests_status_from_game() -> void:
	for quest in quests_list:
		var qid: String = quest.id
		var btn: Button = quest_buttons.get(qid)
		if btn == null:
			continue

		var qs = DialogueSystem.game_state.get(qid)
		var status := "not_started"
		if qs is Dictionary:
			status = qs.get("status", "not_started")

		var zone_color: Color = _zone_color(quest.zone)
		var style_normal := StyleBoxFlat.new()
		style_normal.border_width_left = 1
		style_normal.border_width_right = 1
		style_normal.border_width_top = 1
		style_normal.border_width_bottom = 1
		style_normal.corner_radius_top_left = 6
		style_normal.corner_radius_top_right = 6
		style_normal.corner_radius_bottom_left = 6
		style_normal.corner_radius_bottom_right = 6

		if status == "done":
			# Glowing completed style (emerald neon theme)
			style_normal.bg_color = Color(0.1, 0.35, 0.18, 0.8) # Rich emerald green
			style_normal.border_color = Color(0.2, 0.9, 0.45, 0.9) # Bright glowing green border
			btn.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
			btn.text = quest.name + " [FAIT]"
		elif status == "active":
			# Active quest style (warm amber theme)
			style_normal.bg_color = Color(0.35, 0.22, 0.1, 0.7) # Warm amber/brown
			style_normal.border_color = Color(1.0, 0.65, 0.2, 0.9) # Glowing orange border
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
			btn.text = quest.name + " [EN COURS]"
		else:
			# Dimmed/inactive style matching the era's color slightly
			style_normal.bg_color = Color(0.09, 0.09, 0.11, 0.6)
			style_normal.border_color = Color(zone_color.r * 0.35, zone_color.g * 0.35, zone_color.b * 0.35, 0.4)
			btn.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
			btn.text = quest.name + " [NON COMMENCÉ]"

		var style_hover := style_normal.duplicate() as StyleBoxFlat
		if status == "done":
			style_hover.bg_color = Color(0.12, 0.42, 0.22, 0.9)
			style_hover.border_color = Color(0.3, 1.0, 0.55, 1.0)
		elif status == "active":
			style_hover.bg_color = Color(0.42, 0.27, 0.12, 0.85)
			style_hover.border_color = Color(1.0, 0.75, 0.3, 1.0)
		else:
			style_hover.bg_color = Color(0.14, 0.14, 0.18, 0.8)
			style_hover.border_color = Color(zone_color.r, zone_color.g, zone_color.b, 0.8)

		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_normal)


func _do_warp(zone: String, spawn_id: String) -> void:
	var main = get_tree().current_scene
	if not main or not main.has_method("warp_to_era"):
		return

	main.warp_to_era(zone, spawn_id)
