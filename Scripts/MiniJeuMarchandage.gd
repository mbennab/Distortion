extends CanvasLayer

signal done(success: bool)

const ROUNDS := 3
const BAR_W := 440.0
const BAR_H := 30.0
const CURSOR_SPEED := 240.0
const MAX_FAILS := 3

enum State { SELECTING, FEEDBACK }

var round := 0
var cursor_x := 0.0
var green_x := 0.0
var green_w := 0.0
var attempts := 0
var state := State.SELECTING
var feedback_timer := 0.0
var feedback_ok := false

var items := [
	"Tunique de paysan",
	"Manteau de voyage",
	"Chapeau à large bord"
]
var zone_widths := [120.0, 80.0, 50.0]
var bar_x := 0.0
var bar_y := 0.0

var draw_area: Node2D
var round_label: Label
var item_label: Label
var msg_label: Label
var bg: ColorRect
var feedback: Label


func _ready() -> void:
	_build_ui()

	var vp := get_viewport().get_visible_rect().size
	bg.size = vp
	bar_x = vp.x / 2.0 - BAR_W / 2.0
	bar_y = vp.y / 2.0 - BAR_H / 2.0
	draw_area.position = Vector2(bar_x, bar_y)

	round_label.position = Vector2(vp.x / 2.0 - 100, 40)
	round_label.size = Vector2(200, 36)
	item_label.position = Vector2(vp.x / 2.0 - 150, 85)
	item_label.size = Vector2(300, 28)
	msg_label.position = Vector2(vp.x / 2.0 - 220, vp.y - 90)
	msg_label.size = Vector2(440, 60)

	feedback = Label.new()
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 18)
	feedback.add_theme_color_override("font_color", Color.WHITE)
	feedback.position = Vector2(vp.x / 2.0 - 220, vp.y / 2.0 + 60)
	feedback.size = Vector2(440, 60)
	feedback.visible = false
	add_child(feedback)

	draw_area.draw.connect(_on_draw)
	_begin_round(0)


func _build_ui() -> void:
	bg = ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0, 0, 0, 0.72)
	add_child(bg)

	draw_area = Node2D.new()
	add_child(draw_area)

	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 22)
	round_label.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(round_label)

	item_label = Label.new()
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item_label.add_theme_font_size_override("font_size", 18)
	item_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	add_child(item_label)

	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(msg_label)


func _begin_round(r: int) -> void:
	round = r
	attempts = 0
	cursor_x = BAR_W / 2.0
	green_w = zone_widths[r]
	var margin := 30.0
	green_x = randf_range(margin, BAR_W - green_w - margin)
	state = State.SELECTING
	feedback.visible = false
	round_label.text = "Manche %d / %d" % [r + 1, ROUNDS]
	item_label.text = "— %s —" % items[r]
	msg_label.text = "← → pour négocier  ·  E pour faire une offre"
	draw_area.queue_redraw()


func _process(delta: float) -> void:
	if state == State.FEEDBACK:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			state = State.SELECTING
			feedback.visible = false
			if feedback_ok:
				if round >= ROUNDS - 1:
					done.emit(true)
					queue_free()
				else:
					_begin_round(round + 1)
			else:
				if attempts >= MAX_FAILS:
					done.emit(false)
					queue_free()
				else:
					_begin_round(round)
		return

	if Input.is_action_pressed("marche_gauche"):
		cursor_x = maxf(0.0, cursor_x - CURSOR_SPEED * delta)
	if Input.is_action_pressed("marche_droite"):
		cursor_x = minf(BAR_W, cursor_x + CURSOR_SPEED * delta)
	draw_area.queue_redraw()


func _input(event: InputEvent) -> void:
	if state != State.SELECTING:
		return
	if event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_check_offer()
	if event.is_action_pressed("marche_gauche") or event.is_action_pressed("marche_droite"):
		get_viewport().set_input_as_handled()


func _check_offer() -> void:
	var in_green := cursor_x >= green_x - 2.0 and cursor_x <= green_x + green_w + 2.0
	state = State.FEEDBACK

	if in_green:
		feedback.text = "« Marché conclu ! » — le marchand hoche la tête."
		feedback.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		feedback_ok = true
		feedback_timer = 1.2
	else:
		attempts += 1
		var remaining := MAX_FAILS - attempts
		if cursor_x < green_x:
			feedback.text = "« Trop bas, l'ami ! »  (%d essais restants)" % remaining
		else:
			feedback.text = "« Trop cher pour un fugitif ! »  (%d essais restants)" % remaining

		if attempts >= MAX_FAILS:
			feedback.text = "« Hors de ma boutique, vaurien ! »"
			feedback.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			feedback_ok = false
			feedback_timer = 1.5
		else:
			feedback.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			feedback_ok = false
			feedback_timer = 1.5

	feedback.visible = true
	msg_label.text = ""


func _on_draw() -> void:
	draw_area.draw_rect(Rect2(-2, -2, BAR_W + 4, BAR_H + 4), Color(0.5, 0.45, 0.35))
	draw_area.draw_rect(Rect2(0, 0, BAR_W, BAR_H), Color(0.25, 0.2, 0.15))
	draw_area.draw_rect(Rect2(green_x, 0, green_w, BAR_H), Color(0.2, 0.75, 0.2))

	var font := ThemeDB.fallback_font
	draw_area.draw_string(font, Vector2(4, BAR_H + 20), "Trop bas", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.4, 0.4))
	draw_area.draw_string(font, Vector2(BAR_W - 64, BAR_H + 20), "Trop cher", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.4, 0.4))

	draw_area.draw_rect(Rect2(cursor_x - 2, -4, 4, BAR_H + 8), Color(1, 0.9, 0.1))
	var tip := Vector2(cursor_x, -8)
	var left := Vector2(cursor_x - 7, -20)
	var right := Vector2(cursor_x + 7, -20)
	draw_area.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1, 0.9, 0.1))
