extends CanvasLayer

signal done(success: bool)

const ROUND_CONFIG := [
	{"green_speed": 60.0, "info_rate": 15.0, "attn_rate": 10.0, "dir_min": 1.5, "dir_max": 3.0},
	{"green_speed": 100.0, "info_rate": 12.0, "attn_rate": 13.0, "dir_min": 1.0, "dir_max": 2.0},
	{"green_speed": 140.0, "info_rate": 10.0, "attn_rate": 18.0, "dir_min": 0.5, "dir_max": 1.5},
]

const BAR_W := 40.0
const BAR_H := 350.0
const ZONE_H := 60.0
const CURSOR_SPEED_UP := 250.0
const CURSOR_SPEED_DOWN := 150.0
const GAUGE_W := 300.0
const GAUGE_H := 22.0

var round: int = 1
var green_y: float
var green_dir := 1
var cursor_y: float
var info_progress := 0.0
var attn_progress := 0.0
var running := false
var dir_time := 0.0

var bar_container: Node2D
var green_zone: ColorRect
var cursor_sprite: ColorRect
var info_fill: ColorRect
var attn_fill: ColorRect


func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cx := vp.x / 2.0

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = vp
	add_child(bg)

	var rlbl := Label.new()
	rlbl.text = "Manche %d / 3 — Écouter aux tables" % round
	rlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rlbl.add_theme_font_size_override("font_size", 22)
	rlbl.add_theme_color_override("font_color", Color(1, 1, 1))
	rlbl.position = Vector2(cx - 200, 30)
	rlbl.size = Vector2(400, 36)
	add_child(rlbl)

	var gauge_y := 102.0

	var ilbl := Label.new()
	ilbl.text = "Infos glanées"
	ilbl.add_theme_font_size_override("font_size", 13)
	ilbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	ilbl.position = Vector2(cx - GAUGE_W - 20, 80)
	ilbl.size = Vector2(GAUGE_W, 18)
	add_child(ilbl)

	var albl := Label.new()
	albl.text = "Éveil des soupçons"
	albl.add_theme_font_size_override("font_size", 13)
	albl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	albl.position = Vector2(cx + 20, 80)
	albl.size = Vector2(GAUGE_W, 18)
	add_child(albl)

	var ibg := ColorRect.new()
	ibg.color = Color(0.15, 0.15, 0.15)
	ibg.position = Vector2(cx - GAUGE_W - 20, gauge_y)
	ibg.size = Vector2(GAUGE_W, GAUGE_H)
	add_child(ibg)

	var abg := ColorRect.new()
	abg.color = Color(0.15, 0.15, 0.15)
	abg.position = Vector2(cx + 20, gauge_y)
	abg.size = Vector2(GAUGE_W, GAUGE_H)
	add_child(abg)

	info_fill = ColorRect.new()
	info_fill.color = Color(0.2, 0.9, 0.2)
	info_fill.position = Vector2(cx - GAUGE_W - 20, gauge_y)
	info_fill.size = Vector2(0, GAUGE_H)
	add_child(info_fill)

	attn_fill = ColorRect.new()
	attn_fill.color = Color(0.9, 0.2, 0.2)
	attn_fill.position = Vector2(cx + 20, gauge_y)
	attn_fill.size = Vector2(0, GAUGE_H)
	add_child(attn_fill)

	var bar_x := cx - BAR_W / 2.0
	var bar_y := gauge_y + GAUGE_H + 40.0

	bar_container = Node2D.new()
	bar_container.position = Vector2(bar_x, bar_y)
	add_child(bar_container)

	var border := ColorRect.new()
	border.color = Color(0.35, 0.35, 0.4)
	border.position = Vector2(-2, -2)
	border.size = Vector2(BAR_W + 4, BAR_H + 4)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(border)

	var bb := ColorRect.new()
	bb.color = Color(0.08, 0.08, 0.1)
	bb.size = Vector2(BAR_W, BAR_H)
	bb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bb)

	green_zone = ColorRect.new()
	green_zone.color = Color(0.2, 0.85, 0.2, 0.4)
	green_zone.size = Vector2(BAR_W, ZONE_H)
	green_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(green_zone)

	cursor_sprite = ColorRect.new()
	cursor_sprite.color = Color(1, 1, 1)
	cursor_sprite.size = Vector2(BAR_W, 4)
	cursor_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(cursor_sprite)

	var hint := Label.new()
	hint.text = "[E] Se pencher  ·  [Relâcher] Se redresser"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.position = Vector2(cx - 200, vp.y - 60)
	hint.size = Vector2(400, 24)
	add_child(hint)

	green_y = BAR_H / 2.0
	cursor_y = BAR_H / 2.0
	dir_time = randf_range(ROUND_CONFIG[round - 1].dir_min, ROUND_CONFIG[round - 1].dir_max)
	running = true


func _process(delta: float) -> void:
	if not running:
		return

	var cfg = ROUND_CONFIG[round - 1]

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

	if Input.is_action_pressed("interagir"):
		cursor_y -= CURSOR_SPEED_UP * delta
	else:
		cursor_y += CURSOR_SPEED_DOWN * delta
	cursor_y = clampf(cursor_y, 0.0, BAR_H - 4.0)

	var zone_top := green_y - ZONE_H / 2.0
	var zone_bot := green_y + ZONE_H / 2.0
	var in_zone := cursor_y >= zone_top and cursor_y <= zone_bot

	if in_zone:
		info_progress += cfg.info_rate * delta
	else:
		attn_progress += cfg.attn_rate * delta

	green_zone.position.y = green_y - ZONE_H / 2.0
	cursor_sprite.position.y = cursor_y

	info_fill.size.x = clampf(info_progress / 100.0 * GAUGE_W, 0.0, GAUGE_W)
	attn_fill.size.x = clampf(attn_progress / 100.0 * GAUGE_W, 0.0, GAUGE_W)

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


func _show_result(success: bool) -> void:
	var vp := get_viewport().get_visible_rect().size
	var label := Label.new()

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(vp.x / 2.0 - 250, vp.y / 2.0 + 30)
	label.size = Vector2(500, 120)
	label.modulate = Color(1, 1, 1, 0)

	if success:
		label.text = "Informations obtenues !"
		label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		label.text = "Tu t'es fait repérer…\nRecommence les écoutes !"
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))

	add_child(label)

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_finish_game.bind(success))


func _finish_game(success: bool) -> void:
	done.emit(success)
	queue_free()
