extends CanvasLayer

signal done(success: bool)

const STAGES := 5
const CIRCLE_RADIUS := 140.0
const BASE_INDICATOR_SPEED := 2.2
const SPEED_INCREMENT := 0.4
const GREEN_SPEED := 0.5
const DIR_CHANGE_MIN := 2.0
const DIR_CHANGE_MAX := 5.0
const PULSE_SPEED := 3.5
const PULSE_AMOUNT := 0.18

var _current_stage := 0
var _green_angle := deg_to_rad(90.0)
var _green_offset := 0.0
var _pulse_t := 0.0
var _indicator_angle := 0.0
var _indicator_speed := BASE_INDICATOR_SPEED
var _indicator_dir := 1.0
var _green_dir := 1.0
var _dir_change_timer := 0.0
var _running := false
var _cancel_requested := false

var _draw_area: Node2D
var _stage_label: Label
var _msg_label: Label
var _bg: ColorRect
var _progress_container: Control
var _progress_dots: Array[ColorRect] = []
var _info_label: Label

# —— FX —————————————————
var _shake := 0.0
var _golden_flash := 0.0
var _red_flash := 0.0
var _particles: Array[Dictionary] = []
var _vignette_pulse := 0.0

# —— Audio —————————————
var _audio_tick: Array[AudioStream] = []
var _audio_success: Array[AudioStream] = []
var _audio_failure: Array[AudioStream] = []
var _audio_final: Array[AudioStream] = []
var _tick_player: AudioStreamPlayer = null
var _tick_timer := 0.0
const TICK_INTERVAL := 0.18
const TICK_INTERVAL_FAST := 0.09
var _last_tick_angle := 0.0

# —— Cutscene victoire —————————
var _victory_playing := false
var _victory_timer := 0.0
var _victory_cracks: Array[Dictionary] = []

var _stage_angles := [
	deg_to_rad(90.0),
	deg_to_rad(60.0),
	deg_to_rad(40.0),
	deg_to_rad(25.0),
	deg_to_rad(15.0),
]

var _stage_labels := [
	"Goupille n°1",
	"Goupille n°2",
	"Goupille n°3",
	"Goupille n°4",
	"Goupille n°5",
]


func _ready() -> void:
	_draw_area = $draw_area
	_stage_label = $stage_label
	_bg = $bg

	var vp := get_viewport().get_visible_rect().size
	_bg.size = vp
	_draw_area.position = vp / 2.0
	_stage_label.position = Vector2(vp.x / 2.0 - 120, 50)
	_stage_label.size = Vector2(240, 40)

	_setup_progress_dots(vp)
	_setup_info_label(vp)
	_setup_msg_label(vp)
	_load_audio()
	_setup_tick_player()
	_draw_area.draw.connect(_on_draw_area_draw)
	_start_stage(0)


func _setup_progress_dots(vp: Vector2) -> void:
	_progress_container = Control.new()
	_progress_container.position = Vector2(0, 100)
	_progress_container.size = Vector2(vp.x, 30)
	_progress_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress_container)

	var start_x := vp.x / 2.0 - (STAGES * 34.0) / 2.0
	for i in STAGES:
		var dot := ColorRect.new()
		dot.size = Vector2(24, 24)
		dot.position = Vector2(start_x + i * 34.0, 0)
		dot.color = Color(0.15, 0.15, 0.15)
		_progress_container.add_child(dot)
		_progress_dots.append(dot)


func _setup_info_label(vp: Vector2) -> void:
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.5))
	_info_label.position = Vector2(vp.x / 2.0 - 150, vp.y / 2.0 + CIRCLE_RADIUS + 55)
	_info_label.size = Vector2(300, 40)
	_info_label.text = "Échap pour abandonner"
	add_child(_info_label)


func _setup_msg_label(vp: Vector2) -> void:
	_msg_label = Label.new()
	_msg_label.text = "Appuyez sur E quand l'indicateur\nest dans la zone verte"
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.add_theme_font_size_override("font_size", 15)
	_msg_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))
	_msg_label.position = Vector2(vp.x / 2.0 - 160, vp.y - 75)
	_msg_label.size = Vector2(320, 50)
	add_child(_msg_label)


func _load_audio() -> void:
	_audio_tick = _scan_audio_dir("res://audio/crochetage/tick")
	_audio_success = _scan_audio_dir("res://audio/crochetage/success")
	_audio_failure = _scan_audio_dir("res://audio/crochetage/failure")
	_audio_final = _scan_audio_dir("res://audio/crochetage/final")


