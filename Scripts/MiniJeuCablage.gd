extends CanvasLayer

signal done(success: bool)

enum Phase { PLAYING, ROUND_TRANSITION, SUCCESS, FAILURE, EXITING }
enum NType { SOURCE, TARGET, AND_GATE, OR_GATE, NOT_GATE, JUNCTION }

const TOTAL_ROUNDS := 3
const NODE_R := 30.0
const GATE_W := 90.0
const GATE_H := 50.0
const CABLE_W := 4.0
const CABLE_W_LIT := 7.0
const CLICK_CABLE_DIST := 14.0

var _phase: int = Phase.PLAYING
var _current_round: int = 1
var _terminals: Dictionary = {}
var _connections: Array = []
var _preset_connections: Array = []
var _cable_used: float = 0.0
var _cable_budget: float = 0.0
var _selected_id: String = ""
var _objectives: Array = []
var _cable_line_nodes: Array = []
var _preset_line_nodes: Array = []
var _dynamic: Array = []
var _levels: Array = []
var _vp: Vector2 = Vector2.ZERO
var _board_origin: Vector2 = Vector2.ZERO
var _board_size: Vector2 = Vector2.ZERO

var _bg: ColorRect
var _round_lbl: Label
var _title_lbl: Label
var _status_lbl: Label
var _budget_lbl: Label
var _validate_btn: Button
var _clear_btn: Button
var _reset_btn: Button
var _retry_btn: Button
var _cable_layer: Node2D
var _preview_line: Line2D
var _target_panels: Dictionary = {}


func _ready() -> void:
	layer = 129
	_define_levels()
	_init_round(1)


func _define_levels() -> void:
	_levels.clear()
	_levels.append({
		"terminals": [
			{"id": "A", "type": "source", "label": "A", "px": 0.10, "py": 0.25, "on": true},
			{"id": "B", "type": "source", "label": "B", "px": 0.10, "py": 0.75, "on": true},
			{"id": "1", "type": "target", "label": "OUT 1", "px": 0.88, "py": 0.22},
			{"id": "2", "type": "target", "label": "OUT 2", "px": 0.88, "py": 0.50},
			{"id": "3", "type": "target", "label": "OUT 3", "px": 0.88, "py": 0.78},
		],
		"connections": [],
		"objectives": ["1", "2", "3"],
		"budget": 4000.0,
		"title": "Alimentation d'urgence",
		"hints": [
			"Reliez les SOURCES aux CIBLES",
			"pour alimener tout le circuit.",
			"",
			"SOURCE verte = alimentee",
			"CIBLE jaune = en attente",
			"CIBLE verte = alimentee",
			"",
			"Clic noeud puis noeud = cable",
			"Clic droit = annuler selection",
			"ESC = quitter",
		]
	})
	_levels.append({
		"terminals": [
			{"id": "A", "type": "source", "label": "A", "px": 0.06, "py": 0.20, "on": true},
			{"id": "B", "type": "source", "label": "B", "px": 0.06, "py": 0.50, "on": true},
			{"id": "X", "type": "source", "label": "X", "px": 0.06, "py": 0.82, "on": false},
			{"id": "AND", "type": "and_gate", "label": "AND", "px": 0.40, "py": 0.25},
			{"id": "OR", "type": "or_gate", "label": "OR", "px": 0.40, "py": 0.60},
			{"id": "1", "type": "target", "label": "OUT 1", "px": 0.88, "py": 0.20},
			{"id": "2", "type": "target", "label": "OUT 2", "px": 0.88, "py": 0.55},
			{"id": "3", "type": "target", "label": "OUT 3", "px": 0.88, "py": 0.85},
		],
		"connections": [],
		"objectives": ["1", "2", "3"],
		"budget": 3200.0,
		"title": "Circuit de securite",
		"hints": [
			"Source X en PANNE (rouge) !",
			"Ne l'utilisez pas...",
			"",
			"AND : active si les 2 entrees ON",
			"OR : active si au moins 1 ON",
			"",
			"Objectif 1 : A et B via AND",
			"Objectif 2 : A ou B via OR",
			"Objectif 3 : B direct",
		]
	})
	_levels.append({
		"terminals": [
			{"id": "A", "type": "source", "label": "A", "px": 0.06, "py": 0.15, "on": true},
			{"id": "B", "type": "source", "label": "B", "px": 0.06, "py": 0.50, "on": true},
			{"id": "D", "type": "source", "label": "D", "px": 0.06, "py": 0.85, "on": false},
			{"id": "AND1", "type": "and_gate", "label": "AND", "px": 0.40, "py": 0.18},
			{"id": "OR1", "type": "or_gate", "label": "OR", "px": 0.40, "py": 0.50},
			{"id": "NOT1", "type": "not_gate", "label": "NOT", "px": 0.40, "py": 0.82},
			{"id": "1", "type": "target", "label": "OUT 1", "px": 0.90, "py": 0.15},
			{"id": "2", "type": "target", "label": "OUT 2", "px": 0.90, "py": 0.50},
			{"id": "3", "type": "target", "label": "OUT 3", "px": 0.90, "py": 0.85},
		],
		"connections": [{"from": "NOT1", "to": "2"}],
		"objectives": ["1", "2", "3"],
		"budget": 2800.0,
		"title": "Reboot du reacteur",
		"hints": [
			"Source D en PANNE (rouge) !",
			"Un cable pre-poses (gris).",
			"",
			"NOT inverse :",
			"NOT(PANNE) = alimente !",
			"NOT(alimente) = eteint",
			"",
			"Objectif 1 : AND(A, B)",
			"Objectif 2 : NOT(D) deja cable",
			"Objectif 3 : B -> OR -> 3",
			"OU A -> OR -> 3",
		]
	})


