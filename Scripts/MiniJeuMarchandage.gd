extends CanvasLayer

signal done(success: bool)

enum Phase { STRATEGIE, SKILL, NARRATIF, DONE }

const TIMER_MAX := 15.0
const BUDGET := 30
const COLUMNS := 3
const ROWS := 2
const CELL_W := 190
const CELL_H := 155
const GRID_ORIGIN_Y := 135
const PLAYER_SPEED := 380.0
const FALL_DURATION := 2.2
const CATCH_RADIUS := 58.0

var _phase := Phase.STRATEGIE
var _timer := TIMER_MAX
var _cursor := Vector2i(0, 0)
var _selected: Array[int] = []
var _items: Array[Dictionary] = []
var _budget_spent := 0
var _good_choices := 0
var _hover_bounce := 0.0
var _transition_alpha := 0.0
var _transitioning := false

var _skill_round := 0
var _player_x := 0.0
var _fall_elapsed := 0.0
var _fall_x_start := 0.0
var _fall_x_land := 0.0
var _fall_radius := 80.0
var _falling := false
var _catch_feedback_timer := 0.0
var _catch_feedback_text := ""
var _catches: Array[bool] = []
var _chosen_items: Array[Dictionary] = []
var _shake_amount := 0.0
var _dust_particles: Array[Dictionary] = []
var _pulse_t := 0.0
var _anticipation_timer := 0.0
var _anticipating := false

var _dialogue_cursor := 0
var _final_score := 0
var _negotiation_done := false
var _succeeded := false
var _star_anim_t := 0.0
var _star_anim_done := false

var _bg: ColorRect
var _draw_node: Node2D
var _title_label: Label
var _timer_label: Label
var _budget_label: Label
var _hint_label: Label
var _feedback_label: Label
var _phase_label: Label
var _option_labels: Array[Label] = []
var _marchand_text: Label

var _fabric_colors := [
	Color(0.55, 0.32, 0.18),
	Color(0.25, 0.35, 0.55),
	Color(0.45, 0.5, 0.35),
	Color(0.6, 0.5, 0.3),
	Color(0.5, 0.25, 0.25),
	Color(0.35, 0.3, 0.45),
]
var _fabric_style: Array[String] = []
var _item_icons: Array[Dictionary] = []

var _tunique_pool := [
	{"name": "Tunique en lin", "price": 15, "good_hint": "Cette étoffe vient de Flandre, touchez-moi ça !", "bad_hint": "Un excellent rapport qualité-prix, si vous voulez mon avis..."},
	{"name": "Tunique en laine", "price": 14, "good_hint": "Tissée serré, elle vous tiendra chaud tout l'hiver.", "bad_hint": "Elle a été... légèrement portée. Très légèrement."},
	{"name": "Tunique de voyage", "price": 13, "good_hint": "Double couture aux épaules — increvable !", "bad_hint": "Regardez-moi cette couleur ! ...Bon, elle est un peu passée."},
	{"name": "Tunique de paysan", "price": 6, "good_hint": "Simple mais solide, comme ceux qui la portent.", "bad_hint": "Je vous la laisse à prix d'ami. Un ami très proche."},
	{"name": "Tunique en chanvre", "price": 8, "good_hint": "Respirante et robuste, parfaite pour la route.", "bad_hint": "Elle gratte un peu au début, on s'y fait."},
]
var _manteau_pool := [
	{"name": "Manteau de voyage", "price": 12, "good_hint": "Avec capuche doublée de fourrure. Voyez le travail !", "bad_hint": "La capuche est... optionnelle. Elle s'enlève toute seule."},
	{"name": "Cape en laine", "price": 10, "good_hint": "Tissée par les meilleurs artisans du royaume.", "bad_hint": "Un peu mitée sur les bords, mais ça ne se voit pas trop."},
	{"name": "Cape de rôdeur", "price": 11, "good_hint": "Foncée, discrète — idéale pour passer inaperçu.", "bad_hint": "Idéale si vous voulez qu'on vous ignore... ou qu'on vous plaigne."},
	{"name": "Manteau rapiécé", "price": 5, "good_hint": "Les pièces sont cousues main ! Regardez ces points.", "bad_hint": "Il a vécu, ce manteau. Beaucoup vécu."},
]
var _chapeau_pool := [
	{"name": "Chapeau à large bord", "price": 8, "good_hint": "Idéal pour se fondre dans la foule, croyez-moi.", "bad_hint": "Le bord est un peu... asymétrique. C'est la mode."},
	{"name": "Capuche de moine", "price": 7, "good_hint": "Passez inaperçu avec cette capuche discrète et sobre.", "bad_hint": "On dirait presque un moine. Presque."},
	{"name": "Coiffe de voyage", "price": 9, "good_hint": "Protège du soleil ET de la pluie. Un must !", "bad_hint": "Elle protège de la pluie... sauf quand il pleut vraiment."},
]


