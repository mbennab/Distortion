extends Node2D

signal battle_won
signal battle_lost

enum Action { NONE, ATTACK, DEFEND, HEAL }

var player_hp := 100
var player_max_hp := 100
var player_atk := 20
var player_def := 10
var player_defending := false
var heals_remaining := 3

var boss_hp := 150
var boss_max_hp := 150
var boss_atk := 15
var boss_def := 5
var boss_atk_buff := 0

var intankables_hp := 200
var intankables_max_hp := 200
var intankables_atk := 8
var prev_intankables_hp: int

var battle_active := false
var current_action := Action.NONE

@onready var bg_sprite: Sprite2D = $BackgroundContainer/BG
@onready var boss_sprite: AnimatedSprite2D = $BossSprite
@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
@onready var boss_p2_sprite: AnimatedSprite2D = $boss_p2
@onready var cheffe_combat_sprite: AnimatedSprite2D = $cheffe_combat
var ui_layer: CanvasLayer

var msg_label: Label
var hp_bar_style: StyleBoxFlat
var hp_fill_style: StyleBoxFlat
var hp_damage_style: StyleBoxFlat
var player_hp_bar: Panel
var player_hp_fill: Panel
var player_hp_dmg: Panel
var player_hp_text: Label
var boss_hp_bar: Panel
var boss_hp_fill: Panel
var boss_hp_dmg: Panel
var boss_hp_text: Label
var player_name_label: Label
var boss_name_label: Label

var msg_panel: Panel
var btn_attack: Button
var btn_defend: Button
var btn_heal: Button
var btn_container: HBoxContainer

var intankables_hp_bar: Panel
var intankables_hp_fill: Panel
var intankables_hp_dmg: Panel
var intankables_hp_text: Label
var intankables_name_label: Label

var prev_boss_hp: int
var prev_player_hp: int
var _flash_rect: ColorRect
var _music_player: AudioStreamPlayer
var _phase2_active := false
var _fade_rect: ColorRect
var _player_original_y: float

var attack_count := 0
var qte_active := false
var qte_keys := []
var qte_current_index := 0
var qte_time_remaining := 3.0
var qte_critical := false
var qte_key_labels := []
var qte_panel: Panel
var qte_prompt: Label
var qte_timer_bar: Panel
var qte_timer_fill: Panel
var qte_timer_fill_style: StyleBoxFlat
var qte_result_label: Label
var qte_time_limit := 3.0
var parry_qte_success := false


func _ready() -> void:
	prev_boss_hp = boss_hp
	prev_player_hp = player_hp
	prev_intankables_hp = intankables_hp
	_setup_ui()
	_update_hp_bars()
	_setup_music()
	boss_p2_sprite.visible = false
	boss_p2_sprite.stop()
	cheffe_combat_sprite.visible = false
	cheffe_combat_sprite.stop()
	_player_original_y = player_sprite.position.y
	await _play_battle_intro()
	battle_active = true
	var tween := create_tween().set_loops(-1)
	tween.tween_property(player_sprite, "position:y", player_sprite.position.y - 8, 0.8)
	tween.tween_property(player_sprite, "position:y", player_sprite.position.y, 0.8)
	_show_message("Alfredo Sinko Nochez vous attaque !")
	await get_tree().create_timer(1.5).timeout
	_start_player_turn()