func _setup_tick_player() -> void:
	if _audio_tick.is_empty():
		return
	_tick_player = AudioStreamPlayer.new()
	_tick_player.bus = "Master"
	_tick_player.volume_db = -14.0
	_tick_player.stream = _audio_tick[0]
	add_child(_tick_player)


func _scan_audio_dir(dir_path: String) -> Array[AudioStream]:
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


func _play_audio(streams: Array[AudioStream], vol_db: float = -6.0) -> void:
	if streams.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = vol_db
	player.stream = streams[randi() % streams.size()]
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func _start_stage(stage: int) -> void:
	_current_stage = stage
	_green_angle = _stage_angles[stage]
	_green_offset = randf_range(0, TAU)
	_pulse_t = randf_range(0, TAU)
	_indicator_angle = randf_range(0, TAU)
	_indicator_speed = BASE_INDICATOR_SPEED + stage * SPEED_INCREMENT
	_indicator_dir = 1.0 if randi() % 2 == 0 else -1.0
	_green_dir = 1.0 if randi() % 2 == 0 else -1.0
	_dir_change_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
	_last_tick_angle = _indicator_angle
	_tick_timer = 0.0
	_stage_label.text = "%s (%d/%d)" % [_stage_labels[stage], stage + 1, STAGES]
	_stage_label.add_theme_color_override("font_color", Color.WHITE)
	_update_msg_for_urgency()
	_update_progress_dots()
	_running = true


func _update_msg_for_urgency() -> void:
	if _current_stage >= 3:
		_msg_label.text = "DÉPÊCHEZ-VOUS ! La serrure\nva se bloquer !"
		_msg_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.25))
	else:
		_msg_label.text = "Appuyez sur E quand l'indicateur\nest dans la zone verte"
		_msg_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.7))


func _update_progress_dots() -> void:
	for i in STAGES:
		if i < _current_stage:
			_progress_dots[i].color = Color(0.2, 0.85, 0.25)
		elif i == _current_stage:
			_progress_dots[i].color = Color(0.85, 0.75, 0.2)
		else:
			_progress_dots[i].color = Color(0.12, 0.12, 0.12)


func _effective_green_angle() -> float:
	var pulse := 1.0 - PULSE_AMOUNT * absf(sin(_pulse_t))
	return _green_angle * pulse


func _process(delta: float) -> void:
	if _victory_playing:
		_process_victory(delta)
		return

	if _cancel_requested:
		return

	if not _running:
		_update_fx(delta)
		_draw_area.queue_redraw()
		return

	_pulse_t += PULSE_SPEED * delta
	if _current_stage >= 3:
		_vignette_pulse += delta * 5.0

	_indicator_angle += _indicator_speed * delta * _indicator_dir
	if _indicator_angle > TAU:
		_indicator_angle -= TAU
	elif _indicator_angle < 0.0:
		_indicator_angle += TAU

	_green_offset += GREEN_SPEED * delta * _green_dir * (1.0 + _current_stage * 0.15)
	if _green_offset > TAU:
		_green_offset -= TAU
	elif _green_offset < 0.0:
		_green_offset += TAU

	_dir_change_timer -= delta
	if _dir_change_timer <= 0.0:
		_dir_change_timer = randf_range(DIR_CHANGE_MIN, DIR_CHANGE_MAX)
		if randi() % 3 == 0:
			_indicator_dir *= -1.0
		if randi() % 3 == 0:
			_green_dir *= -1.0

	_tick_timer += delta
	var tick_period := TICK_INTERVAL_FAST if _current_stage >= 3 else TICK_INTERVAL
	if _tick_timer >= tick_period:
		_tick_timer = 0.0
		var angle_diff := absf(_indicator_angle - _last_tick_angle)
		if angle_diff >= 0.25 or (_indicator_angle + TAU - _last_tick_angle) >= 0.25:
			_play_tick()
		_last_tick_angle = _indicator_angle

	_update_fx(delta)
	_draw_area.queue_redraw()