func _ready() -> void:
	randomize()
	_build_ui()
	_generate_items()
	_enter_strategie()


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = Color(0.04, 0.02, 0.01, 0.88)
	_bg.size = vp
	add_child(_bg)

	_draw_node = Node2D.new()
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)

	_title_label = _make_label("", 28, Color(1, 0.95, 0.7))
	_title_label.position = Vector2(vp.x / 2.0 - 260, 44)
	_title_label.size = Vector2(520, 44)
	add_child(_title_label)

	_timer_label = _make_label("", 20, Color(1, 0.85, 0.3))
	_timer_label.position = Vector2(vp.x / 2.0 - 100, 92)
	_timer_label.size = Vector2(200, 30)
	add_child(_timer_label)

	_budget_label = _make_label("", 18, Color(0.9, 0.85, 0.5))
	_budget_label.position = Vector2(vp.x - 220, 92)
	_budget_label.size = Vector2(200, 30)
	add_child(_budget_label)

	_hint_label = _make_label("", 17, Color(0.75, 0.9, 0.75))
	_hint_label.position = Vector2(vp.x / 2.0 - 300, vp.y - 100)
	_hint_label.size = Vector2(600, 64)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_hint_label)

	_feedback_label = _make_label("", 22, Color.WHITE)
	_feedback_label.position = Vector2(vp.x / 2.0 - 260, vp.y / 2.0 - 40)
	_feedback_label.size = Vector2(520, 80)
	add_child(_feedback_label)

	_phase_label = _make_label("", 15, Color(0.45, 0.45, 0.45))
	_phase_label.position = Vector2(20, 18)
	_phase_label.size = Vector2(320, 28)
	add_child(_phase_label)

	_marchand_text = _make_label("", 19, Color(0.85, 0.75, 0.55))
	_marchand_text.position = Vector2(vp.x / 2.0 - 320, 180)
	_marchand_text.size = Vector2(640, 110)
	_marchand_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_marchand_text)

	for i in 3:
		var opt := _make_label("", 19, Color(0.85, 0.85, 0.7))
		opt.position = Vector2(vp.x / 2.0 - 280, 340 + i * 52)
		opt.size = Vector2(560, 46)
		opt.visible = false
		add_child(opt)
		_option_labels.append(opt)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


# =============================================================
#  PHASE 1 — STRATEGIE
# =============================================================

func _generate_items() -> void:
	_items.clear()
	_item_icons.clear()
	_fabric_style.clear()
	for _i in 6:
		_fabric_style.append(["stripes", "dots", "solid", "checker"][randi() % 4])
		_item_icons.append({
			"col": _fabric_colors[randi() % _fabric_colors.size()],
			"alt_col": _fabric_colors[randi() % _fabric_colors.size()],
		})

	var tunics := _tunique_pool.duplicate()
	tunics.shuffle()
	var manteaux := _manteau_pool.duplicate()
	manteaux.shuffle()
	var chapeau := _chapeau_pool.duplicate()
	chapeau.shuffle()

	var good_tunics := 2
	for i in 3:
		var is_good := i < good_tunics
		var q := "bonne" if is_good else "mauvaise"
		var hint: String = tunics[i].good_hint if is_good else tunics[i].bad_hint
		_items.append({
			"name": tunics[i].name, "type": "tunique", "quality": q,
			"price": tunics[i].price, "hint": hint, "row": 0, "col": i,
		})

	var good_manteaux := 1
	for i in 2:
		var is_good := i < good_manteaux
		var q := "bonne" if is_good else "mauvaise"
		var hint: String = manteaux[i].good_hint if is_good else manteaux[i].bad_hint
		_items.append({
			"name": manteaux[i].name, "type": "manteau", "quality": q,
			"price": manteaux[i].price, "hint": hint, "row": 1, "col": i,
		})

	var c: Dictionary = chapeau[0]
	var is_good := randi() % 2 == 0
	var q := "bonne" if is_good else "mauvaise"
	var hint: String = c.good_hint if is_good else c.bad_hint
	_items.append({
		"name": c.name, "type": "chapeau", "quality": q,
		"price": c.price, "hint": hint, "row": 1, "col": 2,
	})


func _enter_strategie() -> void:
	_phase = Phase.STRATEGIE
	_phase_label.text = "PHASE 1/3 — Choisissez vos vêtements"
	_title_label.text = "Le Marchandage des Étoffes"
	_timer = TIMER_MAX
	_cursor = Vector2i(0, 0)
	_selected.clear()
	_budget_spent = 0
	_good_choices = 0
	_hover_bounce = 0.0
	_budget_label.text = "Bourse : %d écus" % BUDGET
	_update_hint_for_cursor()
	_draw_node.queue_redraw()


# =============================================================
#  PHASE 2 — SKILL
# =============================================================

