extends CanvasLayer

var hub: Node
var _active_instance: Node = null
var _active_bg: Node = null
var _active_music: AudioStreamPlayer = null
var _is_open := false
var _menu_visible := false
var _ecoute_round := 1
var _laser_player: CharacterBody2D = null
var _buttons: Array[Button] = []
var _menu_root: Control

class MiniGameData:
	var name: String
	var path: String
	var location: String
	var is_scene: bool
	var has_start: bool
	var sig: String
	var dual: bool
	var child_mg: String
	var music: String
	var color: Color

	func _init(n: String, p: String, loc: String, s: bool, h: bool, sg: String, d: bool, cm: String, m: String, c: Color):
		name = n
		path = p
		location = loc
		is_scene = s
		has_start = h
		sig = sg
		dual = d
		child_mg = cm
		music = m
		color = c

var _minigames: Array[MiniGameData] = []

func _ready() -> void:
	_minigames.append(MiniGameData.new("Chien",       "res://HUB Central/MiniJeuChien.gd",          "",                                  false, false, "game_finished", false, "", "", Color(0.7, 0.5, 0.3)))
	_minigames.append(MiniGameData.new("Crochetage",  "res://Scripts/MiniJeuCrochetage.tscn",       "res://MoyenAge/prison_moyen_age.tscn", true,  false, "done",          false, "", "res://audio/moyen_age/minijeu_crochetage/stealth_tension.mp3", Color(0.8, 0.4, 0.2)))
	_minigames.append(MiniGameData.new("Marchandage", "res://Scripts/MiniJeuMarchandage.tscn",      "res://MoyenAge/magasin_moyen_age.tscn",true,  false, "done",          false, "", "res://audio/moyen_age/minijeu_marchandage/market_game.mp3", Color(0.9, 0.7, 0.2)))
	_minigames.append(MiniGameData.new("Écoute",      "res://Scripts/MiniJeuEcouteTables.tscn",     "res://MoyenAge/auberge.tscn",           true,  false, "done",          false, "", "", Color(0.3, 0.6, 0.8)))
	_minigames.append(MiniGameData.new("Soleil",      "res://Scripts/MiniJeuSoleil.tscn",           "res://Present/parking.tscn",            true,  false, "done",          false, "", "res://audio/present/minijeu_soleil/soleil.mp3", Color(0.9, 0.5, 0.1)))
	_minigames.append(MiniGameData.new("Tuyaux",      "res://Scripts/MiniJeuTuyau.tscn",            "res://Present/salleMachine.tscn",       true,  false, "done",          false, "", "res://audio/present/minijeu_tuyau/tuyau.mp3", Color(0.2, 0.7, 0.4)))
	_minigames.append(MiniGameData.new("Câblage",     "res://Scripts/MiniJeuCablage.tscn",          "res://Present/salleElectricite.tscn",   true,  false, "done",          false, "", "res://audio/present/minijeu_cablage/cablage.mp3", Color(0.6, 0.3, 0.9)))
	_minigames.append(MiniGameData.new("Hacking",     "res://Scripts/MiniJeuHacking.gd",            "res://Present/vestiaire.tscn",          false, false, "done",          false, "", "res://audio/present/minijeu_hacking/hacking.mp3", Color(0.0, 0.8, 0.8)))
	_minigames.append(MiniGameData.new("Conduite",    "res://Futur/route.tscn",                     "",                                  true,  true,  "finished",      false, "", "res://audio/futur/minijeu_car/chase.mp3", Color(0.1, 0.5, 0.9)))
	_minigames.append(MiniGameData.new("Lasers",      "res://Futur/fond_superette.tscn",            "",                                  true,  true,  "finished",      false, "MiniJeuTourelles", "res://audio/futur/superette/nightclub.mp3", Color(0.5, 0.9, 0.2)))
	_minigames.append(MiniGameData.new("Boss",        "res://Futur/combat_boss_futur.tscn",         "",                                  true,  false, "battle_won",    true,  "", "", Color(0.9, 0.1, 0.1)))

	_build_ui()
	hide()

func _build_ui() -> void:
	_menu_root = Control.new()
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	_menu_root.add_child(overlay)
	_resize_overlay(overlay)

	var title := Label.new()
	title.text = "ARCADE — Parties Rapides"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	title.position = Vector2(0, 30)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_menu_root.add_child(title)
	await get_tree().process_frame
	title.position = Vector2((get_viewport().get_visible_rect().size.x - title.size.x) / 2.0, 30)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(0, 80)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	_menu_root.add_child(grid)

	for i in _minigames.size():
		var data: MiniGameData = _minigames[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 115)
		btn.toggle_mode = false
		btn.connect("pressed", Callable(self, "_on_minigame_selected").bind(i))
		grid.add_child(btn)
		_buttons.append(btn)

	var esc_hint := Label.new()
	esc_hint.text = "ESC pour fermer"
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	esc_hint.add_theme_font_size_override("font_size", 16)
	esc_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_menu_root.add_child(esc_hint)

	await get_tree().process_frame
	var vp = get_viewport().get_visible_rect().size
	var grid_size := grid.get_minimum_size()
	grid.position = Vector2(maxf(0, (vp.x - grid_size.x) / 2.0), 80)
	esc_hint.position = Vector2(maxf(0, (vp.x - esc_hint.size.x) / 2.0), vp.y - 60)

	for i in _minigames.size():
		_draw_button_content(_buttons[i], _minigames[i])