func _init_round(round_num: int) -> void:
	_current_round = round_num
	_phase = Phase.PLAYING
	_connections.clear()
	_preset_connections.clear()
	_cable_used = 0.0
	_selected_id = ""
	_terminals.clear()
	_objectives.clear()
	_target_panels.clear()
	_cable_line_nodes.clear()
	_preset_line_nodes.clear()

	var ld: Dictionary = _levels[round_num - 1]
	_cable_budget = ld["budget"]
	_objectives = ld["objectives"].duplicate()

	for t in ld["terminals"]:
		var td: Dictionary = t
		_terminals[td["id"]] = {
			"type": _str_to_type(td["type"]),
			"label": td["label"],
			"pos": Vector2(td["px"], td["py"]),
			"powered": td.get("on", false) if td["type"] == "source" else false,
			"on_default": td.get("on", false) if td["type"] == "source" else false,
		}

	var pc = ld.get("connections", [])
	for c in pc:
		var cd: Dictionary = c
		_preset_connections.append({"from": cd["from"], "to": cd["to"]})
		var dist: float = _node_pos(cd["from"]).distance_to(_node_pos(cd["to"]))

	_clear_dynamic()
	_build_ui()
	_refresh_cables()
	_propagate_power()


func _str_to_type(s: String) -> int:
	match s:
		"source": return NType.SOURCE
		"target": return NType.TARGET
		"and_gate": return NType.AND_GATE
		"or_gate": return NType.OR_GATE
		"not_gate": return NType.NOT_GATE
		"junction": return NType.JUNCTION
		_: return NType.JUNCTION


func _clear_dynamic() -> void:
	for node in _dynamic:
		if is_instance_valid(node):
			node.queue_free()
	_dynamic.clear()
	_cable_line_nodes.clear()
	_preset_line_nodes.clear()


func _node_pos(id: String) -> Vector2:
	return _board_origin + _terminals[id]["pos"] * _board_size


func _node_half(id: String) -> float:
	var t: Dictionary = _terminals[id]
	match t["type"]:
		NType.AND_GATE, NType.OR_GATE, NType.NOT_GATE:
			return GATE_W / 2.0
		_:
			return NODE_R


