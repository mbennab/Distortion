extends CanvasLayer

signal done(success: bool)

# ── Difficulté par round (8 lancers) ─────────────────────────────────────────
const TOTAL_ROUNDS   := 8
const GOOD_ROUNDS    := 5   # items à attraper
const DECOY_ROUNDS   := 3   # items à esquiver
const WIN_CATCHES    := 4   # bonnes prises minimum
const WIN_MAX_DECOYS := 1   # décoys rattrapés maximum pour gagner
const PLAYER_SPEED   := 720.0

# Paramètres par round : [durée_chute, rayon_attrap, durée_anticip]
# Calibré pour que le joueur puisse TOUJOURS atteindre la zone depuis le centre
# en moins de (durée_chute) secondes à 720px/s
const ROUND_PARAMS := [
	[2.00, 60.0, 0.50],
	[1.75, 60.0, 0.44],
	[1.50, 65.0, 0.38],
	[1.28, 65.0, 0.33],
	[1.08, 70.0, 0.28],
	[0.90, 70.0, 0.24],
	[0.75, 75.0, 0.20],
	[0.62, 75.0, 0.16],
]

# ── State ─────────────────────────────────────────────────────────────────────
var _round         := 0
var _global_t      := 0.0
var _good_catches  := 0
var _decoy_caught  := 0
var _combo         := 0
var _game_over     := false

# Résultats par round : 1=bonne prise, 0=raté bon, -1=décoy rattrapé, 2=décoy esquivé
var _results: Array[int] = []

# Round courant
var _cur_is_decoy  := false
var _cur_name      := ""
var _cur_color     := Color.WHITE
var _anticipating  := false
var _anticip_timer := 0.0
var _falling       := false
var _fall_elapsed  := 0.0
var _fall_x_start  := 0.0
var _fall_x_land   := 0.0
var _fall_radius   := 60.0
var _fall_duration := 2.0
var _item_spin     := 0.0
var _arc_height    := 220.0  # hauteur de l'arc, varie par round
var _wobble_seed   := 0.0    # phase du sinus de déviation
var _item_visual_x := 0.0    # X réel avec déviation (pour catch detection)
var _merch_x       := 90.0   # position X du marchand, change entre rounds

# Player
var _player_x      := 0.0
var _player_walk_t := 0.0
var _player_moving := false

# FX
var _shake         := 0.0
var _pulse_t       := 0.0
var _catch_flash_t := 0.0
var _warn_flash_t  := 0.0   # flash rouge sur décoy raté
var _fb_timer      := 0.0
var _fb_text       := ""
var _fb_ok         := true
var _dust: Array[Dictionary] = []

# ── Textures ──────────────────────────────────────────────────────────────────
var _tex_idle:   Texture2D
var _tex_walk1:  Texture2D
var _tex_walk2:  Texture2D
var _tex_merch:  Texture2D

# ── Nodes ─────────────────────────────────────────────────────────────────────
var _bg:           ColorRect
var _draw_node:    Node2D
var _player_spr:   Sprite2D
var _merch_spr:    Sprite2D
var _title_lbl:    Label
var _hint_lbl:     Label
var _fb_lbl:       Label
var _round_lbl:    Label
var _warn_lbl:     Label
var _obj_lbl:      Label   # barre d'objectifs persistante

# ── BGM ────────────────────────────────────────────────────────────────────────
var _bgm_player: AudioStreamPlayer

# ── SFX ────────────────────────────────────────────────────────────────────────
var _audio_catch: Array[AudioStream] = []
var _audio_decoy: Array[AudioStream] = []
var _audio_miss: Array[AudioStream] = []

# ── Pools d'items ─────────────────────────────────────────────────────────────
var _good_pool := [
	{"name": "Tunique en lin",    "col": Color(0.45, 0.50, 0.65)},
	{"name": "Cape en laine",     "col": Color(0.52, 0.33, 0.22)},
	{"name": "Coiffe de voyage",  "col": Color(0.48, 0.44, 0.32)},
	{"name": "Manteau de voyage", "col": Color(0.38, 0.50, 0.36)},
	{"name": "Cape de rôdeur",    "col": Color(0.33, 0.28, 0.42)},
	{"name": "Tunique de paysan", "col": Color(0.55, 0.42, 0.26)},
]
var _decoy_pool := [
	{"name": "⚠ Hardes pourries !", "col": Color(0.75, 0.15, 0.10)},
	{"name": "⚠ Fausse étoffe !",   "col": Color(0.80, 0.18, 0.12)},
	{"name": "⚠ Piège du marchand !","col": Color(0.70, 0.12, 0.08)},
]

