extends CanvasLayer

signal done(success: bool)

const ROUND_CONFIG := [
	{"green_speed": 70.0, "info_rate": 15.0, "attn_rate": 10.0, "dir_min": 1.5, "dir_max": 3.0},
	{"green_speed": 110.0, "info_rate": 12.0, "attn_rate": 13.0, "dir_min": 1.0, "dir_max": 2.0},
	{"green_speed": 140.0, "info_rate": 10.0, "attn_rate": 18.0, "dir_min": 0.5, "dir_max": 1.5},
]

# ── Dimensions ─────────────────────────────────────────────────────────────────
const BAR_W := 44.0
const BAR_H := 380.0
const ZONE_H := 64.0
const CURSOR_SPEED_UP := 250.0
const CURSOR_SPEED_DOWN := 150.0
const GAUGE_W := 300.0
const GAUGE_H := 24.0

# ── Dialogue bribes (tavern chatter) ───────────────────────────────────────────
const CHATTER_LINES := [
	"…et puis le forgeron a juré que c'était vrai !",
	"Tu as entendu ? Le roi ne sort plus de son château…",
	"Encore une bière ? Non, je dois retrouver ma femme.",
	"Les gardes cherchent quelqu'un dans la forêt, paraît-il.",
	"J'ai vu une silhouette hier soir, près du pont…",
	"Le marchand d'épices vend du poivre à prix d'or !",
	"Chut ! Pas si fort… les murs ont des oreilles.",
	"La récolte sera mauvaise cette année, c'est certain.",
	"Tu connais la femme du parc ? Étrange, cette dame…",
	"On dit que l'assassin porte un manteau noir.",
	"Le bouffon du roi sait plus qu'il n'en dit.",
	"J'ai perdu toutes mes économies aux dés, hier.",
	"La princesse refuse tous les prétendants.",
	"Il paraît qu'une arme a disparu de la forge royale.",
	"Le chapelain marmonne dans son sommeil…",
	"Encore un voyageur qui pose trop de questions.",
	"La nuit dernière, des cris dans le quartier nord.",
	"Mon cousin garde les prisons. Il en voit des vertes…",
	"Si le roi meurt, ce sera la guerre civile.",
	"Bois donc ! Ce vin vient direct des caves du palais.",
	"J'ai vu des torches bouger près des remparts.",
	"Le bourreau prend ses vacances, ça veut tout dire.",
	"On murmure qu'un complot mijote en haut lieu…",
	"La boulette de viande est suspecte aujourd'hui.",
	"Le seul témoin a disparu. Coincidence ?",
]

# ── State ──────────────────────────────────────────────────────────────────────
var round: int = 1
var green_y: float
var green_dir := 1
var cursor_y: float
var info_progress := 0.0
var attn_progress := 0.0
var running := false
var dir_time := 0.0
var _in_zone := false
var _zone_glow_t: float = 0.0
var _chatter_timer := 0.0
var _next_chatter := 1.5
var _active_bubbles: Array[Node] = []

# ── Refs ───────────────────────────────────────────────────────────────────────
var bar_container: Node2D
var green_zone: ColorRect
var cursor_sprite: ColorRect
var cursor_glow: ColorRect
var info_fill: ColorRect
var info_bg: ColorRect
var attn_fill: ColorRect
var attn_bg: ColorRect

# ── BGM ────────────────────────────────────────────────────────────────────────
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0

	_setup_bgm()
	_setup_background(vp)
	_setup_title(cx)
	_setup_gauges(cx)
	_setup_bar(cx, vp)
	_setup_hint(cx, vp)
	_setup_chatter_zones(vp)

	green_y = BAR_H / 2.0
	cursor_y = BAR_H / 2.0
	dir_time = randf_range(ROUND_CONFIG[round - 1].dir_min, ROUND_CONFIG[round - 1].dir_max)
	running = true