func _play_tick() -> void:
	if _tick_player == null:
		_play_audio(_audio_tick, -14.0)
		return

	var center := _green_offset + _green_angle / 2.0
	var dist_to_center := absf(wrapf(_indicator_angle - center, -PI, PI))
	var max_dist := PI - _green_angle / 2.0
	var proximity := 1.0 - clampf(dist_to_center / maxf(max_dist, 0.01), 0.0, 1.0)
	var pitch := lerpf(1.0, 2.2, proximity * proximity)
	_tick_player.pitch_scale = pitch

	if _tick_player.playing:
		_tick_player.stop()
	_tick_player.play()


func _process_victory(delta: float) -> void:
	_victory_timer += delta
	_update_fx(delta)

	if _victory_timer < 1.4:
		var intensity := clampf(_victory_timer / 0.6, 0.0, 1.0)
		_shake = lerpf(3.0, 14.0, intensity)
		if _victory_timer > 0.3:
			_golden_flash = clampf((_victory_timer - 0.3) / 0.4, 0.0, 1.0) * 0.8
		if _victory_timer > 0.8:
			_spawn_particles(Color(0.3, 1.0, 0.3), 3)

	if _victory_timer >= 1.4:
		done.emit(true)
		queue_free()
		return

	_draw_area.queue_redraw()


func _update_fx(delta: float) -> void:
	if _current_stage >= 3 and _running and not _victory_playing:
		if _shake < 0.8:
			_shake = lerpf(_shake, 1.2, delta * 2.0)
	if _shake > 0.12:
		_shake = lerpf(_shake, 0.0, delta * 8.0)
	if _golden_flash > 0.0:
		_golden_flash = maxf(0.0, _golden_flash - delta * 3.0)
	if _red_flash > 0.0:
		_red_flash = maxf(0.0, _red_flash - delta * 3.0)

	var particles_alive: Array[Dictionary] = []
	for p: Dictionary in _particles:
		p.life -= delta
		if p.life > 0.0:
			p.x += p.vx * delta
			p.y += p.vy * delta
			p.vy += 120.0 * delta
			particles_alive.append(p)
	_particles = particles_alive


func _input(event: InputEvent) -> void:
	if not is_inside_tree():
		return

	if _victory_playing:
		return

	if event.is_action_pressed("ui_cancel") and _running:
		get_viewport().set_input_as_handled()
		_cancel()
		return

	if not _running or _cancel_requested:
		return

	if event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_check_hit()


func _cancel() -> void:
	_cancel_requested = true
	_running = false

	var tween := create_tween()
	tween.tween_property(_bg, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _check_hit() -> void:
	var diff := wrapf(_indicator_angle - _green_offset, 0, TAU)
	var eff_angle := _effective_green_angle()

	if diff <= eff_angle:
		_on_success()
	else:
		_on_failure()


func _on_success() -> void:
	_running = false
	_settle_pin(_current_stage)
	_spawn_particles(Color(0.3, 1.0, 0.3), 22)
	_golden_flash = 1.0
	_play_audio(_audio_success, -4.0)
	_update_progress_dots()

	if _current_stage >= STAGES - 1:
		_start_victory_cutscene()
	else:
		var tween := create_tween()
		tween.tween_interval(0.35)
		tween.tween_callback(func():
			_start_stage(_current_stage + 1)
		)


func _on_failure() -> void:
	_running = false
	_shake = 7.0
	_red_flash = 0.7
	_play_audio(_audio_failure, -4.0)
	_spawn_particles(Color(1.0, 0.2, 0.15), 16)
	_stage_label.text = "Raté ! Recommencez..."
	_stage_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_update_msg_for_urgency()

	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func():
		for i in STAGES:
			_progress_dots[i].color = Color(0.12, 0.12, 0.12)
		_start_stage(0)
	)


func _settle_pin(stage: int) -> void:
	for i in range(stage + 1):
		_progress_dots[i].color = Color(0.2, 0.85, 0.25)


func _start_victory_cutscene() -> void:
	_victory_playing = true
	_victory_timer = 0.0
	_progress_dots[_current_stage].color = Color(0.2, 0.85, 0.25)
	_play_audio(_audio_final, -2.0)
	_stage_label.text = "Serrure déverrouillée !"
	_stage_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_msg_label.text = ""
	_info_label.text = ""

	_victory_cracks.clear()
	for _i in range(6):
		var a1 := randf_range(0, TAU)
		var a2 := a1 + randf_range(-PI * 0.3, PI * 0.3)
		var dist := randf_range(CIRCLE_RADIUS * 0.3, CIRCLE_RADIUS * 1.4)
		_victory_cracks.append({a1 = a1, a2 = a2, dist = dist, life = randf_range(0.8, 1.5)})