var _item_sequence: Array[Dictionary] = []


# =============================================================================
# INIT
# =============================================================================

func _ready() -> void:
	randomize()
	_load_textures()
	_build_ui()
	_setup_bgm()
	_load_sfx()
	_build_sequence()
	_show_intro()


func _show_intro() -> void:
	_title_lbl.text = "Le Marchandage des Habits"
	_round_lbl.text = "Le marchand vous lance ses affaires — soyez prêt !"
	_round_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.58))
	_hint_lbl.text  = (
		"Objectif : attraper %d vêtements sur %d\n"
		+ "Esquivez les %d pièges (items rouges ⚠)\n"
		+ "← → pour vous déplacer"
	) % [WIN_CATCHES, GOOD_ROUNDS, DECOY_ROUNDS]
	_hint_lbl.add_theme_font_size_override("font_size", 15)
	_obj_lbl.text = ""
	await get_tree().create_timer(3.0).timeout
	_hint_lbl.text = "← → pour vous déplacer"
	_hint_lbl.add_theme_font_size_override("font_size", 16)
	_round_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	_enter_round()


func _load_textures() -> void:
	_tex_idle  = load("res://art/perso_idle_face.png")
	_tex_walk1 = load("res://art/perso_marche_face1.png")
	_tex_walk2 = load("res://art/perso_marche_face2.png")
	_tex_merch = load("res://art/MoyenAge/marchand.png")


func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -14.0
	var dir := DirAccess.open("res://audio/moyen_age/minijeu_marchandage/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
				_bgm_player.stream = load("res://audio/moyen_age/minijeu_marchandage/" + file_name)
				if _bgm_player.stream:
					break
			file_name = dir.get_next()
		dir.list_dir_end()
	add_child(_bgm_player)
	if _bgm_player.stream:
		_bgm_player.play()


func _scan_sfx_dir(dir_path: String) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return streams
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return streams
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext := file_name.get_extension().to_lower()
			if ext in ["mp3", "ogg", "wav"]:
				var full_path := dir_path + "/" + file_name
				var stream: AudioStream
				if ext == "mp3":
					stream = load(full_path) as AudioStreamMP3
				elif ext == "ogg":
					stream = load(full_path) as AudioStreamOggVorbis
				else:
					stream = load(full_path) as AudioStreamWAV
				if stream:
					streams.append(stream)
		file_name = dir.get_next()
	dir.list_dir_end()
	return streams


func _load_sfx() -> void:
	_audio_catch = _scan_sfx_dir("res://audio/marchandage/catch")
	_audio_decoy = _scan_sfx_dir("res://audio/marchandage/decoy")
	_audio_miss = _scan_sfx_dir("res://audio/marchandage/miss")


func _play_sfx(streams: Array[AudioStream], vol_db: float = -6.0) -> void:
	if streams.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = vol_db
	player.stream = streams[randi() % streams.size()]
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	_player_x = vp.x / 2.0

	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.04, 0.02, 0.01, 0.94)
	_bg.size = vp
	add_child(_bg)

	_draw_node = Node2D.new()
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)

	# Merchant sprite (gauche)
	if _tex_merch:
		_merch_spr = Sprite2D.new()
		_merch_spr.texture = _tex_merch
		_merch_spr.hframes = 2
		_merch_spr.frame = 0
		_merch_spr.scale = Vector2(0.28, 0.28)
		_merch_spr.position = Vector2(90, vp.y - 148)
		add_child(_merch_spr)

	# Player sprite
	if _tex_idle:
		_player_spr = Sprite2D.new()
		_player_spr.texture = _tex_idle
		_player_spr.hframes = 2
		_player_spr.frame = 0
		_player_spr.scale = Vector2(0.22, 0.22)
		_player_spr.position = Vector2(_player_x, vp.y - 180)
		add_child(_player_spr)

	# Labels
	_title_lbl = _lbl("Attrapez les vêtements !", 28, Color(1, 0.92, 0.60))
	_title_lbl.position = Vector2(vp.x / 2.0 - 280, 30)
	_title_lbl.size = Vector2(560, 50)
	add_child(_title_lbl)

	_round_lbl = _lbl("", 15, Color(0.45, 0.42, 0.38))
	_round_lbl.position = Vector2(20, 16)
	_round_lbl.size = Vector2(280, 26)
	_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_round_lbl)

	_hint_lbl = _lbl("← → pour vous déplacer", 16, Color(0.70, 0.88, 0.70))
	_hint_lbl.position = Vector2(vp.x / 2.0 - 240, vp.y - 72)
	_hint_lbl.size = Vector2(480, 48)
	add_child(_hint_lbl)

	_fb_lbl = _lbl("", 30, Color.WHITE)
	_fb_lbl.position = Vector2(vp.x / 2.0 - 260, vp.y / 2.0 - 50)
	_fb_lbl.size = Vector2(520, 70)
	add_child(_fb_lbl)

	_warn_lbl = _lbl("", 32, Color(1, 0.15, 0.15))
	_warn_lbl.position = Vector2(vp.x / 2.0 - 260, 86)
	_warn_lbl.size = Vector2(520, 58)
	add_child(_warn_lbl)

	_obj_lbl = _lbl("", 15, Color(0.78, 0.76, 0.62))
	_obj_lbl.position = Vector2(vp.x / 2.0 - 280, 82)
	_obj_lbl.size = Vector2(560, 28)
	add_child(_obj_lbl)


