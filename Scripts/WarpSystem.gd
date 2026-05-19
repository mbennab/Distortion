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
	"present_entree":	{"zone": "present", "name": "Present — Entrée", "id": "entree"},
	"futur_entree":		{"zone": "futur", "name": "Futur — Entrée", "id": "entree"},
	"futur_soussol":	{"zone": "futur", "name": "Futur — Sous-sol", "id": "soussol"},
	"futur_superette":	{"zone": "futur", "name": "Futur — Supérette", "id": "superette"},
	"futur_metro":		{"zone": "futur", "name": "Futur — Métro (QG Alfredo)", "id": "metro"},
	"futur_tour":		{"zone": "futur", "name": "Futur — Tour Alfredo", "id": "tour"},
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

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	container.add_child(bg)

	var title := Label.new()
	title.text = "Warp System"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.anchor_right = 1.0
	title.offset_top = 20
	title.offset_bottom = 60
	container.add_child(title)

	var hint := Label.new()
	hint.text = "F2 pour fermer  •  Cliquez une destination pour vous y téléporter"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.anchor_right = 1.0
	hint.offset_top = 55
	hint.offset_bottom = 75
	container.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 100
	scroll.offset_top = 90
	scroll.offset_right = -100
	scroll.offset_bottom = -100
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# --- Debug: Disguise toggle ---
	var debug_bar := HBoxContainer.new()
	debug_bar.anchor_right = 1.0
	debug_bar.anchor_top = 1.0
	debug_bar.anchor_bottom = 1.0
	debug_bar.offset_top = -80
	debug_bar.offset_bottom = -10
	debug_bar.offset_left = 100
	debug_bar.offset_right = -100
	debug_bar.add_theme_constant_override("separation", 12)
	debug_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(debug_bar)

	var disguise_btn := Button.new()
	disguise_btn.text = "👗 Se déguiser"
	disguise_btn.custom_minimum_size = Vector2(220, 36)
	disguise_btn.pressed.connect(_on_disguise)
	_add_btn_style(disguise_btn, Color(0.2, 0.5, 0.2))
	debug_bar.add_child(disguise_btn)

	var undisguise_btn := Button.new()
	undisguise_btn.text = "👤 Enlever déguisement"
	undisguise_btn.custom_minimum_size = Vector2(220, 36)
	undisguise_btn.pressed.connect(_on_undisguise)
	_add_btn_style(undisguise_btn, Color(0.5, 0.2, 0.2))
	debug_bar.add_child(undisguise_btn)

	for zone in zone_order:
		var zone_dests := []
		for key in destinations:
			if destinations[key].zone == zone:
				zone_dests.append(key)
		if zone_dests.is_empty():
			continue

		var section := Label.new()
		section.text = zone_labels.get(zone, zone)
		section.add_theme_font_size_override("font_size", 18)
		section.add_theme_color_override("font_color", _zone_color(zone))
		section.custom_minimum_size = Vector2(0, 32)
		vbox.add_child(section)

		for key in zone_dests:
			var dest := destinations[key] as Dictionary
			var btn := Button.new()
			btn.text = dest.name
			btn.custom_minimum_size = Vector2(0, 36)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var btn_style := StyleBoxFlat.new()
			btn_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
			btn_style.border_color = Color(0.4, 0.4, 0.5)
			btn_style.border_width_top = 1
			btn_style.border_width_bottom = 1
			btn_style.corner_radius_top_left = 4
			btn_style.corner_radius_top_right = 4
			btn_style.corner_radius_bottom_left = 4
			btn_style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", btn_style)
			btn.add_theme_stylebox_override("hover", btn_style)
			btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
			btn.pressed.connect(_on_warp.bind(key))
			vbox.add_child(btn)
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
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.8)
	s.border_color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.8)
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left = 4
	s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4
	s.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))


func _on_disguise() -> void:
	TimeAunoteScript.disguised = true
	var player = get_tree().current_scene.find_child("TimeAunote", true)
	if player:
		player.apply_disguise()


func _on_undisguise() -> void:
	TimeAunoteScript.disguised = false
	var player = get_tree().current_scene.find_child("TimeAunote", true)
	if player:
		player.remove_disguise()


func _do_warp(zone: String, spawn_id: String) -> void:
	var main = get_tree().current_scene
	if not main or not main.has_method("warp_to_era"):
		return

	main.warp_to_era(zone, spawn_id)
