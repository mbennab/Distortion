extends CanvasLayer

signal done(success: bool)

enum Phase { INTRO, LOOKING_AWAY, WARNING, LOOKING_AT, STRIKE, WIN, GAME_OVER }

const MAX_STRIKES := 3
const CATCH_DISTANCE := 55.0
const PLAYER_SPEED := 82.0
const GRACE_PERIOD := 0.10
const WARNING_DURATION := 0.30
const INTRO_DURATION := 2.5
const STRIKE_PAUSE := 1.2
const KNOCKBACK := 200.0

const INITIAL_SAFE := 2.5
const MIN_SAFE := 0.85
const INITIAL_DANGER := 1.7
const MAX_DANGER := 3.5
const SAFE_DECAY := 0.35
const DANGER_GROWTH := 0.28
const SAFE_RANDOM_SPREAD := 0.60
const SKIP_WARNING_CHANCE := 0.40

var _phase: int = Phase.INTRO
var _timer := 0.0
var _strikes := 0
var _cycles := 0
var _game_over := false
var _grace := 0.0

var _player_x := 0.0
var _npc_x := 0.0
var _start_x := 0.0

var _safe_dur := INITIAL_SAFE
var _danger_dur := INITIAL_DANGER

var _walk_t := 0.0
var _moving := false
var _flash_r := 0.0
var _flash_g := 0.0
var _t := 0.0
var _progress := 0.0

var _tex_npc: Texture2D
var _tex_idle_cote: Texture2D
var _tex_walk_cote1: Texture2D
var _tex_walk_cote2: Texture2D
var _tex_idle_face: Texture2D

var _bg: ColorRect
var _draw: Node2D
var _npc_spr: Sprite2D
var _player_spr: Sprite2D
var _title: Label
var _status: Label
var _hint: Label
var _strikes_lbl: Label
var _progress_lbl: Label


func _ready() -> void:
	layer = 129
	_load_textures()
	_build_ui()
	_start_intro()


func _load_textures() -> void:
	_tex_npc = load("res://art/Present/gars_maintenance_profil.png")
	_tex_idle_cote = load("res://art/perso_idle_cote.png")
	_tex_walk_cote1 = load("res://art/perso_marche_cote1.png")
	_tex_walk_cote2 = load("res://art/perso_marche_cote2.png")
	_tex_idle_face = load("res://art/perso_idle_face.png")


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.color = Color(0.04, 0.04, 0.06)
	_bg.size = vp
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_draw = Node2D.new()
	_draw.draw.connect(_on_draw)
	add_child(_draw)

	_npc_x = 140.0
	_start_x = vp.x - 120.0

	_npc_spr = Sprite2D.new()
	_npc_spr.texture = _tex_npc
	_npc_spr.hframes = 2
	_npc_spr.frame = 0
	_npc_spr.scale = Vector2(0.2475, 0.2475)
	_npc_spr.position = Vector2(_npc_x, vp.y / 2.0)
	add_child(_npc_spr)

	_player_x = _start_x
	_player_spr = Sprite2D.new()
	_player_spr.texture = _tex_idle_cote
	_player_spr.hframes = 2
	_player_spr.frame = 0
	_player_spr.scale = Vector2(0.28, 0.28)
	_player_spr.flip_h = false
	_player_spr.position = Vector2(_player_x, vp.y / 2.0)
	add_child(_player_spr)

	_title = _lbl("Discrétion !", 30, Color(1, 0.95, 0.7))
	_title.position = Vector2(vp.x / 2.0 - 280, 14)
	_title.size = Vector2(560, 50)
	add_child(_title)

	_status = _lbl("", 22, Color.WHITE)
	_status.position = Vector2(vp.x / 2.0 - 220, vp.y / 2.0 - 190)
	_status.size = Vector2(440, 44)
	add_child(_status)

	_hint = _lbl("← Avancez quand il regarde ailleurs\nArrêtez-vous quand il tourne !", 14, Color(0.65, 0.82, 0.65))
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.position = Vector2(vp.x / 2.0 - 260, vp.y - 90)
	_hint.size = Vector2(520, 60)
	add_child(_hint)

	_strikes_lbl = _lbl("", 24, Color(1, 0.35, 0.35))
	_strikes_lbl.position = Vector2(vp.x - 200, 14)
	_strikes_lbl.size = Vector2(180, 36)
	_strikes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_strikes_lbl)

	_progress_lbl = _lbl("", 14, Color(0.62, 0.62, 0.58))
	_progress_lbl.position = Vector2(14, 14)
	_progress_lbl.size = Vector2(220, 28)
	_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_progress_lbl)


func _on_viewport_resized() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_bg.size = vp
	_hint.position = Vector2(vp.x / 2.0 - 260, vp.y - 90)