func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _build_sequence() -> void:
	var good := _good_pool.duplicate()
	good.shuffle()
	var decoy := _decoy_pool.duplicate()
	decoy.shuffle()
	_item_sequence.clear()
	for i in GOOD_ROUNDS:
		_item_sequence.append({"name": good[i].name, "col": good[i].col, "decoy": false})
	for i in DECOY_ROUNDS:
		_item_sequence.append({"name": decoy[i].name, "col": decoy[i].col, "decoy": true})
	_item_sequence.shuffle()


# =============================================================================
# ROUND LOGIC
# =============================================================================

func _update_obj_lbl() -> void:
	var needed  := WIN_CATCHES - _good_catches
	var catches_col := Color(0.40, 0.92, 0.40) if needed <= 1 else Color(0.78, 0.76, 0.62)
	var decoys_col  := Color(1, 0.35, 0.25) if _decoy_caught >= WIN_MAX_DECOYS else Color(0.78, 0.76, 0.62)
	# On affiche les deux infos séparément via les deux overrides de couleur impossibles,
	# donc on concatène en texte avec état lisible
	var catches_txt := "%d/%d vêtements" % [_good_catches, WIN_CATCHES]
	var decoys_txt  := "%d/%d piège(s)" % [_decoy_caught, WIN_MAX_DECOYS + 1]
	if _decoy_caught > WIN_MAX_DECOYS:
		_obj_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
	elif needed <= 1 and needed > 0:
		_obj_lbl.add_theme_color_override("font_color", Color(0.40, 0.92, 0.40))
	else:
		_obj_lbl.add_theme_color_override("font_color", Color(0.78, 0.76, 0.62))
	_obj_lbl.text = "🎯 %s  ·  ⚠ %s" % [catches_txt, decoys_txt]


func _enter_round() -> void:
	if _round >= TOTAL_ROUNDS:
		_finish_game()
		return

	var params: Array = ROUND_PARAMS[_round]
	_fall_duration = float(params[0])
	_fall_radius   = float(params[1])
	_anticip_timer = float(params[2])

	var item       := _item_sequence[_round]
	_cur_is_decoy  = item.decoy
	_cur_name      = item.name
	_cur_color     = item.col

	_anticipating  = true
	_falling       = false
	_fall_elapsed  = 0.0
	_item_spin   = randf_range(0.0, TAU)
	_wobble_seed = randf_range(0.0, TAU)

	var vp := get_viewport().get_visible_rect().size
	# Arc max safe : au pic (t=0.5), item_y = (start_y+gnd)/2 - arc_h >= 30
	var start_y  := 80.0
	var gnd_y    := vp.y - 140.0
	var max_arc  := (start_y + gnd_y) / 2.0 - 45.0
	_arc_height  = randf_range(60.0, max_arc)
	var m  := 110.0
	# Le marchand se déplace vers une nouvelle position
	var merch_positions := [80.0, 130.0, vp.x - 130.0, vp.x - 80.0]
	_merch_x       = merch_positions[randi() % merch_positions.size()]
	_fall_x_start  = _merch_x
	_fall_x_land   = randf_range(m, vp.x - m)
	_item_visual_x = _fall_x_start

	if _merch_spr:
		_merch_spr.position.x = _merch_x

	_round_lbl.text = "Lancer %d / %d" % [_round + 1, TOTAL_ROUNDS]
	_update_obj_lbl()

	# Avertissement visuel AVANT la chute si décoy
	if _cur_is_decoy:
		_warn_lbl.text = "⚠  PIÈGE — ESQUIVEZ !"
	else:
		_warn_lbl.text = ""

	_draw_node.queue_redraw()