# ═══════════════════════════════════════════════════════════════════════════════
#  VISUAL SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_background(vp: Vector2) -> void:
	# Dark overlay with subtle vignette feel
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.82)
	bg.size = vp
	add_child(bg)

	# Decorative horizontal rule near top
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.35, 0.2, 0.35)
	rule.position = Vector2(vp.x * 0.15, 68)
	rule.size = Vector2(vp.x * 0.7, 1)
	add_child(rule)

	var rule2 := ColorRect.new()
	rule2.color = Color(0.45, 0.35, 0.2, 0.2)
	rule2.position = Vector2(vp.x * 0.15, 69)
	rule2.size = Vector2(vp.x * 0.7, 1)
	add_child(rule2)


func _setup_title(cx: float) -> void:
	var rlbl := Label.new()
	rlbl.text = "Manche %d / 3 — Écoute aux tables" % round
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rlbl.add_theme_font_size_override("font_size", 24)
	rlbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	rlbl.position = Vector2(cx - 220, 26)
	rlbl.size = Vector2(440, 40)
	add_child(rlbl)


func _setup_gauges(cx: float) -> void:
	var gauge_y := 102.0
	var label_y := 78.0

	# ── Info gauge (left) ──
	var ilbl := Label.new()
	ilbl.text = "Infos glanées"
	ilbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ilbl.add_theme_font_size_override("font_size", 13)
	ilbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	ilbl.position = Vector2(cx - GAUGE_W - 20, label_y)
	ilbl.size = Vector2(GAUGE_W, 18)
	add_child(ilbl)

	# Info background (rounded feel via nested rects)
	info_bg = ColorRect.new()
	info_bg.color = Color(0.12, 0.14, 0.12)
	info_bg.position = Vector2(cx - GAUGE_W - 20, gauge_y)
	info_bg.size = Vector2(GAUGE_W, GAUGE_H)
	add_child(info_bg)

	info_fill = ColorRect.new()
	info_fill.color = Color(0.25, 0.95, 0.35)
	info_fill.position = Vector2(cx - GAUGE_W - 20, gauge_y)
	info_fill.size = Vector2(0, GAUGE_H)
	add_child(info_fill)

	# Info glow line (top)
	var info_glow := ColorRect.new()
	info_glow.color = Color(0.5, 1.0, 0.5, 0.35)
	info_glow.position = Vector2(cx - GAUGE_W - 20, gauge_y - 1)
	info_glow.size = Vector2(GAUGE_W, 1)
	add_child(info_glow)

	# ── Attention gauge (right) ──
	var albl := Label.new()
	albl.text = "Éveil des soupçons"
	albl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	albl.add_theme_font_size_override("font_size", 13)
	albl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	albl.position = Vector2(cx + 20, label_y)
	albl.size = Vector2(GAUGE_W, 18)
	add_child(albl)

	attn_bg = ColorRect.new()
	attn_bg.color = Color(0.14, 0.12, 0.12)
	attn_bg.position = Vector2(cx + 20, gauge_y)
	attn_bg.size = Vector2(GAUGE_W, GAUGE_H)
	add_child(attn_bg)

	attn_fill = ColorRect.new()
	attn_fill.color = Color(0.95, 0.25, 0.25)
	attn_fill.position = Vector2(cx + 20, gauge_y)
	attn_fill.size = Vector2(0, GAUGE_H)
	add_child(attn_fill)

	var attn_glow := ColorRect.new()
	attn_glow.color = Color(1.0, 0.5, 0.5, 0.35)
	attn_glow.position = Vector2(cx + 20, gauge_y - 1)
	attn_glow.size = Vector2(GAUGE_W, 1)
	add_child(attn_glow)