func _enter_skill() -> void:
	_phase = Phase.SKILL
	_skill_round = 0
	_catches.clear()
	_chosen_items.clear()
	_dust_particles.clear()

	for idx in _selected:
		_chosen_items.append(_items[idx])

	_player_x = get_viewport().get_visible_rect().size.x / 2.0
	_falling = false
	_anticipating = false
	_catch_feedback_timer = 0.0
	_catch_feedback_text = ""
	_shake_amount = 0.0
	_pulse_t = 0.0

	_feedback_label.text = ""
	_title_label.text = "Attrapez les vêtements !"
	_phase_label.text = "PHASE 2/3 — Le marchand vous lance les habits"
	_timer_label.text = ""
	_budget_label.text = ""
	_hint_label.text = "← → pour vous déplacer"
	_marchand_text.text = ""

	_start_fall()


func _start_fall() -> void:
	if _skill_round >= _chosen_items.size():
		_enter_narratif()
		return

	_anticipating = true
	_anticipation_timer = 0.5

	var vp := get_viewport().get_visible_rect().size
	var margin := 120.0
	_fall_x_start = randf_range(margin, vp.x - margin)
	_fall_x_land = randf_range(margin, vp.x - margin)
	_fall_radius = lerpf(120.0, 75.0, float(_skill_round) / 2.0)
	_fall_elapsed = 0.0

	_title_label.text = "%s !" % _chosen_items[_skill_round].name
	_phase_label.text = "PHASE 2/3 — Lancer %d/3" % (_skill_round + 1)
	_draw_node.queue_redraw()


func _catch_item(ok: bool) -> void:
	_catches.append(ok)
	_falling = false
	if ok:
		_catch_feedback_text = "Attrapé !"
		_catch_feedback_timer = 1.0
		var count := 0
		for cc in _catches:
			if cc:
				count += 1
		if count >= 2:
			_catch_feedback_text = "COMBO x%d !" % count
	else:
		_catch_feedback_text = "Raté !"
		_catch_feedback_timer = 1.0
		_shake_amount = 6.0
		var vp := get_viewport().get_visible_rect().size
		for _k in randi_range(8, 15):
			_dust_particles.append({
				"x": _fall_x_land + randf_range(-40, 40),
				"y": vp.y - 140.0 + randf_range(-10, 20),
				"vx": randf_range(-60, 60),
				"vy": randf_range(-80, -20),
				"life": randf_range(0.4, 0.9),
				"size": randf_range(1.5, 3.5),
			})

	_skill_round += 1
	await get_tree().create_timer(0.8).timeout
	_catch_feedback_text = ""
	_dust_particles.clear()
	_start_fall()


# =============================================================
#  PHASE 3 — NARRATIF
# =============================================================

func _enter_narratif() -> void:
	_phase = Phase.NARRATIF
	_dialogue_cursor = 0
	_negotiation_done = false
	_star_anim_t = 0.0
	_star_anim_done = false

	var vp := get_viewport().get_visible_rect().size
	_player_x = vp.x / 2.0

	var good_phase1 := _good_choices
	var good_phase2 := 0
	for ct in _catches:
		if ct:
			good_phase2 += 1
	_final_score = good_phase1 + good_phase2

	_title_label.text = "La Négociation"
	_phase_label.text = "PHASE 3/3 — Convainquez le marchand"
	_timer_label.text = ""
	_budget_label.text = ""
	_hint_label.text = "↑ ↓ pour choisir  ·  E pour parler"
	_feedback_label.text = ""
	_marchand_text.text = _marchand_verdict()
	_marchand_text.position = Vector2(vp.x / 2.0 - 320, 155)

	for i in 3:
		_option_labels[i].visible = true

	_update_option_labels()
	_draw_node.queue_redraw()


func _marchand_verdict() -> String:
	var score := _final_score
	var items_shown := ""
	for item in _chosen_items:
		items_shown += item.name + ", "
	items_shown = items_shown.trim_suffix(", ")

	if score <= 2:
		return "Hmm... %s.\nFranchement, c'est pas folichon tout ça.\nVous avez de la chance que je sois de bonne humeur.\nAlors, qu'avez-vous à dire pour vous ?" % items_shown
	elif score <= 4:
		return "Pas mal, pas mal... %s.\nÇa pourrait être pire. Bon, je suis prêt\nà écouter votre meilleur argument." % items_shown
	else:
		return "Magnifique ! %s.\nVoilà un déguisement digne de ce nom.\nJe suis presque fier de mon travail.\nBon... vous voulez négocier quand même, hein ?" % items_shown


func _update_option_labels() -> void:
	var options := [
		"[PITIÉ]   « Je suis un humble voyageur, ayez pitié... »",
		"[BLUFF]    « Cette étoffe est trouée, regardez ! »",
		"[CHARME]   « Votre réputation de tailleur est en jeu ! »",
	]
	for i in 3:
		var text: String = options[i]
		if i == _dialogue_cursor:
			text = "▶ " + text
		else:
			text = "   " + text
		_option_labels[i].text = text
		_option_labels[i].add_theme_color_override("font_color", Color(1, 1, 0.35) if i == _dialogue_cursor else Color(0.65, 0.65, 0.55))


