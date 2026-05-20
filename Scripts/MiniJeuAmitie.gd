extends CanvasLayer

signal done(success: bool)

const WIN_SCORE := 100

var score := 0
var _bar: Control
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _label: Label
var _score_label: Label
var _rating_label: Label
var _rating_tween: Tween
var _connected := false
var _won := false

var _positive_mots: PackedStringArray = [
	"bonjour", "salut", "merci", "enchanté", "ravi", "gentil",
	"aimable", "sympa", "charmant", "joli", "super", "génial",
	"cool", "ami", "amitié", "j'aime", "adore", "plaisir",
	"content", "heureux", "sourire", "comprend", "écoute",
	"parler", "confiance", "aide", "aider", "magnifique",
	"passionnant", "intéressant", "agréable", "douce", "doux",
	"chaleureux", "merveilleux", "formidable", "excellent",
	"parfait", "bravo", "s'il te plaît", "s'il vous plaît",
	"stp", "svp", "pardon", "excuse", "désolé"
]

var _negative_mots: PackedStringArray = [
	"va-t'en", "dégage", "nul", "nulle", "moche", "stupide",
	"idiot", "idiote", "bête", "méchant", "méchante", "horrible",
	"laid", "laide", "tais-toi", "ferme-la", "ennuyeux",
	"ennuyeuse", "fatigant", "déteste", "hais", "haine",
	"ignoble", "vulgaire"
]


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	_bar = Control.new()
	_bar.anchor_left = 0.3
	_bar.anchor_right = 0.7
	_bar.anchor_top = 0.02
	_bar.anchor_bottom = 0.06
	add_child(_bar)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.1, 0.1, 0.15, 0.85)
	_bar_bg.size_flags_horizontal = Control.SIZE_FILL
	_bar_bg.size_flags_vertical = Control.SIZE_FILL
	_bar.add_child(_bar_bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.2, 0.8, 0.4, 0.9)
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 1.0
	_bar_fill.anchor_right = 0.0
	_bar.add_child(_bar_fill)

	var border = StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_width_left = 2
	border.border_width_right = 2
	border.border_width_top = 2
	border.border_width_bottom = 2
	border.border_color = Color(0.8, 0.8, 0.8, 0.5)

	var panel := Panel.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", border)
	_bar.add_child(panel)

	_score_label = Label.new()
	_score_label.text = "❤ Amitié : 0"
	_score_label.add_theme_font_size_override("font_size", 14)
	_score_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.anchor_left = 0.0
	_score_label.anchor_right = 1.0
	_score_label.anchor_top = 0.0
	_score_label.anchor_bottom = 1.0
	_bar.add_child(_score_label)

	_rating_label = Label.new()
	_rating_label.add_theme_font_size_override("font_size", 36)
	_rating_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rating_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rating_label.anchor_left = 0.2
	_rating_label.anchor_right = 0.8
	_rating_label.anchor_top = 0.35
	_rating_label.anchor_bottom = 0.55
	_rating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rating_label)


func start() -> void:
	score = 0
	_won = false
	_update_bar()
	if not _connected:
		DialogueSystem.player_message_submitted.connect(_on_player_message)
		_connected = true


func stop() -> void:
	if _connected:
		if DialogueSystem.player_message_submitted.is_connected(_on_player_message):
			DialogueSystem.player_message_submitted.disconnect(_on_player_message)
		_connected = false


func _on_player_message(message: String) -> void:
	if DialogueSystem.current_npc_id != "npc_femme_parc":
		return
	if _won:
		return

	var evaluation = _evaluate_message(message)
	var delta = evaluation.delta
	var rating_text = evaluation.rating

	score = clampi(score + delta, 0, WIN_SCORE)
	_update_bar()
	_show_rating(rating_text, delta)

	if score >= WIN_SCORE:
		_won = true
		DialogueUI.close_dialogue()
		_trigger_win()