const _MSG_CATCH  := ["Attrapé !", "Bien joué !", "Dans la poche !", "Parfait !"]
const _MSG_MISS   := ["Raté !", "Trop lent !", "Passé à côté !", "Malheureux !"]
const _MSG_DODGE  := ["Esquivé !", "Bon réflexe !", "Vous l'aviez vu venir !", "Belle esquive !"]
const _MSG_TRAP   := ["Piégé !", "C'était un piège !", "Le marchand ricane...", "Mauvais flair !"]
const _MSG_COMBO  := ["EN FEU !", "Le marchand s'énerve !", "Incroyable !", "Inarrêtable !"]

func _resolve_round(caught: bool) -> void:
	_falling = false
	if _cur_is_decoy:
		if caught:
			_decoy_caught += 1
			_combo        = 0
			_fb_text      = _MSG_TRAP[randi() % _MSG_TRAP.size()]
			_fb_ok        = false
			_fb_timer     = 1.2
			_shake        = 9.0
			_warn_flash_t = 0.65
			_results.append(-1)
			_spawn_dust(_fall_x_land)
			_play_sfx(_audio_decoy, -8.0)
		else:
			_fb_text  = _MSG_DODGE[randi() % _MSG_DODGE.size()]
			_fb_ok    = true
			_fb_timer = 0.9
			_results.append(2)
	else:
		if caught:
			_good_catches += 1
			_combo        += 1
			_catch_flash_t = 0.55
			_play_sfx(_audio_catch, -8.0)
			if _combo >= 3:
				_fb_text = "COMBO x%d — %s" % [_combo, _MSG_COMBO[randi() % _MSG_COMBO.size()]]
			elif _combo == 2:
				_fb_text = "COMBO x2 !"
			else:
				_fb_text = _MSG_CATCH[randi() % _MSG_CATCH.size()]
			_fb_ok    = true
			_fb_timer = 1.0
			_results.append(1)
		else:
			_combo   = 0
			_fb_text = _MSG_MISS[randi() % _MSG_MISS.size()]
			_fb_ok   = false
			_fb_timer = 1.0
			_shake   = 7.0
			_results.append(0)
			_spawn_dust(_fall_x_land)
			_play_sfx(_audio_miss, -8.0)

	_round += 1
	_warn_lbl.text = ""
	_update_obj_lbl()
	await get_tree().create_timer(0.9).timeout
	_fb_text = ""
	_dust.clear()
	_catch_flash_t = 0.0
	_enter_round()