func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var vp := get_viewport_rect().size

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 20
	add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.size = vp
	flash_layer.add_child(_flash_rect)

	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 30
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.size = vp
	fade_layer.add_child(_fade_rect)

	hp_bar_style = StyleBoxFlat.new()
	hp_bar_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	hp_bar_style.border_width_left = 1
	hp_bar_style.border_width_right = 1
	hp_bar_style.border_width_top = 1
	hp_bar_style.border_width_bottom = 1
	hp_bar_style.border_color = Color(0.3, 0.3, 0.4, 0.8)
	hp_bar_style.corner_radius_top_left = 4
	hp_bar_style.corner_radius_bottom_left = 4
	hp_bar_style.corner_radius_top_right = 4
	hp_bar_style.corner_radius_bottom_right = 4

	hp_fill_style = StyleBoxFlat.new()
	hp_fill_style.bg_color = Color(0.2, 0.9, 0.2, 1.0)
	hp_fill_style.corner_radius_top_left = 3
	hp_fill_style.corner_radius_bottom_left = 3
	hp_fill_style.corner_radius_top_right = 3
	hp_fill_style.corner_radius_bottom_right = 3

	hp_damage_style = StyleBoxFlat.new()
	hp_damage_style.bg_color = Color(0.9, 0.15, 0.15, 0.6)
	hp_damage_style.corner_radius_top_left = 3
	hp_damage_style.corner_radius_bottom_left = 3
	hp_damage_style.corner_radius_top_right = 3
	hp_damage_style.corner_radius_bottom_right = 3

	var bar_w := 260.0
	var bar_h := 24.0

	boss_name_label = Label.new()
	boss_name_label.text = "Alfredo Sinko Nochez"
	boss_name_label.add_theme_font_size_override("font_size", 18)
	boss_name_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3, 1))
	boss_name_label.add_theme_constant_override("outline_size", 1)
	boss_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	boss_name_label.position = Vector2(vp.x * 0.58, vp.y * 0.10)
	boss_name_label.size = Vector2(bar_w + 40, 24)
	ui_layer.add_child(boss_name_label)

	boss_hp_bar = Panel.new()
	boss_hp_bar.position = Vector2(vp.x * 0.58, vp.y * 0.10 + 26)
	boss_hp_bar.size = Vector2(bar_w, bar_h)
	boss_hp_bar.add_theme_stylebox_override("panel", hp_bar_style)
	ui_layer.add_child(boss_hp_bar)

	boss_hp_dmg = Panel.new()
	boss_hp_dmg.position = Vector2(vp.x * 0.58 + 1, vp.y * 0.10 + 27)
	boss_hp_dmg.size = Vector2(bar_w, bar_h)
	boss_hp_dmg.add_theme_stylebox_override("panel", hp_damage_style)
	ui_layer.add_child(boss_hp_dmg)

	boss_hp_fill = Panel.new()
	boss_hp_fill.position = Vector2(vp.x * 0.58 + 1, vp.y * 0.10 + 27)
	boss_hp_fill.size = Vector2(bar_w, bar_h)
	boss_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
	ui_layer.add_child(boss_hp_fill)

	boss_hp_text = Label.new()
	boss_hp_text.text = "%d/%d" % [boss_hp, boss_max_hp]
	boss_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_hp_text.add_theme_font_size_override("font_size", 13)
	boss_hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	boss_hp_text.add_theme_constant_override("outline_size", 1)
	boss_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	boss_hp_text.position = Vector2(vp.x * 0.58, vp.y * 0.10 + 26)
	boss_hp_text.size = Vector2(bar_w, bar_h)
	ui_layer.add_child(boss_hp_text)

	intankables_name_label = Label.new()
	intankables_name_label.text = "Les Intankables"
	intankables_name_label.add_theme_font_size_override("font_size", 18)
	intankables_name_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1, 1))
	intankables_name_label.add_theme_constant_override("outline_size", 1)
	intankables_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	intankables_name_label.position = Vector2(vp.x * 0.06, vp.y * 0.36)
	intankables_name_label.size = Vector2(bar_w + 40, 24)
	intankables_name_label.visible = false
	ui_layer.add_child(intankables_name_label)

	intankables_hp_bar = Panel.new()
	intankables_hp_bar.position = Vector2(vp.x * 0.06, vp.y * 0.36 + 26)
	intankables_hp_bar.size = Vector2(bar_w, bar_h)
	intankables_hp_bar.add_theme_stylebox_override("panel", hp_bar_style)
	intankables_hp_bar.visible = false
	ui_layer.add_child(intankables_hp_bar)

	intankables_hp_dmg = Panel.new()
	intankables_hp_dmg.position = Vector2(vp.x * 0.06 + 1, vp.y * 0.36 + 27)
	intankables_hp_dmg.size = Vector2(bar_w, bar_h)
	intankables_hp_dmg.add_theme_stylebox_override("panel", hp_damage_style)
	intankables_hp_dmg.visible = false
	ui_layer.add_child(intankables_hp_dmg)

	intankables_hp_fill = Panel.new()
	intankables_hp_fill.position = Vector2(vp.x * 0.06 + 1, vp.y * 0.36 + 27)
	intankables_hp_fill.size = Vector2(bar_w, bar_h)
	intankables_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
	intankables_hp_fill.visible = false
	ui_layer.add_child(intankables_hp_fill)

	intankables_hp_text = Label.new()
	intankables_hp_text.text = "%d/%d" % [intankables_hp, intankables_max_hp]
	intankables_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intankables_hp_text.add_theme_font_size_override("font_size", 13)
	intankables_hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	intankables_hp_text.add_theme_constant_override("outline_size", 1)
	intankables_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	intankables_hp_text.position = Vector2(vp.x * 0.06, vp.y * 0.36 + 26)
	intankables_hp_text.size = Vector2(bar_w, bar_h)
	intankables_hp_text.visible = false
	ui_layer.add_child(intankables_hp_text)

	player_name_label = Label.new()
	player_name_label.text = "Voyageur"
	player_name_label.add_theme_font_size_override("font_size", 18)
	player_name_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1, 1))
	player_name_label.add_theme_constant_override("outline_size", 1)
	player_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	player_name_label.position = Vector2(vp.x * 0.06, vp.y * 0.36)
	player_name_label.size = Vector2(bar_w + 40, 24)
	ui_layer.add_child(player_name_label)

	player_hp_bar = Panel.new()
	player_hp_bar.position = Vector2(vp.x * 0.06, vp.y * 0.36 + 26)
	player_hp_bar.size = Vector2(bar_w, bar_h)
	player_hp_bar.add_theme_stylebox_override("panel", hp_bar_style)
	ui_layer.add_child(player_hp_bar)

	player_hp_dmg = Panel.new()
	player_hp_dmg.position = Vector2(vp.x * 0.06 + 1, vp.y * 0.36 + 27)
	player_hp_dmg.size = Vector2(bar_w, bar_h)
	player_hp_dmg.add_theme_stylebox_override("panel", hp_damage_style)
	ui_layer.add_child(player_hp_dmg)

	player_hp_fill = Panel.new()
	player_hp_fill.position = Vector2(vp.x * 0.06 + 1, vp.y * 0.36 + 27)
	player_hp_fill.size = Vector2(bar_w, bar_h)
	player_hp_fill.add_theme_stylebox_override("panel", hp_fill_style)
	ui_layer.add_child(player_hp_fill)

	player_hp_text = Label.new()
	player_hp_text.text = "%d/%d" % [player_hp, player_max_hp]
	player_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_hp_text.add_theme_font_size_override("font_size", 13)
	player_hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	player_hp_text.add_theme_constant_override("outline_size", 1)
	player_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	player_hp_text.position = Vector2(vp.x * 0.06, vp.y * 0.36 + 26)
	player_hp_text.size = Vector2(bar_w, bar_h)
	ui_layer.add_child(player_hp_text)

	msg_panel = Panel.new()
	var msg_style := StyleBoxFlat.new()
	msg_style.bg_color = Color(0, 0, 0, 0.8)
	msg_style.border_width_left = 2
	msg_style.border_width_right = 2
	msg_style.border_width_top = 2
	msg_style.border_width_bottom = 2
	msg_style.border_color = Color(0.4, 0.6, 1, 0.5)
	msg_style.corner_radius_top_left = 6
	msg_style.corner_radius_top_right = 6
	msg_style.corner_radius_bottom_left = 6
	msg_style.corner_radius_bottom_right = 6
	msg_panel.add_theme_stylebox_override("panel", msg_style)
	msg_panel.position = Vector2(vp.x - 710, vp.y - 180)
	msg_panel.size = Vector2(700, 70)
	ui_layer.add_child(msg_panel)

	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	msg_label.position = Vector2(vp.x - 700, vp.y - 175)
	msg_label.size = Vector2(680, 60)
	msg_label.text = ""
	ui_layer.add_child(msg_label)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.12, 0.2, 0.9)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.3, 0.5, 0.9, 0.6)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.2, 0.25, 0.4, 0.95)
	btn_hover.border_width_left = 1
	btn_hover.border_width_right = 1
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.border_color = Color(0.5, 0.7, 1, 1)
	btn_hover.corner_radius_top_left = 4
	btn_hover.corner_radius_top_right = 4
	btn_hover.corner_radius_bottom_left = 4
	btn_hover.corner_radius_bottom_right = 4

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.05, 0.05, 0.1, 0.5)

	btn_container = HBoxContainer.new()
	btn_container.position = Vector2(vp.x - 660, vp.y - 100)
	btn_container.size = Vector2(640, 50)
	btn_container.add_theme_constant_override("separation", 16)
	ui_layer.add_child(btn_container)

	var names := ["Attaquer", "Parer", "Soin"]
	var actions := [Action.ATTACK, Action.DEFEND, Action.HEAL]
	var tooltips := ["Attaque avec tes poings", "Réduit les dégâts reçus", "Soigne-toi (3 fois max)"]

	for i in 3:
		var btn := Button.new()
		btn.text = names[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(200, 50)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_stylebox_override("disabled", btn_disabled)
		btn.tooltip_text = tooltips[i]
		btn.pressed.connect(_on_action_pressed.bind(actions[i]))
		btn_container.add_child(btn)

	btn_attack = btn_container.get_child(0)
	btn_defend = btn_container.get_child(1)
	btn_heal = btn_container.get_child(2)

	qte_timer_fill_style = StyleBoxFlat.new()
	qte_timer_fill_style.bg_color = Color(0.2, 0.9, 0.2, 1.0)

	qte_panel = Panel.new()
	var qte_style := StyleBoxFlat.new()
	qte_style.bg_color = Color(0, 0, 0, 0.85)
	qte_style.border_width_left = 2
	qte_style.border_width_right = 2
	qte_style.border_width_top = 2
	qte_style.border_width_bottom = 2
	qte_style.border_color = Color(0.9, 0.8, 0.1, 0.8)
	qte_style.corner_radius_top_left = 8
	qte_style.corner_radius_top_right = 8
	qte_style.corner_radius_bottom_left = 8
	qte_style.corner_radius_bottom_right = 8
	qte_panel.add_theme_stylebox_override("panel", qte_style)
	qte_panel.position = Vector2(vp.x / 2.0 - 200, vp.y / 2.0 - 60)
	qte_panel.size = Vector2(400, 120)
	qte_panel.visible = false
	ui_layer.add_child(qte_panel)

	qte_prompt = Label.new()
	qte_prompt.text = "QTE ! Appuyez sur les touches dans l'ordre !"
	qte_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte_prompt.add_theme_font_size_override("font_size", 16)
	qte_prompt.add_theme_color_override("font_color", Color(0.9, 0.8, 0.1, 1))
	qte_prompt.position = Vector2(vp.x / 2.0 - 180, vp.y / 2.0 - 50)
	qte_prompt.size = Vector2(360, 30)
	qte_prompt.visible = false
	ui_layer.add_child(qte_prompt)

	qte_key_labels = []
	var key_start_x := vp.x / 2.0 - 80
	for i in 3:
		var label := Label.new()
		label.text = "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 32)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.position = Vector2(key_start_x + i * 80, vp.y / 2.0 - 10)
		label.size = Vector2(60, 50)
		label.visible = false
		ui_layer.add_child(label)
		qte_key_labels.append(label)

	qte_timer_bar = Panel.new()
	qte_timer_bar.position = Vector2(vp.x / 2.0 - 180, vp.y / 2.0 + 45)
	qte_timer_bar.size = Vector2(360, 8)
	var timer_bg_style := StyleBoxFlat.new()
	timer_bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	qte_timer_bar.add_theme_stylebox_override("panel", timer_bg_style)
	qte_timer_bar.visible = false
	ui_layer.add_child(qte_timer_bar)

	qte_timer_fill = Panel.new()
	qte_timer_fill.position = Vector2(vp.x / 2.0 - 180, vp.y / 2.0 + 45)
	qte_timer_fill.size = Vector2(360, 8)
	qte_timer_fill.add_theme_stylebox_override("panel", qte_timer_fill_style)
	qte_timer_fill.visible = false
	ui_layer.add_child(qte_timer_fill)

	qte_result_label = Label.new()
	qte_result_label.text = ""
	qte_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qte_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qte_result_label.add_theme_font_size_override("font_size", 44)
	qte_result_label.add_theme_constant_override("outline_size", 4)
	qte_result_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	qte_result_label.position = Vector2(vp.x / 2.0 - 250, vp.y / 2.0 - 130)
	qte_result_label.size = Vector2(500, 70)
	qte_result_label.visible = false
	ui_layer.add_child(qte_result_label)


func _set_hp_fill(fill: Panel, damage: Panel, current: int, max_hp: int, prev: int) -> void:
	var bar_w := 258.0
	var ratio := float(current) / float(max_hp)
	var prev_ratio := float(prev) / float(max_hp)
	var w := maxf(bar_w * ratio, 0.0)
	var prev_w := maxf(bar_w * prev_ratio, 0.0)

	fill.size = Vector2(w, 22)

	if current > prev:
		damage.size = Vector2(0, 22)
		damage.visible = false
	elif prev > current:
		damage.size = Vector2(prev_w, 22)
		damage.visible = true

	var c: Color
	if ratio > 0.5:
		c = Color(0.2, 0.9, 0.2)
	elif ratio > 0.25:
		c = Color(0.9, 0.85, 0.1)
	else:
		c = Color(0.9, 0.15, 0.15)
	hp_fill_style.bg_color = c


func _update_hp_bars() -> void:
	prev_boss_hp = boss_hp
	prev_player_hp = player_hp
	prev_intankables_hp = intankables_hp

	boss_hp_text.text = "%d/%d" % [boss_hp, boss_max_hp]
	_set_hp_fill(boss_hp_fill, boss_hp_dmg, boss_hp, boss_max_hp, prev_boss_hp)

	player_hp_text.text = "%d/%d" % [player_hp, player_max_hp]
	_set_hp_fill(player_hp_fill, player_hp_dmg, player_hp, player_max_hp, prev_player_hp)

	intankables_hp_text.text = "%d/%d" % [intankables_hp, intankables_max_hp]
	_set_hp_fill(intankables_hp_fill, intankables_hp_dmg, intankables_hp, intankables_max_hp, prev_intankables_hp)


func _animate_hp_change(is_boss: bool) -> void:
	var fill := boss_hp_fill if is_boss else player_hp_fill
	var damage := boss_hp_dmg if is_boss else player_hp_dmg
	var current := boss_hp if is_boss else player_hp
	var max_hp := boss_max_hp if is_boss else player_max_hp
	var prev := prev_boss_hp if is_boss else prev_player_hp

	if prev <= current:
		damage.visible = false
		return

	var bar_w := 258.0
	var target_ratio := float(current) / float(max_hp)
	var prev_ratio := float(prev) / float(max_hp)
	var target_w := maxf(bar_w * target_ratio, 0.0)
	var prev_w := maxf(bar_w * prev_ratio, 0.0)

	fill.size = Vector2(target_w, 22)

	damage.size = Vector2(prev_w, 22)
	damage.visible = true

	var tween := create_tween()
	tween.tween_method(func(w: float): damage.size.x = w, prev_w, target_w, 0.6)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	await tween.finished
	damage.visible = false


func _animate_hp_change_intankables() -> void:
	var prev := prev_intankables_hp
	if prev <= intankables_hp:
		intankables_hp_dmg.visible = false
		return

	var bar_w := 258.0
	var target_ratio := float(intankables_hp) / float(intankables_max_hp)
	var prev_ratio := float(prev) / float(intankables_max_hp)
	var target_w := maxf(bar_w * target_ratio, 0.0)
	var prev_w := maxf(bar_w * prev_ratio, 0.0)

	intankables_hp_fill.size = Vector2(target_w, 22)
	intankables_hp_dmg.size = Vector2(prev_w, 22)
	intankables_hp_dmg.visible = true

	var tween := create_tween()
	tween.tween_method(func(w: float): intankables_hp_dmg.size.x = w, prev_w, target_w, 0.6)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	await tween.finished
	intankables_hp_dmg.visible = false


func _enable_actions(enabled: bool) -> void:
	btn_attack.disabled = not enabled
	btn_defend.disabled = not enabled
	btn_heal.disabled = not enabled or heals_remaining <= 0
	if heals_remaining <= 0:
		btn_heal.text = "Soin (épuisé)"
	else:
		btn_heal.text = "Soin (%d/3)" % heals_remaining


func _show_message(text: String) -> void:
	msg_label.text = text


func _play_battle_intro() -> void:
	var boss_target := boss_sprite.position
	var player_target := player_sprite.position
	var boss_name_target := boss_name_label.position
	var boss_bar_target := boss_hp_bar.position
	var boss_dmg_target := boss_hp_dmg.position
	var boss_fill_target := boss_hp_fill.position
	var boss_text_target := boss_hp_text.position
	var player_name_target := player_name_label.position
	var player_bar_target := player_hp_bar.position
	var player_dmg_target := player_hp_dmg.position
	var player_fill_target := player_hp_fill.position
	var player_text_target := player_hp_text.position
	var msg_panel_target := msg_panel.position
	var msg_label_target := msg_label.position
	var btn_target := btn_container.position

	boss_sprite.position.x += 800
	player_sprite.position.x -= 600

	var ui_offset_right := 600.0
	boss_name_label.position.x += ui_offset_right
	boss_hp_bar.position.x += ui_offset_right
	boss_hp_dmg.position.x += ui_offset_right
	boss_hp_fill.position.x += ui_offset_right
	boss_hp_text.position.x += ui_offset_right

	var ui_offset_left := 400.0
	player_name_label.position.x -= ui_offset_left
	player_hp_bar.position.x -= ui_offset_left
	player_hp_dmg.position.x -= ui_offset_left
	player_hp_fill.position.x -= ui_offset_left
	player_hp_text.position.x -= ui_offset_left

	msg_panel.position.y += 200
	msg_label.position.y += 200
	btn_container.position.y += 200

	_flash_rect.color = Color(1, 1, 1, 1)

	await get_tree().create_timer(0.15).timeout

	var intro_tween := create_tween().set_parallel(true)
	intro_tween.tween_property(_flash_rect, "color:a", 0.0, 0.4)
	intro_tween.tween_property(boss_sprite, "position", boss_target, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	intro_tween.tween_property(player_sprite, "position", player_target, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await intro_tween.finished

	var ui_tween := create_tween().set_parallel(true)
	ui_tween.tween_property(boss_name_label, "position", boss_name_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(boss_hp_bar, "position", boss_bar_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(boss_hp_dmg, "position", boss_dmg_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(boss_hp_fill, "position", boss_fill_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(boss_hp_text, "position", boss_text_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(player_name_label, "position", player_name_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(player_hp_bar, "position", player_bar_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(player_hp_dmg, "position", player_dmg_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(player_hp_fill, "position", player_fill_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(player_hp_text, "position", player_text_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(msg_panel, "position", msg_panel_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(msg_label, "position", msg_label_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	ui_tween.tween_property(btn_container, "position", btn_target, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await ui_tween.finished


func _setup_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -12.0
	var stream := load("res://art/Futur/musique_final_futur.mp3") as AudioStream
	if stream:
		_music_player.stream = stream
		_music_player.finished.connect(_music_player.play)
	add_child(_music_player)
	_music_player.play()


func _trigger_phase2() -> void:
	battle_active = false
	_enable_actions(false)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 1.0)
	await tween.finished

	boss_sprite.visible = false
	boss_p2_sprite.visible = true
	boss_p2_sprite.play()

	cheffe_combat_sprite.visible = true
	cheffe_combat_sprite.play()
	cheffe_combat_sprite.position = Vector2(cheffe_combat_sprite.position.x, cheffe_combat_sprite.position.y)

	player_name_label.visible = false
	player_hp_bar.visible = false
	player_hp_dmg.visible = false
	player_hp_fill.visible = false
	player_hp_text.visible = false

	intankables_name_label.visible = true
	intankables_hp_bar.visible = true
	intankables_hp_dmg.visible = true
	intankables_hp_fill.visible = true
	intankables_hp_text.visible = true

	player_sprite.position.y = _player_original_y - 200

	var vp := get_viewport_rect().size
	var text_label := Label.new()
	text_label.text = "La Distortion intervient et modifie la réalité..."
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 24)
	text_label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0, 1))
	text_label.add_theme_constant_override("outline_size", 2)
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	text_label.custom_minimum_size = Vector2(700, 0)
	text_label.position = Vector2(vp.x / 2.0 - 350, vp.y / 2.0 - 60)
	text_label.size = Vector2(700, 120)
	_fade_rect.get_parent().add_child(text_label)

	await get_tree().create_timer(2.5).timeout

	if is_instance_valid(text_label):
		text_label.queue_free()

	_phase2_active = true
	boss_hp = 250
	boss_max_hp = 250
	boss_atk = 15
	boss_atk_buff = 0
	intankables_hp = mini(250, player_hp + intankables_hp)
	intankables_max_hp = 250
	intankables_name_label.text = "Voyageur + Intankables"
	prev_boss_hp = boss_hp
	prev_player_hp = player_hp
	prev_intankables_hp = intankables_hp
	_update_hp_bars()

	tween = create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, 1.0)
	await tween.finished

	battle_active = true
	_show_message("Alfredo Sinko Nochez, amplifié par la Distortion !")
	await get_tree().create_timer(1.0).timeout
	_start_player_turn()


func _start_player_turn() -> void:
	player_defending = false
	parry_qte_success = false
	current_action = Action.NONE
	_enable_actions(true)
	_show_message("Que voulez-vous faire ?")


func _on_action_pressed(action: Action) -> void:
	if not battle_active or current_action != Action.NONE:
		return
	current_action = action
	_enable_actions(false)

	match action:
		Action.ATTACK:
			await _do_player_attack()
		Action.DEFEND:
			await _do_player_defend()
		Action.HEAL:
			await _do_player_heal()


func _do_player_attack() -> void:
	attack_count += 1
	var is_critical := false
	if attack_count % 5 == 0:
		_start_qte(3, 3.0)
		while qte_active:
			await get_tree().process_frame
		is_critical = qte_critical

	var dmg = maxi(5, player_atk - boss_def / 2 + randi() % 7 - 3)
	if _phase2_active:
		dmg = ceili(dmg * 1.07)
	if is_critical:
		dmg *= 2
		boss_hp = maxi(0, boss_hp - dmg)
		_show_message("Coup critique ! Vous infligez %d dégâts !" % dmg)
	else:
		boss_hp = maxi(0, boss_hp - dmg)
		_show_message("Vous attaquez et infligez %d dégâts !" % dmg)
	_update_hp_bars()
	await _animate_hp_change(true)
	await get_tree().create_timer(1.0).timeout

	if boss_hp <= 0:
		if not _phase2_active:
			await _trigger_phase2()
		else:
			await _on_victory()
	else:
		await _boss_turn()


func _do_player_defend() -> void:
	player_defending = true
	parry_qte_success = false
	_start_qte(2, 2.0)
	while qte_active:
		await get_tree().process_frame
	parry_qte_success = qte_critical
	if parry_qte_success:
		_show_message("Parade parfaite ! Vous vous préparez à contrer l'attaque !")
	else:
		_show_message("Vous vous préparez à parer l'attaque !")
	await get_tree().create_timer(1.0).timeout
	await _boss_turn()


func _do_player_heal() -> void:
	if heals_remaining <= 0:
		_show_message("Vous n'avez plus de quoi vous soigner !")
		current_action = Action.NONE
		_enable_actions(true)
		return
	heals_remaining -= 1
	var heal = 35
	if _phase2_active:
		intankables_hp = mini(intankables_max_hp, intankables_hp + heal)
	else:
		player_hp = mini(player_max_hp, player_hp + heal)
	_show_message("Vous récupérez %d PV ! (encore %d/3)" % [heal, heals_remaining])
	_update_hp_bars()
	if _phase2_active:
		await _animate_hp_change_intankables()
	else:
		await _animate_hp_change(false)
	await get_tree().create_timer(1.0).timeout
	await _boss_turn()


func _boss_turn() -> void:
	_show_message("Au tour d'Alfredo...")
	await get_tree().create_timer(1.0).timeout

	var roll := randi() % 10
	var phase2_dmg_bonus := 7 if _phase2_active else 0
	var dmg_mult := 1.50 if _phase2_active else 1.05
	if roll < 7:
		if randf() < 0.1:
			_show_message("Alfredo charge, mais trébuche et rate complètement son attaque !")
		elif player_defending and parry_qte_success:
			_show_message("Parade parfaite ! Vous neutralisez l'attaque d'Alfredo !\nAucun dégât subi !")
		else:
			var effective_def := player_def * 2 if player_defending else player_def
			var dmg = maxi(5, ceili((boss_atk + boss_atk_buff + phase2_dmg_bonus - effective_def / 2 + randi() % 6 - 2) * dmg_mult))
			if _phase2_active:
				intankables_hp = maxi(0, intankables_hp - dmg)
			else:
				player_hp = maxi(0, player_hp - dmg)
			if player_defending:
				_show_message("Alfredo attaque violemment, mais vous parez en partie !\nVous subissez %d dégâts." % dmg)
			else:
				_show_message("Alfredo vous frappe de toutes ses forces !\nVous subissez %d dégâts !" % dmg)
	elif roll < 9:
		boss_atk_buff += 3
		if _phase2_active:
			_show_message("La Distortion alimente la rage d'Alfredo !\nSon attaque augmente !")
		else:
			_show_message("Alfredo se concentre et devient plus fort !\nSon attaque augmente !")
	else:
		if _phase2_active:
			_show_message("Alfredo rugit : \"La Distortion\nme rend plus fort, MISÉRABLE !\"")
		else:
			_show_message("Alfredo ricane : \"Vous croyez pouvoir\nme vaincre, misérable créature ?\"")

	_update_hp_bars()
	if _phase2_active:
		await _animate_hp_change_intankables()
	else:
		await _animate_hp_change(false)
	await get_tree().create_timer(1.0).timeout

	if _phase2_active:
		if intankables_hp <= 0:
			await _on_defeat()
			return
	else:
		if player_hp <= 0:
			await _on_defeat()
			return

	_start_player_turn()


func _process(delta: float) -> void:
	if not qte_active:
		return
	qte_time_remaining -= delta
	var ratio := clampf(qte_time_remaining / qte_time_limit, 0.0, 1.0)
	qte_timer_fill.size.x = 360.0 * ratio
	if ratio > 0.5:
		qte_timer_fill_style.bg_color = Color(0.2, 0.9, 0.2, 1.0)
	elif ratio > 0.25:
		qte_timer_fill_style.bg_color = Color(0.9, 0.85, 0.1, 1.0)
	else:
		qte_timer_fill_style.bg_color = Color(0.9, 0.15, 0.15, 1.0)
	if qte_time_remaining <= 0:
		_complete_qte(false)


func _unhandled_input(event: InputEvent) -> void:
	if not qte_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == qte_keys[qte_current_index]:
			qte_key_labels[qte_current_index].add_theme_color_override("font_color", Color(0, 1, 0, 1))
			qte_current_index += 1
			if qte_current_index >= qte_keys.size():
				_complete_qte(true)
		else:
			_complete_qte(false)


func _generate_qte_keys(count: int = 3) -> Array:
	var pool := [KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_M, KEY_N, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T, KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z]
	pool.shuffle()
	return pool.slice(0, count)


func _start_qte(key_count: int = 3, time_limit: float = 3.0) -> void:
	qte_active = true
	qte_critical = false
	qte_current_index = 0
	qte_time_limit = time_limit
	qte_time_remaining = time_limit
	qte_keys = _generate_qte_keys(key_count)

	for i in 3:
		qte_key_labels[i].visible = i < key_count
		if i < key_count:
			qte_key_labels[i].text = OS.get_keycode_string(qte_keys[i])
			qte_key_labels[i].add_theme_color_override("font_color", Color(1, 1, 1, 1))

	qte_panel.visible = true
	qte_prompt.visible = true
	qte_timer_bar.visible = true
	qte_timer_fill.visible = true
	qte_timer_fill.size.x = 360.0
	qte_result_label.visible = false

	_enable_actions(false)
	_show_message("QTE ! Appuyez sur les touches dans l'ordre !")


func _complete_qte(success: bool) -> void:
	qte_active = false
	qte_critical = success

	for label in qte_key_labels:
		label.visible = false

	qte_panel.visible = false
	qte_prompt.visible = false
	qte_timer_bar.visible = false
	qte_timer_fill.visible = false

	if success:
		qte_result_label.text = "COUP CRITIQUE !"
		qte_result_label.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	else:
		qte_result_label.text = "ÉCHEC..."
		qte_result_label.add_theme_color_override("font_color", Color(1, 0, 0, 1))
	qte_result_label.visible = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(qte_result_label):
		qte_result_label.visible = false


func _on_victory() -> void:
	battle_active = false
	_music_player.stop()
	_enable_actions(false)

	if _phase2_active:
		_show_message("Victoire ! Les forces alliées\nont triomphé d'Alfredo !")
	else:
		_show_message("Victoire ! Alfredo Sinko Nochez est vaincu !")

	var tween := create_tween()
	if _phase2_active:
		tween.parallel().tween_property(boss_p2_sprite, "modulate:a", 0.0, 1.5)
		tween.parallel().tween_property(boss_p2_sprite, "position:y", boss_p2_sprite.position.y + 40, 1.5)
	else:
		tween.parallel().tween_property(boss_sprite, "modulate:a", 0.0, 1.5)
		tween.parallel().tween_property(boss_sprite, "position:y", boss_sprite.position.y + 40, 1.5)
	await tween.finished

	msg_panel.visible = false
	msg_label.visible = false
	btn_container.visible = false
	player_name_label.visible = false
	player_hp_bar.visible = false
	player_hp_dmg.visible = false
	player_hp_fill.visible = false
	player_hp_text.visible = false
	boss_name_label.visible = false
	boss_hp_bar.visible = false
	boss_hp_dmg.visible = false
	boss_hp_fill.visible = false
	boss_hp_text.visible = false
	if _phase2_active:
		intankables_name_label.visible = false
		intankables_hp_bar.visible = false
		intankables_hp_dmg.visible = false
		intankables_hp_fill.visible = false
		intankables_hp_text.visible = false

	var vp := get_viewport_rect().size

	var tween2 := create_tween()
	tween2.tween_property(_fade_rect, "color", Color(0, 0, 0, 1), 1.0)
	await tween2.finished

	var victory_layer := CanvasLayer.new()
	victory_layer.layer = 25
	add_child(victory_layer)

	var victory_sprite := Sprite2D.new()
	victory_sprite.texture = load("res://art/Futur/victoire_futur1.png")
	victory_sprite.centered = false
	var tex_size := victory_sprite.texture.get_size()
	var s := maxf(vp.x / tex_size.x, vp.y / tex_size.y)
	victory_sprite.scale = Vector2(s, s)
	victory_sprite.position = Vector2.ZERO
	victory_layer.add_child(victory_sprite)

	var text_panel := Panel.new()
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = Color(0, 0, 0, 0.75)
	text_style.border_width_left = 2
	text_style.border_width_right = 2
	text_style.border_width_top = 2
	text_style.border_width_bottom = 2
	text_style.border_color = Color(1, 1, 1, 0.4)
	text_style.corner_radius_top_left = 6
	text_style.corner_radius_top_right = 6
	text_style.corner_radius_bottom_left = 6
	text_style.corner_radius_bottom_right = 6
	text_panel.add_theme_stylebox_override("panel", text_style)
	text_panel.position = Vector2(vp.x * 0.1, vp.y * 0.8)
	text_panel.size = Vector2(vp.x * 0.8, 80)
	victory_layer.add_child(text_panel)

	var text_label := Label.new()
	text_label.text = "Après ce combat rude, la distortion du futur est réglée, une belle victoire pour l'équipe !"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 16)
	text_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	text_label.add_theme_constant_override("outline_size", 1)
	text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	text_label.position = Vector2(vp.x * 0.1 + 10, vp.y * 0.8 + 5)
	text_label.size = Vector2(vp.x * 0.8 - 20, 70)
	victory_layer.add_child(text_label)

	var tween3 := create_tween()
	tween3.tween_property(_fade_rect, "color:a", 0.0, 0.8)
	await tween3.finished

	var slide_tween := create_tween()
	slide_tween.tween_property(victory_sprite, "position:x", -50, 5.0)

	await get_tree().create_timer(5.0).timeout
	battle_won.emit()


func _on_defeat() -> void:
	battle_active = false
	_music_player.stop()
	if _phase2_active:
		_show_message("Vous êtes vaincu... Alfredo a triomphé\nde vos forces combinées...")
	else:
		_show_message("Vous êtes vaincu... Alfredo a gagné...")
	_enable_actions(false)

	var tween := create_tween()
	tween.tween_property(player_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_property(player_sprite, "position:y", player_sprite.position.y + 50, 1.0)
	if _phase2_active:
		tween.parallel().tween_property(cheffe_combat_sprite, "modulate:a", 0.0, 1.0)
		tween.parallel().tween_property(cheffe_combat_sprite, "position:y", cheffe_combat_sprite.position.y + 50, 1.0)
	await tween.finished

	await get_tree().create_timer(1.5).timeout
	battle_lost.emit()