func _lbl(text: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, bg: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", s)
	var h: StyleBoxFlat = s.duplicate()
	h.bg_color = bg + Color(0.06, 0.06, 0.06)
	b.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = s.duplicate()
	p.bg_color = bg - Color(0.04, 0.04, 0.04)
	b.add_theme_stylebox_override("pressed", p)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


func _build_ui() -> void:
	_vp = get_viewport().get_visible_rect().size
	var bw: float = _vp.x * 0.60
	var bh: float = _vp.y - 110.0
	_board_origin = Vector2(15, 60)
	_board_size = Vector2(bw, bh)

	_bg = ColorRect.new()
	_bg.color = Color(0.02, 0.04, 0.08, 0.98)
	_bg.size = _vp
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_dynamic.append(_bg)

	var board_panel := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.04, 0.06, 0.10, 0.90)
	bs.border_color = Color(0.15, 0.25, 0.35, 0.6)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(8)
	board_panel.add_theme_stylebox_override("panel", bs)
	board_panel.position = Vector2(_board_origin.x - 8, _board_origin.y - 8)
	board_panel.size = Vector2(_board_size.x + 16, _board_size.y + 16)
	board_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board_panel)
	_dynamic.append(board_panel)

	_draw_grid()

	_cable_layer = Node2D.new()
	add_child(_cable_layer)
	_dynamic.append(_cable_layer)

	_preview_line = Line2D.new()
	_preview_line.width = 3.0
	_preview_line.default_color = Color(1.0, 1.0, 1.0, 0.4)
	_preview_line.z_index = 4
	_preview_line.visible = false
	add_child(_preview_line)
	_dynamic.append(_preview_line)

	var title_bg := ColorRect.new()
	title_bg.color = Color(0.02, 0.04, 0.07, 0.95)
	title_bg.position = Vector2(0, 0)
	title_bg.size = Vector2(_vp.x, 55)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)
	_dynamic.append(title_bg)

	_round_lbl = _lbl("PANNEAU " + str(_current_round) + " / " + str(TOTAL_ROUNDS), 13, Color(0.45, 0.65, 0.75))
	_round_lbl.position = Vector2(0, 3)
	_round_lbl.size = Vector2(_vp.x, 18)
	add_child(_round_lbl)
	_dynamic.append(_round_lbl)

	_title_lbl = _lbl(_levels[_current_round - 1].get("title", ""), 20, Color(0.7, 0.85, 1.0))
	_title_lbl.position = Vector2(0, 22)
	_title_lbl.size = Vector2(_vp.x, 28)
	add_child(_title_lbl)
	_dynamic.append(_title_lbl)

	_draw_nodes()

	_budget_lbl = _lbl("", 14, Color(0.65, 0.85, 0.65))
	_budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_budget_lbl.position = Vector2(25, _vp.y - 42)
	_budget_lbl.size = Vector2(350, 20)
	add_child(_budget_lbl)
	_dynamic.append(_budget_lbl)
	_update_budget()

	_status_lbl = _lbl("Cliquez sur un noeud pour commencer", 15, Color(0.65, 0.75, 0.85))
	_status_lbl.position = Vector2(0, _vp.y - 60)
	_status_lbl.size = Vector2(_vp.x, 24)
	add_child(_status_lbl)
	_dynamic.append(_status_lbl)

	var hint_lbl := _lbl("Clic noeud puis noeud = cable  |  Clic droit = annuler  |  ESC = quitter", 11, Color(0.38, 0.42, 0.48))
	hint_lbl.position = Vector2(0, _vp.y - 22)
	hint_lbl.size = Vector2(_vp.x, 16)
	add_child(hint_lbl)
	_dynamic.append(hint_lbl)

	var px: float = _board_size.x + 45.0
	var pw: float = _vp.x - px - 15.0

	var instr_panel := PanelContainer.new()
	var is_ := StyleBoxFlat.new()
	is_.bg_color = Color(0.04, 0.06, 0.10, 0.95)
	is_.border_color = Color(0.2, 0.3, 0.4, 0.6)
	is_.set_border_width_all(2)
	is_.set_corner_radius_all(10)
	instr_panel.add_theme_stylebox_override("panel", is_)
	instr_panel.position = Vector2(px, 60)
	instr_panel.size = Vector2(pw, _vp.y - 170)
	instr_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(instr_panel)
	_dynamic.append(instr_panel)

	var enigme_lbl := _lbl("ENIGME", 17, Color(0.9, 0.78, 0.35))
	enigme_lbl.position = Vector2(px + 10, 68)
	enigme_lbl.size = Vector2(pw - 20, 24)
	add_child(enigme_lbl)
	_dynamic.append(enigme_lbl)

	var hints: Array = _levels[_current_round - 1].get("hints", [])
	var hy: float = 100.0
	for h in hints:
		var hl := Label.new()
		hl.text = h
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.add_theme_font_size_override("font_size", 13)
		if h.begins_with("Objectif"):
			hl.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
		elif h.begins_with("NOT") or h.begins_with("AND") or h.begins_with("OR"):
			hl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		elif h.begins_with("Source") or h.begins_with("Attention") or h.begins_with("Cable") or h.begins_with("Ne l"):
			hl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.35))
		elif h.begins_with("Un cable"):
			hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		elif h.begins_with("Vert") or h.begins_with("CIBLE") or h.begins_with("SOURCE"):
			hl.add_theme_color_override("font_color", Color(0.45, 0.85, 0.5))
		else:
			hl.add_theme_color_override("font_color", Color(0.72, 0.78, 0.82))
		hl.position = Vector2(px + 14, hy)
		hl.size = Vector2(pw - 28, 18)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(hl)
		_dynamic.append(hl)
		hy += 21.0

	var btn_w: float = (pw - 40) / 3.0
	_validate_btn = _btn("Valider", Color(0.12, 0.45, 0.18), Color(0.25, 0.6, 0.3))
	_validate_btn.position = Vector2(px + 10, _vp.y - 100)
	_validate_btn.size = Vector2(btn_w, 40)
	_validate_btn.pressed.connect(_on_validate)
	add_child(_validate_btn)
	_dynamic.append(_validate_btn)

	_clear_btn = _btn("Effacer", Color(0.5, 0.18, 0.08), Color(0.65, 0.28, 0.12))
	_clear_btn.position = Vector2(px + 20 + btn_w, _vp.y - 100)
	_clear_btn.size = Vector2(btn_w, 40)
	_clear_btn.pressed.connect(_on_clear_all)
	add_child(_clear_btn)
	_dynamic.append(_clear_btn)

	_reset_btn = _btn("Reset complet", Color(0.45, 0.35, 0.08), Color(0.6, 0.45, 0.15))
	_reset_btn.position = Vector2(px + 30 + btn_w * 2, _vp.y - 100)
	_reset_btn.size = Vector2(btn_w, 40)
	_reset_btn.pressed.connect(_on_reset)
	add_child(_reset_btn)
	_dynamic.append(_reset_btn)

	_retry_btn = _btn(">> Reessayer", Color(0.55, 0.16, 0.06), Color(0.8, 0.32, 0.12))
	_retry_btn.position = Vector2(_vp.x / 2.0 - 120, _vp.y - 75)
	_retry_btn.size = Vector2(240, 48)
	_retry_btn.pressed.connect(_on_retry)
	_retry_btn.visible = false
	add_child(_retry_btn)
	_dynamic.append(_retry_btn)