func _resolve_negociation(tactic: String) -> void:
	_negotiation_done = true
	var score := _final_score
	var effective := false

	match tactic:
		"pitie":
			effective = score <= 2
		"bluff":
			effective = score >= 3 and score <= 4
		"charme":
			effective = score >= 5

	_feedback_label.text = ""
	_marchand_text.text = ""
	for opt in _option_labels:
		opt.visible = false
	_hint_label.text = ""

	if effective:
		_succeeded = true
		_title_label.text = "Marché conclu !"
		_title_label.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		var msg := ""
		match tactic:
			"pitie":
				msg = "« Bon, bon, ne faites pas cette tête.\nPrenez, et disparaissez de ma vue. »"
			"bluff":
				msg = "« Pff, vous avez l'œil.\nD'accord, d'accord, emportez tout. »"
			"charme":
				msg = "« Ah, vous savez parler aux artisans !\nTrès bien, le lot est à vous. »"
		_marchand_text.text = msg
	else:
		_succeeded = false
		_title_label.text = "Négociation échouée..."
		_title_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		var msg := ""
		match tactic:
			"pitie":
				msg = "« Arrêtez votre comédie, je ne suis pas dupe.\nDehors ! »"
			"bluff":
				msg = "« Vous me prenez pour un imbécile ?!\nCes étoffes sont impeccables ! Dehors ! »"
			"charme":
				msg = "« Ma réputation se porte très bien, merci.\nGardez vos flatteries et sortez. »"
		_marchand_text.text = msg

	await get_tree().create_timer(2.5).timeout
	done.emit(_succeeded)
	queue_free()


# =============================================================
#  PROCESS & INPUT
# =============================================================

func _process(delta: float) -> void:
	match _phase:
		Phase.STRATEGIE:
			_process_strategie(delta)
		Phase.SKILL:
			_process_skill(delta)
		Phase.NARRATIF:
			_process_narratif(delta)

	_draw_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if _phase == Phase.STRATEGIE:
		_input_strategie(event)
	elif _phase == Phase.SKILL:
		_input_skill(event)
	elif _phase == Phase.NARRATIF:
		_input_narratif(event)


# --- Phase 1 ---

func _process_strategie(delta: float) -> void:
	if _transitioning:
		return
	_timer -= delta
	_hover_bounce += delta * 3.0
	if _timer <= 0.0:
		_timer = 0.0
		_force_selection()
		return

	_timer_label.text = "⏳ %.0fs" % ceilf(_timer)
	if _timer < 5.0:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	else:
		_timer_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))

	_budget_label.text = "🪙 %d / %d écus" % [_budget_spent, BUDGET]
	if _budget_spent > BUDGET:
		_budget_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		_budget_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))