func _evaluate_message(text: String) -> Dictionary:
	var lower := text.to_lower()
	var pos_count := 0
	var neg_count := 0
	var polite := false
	var has_question := "?" in text
	var words := text.split(" ", false)
	var word_count := words.size()

	for mot in _positive_mots:
		if mot in lower:
			pos_count += 1

	for mot in _negative_mots:
		if mot in lower:
			neg_count += 1

	var polite_mots := ["s'il te plaît", "s'il vous plaît", "merci", "bonjour",
		"bonsoir", "salut", "pardon", "excuse", "désolé", "stp", "svp"]
	for mot in polite_mots:
		if mot in lower:
			polite = true
			break

	var delta := 0
	var rating := ""

	if neg_count >= 2:
		delta = -20
		rating = "💥 Bourde"
	elif neg_count == 1:
		delta = -10
		rating = "❌ Erreur"
	elif pos_count >= 3 and polite and has_question and word_count >= 4:
		delta = 20
		rating = "✨ Coup brillant"
	elif pos_count >= 2 or (pos_count >= 1 and polite):
		delta = 10
		rating = "✅ Bon coup"
	elif pos_count == 1:
		delta = 5
		rating = "👍 Bien"
	elif pos_count == 0 and neg_count == 0:
		if word_count <= 2:
			delta = -5
			rating = "⚠ Imprécision"
		else:
			delta = 0
			rating = "➖ Neutre"
	else:
		delta = -5
		rating = "⚠ Imprécision"

	return {"delta": delta, "rating": rating, "pos": pos_count, "neg": neg_count}


func _update_bar() -> void:
	var pct := float(score) / float(WIN_SCORE)
	_bar_fill.anchor_right = pct

	if score < 30:
		_bar_fill.color = Color(0.8, 0.2, 0.2, 0.9)
	elif score < 60:
		_bar_fill.color = Color(0.8, 0.6, 0.2, 0.9)
	else:
		_bar_fill.color = Color(0.2, 0.8, 0.4, 0.9)

	_score_label.text = "❤ Amitié : %d/%d" % [score, WIN_SCORE]


func _show_rating(rating_text: String, delta: int) -> void:
	if _rating_tween and _rating_tween.is_valid():
		_rating_tween.kill()

	var color := Color.WHITE
	if delta >= 20:
		color = Color(1, 0.85, 0.2)
	elif delta >= 5:
		color = Color(0.3, 1, 0.4)
	elif delta >= 0:
		color = Color(0.7, 0.7, 0.7)
	elif delta >= -5:
		color = Color(1, 0.7, 0.2)
	else:
		color = Color(1, 0.2, 0.2)

	var sign := "+" if delta >= 0 else ""
	var display := "%s (%s%d)" % [rating_text, sign, delta]

	_rating_label.text = display
	_rating_label.add_theme_color_override("font_color", Color(color, 0))
	_rating_label.modulate = Color(color, 0)

	_rating_tween = create_tween()
	_rating_tween.set_parallel(true)
	_rating_tween.tween_property(_rating_label, "modulate", Color(color, 1), 0.3)
	_rating_tween.tween_property(_rating_label, "scale", Vector2(1.3, 1.3), 0.3).from(Vector2(0.5, 0.5)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_rating_tween.tween_interval(1.8)
	_rating_tween.tween_property(_rating_label, "modulate", Color(color, 0), 0.5)
	_rating_tween.tween_callback(func():
		_rating_label.scale = Vector2(1, 1)
	)


func _trigger_win() -> void:
	var win_label := Label.new()
	win_label.text = "La femme du parc te prend par la main :\n« Viens, suis-moi, je te montre où il est… »"
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_label.add_theme_font_size_override("font_size", 22)
	win_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	win_label.custom_minimum_size = Vector2(600, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	win_label.add_theme_stylebox_override("normal", style)
	win_label.z_index = 100
	add_child(win_label)

	var vp := get_viewport().get_visible_rect().size
	win_label.position = Vector2(vp.x / 2.0 - 300, vp.y / 2.0 - 80)
	win_label.size = Vector2(600, 160)
	win_label.modulate = Color(1, 1, 1, 0)

	var tween := create_tween()
	tween.tween_property(win_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(3.5)
	tween.tween_property(win_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(win_label):
			win_label.queue_free()
		done.emit(true)
	)


func _on_tree_exiting() -> void:
	stop()