func _spawn_particles(col: Color, count: int) -> void:
	for _i in count:
		var angle := randf_range(0, TAU)
		var speed := randf_range(60.0, 180.0)
		_particles.append({
			x = _draw_area.position.x,
			y = _draw_area.position.y,
			vx = cos(angle) * speed,
			vy = sin(angle) * speed - 50.0,
			color = col,
			size = randf_range(2.0, 5.5),
			life = randf_range(0.3, 0.8),
			alpha = 1.0,
		})


func _on_draw_area_draw() -> void:
	var r := CIRCLE_RADIUS
	var vp := get_viewport().get_visible_rect().size
	var cx := _draw_area.position.x
	var cy := _draw_area.position.y

	var sx := randf_range(-_shake, _shake) if _shake > 0.1 else 0.0
	var sy := randf_range(-_shake * 0.6, _shake * 0.6) if _shake > 0.1 else 0.0
	var offset := Vector2(sx, sy)

	# ── Vignette urgence ──────────────────────────────────────────────────
	if _current_stage >= 3 and (not _victory_playing):
		var vig_alpha := 0.16 + sin(_vignette_pulse) * 0.08
		var margin := 30.0
		_draw_area.draw_rect(Rect2(-cx + offset.x, -cy + offset.y, vp.x, margin), Color(1.0, 0.05, 0.05, vig_alpha))
		_draw_area.draw_rect(Rect2(-cx + offset.x, vp.y - cy - margin + offset.y, vp.x, margin), Color(1.0, 0.05, 0.05, vig_alpha))
		_draw_area.draw_rect(Rect2(-cx + offset.x, -cy + offset.y, margin, vp.y), Color(1.0, 0.05, 0.05, vig_alpha))
		_draw_area.draw_rect(Rect2(vp.x - cx - margin + offset.x, -cy + offset.y, margin, vp.y), Color(1.0, 0.05, 0.05, vig_alpha))

	if _golden_flash > 0.0:
		_draw_area.draw_rect(Rect2(-cx + offset.x, -cy + offset.y, vp.x, vp.y),
			Color(1.0, 0.90, 0.28, clampf(_golden_flash, 0.0, 1.0) * 0.10))
	if _red_flash > 0.0:
		_draw_area.draw_rect(Rect2(-cx + offset.x, -cy + offset.y, vp.x, vp.y),
			Color(1.0, 0.10, 0.05, clampf(_red_flash, 0.0, 1.0) * 0.06))

	for p in _particles:
		var life_ratio := clampf(p.life / 0.8, 0.0, 1.0)
		_draw_area.draw_circle(Vector2(p.x + offset.x - cx, p.y + offset.y - cy),
			p.size * life_ratio, Color(p.color, p.alpha * life_ratio * 0.8))

	if _cancel_requested:
		return

	# ── Cutscene victoire ──────────────────────────────────────────────────
	if _victory_playing:
		_draw_victory(r, offset)
		return

	# ── Décoratif : anneau externe ──────────────────────────────────────────
	var bezel_r := r + 22.0
	_draw_area.draw_arc(offset, bezel_r, 0, TAU, 96, Color(0.22, 0.18, 0.10), 8.0, true)
	_draw_area.draw_arc(offset, bezel_r, 0, TAU, 96, Color(0.45, 0.35, 0.18), 3.0, true)

	# ── Zone verte (pulsatile) ─────────────────────────────────────────────
	if _green_angle > 0 and _running:
		var eff := _effective_green_angle()
		_draw_area.draw_arc(offset, r, _green_offset, _green_offset + eff,
			64, Color(0.15, 0.85, 0.2), 10.0, true)
		var glow_r := r + 1.0
		_draw_area.draw_arc(offset, glow_r, _green_offset, _green_offset + eff,
			64, Color(0.2, 1.0, 0.25, 0.55), 14.0, true)

	# ── Indicateur (lockpick stylisé) ───────────────────────────────────────
	var tip := Vector2(cos(_indicator_angle), sin(_indicator_angle)) * r + offset
	var base := Vector2(cos(_indicator_angle), sin(_indicator_angle)) * (r - 38.0) + offset
	var handle_width := 6.0
	var perp := Vector2(-sin(_indicator_angle), cos(_indicator_angle))
	var h1 := base + perp * handle_width
	var h2 := base - perp * handle_width
	_draw_area.draw_line(base, tip, Color(0.95, 0.2, 0.15), 2.5, true)
	_draw_area.draw_line(h1, h2, Color(0.6, 0.4, 0.2), 2.0, true)
	_draw_area.draw_circle(tip, 7, Color(0.95, 0.2, 0.15))
	_draw_area.draw_circle(tip, 3, Color(1.0, 0.85, 0.7))

	# ── Centre : trou de serrure ────────────────────────────────────────────
	var keyhole_h := 28.0
	var keyhole_w := 8.0
	_draw_area.draw_line(Vector2(offset.x - keyhole_w / 2.0, offset.y - keyhole_h / 2.0),
		Vector2(offset.x - keyhole_w / 2.0, offset.y + keyhole_h / 2.0), Color(0.08, 0.06, 0.03), 3.0, true)
	_draw_area.draw_line(Vector2(offset.x + keyhole_w / 2.0, offset.y - keyhole_h / 2.0),
		Vector2(offset.x + keyhole_w / 2.0, offset.y + keyhole_h / 2.0), Color(0.08, 0.06, 0.03), 3.0, true)
	_draw_area.draw_arc(offset + Vector2(0, -keyhole_h / 2.0 + keyhole_w / 2.0),
		keyhole_w / 2.0, PI, TAU, 16, Color(0.08, 0.06, 0.03), 3.0, true)
	_draw_area.draw_arc(offset + Vector2(0, keyhole_h / 2.0 + 3.0),
		keyhole_w / 2.0 + 3.0, 0, PI, 16, Color(0.08, 0.06, 0.03), 3.0, true)
	_draw_area.draw_circle(offset + Vector2(0, keyhole_h / 2.0 + 3.0), 7.5, Color(0.04, 0.03, 0.02))

	# ── Anneau interne ──────────────────────────────────────────────────────
	_draw_area.draw_arc(offset, r - 1.0, 0, TAU, 96, Color(0.12, 0.08, 0.04), 1.5, true)
	if _running:
		_draw_area.draw_arc(offset, r, 0, TAU, 96, Color(0.35, 0.28, 0.15), 2.5, true)