func _resize_overlay(r: ColorRect) -> void:
	r.set_deferred("size", get_viewport().get_visible_rect().size)

func _draw_button_content(btn: Button, data: MiniGameData) -> void:
	var bw := 150.0
	var icon_rect := ColorRect.new()
	icon_rect.color = data.color
	icon_rect.size = Vector2(110, 60)
	icon_rect.position = Vector2((bw - 110) / 2.0, 8)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon_rect)

	var label := Label.new()
	label.text = data.name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(140, 32)
	label.position = Vector2((bw - 140) / 2.0, 72)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)

	var abbrev := Label.new()
	abbrev.text = _abbreviation(data.name)
	abbrev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbrev.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	abbrev.add_theme_font_size_override("font_size", 22)
	abbrev.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	abbrev.position = Vector2(0, 8)
	abbrev.size = Vector2(110, 60)
	abbrev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.add_child(abbrev)

func _abbreviation(name: String) -> String:
	match name:
		"Chien": return "CH"
		"Crochetage": return "CR"
		"Marchandage": return "MA"
		"Écoute": return "EC"
		"Soleil": return "SO"
		"Tuyaux": return "TU"
		"Câblage": return "CA"
		"Hacking": return "HA"
		"Conduite": return "CO"
		"Lasers": return "LA"
		"Boss": return "BO"
	return name.left(2).to_upper()

func open() -> void:
	_is_open = true
	_menu_visible = true
	show()
	_resize_overlay(_menu_root.get_child(0))

func close() -> void:
	_is_open = false
	_menu_visible = false
	_stop_music()
	_cleanup_active()
	hide()
	if hub and not hub.is_queued_for_deletion() and hub.has_method("_on_arcade_menu_closed"):
		hub.call("_on_arcade_menu_closed")

func _play_music(path: String) -> void:
	if path.is_empty():
		return
	_stop_music()
	var stream := load(path) as AudioStream
	if not stream:
		return
	_active_music = AudioStreamPlayer.new()
	_active_music.stream = stream
	_active_music.bus = "Master"
	_active_music.volume_db = -10.0
	add_child(_active_music)
	_active_music.play()

func _stop_music() -> void:
	if _active_music and is_instance_valid(_active_music):
		_active_music.stop()
		if not _active_music.is_queued_for_deletion():
			_active_music.queue_free()
	_active_music = null

func _cleanup_active() -> void:
	_laser_player = null
	if _active_bg and is_instance_valid(_active_bg):
		if not _active_bg.is_queued_for_deletion():
			_active_bg.queue_free()
	_active_bg = null
	if _active_instance and is_instance_valid(_active_instance):
		if _active_instance.has_method("stop_game"):
			_active_instance.call("stop_game")
		if not _active_instance.is_queued_for_deletion():
			_active_instance.queue_free()
	_active_instance = null

func _setup_laser_player(parent: Node) -> void:
	var p := CharacterBody2D.new()
	p.name = "TimeAunote"
	p.collision_layer = 1
	p.collision_mask = 0
	p.z_index = 10
	var shape := CollisionShape2D.new()
	shape.shape = CapsuleShape2D.new()
	shape.shape.radius = 20.0
	shape.shape.height = 40.0
	p.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = _create_player_dot_texture()
	sprite.centered = true
	sprite.scale = Vector2(0.5, 0.5)
	p.add_child(sprite)
	p.position = Vector2(1200, 600)
	parent.add_child(p)
	_laser_player = p

func _create_player_dot_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x, y).distance_to(Vector2(16, 16))
			if d < 14.0:
				img.set_pixel(x, y, Color(0.3, 0.8, 1.0, 1.0))
			elif d < 16.0:
				img.set_pixel(x, y, Color(0.2, 0.6, 0.9, 0.5))
	return ImageTexture.create_from_image(img)

func _handle_laser_movement(delta: float) -> void:
	if not _laser_player or not is_instance_valid(_laser_player):
		return
	var speed := 400.0
	var vel := Vector2.ZERO
	if Input.is_action_pressed("marche_haut"):
		vel.y -= 1
	if Input.is_action_pressed("marche_bas"):
		vel.y += 1
	if Input.is_action_pressed("marche_droite"):
		vel.x += 1
	if Input.is_action_pressed("marche_gauche"):
		vel.x -= 1
	_laser_player.move_and_collide(vel.normalized() * speed * delta)