func _setup_bar(cx: float, vp: Vector2) -> void:
	var bar_x := cx - BAR_W / 2.0
	var bar_y := 102.0 + GAUGE_H + 44.0

	bar_container = Node2D.new()
	bar_container.position = Vector2(bar_x, bar_y)
	add_child(bar_container)

	# Outer frame (subtle gold-ish border)
	var border := ColorRect.new()
	border.color = Color(0.35, 0.3, 0.22, 0.9)
	border.position = Vector2(-3, -3)
	border.size = Vector2(BAR_W + 6, BAR_H + 6)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(border)

	# Inner dark backing
	var bb := ColorRect.new()
	bb.color = Color(0.06, 0.06, 0.08)
	bb.size = Vector2(BAR_W, BAR_H)
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bb)

	# Subtle track lines
	for i in range(0, int(BAR_H), 40):
		var tick := ColorRect.new()
		tick.color = Color(0.18, 0.18, 0.22, 0.3)
		tick.position = Vector2(4, float(i))
		tick.size = Vector2(BAR_W - 8, 1)
		bar_container.add_child(tick)

	# Green zone (listening sweet spot)
	green_zone = ColorRect.new()
	green_zone.color = Color(0.25, 0.9, 0.35, 0.22)
	green_zone.size = Vector2(BAR_W, ZONE_H)
	green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(green_zone)

	# Zone border highlight
	var zone_border := ColorRect.new()
	zone_border.color = Color(0.4, 0.95, 0.45, 0.45)
	zone_border.position = Vector2(0, 0)
	zone_border.size = Vector2(2, ZONE_H)
	zone_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	green_zone.add_child(zone_border)
	var zone_border_r := ColorRect.new()
	zone_border_r.color = Color(0.4, 0.95, 0.45, 0.45)
	zone_border_r.position = Vector2(BAR_W - 2, 0)
	zone_border_r.size = Vector2(2, ZONE_H)
	zone_border_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	green_zone.add_child(zone_border_r)

	# Cursor glow (behind)
	cursor_glow = ColorRect.new()
	cursor_glow.color = Color(1, 1, 1, 0.0)
	cursor_glow.position = Vector2(-6, 0)
	cursor_glow.size = Vector2(BAR_W + 12, 8)
	cursor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(cursor_glow)

	# Cursor sprite
	cursor_sprite = ColorRect.new()
	cursor_sprite.color = Color(0.95, 0.95, 1.0)
	cursor_sprite.size = Vector2(BAR_W, 4)
	cursor_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(cursor_sprite)

	# Cursor accents
	var cursor_l := ColorRect.new()
	cursor_l.color = Color(1, 1, 1)
	cursor_l.position = Vector2(-4, -1)
	cursor_l.size = Vector2(4, 6)
	cursor_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_sprite.add_child(cursor_l)
	var cursor_r := ColorRect.new()
	cursor_r.color = Color(1, 1, 1)
	cursor_r.position = Vector2(BAR_W, -1)
	cursor_r.size = Vector2(4, 6)
	cursor_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_sprite.add_child(cursor_r)


func _setup_hint(cx: float, vp: Vector2) -> void:
	var hint := Label.new()
	hint.text = "[E] Se pencher    ·    [Relâcher] Se redresser"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	hint.position = Vector2(cx - 220, vp.y - 56)
	hint.size = Vector2(440, 24)
	add_child(hint)

	# Decorative corner brackets
	var corner_color := Color(0.45, 0.35, 0.2, 0.4)
	var corners := [
		{"pos": Vector2(cx - 180, vp.y - 72), "size": Vector2(12, 2)},
		{"pos": Vector2(cx - 180, vp.y - 72), "size": Vector2(2, 8)},
		{"pos": Vector2(cx + 168, vp.y - 72), "size": Vector2(12, 2)},
		{"pos": Vector2(cx + 178, vp.y - 72), "size": Vector2(2, 8)},
		{"pos": Vector2(cx - 180, vp.y - 38), "size": Vector2(12, 2)},
		{"pos": Vector2(cx - 180, vp.y - 44), "size": Vector2(2, 8)},
		{"pos": Vector2(cx + 168, vp.y - 38), "size": Vector2(12, 2)},
		{"pos": Vector2(cx + 178, vp.y - 44), "size": Vector2(2, 8)},
	]
	for c in corners:
		var rect := ColorRect.new()
		rect.color = corner_color
		rect.position = c["pos"]
		rect.size = c["size"]
		add_child(rect)