func _input_strategie(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("marche_gauche"):
		get_viewport().set_input_as_handled()
		_cursor.x = maxi(0, _cursor.x - 1)
		_update_hint_for_cursor()
	elif event.is_action_pressed("marche_droite"):
		get_viewport().set_input_as_handled()
		_cursor.x = mini(COLUMNS - 1, _cursor.x + 1)
		_update_hint_for_cursor()
	elif event.is_action_pressed("marche_haut"):
		get_viewport().set_input_as_handled()
		_cursor.y = maxi(0, _cursor.y - 1)
		_update_hint_for_cursor()
	elif event.is_action_pressed("marche_bas"):
		get_viewport().set_input_as_handled()
		_cursor.y = mini(ROWS - 1, _cursor.y + 1)
		_update_hint_for_cursor()
	elif event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		_try_select()


func _update_hint_for_cursor() -> void:
	var idx := _cursor.y * COLUMNS + _cursor.x
	if idx >= 0 and idx < _items.size():
		_hint_label.text = "« " + _items[idx].hint + " »"


func _try_select() -> void:
	var idx := _cursor.y * COLUMNS + _cursor.x
	if idx < 0 or idx >= _items.size():
		return
	if idx in _selected:
		return

	var item := _items[idx]
	var already_has_type := false
	for si in _selected:
		if _items[si].type == item.type:
			already_has_type = true
			break
	if already_has_type:
		_hint_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
		_hint_label.text = "⚠  Vous avez déjà choisi un %s !" % item.type
		return

	var remaining_slots := 3 - _selected.size()
	if _budget_spent + item.price + remaining_slots * 4 > BUDGET:
		_hint_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		_hint_label.text = "❌ Trop cher ! Il vous reste %d écus." % (BUDGET - _budget_spent)
		return

	_selected.append(idx)
	_budget_spent += item.price
	if item.quality == "bonne":
		_good_choices += 1

	if _selected.size() >= 3:
		_finish_strategie()
	else:
		_hint_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
		_hint_label.text = "✔  Choisissez encore ! (%d/3 items sélectionnés)" % _selected.size()


func _force_selection() -> void:
	for i in _items.size():
		if _selected.size() >= 3:
			break
		if i in _selected:
			continue
		var item := _items[i]
		var already := false
		for si in _selected:
			if _items[si].type == item.type:
				already = true
				break
		if already:
			continue
		_selected.append(i)
		_budget_spent += item.price
		if item.quality == "bonne":
			_good_choices += 1
	_finish_strategie()


func _finish_strategie() -> void:
	_timer = 0.0
	_title_label.text = "C'est parti !"
	_hint_label.text = ""
	_timer_label.text = ""
	_budget_label.text = ""
	_feedback_label.text = ""
	await get_tree().create_timer(0.7).timeout
	_enter_skill()


# --- Phase 2 ---

func _process_skill(delta: float) -> void:
	if _anticipating:
		_anticipation_timer -= delta
		if _anticipation_timer <= 0.0:
			_anticipating = false
			_falling = true
			_fall_elapsed = 0.0
		return

	if _shake_amount > 0.1:
		_shake_amount = lerpf(_shake_amount, 0.0, delta * 8.0)

	for p in _dust_particles:
		p.life -= delta
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.vy += 120.0 * delta
	var i := 0
	while i < _dust_particles.size():
		if _dust_particles[i].life <= 0.0:
			_dust_particles.remove_at(i)
		else:
			i += 1

	_pulse_t += delta * 2.5

	if _catch_feedback_timer > 0.0:
		_catch_feedback_timer -= delta
		_feedback_label.text = _catch_feedback_text
		if _catch_feedback_timer <= 0.0:
			_feedback_label.text = ""

	if not _falling:
		return

	_fall_elapsed += delta
	var t := clampf(_fall_elapsed / FALL_DURATION, 0.0, 1.0)
	var item_x := lerpf(_fall_x_start, _fall_x_land, t)
	var vp := get_viewport().get_visible_rect().size
	var ground_y := vp.y - 140.0
	var start_y := 60.0
	var arc_height := 200.0
	var item_y := lerpf(start_y, ground_y, t) - arc_height * sin(t * PI)

	if t >= 1.0:
		var dist := absf(item_x - _player_x)
		var ok := dist <= _fall_radius + CATCH_RADIUS
		_catch_item(ok)
		return

	if Input.is_action_pressed("marche_gauche"):
		_player_x = maxf(60.0, _player_x - PLAYER_SPEED * delta)
	if Input.is_action_pressed("marche_droite"):
		_player_x = minf(vp.x - 60.0, _player_x + PLAYER_SPEED * delta)


func _input_skill(event: InputEvent) -> void:
	if event.is_action_pressed("marche_gauche") or event.is_action_pressed("marche_droite"):
		get_viewport().set_input_as_handled()


# --- Phase 3 ---

func _process_narratif(_delta: float) -> void:
	if not _star_anim_done:
		_star_anim_t += _delta
		if _star_anim_t >= 1.0:
			_star_anim_t = 1.0
			_star_anim_done = true


func _input_narratif(event: InputEvent) -> void:
	if _negotiation_done:
		return

	if event.is_action_pressed("marche_haut"):
		get_viewport().set_input_as_handled()
		_dialogue_cursor = maxi(0, _dialogue_cursor - 1)
		_update_option_labels()
	elif event.is_action_pressed("marche_bas"):
		get_viewport().set_input_as_handled()
		_dialogue_cursor = mini(2, _dialogue_cursor + 1)
		_update_option_labels()
	elif event.is_action_pressed("interagir"):
		get_viewport().set_input_as_handled()
		var tactics := ["pitie", "bluff", "charme"]
		_resolve_negociation(tactics[_dialogue_cursor])


# =============================================================
#  DRAW
# =============================================================

func _on_draw() -> void:
	if _transitioning:
		_draw_node.draw_rect(Rect2(0, 0, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y), Color(0, 0, 0, _transition_alpha))

	match _phase:
		Phase.STRATEGIE:
			_draw_strategie()
		Phase.SKILL:
			_draw_skill()
		Phase.NARRATIF:
			_draw_narratif()


func _draw_fabric_swatch(x: float, y: float, w: float, h: float, idx: int) -> void:
	var icon: Dictionary = _item_icons[idx]
	var col: Color = icon.col
	var alt_col: Color = icon.alt_col
	var style: String = _fabric_style[idx]

	_draw_node.draw_rect(Rect2(x, y, w, h), col)
	_draw_node.draw_rect(Rect2(x, y, w, h), Color(0, 0, 0, 0.25), false, 1.0)

	match style:
		"stripes":
			var stripe_h := 5.0
			var sy := y
			while sy < y + h:
				_draw_node.draw_rect(Rect2(x, sy, w, stripe_h), alt_col)
				sy += stripe_h * 2.0
		"dots":
			var dot_r := 2.5
			var dx := x + 8.0
			while dx < x + w:
				var dy := y + 8.0
				while dy < y + h:
					_draw_node.draw_circle(Vector2(dx, dy), dot_r, alt_col)
					dy += 16.0
				dx += 14.0
		"checker":
			var cs := 10.0
			var cx := 0
			while cx * cs < w:
				var cy := 0
				while cy * cs < h:
					if (cx + cy) % 2 == 0:
						_draw_node.draw_rect(Rect2(x + cx * cs, y + cy * cs, cs, cs), alt_col)
					cy += 1
				cx += 1
		"solid":
			var highlight := col.lightened(0.15)
			_draw_node.draw_rect(Rect2(x + 4, y + 4, w - 8, h - 8), highlight, false, 1.0)

	_draw_node.draw_line(Vector2(x + w * 0.3, y), Vector2(x + w * 0.3, y + h), Color(0, 0, 0, 0.12), 0.8)
	_draw_node.draw_line(Vector2(x + w * 0.7, y), Vector2(x + w * 0.7, y + h), Color(0, 0, 0, 0.12), 0.8)


func _draw_strategie() -> void:
	var vp := get_viewport().get_visible_rect().size
	var grid_w := COLUMNS * CELL_W
	var origin_x := vp.x / 2.0 - grid_w / 2.0
	var font := ThemeDB.fallback_font

	# Candle timer visual
	var candle_x := 40.0
	var candle_y := 84.0
	var candle_h := 50.0 * (_timer / TIMER_MAX)
	_draw_node.draw_rect(Rect2(candle_x - 3, candle_y, 6, 52), Color(0.3, 0.25, 0.15))
	_draw_node.draw_rect(Rect2(candle_x - 3, candle_y + 52 - candle_h, 6, candle_h), Color(0.9, 0.7, 0.3))
	var flame_flicker := sin(_hover_bounce * 4.0) * 2.0
	if _timer > 0:
		_draw_node.draw_circle(Vector2(candle_x, candle_y + 50 - candle_h + flame_flicker), 4.0, Color(1, 0.7, 0.2, 0.9))
		_draw_node.draw_circle(Vector2(candle_x, candle_y + 46 - candle_h + flame_flicker), 2.0, Color(1, 0.95, 0.5))

	# Draw grid cells
	for i in _items.size():
		var item := _items[i]
		var col: int = item.col
		var row: int = item.row
		var cx: float = origin_x + col * CELL_W + 8
		var cy: float = GRID_ORIGIN_Y + row * CELL_H + 8
		var cw := CELL_W - 16.0
		var ch := CELL_H - 16.0

		var is_cursor: bool = _cursor.x == col and _cursor.y == row
		var is_selected := i in _selected

		var bg_col := Color(0.12, 0.08, 0.04, 0.85)
		if is_selected:
			bg_col = Color(0.08, 0.28, 0.08, 0.85)
		elif is_cursor:
			bg_col = Color(0.22, 0.16, 0.06, 0.85)
		_draw_node.draw_rect(Rect2(cx - 2, cy - 2, cw + 4, ch + 4), Color(0.05, 0.03, 0.01, 0.9))
		_draw_node.draw_rect(Rect2(cx, cy, cw, ch), bg_col)

		var swatch_h := ch * 0.42
		_draw_fabric_swatch(cx + 6, cy + 6, cw - 12, swatch_h, i)

		if is_cursor:
			var pulse := absf(sin(_hover_bounce)) * 0.4 + 0.6
			_draw_node.draw_rect(Rect2(cx - 1, cy - 1, cw + 2, ch + 2), Color(1, 0.8, 0.2, pulse), false, 2.5)
		elif is_selected:
			_draw_node.draw_rect(Rect2(cx - 1, cy - 1, cw + 2, ch + 2), Color(0.3, 0.9, 0.3, 0.8), false, 2.0)

		var ty := cy + swatch_h + 16
		var type_label := ""
		match item.type:
			"tunique": type_label = "TUNIQUE"
			"manteau": type_label = "MANTEAU"
			"chapeau": type_label = "CHAPEAU"
		_draw_node.draw_string(font, Vector2(cx + 6, ty), type_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.4, 0.3))
		_draw_node.draw_string(font, Vector2(cx + 6, ty + 18), item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 0.7))
		_draw_node.draw_string(font, Vector2(cx + cw - 10, ty + 40), "%d écus" % item.price, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, Color(1, 0.9, 0.4))

		if is_selected:
			var sel_num := _selected.find(i) + 1
			_draw_node.draw_string(font, Vector2(cx + cw - 14, cy + 8), "%d" % sel_num, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.3, 1, 0.3))

	if _selected.size() > 0:
		var px := vp.x - 150.0
		var py := GRID_ORIGIN_Y + 10.0
		_draw_node.draw_string(font, Vector2(px, py - 22), "Votre choix :", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0.7, 0.7, 0.6))
		for j in _selected.size():
			var si := _selected[j]
			var ny := py + j * 40.0
			_draw_node.draw_string(font, Vector2(px, ny), "%d. %s" % [j + 1, _items[si].name], HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.8, 0.85, 0.7))