func _spawn_dust(land_x: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	for _k in randi_range(10, 18):
		_dust.append({
			"x":    land_x + randf_range(-50, 50),
			"y":    vp.y - 140.0 + randf_range(-12, 16),
			"vx":   randf_range(-70, 70),
			"vy":   randf_range(-90, -25),
			"life": randf_range(0.5, 1.0),
			"size": randf_range(1.5, 4.0),
		})


func _finish_game() -> void:
	_game_over  = true
	var success := _good_catches >= WIN_CATCHES and _decoy_caught <= WIN_MAX_DECOYS
	_hint_lbl.text = ""
	_warn_lbl.text = ""
	_obj_lbl.text  = ""
	_round_lbl.text = ""

	if success:
		var perfect := _good_catches == GOOD_ROUNDS and _decoy_caught == 0
		if perfect:
			_title_lbl.text = "Impeccable !"
			_fb_lbl.text    = "Le marchand est bouche bée.\nVous repartez avec le meilleur déguisement."
		else:
			_title_lbl.text = "Marché conclu !"
			_fb_lbl.text    = "Le marchand grogne... mais tient sa parole.\n%d vêtements — de quoi se déguiser." % _good_catches
		_title_lbl.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		_fb_lbl.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	else:
		var reason := ""
		if _decoy_caught > WIN_MAX_DECOYS:
			reason = "Vous avez mordu à l'hameçon trop de fois.\n« Dehors ! » crie le marchand."
		else:
			var missing := WIN_CATCHES - _good_catches
			reason = "Il vous manquait %d vêtement%s.\nLe marchand vous chasse de sa boutique." % [missing, "s" if missing > 1 else ""]
		_title_lbl.text = "Le marché est rompu."
		_title_lbl.add_theme_color_override("font_color", Color(1, 0.32, 0.32))
		_fb_lbl.text = reason
		_fb_lbl.add_theme_color_override("font_color", Color(1, 0.58, 0.58))

	_fb_lbl.add_theme_font_size_override("font_size", 18)
	await get_tree().create_timer(3.2).timeout
	done.emit(success)
	queue_free()


# =============================================================================
# PROCESS & INPUT
# =============================================================================

func _process(delta: float) -> void:
	if _game_over:
		return

	_global_t += delta

	# Merchant sprite bob
	if _merch_spr:
		var bob := sin(_global_t * 2.5) * 1.5
		var vp  := get_viewport().get_visible_rect().size
		_merch_spr.position.y = vp.y - 148 + bob
		if _anticipating:
			_merch_spr.rotation = sin(_global_t * 8.0) * 0.06
		else:
			_merch_spr.rotation = lerpf(_merch_spr.rotation, 0.0, delta * 6.0)

	if _fb_timer > 0.0:
		_fb_timer -= delta
		_fb_lbl.text = _fb_text
		if _fb_timer <= 0.0:
			_fb_lbl.text = ""

	if _shake > 0.1:
		_shake = lerpf(_shake, 0.0, delta * 8.0)
	if _catch_flash_t > 0.0:
		_catch_flash_t -= delta
	if _warn_flash_t > 0.0:
		_warn_flash_t -= delta

	for p in _dust:
		p.life -= delta
		p.x    += p.vx * delta
		p.y    += p.vy * delta
		p.vy   += 130.0 * delta
	var di := 0
	while di < _dust.size():
		if _dust[di].life <= 0.0:
			_dust.remove_at(di)
		else:
			di += 1

	_pulse_t += delta * 2.5

	if _anticipating:
		_anticip_timer -= delta
		if _anticip_timer <= 0.0:
			_anticipating = false
			_falling      = true
			_fall_elapsed = 0.0
	elif _falling:
		_fall_elapsed += delta
		_item_spin    += delta * (4.0 + (float(_round) / TOTAL_ROUNDS) * 4.0)

		var vp := get_viewport().get_visible_rect().size
		_player_moving = false
		if Input.is_action_pressed("marche_gauche"):
			_player_x     = maxf(60.0, _player_x - PLAYER_SPEED * delta)
			_player_walk_t += delta * 10.0
			_player_moving = true
		if Input.is_action_pressed("marche_droite"):
			_player_x     = minf(vp.x - 60.0, _player_x + PLAYER_SPEED * delta)
			_player_walk_t += delta * 10.0
			_player_moving = true

		# Update player sprite texture and position
		if _player_spr:
			if _player_moving:
				_player_spr.texture = _tex_walk1 if int(_player_walk_t) % 2 == 0 else _tex_walk2
			else:
				_player_spr.texture = _tex_idle
			var gnd := vp.y - 140.0
			_player_spr.position = Vector2(_player_x, gnd - 40)

		var t := clampf(_fall_elapsed / _fall_duration, 0.0, 1.0)
		# Déviation latérale qui grandit avec le numéro de round
		var wobble_amp := float(_round) / float(TOTAL_ROUNDS - 1) * 62.0
		var wobble := sin(_fall_elapsed * 5.8 + _wobble_seed) * wobble_amp * clampf(t * 2.2, 0.0, 1.0)
		_item_visual_x = lerpf(_fall_x_start, _fall_x_land, t) + wobble
		if t >= 1.0:
			_resolve_round(absf(_item_visual_x - _player_x) <= _fall_radius + 28.0)

	_draw_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event.is_action_pressed("marche_gauche") or event.is_action_pressed("marche_droite"):
		get_viewport().set_input_as_handled()


# =============================================================================
# DRAW
# =============================================================================

func _on_draw() -> void:
	var vp  := get_viewport().get_visible_rect().size
	var gnd := vp.y - 140.0

	_draw_torches(vp)
	_draw_ground(vp, gnd)
	_draw_fx(vp, gnd)
	_draw_catch_zone(vp, gnd)
	_draw_item(vp, gnd)
	_draw_scoreboard(vp)


func _draw_torches(vp: Vector2) -> void:
	_draw_torch(30.0,        vp.y / 2.0 - 60.0, _global_t)
	_draw_torch(vp.x - 30.0, vp.y / 2.0 - 60.0, _global_t + 1.37)


func _draw_torch(x: float, y: float, t: float) -> void:
	_draw_node.draw_rect(Rect2(x - 4, y, 8, 40), Color(0.28, 0.18, 0.09))
	_draw_node.draw_rect(Rect2(x - 7, y - 8, 14, 10), Color(0.38, 0.26, 0.12))
	var fl := sin(t * 7.4) * 0.16 + sin(t * 11.3) * 0.08
	var fh := 20.0 + fl * 5.0
	var fw := 8.0  + fl * 2.5
	_draw_node.draw_circle(Vector2(x, y - 8), fw * 1.6, Color(1, 0.45, 0.0, 0.06))
	for fi in 3:
		var lyr := float(fi) / 3.0
		_draw_node.draw_circle(
			Vector2(x + fl * 2.5, y - 6 - fh * (0.3 + lyr * 0.15)),
			fw * (1.0 - lyr * 0.5),
			Color(1.0 - lyr * 0.3, 0.58 - lyr * 0.38, lyr * 0.12, 0.85 - lyr * 0.3))
	_draw_node.draw_circle(Vector2(x + fl * 3.0, y - 6 - fh * 0.68), 3.0, Color(1, 0.94, 0.68, 0.92))


func _draw_ground(vp: Vector2, gnd: float) -> void:
	var sx := randf_range(-_shake, _shake) if _shake > 0.1 else 0.0
	var sy := randf_range(-_shake * 0.5, _shake * 0.5) if _shake > 0.1 else 0.0
	_draw_node.draw_rect(Rect2(0 + sx, gnd + 26 + sy, vp.x, 4), Color(0.20, 0.11, 0.05))
	_draw_node.draw_line(
		Vector2(50 + sx, gnd + 30 + sy),
		Vector2(vp.x - 50 + sx, gnd + 30 + sy),
		Color(0.12, 0.07, 0.03), 1.5)


func _draw_fx(vp: Vector2, gnd: float) -> void:
	if _catch_flash_t > 0.0:
		_draw_node.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(1, 0.90, 0.28, clampf(_catch_flash_t / 0.55, 0.0, 1.0) * 0.20))
	if _warn_flash_t > 0.0:
		_draw_node.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(1, 0.10, 0.05, clampf(_warn_flash_t / 0.6, 0.0, 1.0) * 0.18))
	for p in _dust:
		var alpha := clampf(p.life / 0.9, 0.0, 1.0)
		_draw_node.draw_circle(Vector2(p.x, p.y), p.size, Color(0.62, 0.45, 0.25, alpha * 0.75))