func _draw_grid() -> void:
	var gc := Color(0.06, 0.08, 0.12, 0.35)
	var sp: float = 40.0
	for x in range(int(_board_origin.x), int(_board_origin.x + _board_size.x), int(sp)):
		var vl := ColorRect.new()
		vl.color = gc
		vl.position = Vector2(x, _board_origin.y)
		vl.size = Vector2(1, _board_size.y)
		vl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vl)
		_dynamic.append(vl)
	for y in range(int(_board_origin.y), int(_board_origin.y + _board_size.y), int(sp)):
		var hl := ColorRect.new()
		hl.color = gc
		hl.position = Vector2(_board_origin.x, y)
		hl.size = Vector2(_board_size.x, 1)
		hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hl)
		_dynamic.append(hl)


func _draw_nodes() -> void:
	for id in _terminals:
		_draw_one_node(id)


func _draw_one_node(id: String) -> void:
	var t: Dictionary = _terminals[id]
	var pos: Vector2 = _node_pos(id)
	var is_on: bool = t.get("powered", false) if t["type"] != NType.SOURCE else t.get("on_default", true)
	var type: int = t["type"]

	if type == NType.AND_GATE or type == NType.OR_GATE or type == NType.NOT_GATE:
		var bg_c: Color
		var br_c: Color
		var txt_c: Color
		var prefix: String
		match type:
			NType.AND_GATE:
				bg_c = Color(0.06, 0.14, 0.38); br_c = Color(0.22, 0.45, 0.85); txt_c = Color(0.55, 0.75, 1.0); prefix = "PORTE\n"
			NType.OR_GATE:
				bg_c = Color(0.22, 0.06, 0.32); br_c = Color(0.50, 0.28, 0.72); txt_c = Color(0.75, 0.55, 1.0); prefix = "PORTE\n"
			NType.NOT_GATE:
				bg_c = Color(0.35, 0.05, 0.05); br_c = Color(0.72, 0.18, 0.18); txt_c = Color(1.0, 0.55, 0.55); prefix = "PORTE\n"

		var panel := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = bg_c
		ps.border_color = br_c
		ps.set_border_width_all(3)
		ps.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", ps)
		panel.position = Vector2(pos.x - GATE_W / 2.0, pos.y - GATE_H / 2.0)
		panel.size = Vector2(GATE_W, GATE_H)
		panel.z_index = 5
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_dynamic.append(panel)

		var pnl_lbl := Label.new()
		pnl_lbl.text = prefix + t["label"]
		pnl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pnl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pnl_lbl.add_theme_font_size_override("font_size", 11)
		pnl_lbl.add_theme_color_override("font_color", txt_c)
		pnl_lbl.position = Vector2(pos.x - GATE_W / 2.0, pos.y - GATE_H / 2.0)
		pnl_lbl.size = Vector2(GATE_W, GATE_H)
		pnl_lbl.z_index = 6
		pnl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pnl_lbl)
		_dynamic.append(pnl_lbl)

		var pin_c := Color(0.55, 0.58, 0.62)
		var pin_w: float = 14.0
		var pin_h: float = 5.0
		if type == NType.AND_GATE or type == NType.OR_GATE:
			for off_y in [-14.0, 14.0]:
				var pin := ColorRect.new()
				pin.color = pin_c
				pin.position = Vector2(pos.x - GATE_W / 2.0 - pin_w + 2, pos.y + off_y - pin_h / 2.0)
				pin.size = Vector2(pin_w, pin_h)
				pin.z_index = 6
				pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(pin)
				_dynamic.append(pin)
		elif type == NType.NOT_GATE:
			var pin := ColorRect.new()
			pin.color = pin_c
			pin.position = Vector2(pos.x - GATE_W / 2.0 - pin_w + 2, pos.y - pin_h / 2.0)
			pin.size = Vector2(pin_w, pin_h)
			pin.z_index = 6
			pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(pin)
			_dynamic.append(pin)

		var pin_out := ColorRect.new()
		pin_out.color = pin_c
		pin_out.position = Vector2(pos.x + GATE_W / 2.0 - 2, pos.y - pin_h / 2.0)
		pin_out.size = Vector2(pin_w, pin_h)
		pin_out.z_index = 6
		pin_out.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pin_out)
		_dynamic.append(pin_out)

		var in_l := Label.new()
		in_l.text = "IN"
		in_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		in_l.add_theme_font_size_override("font_size", 9)
		in_l.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		in_l.position = Vector2(pos.x - GATE_W / 2.0 - 28, pos.y - 22)
		in_l.size = Vector2(22, 14)
		in_l.z_index = 6
		in_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(in_l)
		_dynamic.append(in_l)

		var out_l := Label.new()
		out_l.text = "OUT"
		out_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		out_l.add_theme_font_size_override("font_size", 9)
		out_l.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		out_l.position = Vector2(pos.x + GATE_W / 2.0 + 6, pos.y - 22)
		out_l.size = Vector2(26, 14)
		out_l.z_index = 6
		out_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(out_l)
		_dynamic.append(out_l)

	else:
		var bg_c: Color
		var br_c: Color
		var lbl_c: Color
		var tag: String = ""
		match type:
			NType.SOURCE:
				if is_on:
					bg_c = Color(0.08, 0.35, 0.12); br_c = Color(0.2, 0.7, 0.25); lbl_c = Color(0.4, 1.0, 0.5)
				else:
					bg_c = Color(0.35, 0.06, 0.06); br_c = Color(0.65, 0.12, 0.08); lbl_c = Color(1.0, 0.4, 0.3)
				tag = "SOURCE"
			NType.TARGET:
				if is_on:
					bg_c = Color(0.18, 0.42, 0.08); br_c = Color(0.4, 0.85, 0.25); lbl_c = Color(0.4, 1.0, 0.4)
				else:
					bg_c = Color(0.35, 0.30, 0.04); br_c = Color(0.85, 0.78, 0.15); lbl_c = Color(1.0, 0.92, 0.3)
				tag = "CIBLE"
			NType.JUNCTION:
				bg_c = Color(0.1, 0.1, 0.14); br_c = Color(0.3, 0.3, 0.35); lbl_c = Color(0.6, 0.6, 0.65)
				tag = "RELAIS"

		var panel := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = bg_c
		ps.border_color = br_c
		ps.set_border_width_all(3)
		ps.set_corner_radius_all(int(NODE_R))
		panel.add_theme_stylebox_override("panel", ps)
		panel.position = Vector2(pos.x - NODE_R, pos.y - NODE_R)
		panel.size = Vector2(NODE_R * 2.0, NODE_R * 2.0)
		panel.z_index = 5
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_dynamic.append(panel)

		if type == NType.TARGET:
			_target_panels[id] = panel

		var main_lbl := Label.new()
		main_lbl.text = t["label"]
		main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		main_lbl.add_theme_font_size_override("font_size", 18)
		main_lbl.add_theme_color_override("font_color", lbl_c)
		main_lbl.position = Vector2(pos.x - NODE_R, pos.y - 10)
		main_lbl.size = Vector2(NODE_R * 2.0, 20)
		main_lbl.z_index = 7
		main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(main_lbl)
		_dynamic.append(main_lbl)

		var tag_lbl := Label.new()
		tag_lbl.text = tag
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_font_size_override("font_size", 9)
		tag_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
		tag_lbl.position = Vector2(pos.x - NODE_R, pos.y + NODE_R + 2)
		tag_lbl.size = Vector2(NODE_R * 2.0, 14)
		tag_lbl.z_index = 7
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag_lbl)
		_dynamic.append(tag_lbl)

		if type == NType.SOURCE and not is_on:
			var brk := Label.new()
			brk.text = "(PANNE)"
			brk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			brk.add_theme_font_size_override("font_size", 10)
			brk.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
			brk.position = Vector2(pos.x - 30, pos.y - NODE_R - 16)
			brk.size = Vector2(60, 14)
			brk.z_index = 7
			brk.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(brk)
			_dynamic.append(brk)