func _lbl(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


func _start_intro() -> void:
	_phase = Phase.INTRO
	_game_over = false
	_title.text = "Discrétion !"
	_title.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	_status.text = "Volez le badge du technicien !"
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	_strikes_lbl.text = ""
	_progress_lbl.text = ""
	_npc_spr.texture = _tex_npc
	_npc_spr.hframes = 2
	_npc_spr.frame = 0
	_npc_spr.scale = Vector2(0.2475, 0.2475)
	_npc_spr.flip_h = false

	await get_tree().create_timer(INTRO_DURATION).timeout
	if not is_inside_tree():
		return
	_enter_away()


func _enter_away() -> void:
	_phase = Phase.LOOKING_AWAY
	_timer = 0.0
	var base := maxf(MIN_SAFE, INITIAL_SAFE - _cycles * SAFE_DECAY)
	_safe_dur = randf_range(maxf(MIN_SAFE, base - SAFE_RANDOM_SPREAD), base + 0.3)

	_npc_spr.texture = _tex_npc
	_npc_spr.hframes = 2
	_npc_spr.frame = 0
	_npc_spr.scale = Vector2(0.2475, 0.2475)
	_npc_spr.flip_h = false

	_status.text = "Il regarde ailleurs… AVANCEZ !"
	_status.add_theme_color_override("font_color", Color(0.25, 0.9, 0.25))
	_title.text = "Avancez…"
	_title.add_theme_color_override("font_color", Color(0.35, 0.88, 0.35))


func _enter_warning() -> void:
	_phase = Phase.WARNING
	_timer = 0.0
	_status.text = "⚠ Attention…"
	_status.add_theme_color_override("font_color", Color(1, 0.82, 0.15))
	_title.text = "⚠ Attention…"
	_title.add_theme_color_override("font_color", Color(1, 0.82, 0.15))


func _enter_at() -> void:
	_phase = Phase.LOOKING_AT
	_timer = 0.0
	_grace = GRACE_PERIOD
	_danger_dur = minf(MAX_DANGER, INITIAL_DANGER + _cycles * DANGER_GROWTH)

	_npc_spr.texture = _tex_npc
	_npc_spr.hframes = 2
	_npc_spr.frame = 1
	_npc_spr.scale = Vector2(0.2475, 0.2475)
	_npc_spr.flip_h = false

	_status.text = "STOP ! NE BOUGEZ PLUS !"
	_status.add_theme_color_override("font_color", Color(1, 0.22, 0.18))
	_title.text = "Il tourne !"
	_title.add_theme_color_override("font_color", Color(1, 0.25, 0.2))


func _apply_strike() -> void:
	_strikes += 1
	_flash_r = 0.9
	_update_strikes_label()

	if _strikes >= MAX_STRIKES:
		_enter_game_over()
		return

	_phase = Phase.STRIKE
	_timer = 0.0
	_player_x = minf(_start_x, _player_x + KNOCKBACK)
	_status.text = "Pris sur le fait ! Reculez…"
	_status.add_theme_color_override("font_color", Color(1, 0.5, 0.3))

	await get_tree().create_timer(STRIKE_PAUSE).timeout
	if not is_inside_tree():
		return
	_cycles += 1
	_enter_away()


func _enter_win() -> void:
	_game_over = true
	_flash_g = 1.0
	_status.text = "Badge volé !"
	_status.add_theme_color_override("font_color", Color(0.25, 0.95, 0.25))
	_title.text = "Badge obtenu !"
	_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_hint.text = "Retournez voir l'agent de sécurité"
	_hint.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	_progress_lbl.text = "Distance : 100%"

	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		done.emit(true)
		queue_free()


func _enter_game_over() -> void:
	_game_over = true
	_status.text = "Le technicien vous a chassé !"
	_status.add_theme_color_override("font_color", Color(1, 0.3, 0.25))
	_title.text = "Échoué !"
	_title.add_theme_color_override("font_color", Color(1, 0.28, 0.22))
	_hint.text = ""

	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		done.emit(false)
		queue_free()


func _update_strikes_label() -> void:
	var txt := ""
	for i in range(MAX_STRIKES):
		if i < _strikes:
			txt += "✗ "
		else:
			txt += "○ "
	_strikes_lbl.text = txt


func _process(delta: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var center_y: float = vp.y / 2.0

	if _phase == Phase.INTRO:
		_t += delta
		_npc_spr.position = Vector2(_npc_x, center_y + sin(_t * 2.5) * 2.0)
		_draw.queue_redraw()
		return

	if _game_over:
		if _flash_r > 0.0:
			_flash_r = maxf(0.0, _flash_r - delta * 2.5)
		if _flash_g > 0.0:
			_flash_g = maxf(0.0, _flash_g - delta * 2.5)
		_player_spr.position = Vector2(_player_x, center_y)
		_npc_spr.position = Vector2(_npc_x, center_y + sin(_t * 2.5) * 2.0)
		_draw.queue_redraw()
		return

	_t += delta
	if _flash_r > 0.0:
		_flash_r = maxf(0.0, _flash_r - delta * 2.5)
	if _flash_g > 0.0:
		_flash_g = maxf(0.0, _flash_g - delta * 2.5)

	_moving = (
		Input.is_action_pressed("marche_gauche")
		or Input.is_action_pressed("marche_droite")
		or Input.is_action_pressed("marche_haut")
		or Input.is_action_pressed("marche_bas")
	)

	match _phase:
		Phase.LOOKING_AWAY:
			_timer += delta
			if Input.is_action_pressed("marche_gauche"):
				_player_x -= PLAYER_SPEED * delta
				_walk_t += delta * 10.0
			if Input.is_action_pressed("marche_droite"):
				_player_x += PLAYER_SPEED * delta * 0.5
				_walk_t += delta * 10.0
			_player_x = clampf(_player_x, _npc_x + CATCH_DISTANCE + 10.0, _start_x)

			if _player_x <= _npc_x + CATCH_DISTANCE + 10.0:
				_enter_win()
				return

			if _timer >= _safe_dur:
				if randf() < SKIP_WARNING_CHANCE:
					_enter_at()
				else:
					_enter_warning()

			if Input.is_action_pressed("marche_gauche") or Input.is_action_pressed("marche_droite"):
				_player_spr.texture = _tex_walk_cote1
				_player_spr.frame = int(_walk_t) % 2
				_player_spr.flip_h = Input.is_action_pressed("marche_droite")
			else:
				_player_spr.texture = _tex_idle_cote
				_player_spr.frame = 0
				_player_spr.flip_h = false

		Phase.WARNING:
			_timer += delta
			if Input.is_action_pressed("marche_gauche"):
				_player_x -= PLAYER_SPEED * delta * 0.25
				_walk_t += delta * 8.0
			if Input.is_action_pressed("marche_droite"):
				_player_x += PLAYER_SPEED * delta * 0.12
			_player_x = clampf(_player_x, _npc_x + CATCH_DISTANCE + 10.0, _start_x)

			if _player_x <= _npc_x + CATCH_DISTANCE + 10.0:
				_enter_win()
				return

			if _timer >= WARNING_DURATION:
				_enter_at()

			if Input.is_action_pressed("marche_gauche") or Input.is_action_pressed("marche_droite"):
				_player_spr.texture = _tex_walk_cote1
				_player_spr.frame = int(_walk_t) % 2
				_player_spr.flip_h = Input.is_action_pressed("marche_droite")
			else:
				_player_spr.texture = _tex_idle_cote
				_player_spr.frame = 0
				_player_spr.flip_h = false

		Phase.LOOKING_AT:
			_timer += delta
			_grace = maxf(0.0, _grace - delta)

			if _grace <= 0.0 and _moving:
				_apply_strike()
				return

			_player_spr.texture = _tex_idle_face
			_player_spr.frame = 0
			_player_spr.flip_h = false

			if _timer >= _danger_dur:
				_cycles += 1
				_enter_away()

		Phase.STRIKE:
			_player_spr.texture = _tex_idle_face
			_player_spr.frame = 0
			_player_spr.flip_h = false

	_progress = 1.0 - clampf((_player_x - _npc_x - CATCH_DISTANCE - 10.0) / (_start_x - _npc_x - CATCH_DISTANCE - 10.0), 0.0, 1.0)
	_progress_lbl.text = "Distance : %d%%" % int(_progress * 100)

	_player_spr.position = Vector2(_player_x, center_y)
	_npc_spr.position = Vector2(_npc_x, center_y + sin(_t * 2.5) * 2.0)

	_draw.queue_redraw()


func _on_draw() -> void:
	if not is_inside_tree():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size

	if _flash_r > 0.0:
		_draw.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(1, 0.08, 0.08, _flash_r * 0.3))
	if _flash_g > 0.0:
		_draw.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(0.08, 1, 0.2, _flash_g * 0.35))

	var bar_y: float = vp.y - 35.0
	var bar_left: float = 60.0
	var bar_w: float = vp.x - 120.0
	var bar_h: float = 14.0
	_draw.draw_rect(Rect2(bar_left, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.18))
	var fill_w: float = bar_w * clampf(_progress, 0.0, 1.0)
	var bar_col: Color
	if _phase == Phase.LOOKING_AWAY or _phase == Phase.INTRO:
		bar_col = Color(0.25, 0.8, 0.25)
	elif _phase == Phase.WARNING:
		bar_col = Color(0.95, 0.8, 0.15)
	else:
		bar_col = Color(0.9, 0.2, 0.15)
	_draw.draw_rect(Rect2(bar_left, bar_y, fill_w, bar_h), bar_col)
	_draw.draw_rect(Rect2(bar_left, bar_y, bar_w, bar_h), Color(0.4, 0.4, 0.45), false, 2.0)

	_draw.draw_line(Vector2(_npc_x + 30, 80), Vector2(_npc_x + 30, vp.y - 55), Color(0.22, 0.22, 0.28), 2.0)

	if _phase == Phase.WARNING:
		var alpha: float = 0.35 + sin(_t * 12.0) * 0.25
		_draw.draw_rect(Rect2(0, 0, vp.x, vp.y), Color(1, 0.85, 0.1, alpha * 0.15))


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if _game_over:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		done.emit(false)
		queue_free()
	if event.is_action_pressed("marche_gauche") or event.is_action_pressed("marche_droite") or event.is_action_pressed("marche_haut") or event.is_action_pressed("marche_bas"):
		get_viewport().set_input_as_handled()