func _setup_chatter_zones(_vp: Vector2) -> void:
	# Left & right side containers for floating dialogue bubbles
	# We just pre-create empty anchors; bubbles are spawned dynamically
	pass


# ═══════════════════════════════════════════════════════════════════════════════
#  PROCESS LOOP
# ═══════════════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not running:
		return

	var cfg: Dictionary = ROUND_CONFIG[round - 1]

	# Move green zone
	green_y += green_dir * cfg.green_speed * delta
	if green_y > BAR_H - ZONE_H / 2.0:
		green_y = BAR_H - ZONE_H / 2.0
		green_dir = -1
	elif green_y < ZONE_H / 2.0:
		green_y = ZONE_H / 2.0
		green_dir = 1

	dir_time -= delta
	if dir_time <= 0.0:
		green_dir = 1 if randf() > 0.5 else -1
		dir_time = randf_range(cfg.dir_min, cfg.dir_max)

	# Cursor movement
	if Input.is_action_pressed("interagir"):
		cursor_y -= CURSOR_SPEED_UP * delta
	else:
		cursor_y += CURSOR_SPEED_DOWN * delta
	cursor_y = clampf(cursor_y, 0.0, BAR_H - 4.0)

	# Zone check
	var zone_top := green_y - ZONE_H / 2.0
	var zone_bot := green_y + ZONE_H / 2.0
	_in_zone = cursor_y >= zone_top and cursor_y <= zone_bot

	if _in_zone:
		info_progress += cfg.info_rate * delta
	else:
		attn_progress += cfg.attn_rate * delta

	# Update visuals
	green_zone.position.y = green_y - ZONE_H / 2.0
	cursor_sprite.position.y = cursor_y
	cursor_glow.position.y = cursor_y - 2

	info_fill.size.x = clampf(info_progress / 100.0 * GAUGE_W, 0.0, GAUGE_W)
	attn_fill.size.x = clampf(attn_progress / 100.0 * GAUGE_W, 0.0, GAUGE_W)

	# Cursor glow when in zone
	_zone_glow_t += delta * 5.0
	if _in_zone:
		var glow_a: float = 0.15 + 0.1 * sin(_zone_glow_t)
		cursor_glow.color = Color(0.4, 1.0, 0.45, glow_a)
	else:
		cursor_glow.color = Color(1, 1, 1, 0.0)

	# Chatter bubbles
	_chatter_timer += delta
	if _chatter_timer >= _next_chatter:
		_chatter_timer = 0.0
		_next_chatter = randf_range(1.2, 3.2)
		_spawn_chatter_bubble()

	# Clean up dead bubbles
	_active_bubbles = _active_bubbles.filter(func(n): return is_instance_valid(n))

	# Win / Lose
	if info_progress >= 100.0:
		running = false
		_show_result(true)
	elif attn_progress >= 100.0:
		running = false
		_show_result(false)


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not running:
		return
	if event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
#  CHATTER BUBBLES
# ═══════════════════════════════════════════════════════════════════════════════