func _update_target_visuals() -> void:
	for id in _objectives:
		if not _target_panels.has(id):
			continue
		var panel: PanelContainer = _target_panels[id]
		if not is_instance_valid(panel):
			continue
		var ps: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if not ps:
			continue
		if _terminals[id]["powered"]:
			ps.bg_color = Color(0.18, 0.42, 0.08)
			ps.border_color = Color(0.45, 0.85, 0.25)
		else:
			ps.bg_color = Color(0.35, 0.30, 0.04)
			ps.border_color = Color(0.85, 0.78, 0.15)


func _refresh_cables() -> void:
	for ln in _cable_line_nodes:
		if is_instance_valid(ln):
			ln.queue_free()
	_cable_line_nodes.clear()

	for ln in _preset_line_nodes:
		if is_instance_valid(ln):
			ln.queue_free()
	_preset_line_nodes.clear()

	for pc in _preset_connections:
		var from_id: String = pc["from"]
		var to_id: String = pc["to"]
		var from_on: bool = _terminals[from_id]["powered"]
		var fp: Vector2 = _node_pos(from_id)
		var tp: Vector2 = _node_pos(to_id)
		var fh: float = _node_half(from_id)
		var th: float = _node_half(to_id)
		var dir: Vector2 = (tp - fp).normalized()
		var start: Vector2 = fp + dir * (fh + 4.0)
		var end: Vector2 = tp - dir * (th + 4.0)
		var line := Line2D.new()
		line.add_point(start)
		line.add_point(end)
		line.width = 3.0
		line.default_color = Color(0.35, 0.35, 0.38) if not from_on else Color(0.2, 0.8, 0.35)
		line.z_index = 2
		_cable_layer.add_child(line)
		_preset_line_nodes.append(line)

		var tag := Label.new()
		tag.text = "(fixe)"
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 9)
		tag.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		var mid: Vector2 = (start + end) / 2.0
		tag.position = Vector2(mid.x - 15, mid.y - 16)
		tag.size = Vector2(30, 14)
		tag.z_index = 4
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tag)
		_preset_line_nodes.append(tag)

	for i in range(_connections.size()):
		var conn: Dictionary = _connections[i]
		var from_id: String = conn["from"]
		var to_id: String = conn["to"]
		var from_on: bool = _terminals[from_id]["powered"]
		var fp: Vector2 = _node_pos(from_id)
		var tp: Vector2 = _node_pos(to_id)
		var fh: float = _node_half(from_id)
		var th: float = _node_half(to_id)
		var dir: Vector2 = (tp - fp).normalized()
		var start: Vector2 = fp + dir * (fh + 4.0)
		var end: Vector2 = tp - dir * (th + 4.0)
		var line := Line2D.new()
		line.add_point(start)
		line.add_point(end)
		line.width = CABLE_W_LIT if from_on else CABLE_W
		line.default_color = Color(0.25, 0.92, 0.4) if from_on else Color(0.5, 0.52, 0.48)
		line.z_index = 3
		_cable_layer.add_child(line)
		_cable_line_nodes.append(line)