func _draw_skill() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ground_y := vp.y - 140.0
	var font := ThemeDB.fallback_font

	var sx := randf_range(-_shake_amount, _shake_amount) if _shake_amount > 0.1 else 0.0
	var sy := randf_range(-_shake_amount * 0.5, _shake_amount * 0.5) if _shake_amount > 0.1 else 0.0

	# Ground surface
	_draw_node.draw_rect(Rect2(0 + sx, ground_y + 30 + sy, vp.x, 4), Color(0.22, 0.12, 0.05))
	_draw_node.draw_line(Vector2(50 + sx, ground_y + 34 + sy), Vector2(vp.x - 50 + sx, ground_y + 34 + sy), Color(0.15, 0.08, 0.03), 1.5)

	# Dust particles
	for p in _dust_particles:
		var alpha := clampf(p.life / 0.9, 0.0, 1.0)
		_draw_node.draw_circle(Vector2(p.x + sx, p.y + sy), p.size, Color(0.6, 0.45, 0.25, alpha * 0.7))

	# Player character
	var px := _player_x + sx
	var py := ground_y + sy

	# Shadow
	_draw_node.draw_rect(Rect2(px - 17, py + 4, 34, 6), Color(0, 0, 0, 0.2))

	# Legs + feet
	_draw_node.draw_rect(Rect2(px - 10, py - 10, 8, 14), Color(0.25, 0.2, 0.15))
	_draw_node.draw_rect(Rect2(px + 2, py - 10, 8, 14), Color(0.25, 0.2, 0.15))
	_draw_node.draw_rect(Rect2(px - 12, py + 2, 10, 5), Color(0.15, 0.1, 0.08))
	_draw_node.draw_rect(Rect2(px + 2, py + 2, 10, 5), Color(0.15, 0.1, 0.08))
	# Body
	_draw_node.draw_rect(Rect2(px - 11, py - 36, 22, 28), Color(0.35, 0.45, 0.6))
	# Belt
	_draw_node.draw_rect(Rect2(px - 11, py - 12, 22, 4), Color(0.4, 0.25, 0.1))
	# Head
	_draw_node.draw_circle(Vector2(px, py - 48), 10, Color(0.85, 0.75, 0.6))
	# Eyes
	_draw_node.draw_circle(Vector2(px - 4, py - 50), 1.5, Color(0, 0, 0))
	_draw_node.draw_circle(Vector2(px + 4, py - 50), 1.5, Color(0, 0, 0))
	# Arms (reaching up)
	var arm_angle := sin(_pulse_t) * 0.15
	_draw_node.draw_line(Vector2(px - 11, py - 34), Vector2(px - 20, py - 48 + sin(arm_angle) * 5), Color(0.85, 0.75, 0.6), 3)
	_draw_node.draw_line(Vector2(px + 11, py - 34), Vector2(px + 20, py - 48 + cos(arm_angle) * 5), Color(0.85, 0.75, 0.6), 3)

	# Catch zone pulse ring
	if _falling or _anticipating:
		var pulse_radius := CATCH_RADIUS + sin(_pulse_t) * 8.0
		var pulse_alpha := 0.3 + sin(_pulse_t * 1.5) * 0.2
		_draw_node.draw_arc(Vector2(px, py - 10), pulse_radius, 0, TAU, 32, Color(0.3, 0.8, 0.3, pulse_alpha), 2.0, true)

	# Anticipation indicator
	if _anticipating:
		var warn_t := _anticipation_timer / 0.5
		var warn_r := lerpf(30.0, _fall_radius, 1.0 - warn_t)
		_draw_node.draw_arc(Vector2(_fall_x_land + sx, ground_y + 8 + sy), warn_r, 0, TAU, 32, Color(1, 0.8, 0.2, 0.5), 2.0, true)
		return

	if not _falling and _skill_round < 3:
		_draw_node.draw_rect(Rect2(_fall_x_land - _fall_radius / 2.0 + sx, ground_y + 24 + sy, _fall_radius, 6), Color(0, 0, 0, 0.25))
		_draw_node.draw_string(font, Vector2(_fall_x_land - 40 + sx, ground_y + 40 + sy), "?", HORIZONTAL_ALIGNMENT_CENTER, -1, 18, Color(0.5, 0.5, 0.5))
		return

	if not _falling:
		return

	var t := clampf(_fall_elapsed / FALL_DURATION, 0.0, 1.0)
	var item_x := lerpf(_fall_x_start, _fall_x_land, t)
	var start_y := 60.0
	var arc_height := 200.0
	var item_y := lerpf(start_y, ground_y, t) - arc_height * sin(t * PI)

	# Shadow follows item position (not landing)
	_draw_node.draw_rect(Rect2(item_x - _fall_radius / 2.0 + sx, ground_y + 24 + sy, _fall_radius, 6), Color(0, 0, 0, 0.2))

	# Item as fabric bundle
	var item_idx: String = _chosen_items[_skill_round].type
	var item_col := Color(0.7, 0.5, 0.3)
	match item_idx:
		"tunique": item_col = Color(0.45, 0.5, 0.65)
		"manteau": item_col = Color(0.55, 0.35, 0.25)
		"chapeau": item_col = Color(0.5, 0.45, 0.35)

	# Draw item as a bundle with folds
	_draw_node.draw_rect(Rect2(item_x - 32 + sx, item_y - 14 + sy, 64, 32), item_col.darkened(0.2))
	_draw_node.draw_rect(Rect2(item_x - 28 + sx, item_y - 10 + sy, 56, 24), item_col)
	_draw_node.draw_line(Vector2(item_x - 8 + sx, item_y - 14 + sy), Vector2(item_x - 4 + sx, item_y + 14 + sy), Color(0, 0, 0, 0.15), 1)
	_draw_node.draw_line(Vector2(item_x + 8 + sx, item_y - 14 + sy), Vector2(item_x + 4 + sx, item_y + 14 + sy), Color(0, 0, 0, 0.15), 1)
	# Label above
	_draw_node.draw_string(font, Vector2(item_x - 60 + sx, item_y - 30 + sy), _chosen_items[_skill_round].name, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 0.95, 0.8))

	# Caught/missed indicators
	for k in _catches.size():
		var ix := 80.0 + k * 40.0
		if _catches[k]:
			_draw_node.draw_string(font, Vector2(ix, 30), "✓", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.3, 1, 0.3))
		else:
			_draw_node.draw_string(font, Vector2(ix, 30), "✗", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(1, 0.3, 0.3))