func _draw_victory(r: float, offset: Vector2) -> void:
	var cx := _draw_area.position.x
	var cy := _draw_area.position.y
	var vp := get_viewport().get_visible_rect().size

	if _victory_timer < 0.3:
		_draw_area.draw_arc(offset, r + 24.0, 0, TAU, 96, Color(0.25, 0.12, 0.08), 9.0, true)

	_draw_area.draw_arc(offset, r, 0, TAU, 96, Color(0.35, 0.28, 0.15), 2.5, true)

	if _victory_timer > 0.3:
		for c: Dictionary in _victory_cracks:
			var life_ratio: float = clampf((_victory_timer - 0.3) / 0.8, 0.0, 1.0)
			if life_ratio <= 0.0:
				continue
			var crack_alpha: float = clampf(life_ratio, 0.0, 1.0) * c.life
			if crack_alpha < 0.05:
				continue
			var d1: float = c.dist * 0.2
			var d2: float = c.dist
			var p1: Vector2 = Vector2(cos(c.a1) * d1, sin(c.a1) * d1) + offset
			var p2: Vector2 = Vector2(cos(c.a2) * d2, sin(c.a2) * d2) + offset
			_draw_area.draw_line(p1, p2, Color(1.0, 0.85, 0.2, crack_alpha * 0.9), 2.5, true)
			_draw_area.draw_line(p1 + Vector2(1, 1), p2 + Vector2(1, 1), Color(0.05, 0.03, 0.0, crack_alpha * 0.5), 1.0, true)

	if _victory_timer > 0.6:
		var burst_alpha := clampf((_victory_timer - 0.6) / 0.4, 0.0, 1.0)
		_draw_area.draw_circle(offset, burst_alpha * 22.0, Color(1.0, 0.9, 0.2, burst_alpha * 0.6))

	if _victory_timer > 0.9:
		var final_alpha := clampf((_victory_timer - 0.9) / 0.3, 0.0, 1.0)
		_draw_area.draw_rect(Rect2(-cx, -cy, vp.x, vp.y), Color(1.0, 1.0, 1.0, final_alpha * 0.25))