func _update_budget() -> void:
	if not _budget_lbl:
		return
	var remaining: float = _cable_budget - _cable_used
	_budget_lbl.text = "Cable restant : " + str(int(remaining)) + " / " + str(int(_cable_budget))
	if remaining < _cable_budget * 0.15:
		_budget_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	elif remaining < _cable_budget * 0.35:
		_budget_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	else:
		_budget_lbl.add_theme_color_override("font_color", Color(0.65, 0.85, 0.65))


func _process(_delta: float) -> void:
	if _phase != Phase.PLAYING:
		_preview_line.visible = false
		return
	if _selected_id != "" and _terminals.has(_selected_id):
		_preview_line.visible = true
		var from_pos: Vector2 = _node_pos(_selected_id)
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		_preview_line.clear_points()
		_preview_line.add_point(from_pos)
		_preview_line.add_point(mouse_pos)
	else:
		_preview_line.visible = false


func _input(event: InputEvent) -> void:
	if _phase != Phase.PLAYING:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_phase = Phase.EXITING
		done.emit(false)
		queue_free()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_selected_id = ""
		_preview_line.visible = false
		_status_lbl.text = "Selection annulee"
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos: Vector2 = event.position
		if click_pos.x > _board_size.x + 30.0:
			return
		_handle_left_click(click_pos)
		get_viewport().set_input_as_handled()