func _draw_catch_zone(vp: Vector2, gnd: float) -> void:
	if not (_falling or _anticipating):
		return
	# Anneau autour du joueur uniquement — pas d'indicateur d'atterrissage
	var pr     := (_fall_radius + 28.0) + sin(_pulse_t) * 6.0
	var pa     := 0.22 + sin(_pulse_t * 1.5) * 0.13
	var ring_c := Color(0.28, 0.85, 0.28, pa) if not _cur_is_decoy else Color(0.85, 0.28, 0.28, pa)
	_draw_node.draw_arc(Vector2(_player_x, gnd - 40), pr, 0, TAU, 32, ring_c, 2.0, true)


func _draw_item(_vp: Vector2, gnd: float) -> void:
	if not _falling:
		return
	var t    := clampf(_fall_elapsed / _fall_duration, 0.0, 1.0)
	var ix   := _item_visual_x
	var iy   := lerpf(80.0, gnd, t) - _arc_height * sin(t * PI)
	var font := ThemeDB.fallback_font

	# Item rotatif (pas d'ombre au sol pour ne pas trahir la position)
	_draw_rotating_item(ix, iy, _cur_color, _item_spin, _cur_is_decoy)

	# Label nom uniquement en début de chute (disparaît après 40%)
	var name_alpha := clampf(1.0 - (t - 0.0) / 0.40, 0.0, 1.0)
	if name_alpha > 0.0:
		var lbl_col := Color(1, 0.92, 0.5, name_alpha) if not _cur_is_decoy else Color(1, 0.28, 0.22, name_alpha)
		_draw_node.draw_string(font, Vector2(ix - 70, iy - 36), _cur_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, lbl_col)