func _spawn_chatter_bubble() -> void:
	var vp := get_viewport().get_visible_rect().size
	var side: String = "left" if randf() > 0.5 else "right"

	var text: String = CHATTER_LINES[randi() % CHATTER_LINES.size()]
	var max_width: int = 280

	# Container
	var container := Control.new()
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_active_bubbles.append(container)

	# Calculate text size (rough estimate)
	var lines := 1 + int(text.length() * 8.5 / max_width)
	var bubble_w := mini(max_width, text.length() * 9 + 24)
	var bubble_h := maxi(36, lines * 18 + 16)

	var margin_x := 32.0
	var start_x: float
	var end_x: float
	if side == "left":
		start_x = -bubble_w - 20
		end_x = margin_x
	else:
		start_x = vp.x + 20
		end_x = vp.x - margin_x - bubble_w

	var y_range := vp.y - 220.0
	var start_y := 100.0 + randf() * y_range
	container.position = Vector2(start_x, start_y)

	# Bubble background
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1, 0.82)
	bg.size = Vector2(bubble_w, bubble_h)
	container.add_child(bg)

	# Bubble border
	var border_color := Color(0.55, 0.42, 0.25, 0.6) if side == "left" else Color(0.35, 0.45, 0.55, 0.6)
	var border := ColorRect.new()
	border.color = border_color
	border.position = Vector2(-2, -2)
	border.size = Vector2(bubble_w + 4, bubble_h + 4)
	container.add_child(border)
	container.move_child(border, 0)

	# Tiny arrow / tail
	var tail := Polygon2D.new()
	if side == "left":
		tail.polygon = PackedVector2Array([
			Vector2(bubble_w - 8, bubble_h - 8),
			Vector2(bubble_w + 6, bubble_h + 4),
			Vector2(bubble_w - 16, bubble_h - 2)
		])
	else:
		tail.polygon = PackedVector2Array([
			Vector2(8, bubble_h - 8),
			Vector2(-6, bubble_h + 4),
			Vector2(16, bubble_h - 2)
		])
	tail.color = border_color
	container.add_child(tail)
	container.move_child(tail, 1)

	# Text
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	lbl.position = Vector2(10, 6)
	lbl.size = Vector2(bubble_w - 20, bubble_h - 12)
	container.add_child(lbl)

	# Entrance tween (slide + fade)
	container.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(container, "position:x", end_x, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "modulate:a", 1.0, 0.35)

	# Auto-dismiss after random duration
	var lifetime := randf_range(2.5, 4.5)
	tween.chain().tween_interval(lifetime)
	tween.tween_property(container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(container.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
#  RESULT & CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func _show_result(success: bool) -> void:
	# Kill any remaining bubbles immediately
	for bub in _active_bubbles:
		if is_instance_valid(bub):
			bub.queue_free()
	_active_bubbles.clear()

	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0
	var cy := vp.y / 2.0

	# Backdrop dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = vp
	dim.z_index = 10
	add_child(dim)

	# Result panel
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.1, 0.9)
	panel.size = Vector2(520, 160)
	panel.position = Vector2(cx - 260, cy - 80)
	panel.z_index = 11
	add_child(panel)

	var pborder := ColorRect.new()
	pborder.color = Color(0.45, 0.35, 0.2, 0.5)
	pborder.position = Vector2(-2, -2)
	pborder.size = Vector2(524, 164)
	panel.add_child(pborder)
	panel.move_child(pborder, 0)

	var label := Label.new()
	if success:
		label.text = "Informations obtenues !"
		label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.4))
	else:
		label.text = "Tu t'es fait repérer…\nRecommence les écoutes !"
		label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(10, 10)
	label.size = Vector2(500, 140)
	panel.add_child(label)

	panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35)
	tween.tween_interval(1.6)
	tween.tween_property(panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(_finish_game.bind(success))


func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -14.0
	var dir := DirAccess.open("res://audio/moyen_age/minijeu_ecoute/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension() in ["mp3", "ogg", "wav"]:
				_bgm_player.stream = load("res://audio/moyen_age/minijeu_ecoute/" + file_name)
				if _bgm_player.stream:
					break
			file_name = dir.get_next()
		dir.list_dir_end()
	add_child(_bgm_player)
	if _bgm_player.stream:
		_bgm_player.play()


func _finish_game(success: bool) -> void:
	done.emit(success)
	queue_free()
