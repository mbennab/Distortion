extends Node2D

signal battle_won
signal battle_lost

enum Action { NONE, ATTACK, DEFEND, HEAL }

var player_hp := 100
var player_max_hp := 100
var player_atk := 20
var player_def := 10
var player_defending := false
var heal_available := true

var boss_hp := 150
var boss_max_hp := 150
var boss_atk := 15
var boss_def := 5
var boss_atk_buff := 0

var battle_active := false
var current_action := Action.NONE

@onready var bg_sprite: Sprite2D = $BackgroundContainer/BG
@onready var boss_sprite: AnimatedSprite2D = $BossSprite
@onready var player_sprite: AnimatedSprite2D = $PlayerSprite
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

var btn_attack: Button
var btn_defend: Button
var btn_heal: Button
var btn_container: HBoxContainer

var prev_boss_hp: int
var prev_player_hp: int


func _ready() -> void:
	prev_boss_hp = boss_hp
	prev_player_hp = player_hp
	_setup_ui()
	_update_hp_bars()
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

	player_name_label = Label.new()
	player_name_label.text = "Voyageur"
	player_name_label.add_theme_font_size_override("font_size", 18)
	player_name_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1, 1))
	player_name_label.add_theme_constant_override("outline_size", 1)
	player_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	player_name_label.position = Vector2(vp.x * 0.12, vp.y * 0.72)
	player_name_label.size = Vector2(bar_w + 40, 24)
	ui_layer.add_child(player_name_label)

	player_hp_bar = Panel.new()
	player_hp_bar.position = Vector2(vp.x * 0.12, vp.y * 0.72 + 24)
	player_hp_bar.size = Vector2(bar_w, bar_h)
	player_hp_bar.add_theme_stylebox_override("panel", hp_bar_style)
	ui_layer.add_child(player_hp_bar)

	player_hp_dmg = Panel.new()
	player_hp_dmg.position = Vector2(vp.x * 0.12 + 1, vp.y * 0.72 + 25)
	player_hp_dmg.size = Vector2(bar_w, bar_h)
	player_hp_dmg.add_theme_stylebox_override("panel", hp_damage_style)
	ui_layer.add_child(player_hp_dmg)

	player_hp_fill = Panel.new()
	player_hp_fill.position = Vector2(vp.x * 0.12 + 1, vp.y * 0.72 + 25)
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
	player_hp_text.position = Vector2(vp.x * 0.12, vp.y * 0.72 + 24)
	player_hp_text.size = Vector2(bar_w, bar_h)
	ui_layer.add_child(player_hp_text)

	var msg_panel := Panel.new()
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
	msg_panel.position = Vector2(vp.x * 0.5 - 350, vp.y - 180)
	msg_panel.size = Vector2(700, 70)
	ui_layer.add_child(msg_panel)

	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_font_size_override("font_size", 18)
	msg_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	msg_label.position = Vector2(vp.x * 0.5 - 340, vp.y - 175)
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
	btn_container.position = Vector2(vp.x * 0.5 - 340, vp.y - 100)
	btn_container.size = Vector2(680, 50)
	btn_container.add_theme_constant_override("separation", 16)
	ui_layer.add_child(btn_container)

	var names := ["Attaquer", "Parer", "Soin"]
	var actions := [Action.ATTACK, Action.DEFEND, Action.HEAL]
	var tooltips := ["Attaque avec tes poings", "Réduit les dégâts reçus", "Soigne-toi (1 fois)"]

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

	boss_hp_text.text = "%d/%d" % [boss_hp, boss_max_hp]
	_set_hp_fill(boss_hp_fill, boss_hp_dmg, boss_hp, boss_max_hp, prev_boss_hp)

	player_hp_text.text = "%d/%d" % [player_hp, player_max_hp]
	_set_hp_fill(player_hp_fill, player_hp_dmg, player_hp, player_max_hp, prev_player_hp)


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


func _enable_actions(enabled: bool) -> void:
	btn_attack.disabled = not enabled
	btn_defend.disabled = not enabled
	btn_heal.disabled = not enabled or not heal_available
	if not heal_available:
		btn_heal.text = "Soin (épuisé)"


func _show_message(text: String) -> void:
	msg_label.text = text


func _start_player_turn() -> void:
	player_defending = false
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
	var dmg = maxi(5, player_atk - boss_def / 2 + randi() % 7 - 3)
	boss_hp = maxi(0, boss_hp - dmg)
	_show_message("Vous attaquez et infligez %d dégâts !" % dmg)
	_update_hp_bars()
	await _animate_hp_change(true)
	await get_tree().create_timer(0.5).timeout

	if boss_hp <= 0:
		await _on_victory()
	else:
		await _boss_turn()


func _do_player_defend() -> void:
	player_defending = true
	_show_message("Vous vous préparez à parer l'attaque !")
	await get_tree().create_timer(0.8).timeout
	await _boss_turn()


func _do_player_heal() -> void:
	if not heal_available:
		_show_message("Vous n'avez plus de quoi vous soigner !")
		current_action = Action.NONE
		_enable_actions(true)
		return
	heal_available = false
	var heal = 35
	player_hp = mini(player_max_hp, player_hp + heal)
	_show_message("Vous récupérez %d PV !" % heal)
	_update_hp_bars()
	await _animate_hp_change(false)
	await get_tree().create_timer(0.5).timeout
	await _boss_turn()


func _boss_turn() -> void:
	_show_message("Au tour d'Alfredo...")
	await get_tree().create_timer(0.8).timeout

	var roll := randi() % 10
	if roll < 7:
		var effective_def := player_def * 2 if player_defending else player_def
		var dmg = maxi(5, boss_atk + boss_atk_buff - effective_def / 2 + randi() % 6 - 2)
		player_hp = maxi(0, player_hp - dmg)
		if player_defending:
			_show_message("Alfredo attaque violemment, mais vous parez en partie !\nVous subissez %d dégâts." % dmg)
		else:
			_show_message("Alfredo vous frappe de toutes ses forces !\nVous subissez %d dégâts !" % dmg)
	elif roll < 9:
		boss_atk_buff += 3
		_show_message("Alfredo se concentre et devient plus fort !\nSon attaque augmente !")
	else:
		_show_message("Alfredo ricane : \"Vous croyez pouvoir\nme vaincre, misérable créature ?\"")

	_update_hp_bars()
	await _animate_hp_change(false)
	await get_tree().create_timer(1.0).timeout

	if player_hp <= 0:
		await _on_defeat()
	else:
		_start_player_turn()


func _on_victory() -> void:
	battle_active = false
	_show_message("Victoire ! Alfredo Sinko Nochez est vaincu !")
	_enable_actions(false)

	var tween := create_tween()
	tween.tween_property(boss_sprite, "modulate:a", 0.0, 1.5)
	tween.tween_property(boss_sprite, "position:y", boss_sprite.position.y + 40, 1.5)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	battle_won.emit()


func _on_defeat() -> void:
	battle_active = false
	_show_message("Vous êtes vaincu... Alfredo a gagné...")
	_enable_actions(false)

	var tween := create_tween()
	tween.tween_property(player_sprite, "modulate:a", 0.0, 1.0)
	tween.tween_property(player_sprite, "position:y", player_sprite.position.y + 50, 1.0)
	await tween.finished

	await get_tree().create_timer(1.5).timeout
	battle_lost.emit()