func _draw_rotating_item(cx: float, cy: float, col: Color, angle: float, is_decoy: bool) -> void:
	var hw := 34.0
	var hh := 17.0
	var pts := [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
	var outer := PackedVector2Array()
	for p in pts:
		outer.append(Vector2(cx + p.x * cos(angle) - p.y * sin(angle), cy + p.x * sin(angle) + p.y * cos(angle)))
	var ipts := [Vector2(-hw + 7, -hh + 5), Vector2(hw - 7, -hh + 5), Vector2(hw - 7, hh - 5), Vector2(-hw + 7, hh - 5)]
	var inner := PackedVector2Array()
	for p in ipts:
		inner.append(Vector2(cx + p.x * cos(angle) - p.y * sin(angle), cy + p.x * sin(angle) + p.y * cos(angle)))
	_draw_node.draw_colored_polygon(outer, col.darkened(0.25))
	_draw_node.draw_colored_polygon(inner, col)
	# Croix rouge sur décoy
	if is_decoy:
		var font := ThemeDB.fallback_font
		_draw_node.draw_string(font, Vector2(cx - 8, cy + 6), "✗", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(1, 0.9, 0.9, 0.9))


func _draw_scoreboard(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font

	# ── Mini cases en haut à droite (bons items seulement) ──
	var sx := vp.x - 180.0
	var sy := 20.0
	_draw_node.draw_string(font, Vector2(sx, sy), "Vêtements :", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.65, 0.55))

	# Dessine d'abord les cases vides pour tous les bons items
	for gi in GOOD_ROUNDS:
		_draw_node.draw_rect(Rect2(sx + gi * 28.0, sy + 16, 22, 14), Color(0.15, 0.15, 0.12))

	# Remplit les cases selon résultats (itère uniquement les items non-décoy)
	var gi := 0
	for i in _results.size():
		if _item_sequence[i].decoy:
			continue
		var bx := sx + gi * 28.0
		var r  := _results[i]
		if r == 1:
			_draw_node.draw_rect(Rect2(bx, sy + 16, 22, 14), Color(0.25, 0.78, 0.28))
			_draw_node.draw_string(font, Vector2(bx + 4, sy + 27), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		elif r == 0:
			_draw_node.draw_rect(Rect2(bx, sy + 16, 22, 14), Color(0.55, 0.12, 0.12))
			_draw_node.draw_string(font, Vector2(bx + 4, sy + 27), "✗", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		gi += 1

	# Avertissement pièges rattrapés
	if _decoy_caught > 0:
		_draw_node.draw_string(font, Vector2(sx, sy + 38),
			"Pièges : %d/%d" % [_decoy_caught, WIN_MAX_DECOYS + 1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.35, 0.25))

	# Score total
	_draw_node.draw_string(font, Vector2(vp.x / 2.0, vp.y - 112.0),
		"%d / %d vêtements" % [_good_catches, WIN_CATCHES],
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.80, 0.78, 0.60))

	# Grandes icônes de résultats en haut (positionnées consécutivement)
	var gi2 := 0
	for k in _results.size():
		if _item_sequence[k].decoy:
			continue
		var r  := _results[k]
		var kx := 155.0 + gi2 * 46.0
		if r == 1:
			_draw_node.draw_string(font, Vector2(kx, 38), "✓", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(0.3, 1, 0.3))
		elif r == 0:
			_draw_node.draw_string(font, Vector2(kx, 38), "✗", HORIZONTAL_ALIGNMENT_CENTER, -1, 26, Color(1, 0.3, 0.3))
		gi2 += 1