func _handle_left_click(pos: Vector2) -> void:
	var clicked: String = ""
	var best_dist: float = 45.0
	for id in _terminals:
		var np: Vector2 = _node_pos(id)
		var d: float = pos.distance_to(np)
		var threshold: float = maxf(_node_half(id) + 15.0, 50.0)
		if d < threshold and d < best_dist:
			best_dist = d
			clicked = id

	if clicked == "":
		var cable_idx: int = _hit_cable(pos)
		if cable_idx >= 0:
			_remove_cable(cable_idx)
			_selected_id = ""
			_preview_line.visible = false
			_status_lbl.text = "Cable retire !"
			_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			_update_budget()
			_propagate_power()
			return
		_selected_id = ""
		_preview_line.visible = false
		_status_lbl.text = "Selection annulee"
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		return

	if _selected_id == "":
		_selected_id = clicked
		_status_lbl.text = "De " + _terminals[clicked]["label"] + " vers..."
		_status_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		return

	if clicked == _selected_id:
		_selected_id = ""
		_preview_line.visible = false
		_status_lbl.text = "Selection annulee"
		_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
		return

	var from_id: String = _selected_id
	var to_id: String = clicked
	_selected_id = ""
	_preview_line.visible = false

	if _conn_exists(from_id, to_id):
		_status_lbl.text = "Cable deja existant"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		return

	var ft: Dictionary = _terminals[from_id]
	var tt: Dictionary = _terminals[to_id]

	var is_preset := false
	for pc in _preset_connections:
		if (pc["from"] == from_id and pc["to"] == to_id) or (pc["from"] == to_id and pc["to"] == from_id):
			is_preset = true
			break
	if is_preset:
		_status_lbl.text = "Ce cable est pre-pose, impossible de le modifier"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		return

	if ft["type"] == NType.TARGET:
		_status_lbl.text = "Les cibles ne canalisent pas vers l'avant"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		return
	if tt["type"] == NType.SOURCE:
		_status_lbl.text = "Les sources ne recoivent pas de cable"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		return

	var dist: float = _node_pos(from_id).distance_to(_node_pos(to_id))
	_cable_used += dist
	if _cable_used > _cable_budget:
		_cable_used -= dist
		_status_lbl.text = "Pas assez de cable !"
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		_update_budget()
		return

	_connections.append({"from": from_id, "to": to_id})
	_status_lbl.text = _terminals[from_id]["label"] + " -> " + _terminals[to_id]["label"] + " connecte"
	_status_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	_update_budget()
	_propagate_power()
	_refresh_cables()


func _hit_cable(pos: Vector2) -> int:
	for i in range(_connections.size()):
		var a: Vector2 = _node_pos(_connections[i]["from"])
		var b: Vector2 = _node_pos(_connections[i]["to"])
		if _point_seg_dist(pos, a, b) < CLICK_CABLE_DIST:
			return i
	return -1