func _draw_narratif() -> void:
	var vp := get_viewport().get_visible_rect().size
	var font := ThemeDB.fallback_font

	# Marchand face (simple but expressive)
	var face_x := vp.x / 2.0 - 200.0
	var face_y := 110.0
	_draw_node.draw_circle(Vector2(face_x, face_y), 28, Color(0.8, 0.7, 0.55))
	_draw_node.draw_circle(Vector2(face_x - 10, face_y - 4), 3, Color(0.1, 0.1, 0.1))
	_draw_node.draw_circle(Vector2(face_x + 10, face_y - 4), 3, Color(0.1, 0.1, 0.1))
	# Beard
	_draw_node.draw_rect(Rect2(face_x - 18, face_y + 8, 36, 16), Color(0.4, 0.35, 0.25))
	# Hat
	_draw_node.draw_rect(Rect2(face_x - 24, face_y - 44, 48, 18), Color(0.35, 0.2, 0.1))
	_draw_node.draw_rect(Rect2(face_x - 14, face_y - 58, 28, 18), Color(0.35, 0.2, 0.1))

	# Player face (simple)
	var pface_x := vp.x / 2.0 + 200.0
	_draw_node.draw_circle(Vector2(pface_x, face_y), 24, Color(0.85, 0.75, 0.6))
	_draw_node.draw_circle(Vector2(pface_x - 8, face_y - 3), 2.5, Color(0.2, 0.2, 0.8))
	_draw_node.draw_circle(Vector2(pface_x + 8, face_y - 3), 2.5, Color(0.2, 0.2, 0.8))
	# Hair
	_draw_node.draw_rect(Rect2(pface_x - 22, face_y - 36, 44, 14), Color(0.3, 0.2, 0.1))

	# Score text
	var score_text := ""
	if _final_score <= 2:
		score_text = "DEGUISEMENT PITOYABLE"
	elif _final_score <= 4:
		score_text = "DEGUISEMENT PASSABLE"
	else:
		score_text = "DEGUISEMENT IMPECCABLE"
	_draw_node.draw_string(font, Vector2(vp.x / 2.0, 290), score_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(0.7, 0.7, 0.6))

	# Animated stars
	var stars_to_show := int(floor(_star_anim_t * 6.5))
	for i in 6:
		var sx := vp.x / 2.0 - 60.0 + i * 22.0
		var lit := i < _final_score
		var shown := i < stars_to_show
		if lit and shown:
			var fade_in := clampf(_star_anim_t * 6.5 - i, 0.0, 1.0)
			_draw_node.draw_string(font, Vector2(sx, 316), "★", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(1, 0.8, 0.2, fade_in))
		elif lit:
			_draw_node.draw_string(font, Vector2(sx, 316), "☆", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.2, 0.2, 0.2))
		else:
			_draw_node.draw_string(font, Vector2(sx, 316), "☆", HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color(0.3, 0.3, 0.3))