func _on_minigame_selected(idx: int) -> void:
	if _active_instance:
		return
	var data: MiniGameData = _minigames[idx]
	_menu_visible = false
	hide()
	_ecoute_round = 1

	if data.name == "Chien":
		var chien_mg := hub.get_node("MiniJeuChien")
		if chien_mg and not chien_mg.is_queued_for_deletion() and chien_mg.has_method("open_game"):
			if chien_mg.game_finished.is_connected(_on_chien_done):
				chien_mg.game_finished.disconnect(_on_chien_done)
			chien_mg.game_finished.connect(_on_chien_done)
			chien_mg.call("open_game")
		else:
			_menu_visible = true
			show()
		return

	_play_music(data.music)

	var has_backdrop := not data.location.is_empty()
	if has_backdrop:
		var bg_scene := load(data.location).instantiate() as Node2D
		bg_scene.process_mode = PROCESS_MODE_DISABLED
		get_tree().root.add_child(bg_scene)
		_active_bg = bg_scene

	var use_full_scene := data.location.is_empty() and data.name != "Chien"
	if use_full_scene:
		var full := load(data.path).instantiate() as Node2D
		get_tree().root.add_child(full)
		_active_instance = full

		if data.name == "Conduite":
			full.position = Vector2(-320, -160)
			var target := full
			if not data.child_mg.is_empty():
				target = full.get_node(data.child_mg)
			if target:
				if target.has_signal(data.sig):
					target.connect(data.sig, Callable(self, "_on_minigame_done"))
				if data.has_start and target.has_method("start_game"):
					target.call("start_game")
			return

		if data.name == "Lasers":
			_setup_laser_player(full)

		var target := full
		if not data.child_mg.is_empty():
			target = full.get_node(data.child_mg)

		if target:
			if data.dual:
				if target.has_signal("battle_lost"):
					target.battle_lost.connect(_on_minigame_done)
				if target.has_signal("battle_won"):
					target.battle_won.connect(_on_minigame_done)
			elif target.has_signal(data.sig):
				target.connect(data.sig, Callable(self, "_on_minigame_done"))

			if data.has_start and target.has_method("start_game"):
				target.call("start_game")
	else:
		var instance: Node
		if data.is_scene:
			instance = load(data.path).instantiate()
		else:
			instance = load(data.path).new()

		if data.name == "Écoute" and instance.has_method("has_signal"):
			instance.set("round", _ecoute_round)

		get_tree().root.add_child(instance)
		_active_instance = instance

		if data.dual:
			if instance.has_signal("battle_lost"):
				instance.battle_lost.connect(_on_minigame_done)
			if instance.has_signal("battle_won"):
				instance.battle_won.connect(_on_minigame_done)
		elif instance.has_signal(data.sig):
			instance.connect(data.sig, Callable(self, "_on_minigame_done").bind(idx))

		if data.has_start and instance.has_method("start_game"):
			instance.call("start_game")

func _on_chien_done() -> void:
	var chien_mg := hub.get_node("MiniJeuChien")
	if chien_mg and not chien_mg.is_queued_for_deletion() and chien_mg.game_finished.is_connected(_on_chien_done):
		chien_mg.game_finished.disconnect(_on_chien_done)
	_menu_visible = true
	show()

func _cleanup_instance_only() -> void:
	if _active_instance and is_instance_valid(_active_instance):
		if _active_instance.has_method("stop_game"):
			_active_instance.call("stop_game")
		if not _active_instance.is_queued_for_deletion():
			_active_instance.queue_free()
	_active_instance = null

func _on_minigame_done(success := true, idx := -1) -> void:
	if not _is_open:
		return
	if idx >= 0 and _minigames[idx].name == "Écoute":
		if success and _ecoute_round < 3:
			_ecoute_round += 1
			var data := _minigames[idx]
			_cleanup_instance_only()
			var instance := load(data.path).instantiate()
			instance.set("round", _ecoute_round)
			instance.done.connect(_on_ecoute_round_done.bind(instance))
			get_tree().root.add_child(instance)
			_active_instance = instance
			return
		_ecoute_round = 1

	_stop_music()
	_cleanup_active()
	_menu_visible = true
	show()

func _on_ecoute_round_done(success: bool, instance: Node) -> void:
	if is_instance_valid(instance):
		instance.queue_free()
	_active_instance = null
	if success and _ecoute_round < 3:
		_ecoute_round += 1
		var data := _find_ecoute_data()
		if data != null:
			var new_instance := load(data.path).instantiate()
			new_instance.set("round", _ecoute_round)
			new_instance.done.connect(_on_ecoute_round_done.bind(new_instance))
			get_tree().root.add_child(new_instance)
			_active_instance = new_instance
			return
	_stop_music()
	_cleanup_active()
	_menu_visible = true
	show()

func _find_ecoute_data() -> MiniGameData:
	for d in _minigames:
		if d.name == "Écoute":
			return d
	return null

func _process(delta: float) -> void:
	if _is_open and _laser_player and is_instance_valid(_laser_player):
		_handle_laser_movement(delta)

func _input(event: InputEvent) -> void:
	if not _menu_visible:
		return
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_stop_music()
		_cleanup_active()