func _point_seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var d: float = ab.dot(ab)
	if d < 0.001:
		return p.distance_to(a)
	var t: float = clampf(ap.dot(ab) / d, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _conn_exists(a: String, b: String) -> bool:
	for c in _connections:
		if (c["from"] == a and c["to"] == b) or (c["from"] == b and c["to"] == a):
			return true
	for pc in _preset_connections:
		if (pc["from"] == a and pc["to"] == b) or (pc["from"] == b and pc["to"] == a):
			return true
	return false


func _remove_cable(idx: int) -> void:
	if idx < 0 or idx >= _connections.size():
		return
	var c: Dictionary = _connections[idx]
	_cable_used -= _node_pos(c["from"]).distance_to(_node_pos(c["to"]))
	_cable_used = maxf(0.0, _cable_used)
	_connections.remove_at(idx)


func _propagate_power() -> void:
	for id in _terminals:
		var t: Dictionary = _terminals[id]
		if t["type"] == NType.SOURCE:
			t["powered"] = t.get("on_default", true)
		else:
			t["powered"] = false

	var all_conns: Array = _connections.duplicate()
	for pc in _preset_connections:
		all_conns.append(pc)

	var ids: Array = _terminals.keys().duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return _terminals[a]["pos"].x < _terminals[b]["pos"].x)

	for _iter in range(10):
		var changed := false
		for id in ids:
			var t: Dictionary = _terminals[id]
			if t["type"] == NType.SOURCE:
				continue
			var ins: Array = []
			for c in all_conns:
				if c["to"] == id:
					ins.append(_terminals[c["from"]]["powered"])
			var np: bool = false
			match t["type"]:
				NType.TARGET, NType.JUNCTION:
					np = ins.has(true)
				NType.AND_GATE:
					if ins.size() >= 2:
						np = true
						for v in ins:
							if not v:
								np = false
								break
					else:
						np = false
				NType.OR_GATE:
					np = ins.has(true)
				NType.NOT_GATE:
					if not ins.is_empty():
						np = not ins[0]
					else:
						np = false
			if t["powered"] != np:
				t["powered"] = np
				changed = true
		if not changed:
			break

	_refresh_cables()
	_update_target_visuals()


func _on_validate() -> void:
	if _phase != Phase.PLAYING:
		return
	_propagate_power()

	var all_met := true
	var unmet: Array = []
	for oid in _objectives:
		if _terminals.has(oid) and not _terminals[oid]["powered"]:
			all_met = false
			unmet.append(_terminals[oid]["label"])

	if all_met:
		_on_round_complete()
	else:
		_phase = Phase.FAILURE
		_status_lbl.text = "Cibles non alimentees : " + ", ".join(unmet)
		_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
		_flash_error()
		_retry_btn.visible = true


func _flash_error() -> void:
	if not is_instance_valid(_bg):
		return
	var tw := create_tween()
	tw.tween_property(_bg, "color", Color(0.15, 0.02, 0.02, 0.98), 0.15)
	tw.tween_property(_bg, "color", Color(0.02, 0.04, 0.08, 0.98), 0.15)
	tw.tween_property(_bg, "color", Color(0.15, 0.02, 0.02, 0.98), 0.15)
	tw.tween_property(_bg, "color", Color(0.02, 0.04, 0.08, 0.98), 0.15)


func _on_clear_all() -> void:
	if _phase != Phase.PLAYING:
		return
	_connections.clear()
	_cable_used = 0.0
	_selected_id = ""
	_preview_line.visible = false
	_update_budget()
	_propagate_power()
	_refresh_cables()
	_status_lbl.text = "Tous les cables retires"
	_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))


func _on_reset() -> void:
	if _phase != Phase.PLAYING:
		return
	_init_round(_current_round)


func _on_retry() -> void:
	if _phase != Phase.FAILURE:
		return
	_retry_btn.visible = false
	_bg.color = Color(0.02, 0.04, 0.08, 0.98)
	_init_round(_current_round)


func _on_round_complete() -> void:
	if _current_round >= TOTAL_ROUNDS:
		_on_all_complete()
		return
	_phase = Phase.ROUND_TRANSITION
	_status_lbl.text = "Panneau " + str(_current_round) + " valide !"
	_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))
	for ln in _cable_line_nodes:
		if is_instance_valid(ln):
			ln.default_color = Color(0.25, 0.95, 0.4)
			ln.width = CABLE_W_LIT
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(_next_round)


func _next_round() -> void:
	_init_round(_current_round + 1)


func _on_all_complete() -> void:
	_phase = Phase.SUCCESS
	_status_lbl.text = "Electricite retablie !"
	_status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))

	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.95, 1.0, 0.0)
	flash.size = _vp
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 50
	add_child(flash)
	_dynamic.append(flash)

	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.8, 0.3).set_trans(Tween.TRANS_SINE)
	ft.tween_property(flash, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE)

	var st := create_tween()
	st.tween_interval(2.5)
	st.tween_callback(_finish)


func _finish() -> void:
	_phase = Phase.EXITING
	done.emit(true)
	queue_free()