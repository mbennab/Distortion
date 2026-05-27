extends CanvasLayer

signal done(success: bool)

enum Side { UP = 0, RIGHT = 1, DOWN = 2, LEFT = 3 }
enum PipeType { STRAIGHT, ELBOW, T_JUNCTION, CROSS }
enum Phase { PLAYING, ANIMATING, ROUND_TRANSITION, BLOCKED, LEAK, EXITING }

const TILE_SIZE := 56
const TILE_GAP := 3
const TOTAL_ROUNDS := 3
const FLUID_SPEED := 0.06
const FLUID_DOT_COUNT := 3

var grid_cols: int = 5
var grid_rows: int = 4
var grid: Array = []
var _source_row := 0
var _drain_row := 0
var _drain_rows: Array = []
var _phase: int = Phase.PLAYING
var _current_round := 1

var _pipe_sprites: Array = []
var _cell_bg: Array = []
var _grid_origin := Vector2.ZERO
var _dynamic_nodes: Array = []
var _fluid_dots: Array = []

var _bg: ColorRect
var _grid_panel: PanelContainer
var _round_label: Label
var _status_label: Label
var _send_btn: Button
var _retry_btn: Button
var _hint_label: Label
var _source_marker: ColorRect
var _drain_marker: ColorRect

var _tex_straight: Texture2D
var _tex_elbow: Texture2D
var _tex_t_junction: Texture2D
var _tex_cross: Texture2D

var _all_configs: Array = [
	{"cols": 6, "rows": 5, "min_bends": 3},
	{"cols": 7, "rows": 6, "min_bends": 5},
	{"cols": 8, "rows": 6, "min_bends": 6, "num_drains": 2},
]
var _round_configs: Array = []
var _current_config: Dictionary = {}


func _ready() -> void:
	layer = 129
	process_mode = PROCESS_MODE_ALWAYS
	_load_textures()
	if _tex_straight == null and _tex_elbow == null and _tex_t_junction == null and _tex_cross == null:
		push_error("MiniJeuTuyau: no textures loaded, aborting")
		done.emit(false)
		call_deferred("queue_free")
		return
	_pick_round_configs()
	if _round_configs.size() < TOTAL_ROUNDS:
		push_error("MiniJeuTuyau: not enough round configs, aborting")
		done.emit(false)
		call_deferred("queue_free")
		return
	_init_round(1)


func _load_textures() -> void:
	_tex_straight = load("res://art/Present/droite_tuyau.png")
	_tex_elbow = load("res://art/Present/coude_tuyau.png")
	_tex_t_junction = load("res://art/Present/T_tuyau.png")
	_tex_cross = load("res://art/Present/tuyau_croix.png")


func _pick_round_configs() -> void:
	var shuffled: Array = []
	for i in range(_all_configs.size()):
		shuffled.append(_all_configs[i])
	shuffled.shuffle()
	_round_configs.clear()
	for i in range(TOTAL_ROUNDS):
		_round_configs.append(shuffled[i])
	_round_configs.sort_custom(_compare_configs_by_size)


func _compare_configs_by_size(a, b) -> bool:
	var da: Dictionary = a
	var db: Dictionary = b
	return int(da["cols"]) * int(da["rows"]) < int(db["cols"]) * int(db["rows"])


func _init_round(round_num: int) -> void:
	_current_round = round_num
	if round_num - 1 >= _round_configs.size():
		push_error("MiniJeuTuyau: round number out of range")
		_phase = Phase.EXITING
		done.emit(false)
		call_deferred("queue_free")
		return
	_current_config = _round_configs[round_num - 1]
	grid_cols = int(_current_config["cols"])
	grid_rows = int(_current_config["rows"])
	_phase = Phase.PLAYING
	_fluid_dots.clear()
	_generate_puzzle()
	_clear_dynamic_nodes()
	_build_ui()
	_update_sprites()


func _clear_dynamic_nodes() -> void:
	for node in _dynamic_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_dynamic_nodes.clear()
	_pipe_sprites.clear()
	_cell_bg.clear()
	_fluid_dots.clear()


func _v2key(v: Vector2i) -> String:
	return str(v.x) + "," + str(v.y)


func _generate_puzzle() -> void:
	var min_bends_value: int = int(_current_config.get("min_bends", 2))
	var num_drains: int = int(_current_config.get("num_drains", 1))
	
	var main_path: Array = []
	var branch_path: Array = []
	
	for outer_try in range(30):
		_source_row = randi() % grid_rows
		_drain_row = randi() % grid_rows
		
		main_path = []
		for _attempt in range(50):
			main_path = _create_path()
			if _count_bends(main_path) >= min_bends_value:
				break
		
		_drain_rows.clear()
		_drain_rows.append(_drain_row)
		
		branch_path = []
		if num_drains >= 2:
			branch_path = _create_branch_path(main_path)
			if branch_path.size() > 1:
				var branch_last: Vector2i = branch_path[branch_path.size() - 1]
				if not _drain_rows.has(branch_last.y):
					_drain_rows.append(branch_last.y)
				else:
					branch_path = []
			else:
				branch_path = []
		
		# Si on voulait 2 drains mais qu'on a echoue, on regenere le main_path
		if num_drains >= 2 and branch_path.is_empty():
			continue
		
		break

	var cell_connections: Dictionary = {}

	for i in range(main_path.size()):
		var cell: Vector2i = main_path[i]
		if not cell_connections.has(cell):
			cell_connections[cell] = []
		if i == 0:
			cell_connections[cell].append(Side.LEFT)
		if i > 0:
			var prev: Vector2i = main_path[i - 1]
			var side: int = _diff_to_side(prev - cell)
			if not cell_connections[cell].has(side):
				cell_connections[cell].append(side)
		if i < main_path.size() - 1:
			var next: Vector2i = main_path[i + 1]
			var side: int = _diff_to_side(next - cell)
			if not cell_connections[cell].has(side):
				cell_connections[cell].append(side)

	for i in range(branch_path.size()):
		var cell: Vector2i = branch_path[i]
		if not cell_connections.has(cell):
			cell_connections[cell] = []
		if i > 0:
			var prev: Vector2i = branch_path[i - 1]
			var side: int = _diff_to_side(prev - cell)
			if not cell_connections[cell].has(side):
				cell_connections[cell].append(side)
		if i < branch_path.size() - 1:
			var next: Vector2i = branch_path[i + 1]
			var side: int = _diff_to_side(next - cell)
			if not cell_connections[cell].has(side):
				cell_connections[cell].append(side)

	for drain_y in _drain_rows:
		var drain_cell := Vector2i(grid_cols - 1, drain_y)
		if cell_connections.has(drain_cell):
			if not cell_connections[drain_cell].has(Side.RIGHT):
				cell_connections[drain_cell].append(Side.RIGHT)

	grid.clear()
	grid.resize(grid_rows)
	for r in range(grid_rows):
		grid[r] = []
		grid[r].resize(grid_cols)
		for c in range(grid_cols):
			grid[r][c] = {"type": PipeType.STRAIGHT, "rotation": 0, "on_path": false}

	for cell in cell_connections:
		var conns: Array = _deduplicate(cell_connections[cell])
		var pipe: Dictionary = _find_pipe_for_connections(conns)
		grid[cell.y][cell.x] = {"type": pipe["type"], "rotation": pipe["rotation"], "on_path": true}

	var fill_types := [PipeType.STRAIGHT, PipeType.ELBOW, PipeType.ELBOW, PipeType.T_JUNCTION]
	for r in range(grid_rows):
		for c in range(grid_cols):
			if not grid[r][c]["on_path"]:
				grid[r][c] = {"type": fill_types[randi() % fill_types.size()], "rotation": 0, "on_path": false}

	var scramble_passes := 3
	for _pass in range(scramble_passes):
		for r in range(grid_rows):
			for c in range(grid_cols):
				grid[r][c]["rotation"] = randi() % 4


func _diff_to_side(diff: Vector2i) -> int:
	if diff == Vector2i(0, -1):
		return Side.UP
	elif diff == Vector2i(1, 0):
		return Side.RIGHT
	elif diff == Vector2i(0, 1):
		return Side.DOWN
	elif diff == Vector2i(-1, 0):
		return Side.LEFT
	return Side.RIGHT


func _deduplicate(arr: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for item in arr:
		if not seen.has(item):
			seen[item] = true
			result.append(item)
	return result


func _create_path() -> Array:
	var path: Array = []
	var visited: Dictionary = {}
	var current := Vector2i(0, _source_row)
	path.append(current)
	visited[_v2key(current)] = true

	while current.x < grid_cols - 1:
		var right := Vector2i(current.x + 1, current.y)
		var up := Vector2i(current.x, current.y - 1)
		var down := Vector2i(current.x, current.y + 1)

		var candidates: Array = []
		if right.x < grid_cols and not visited.has(_v2key(right)):
			candidates.append(right)
		if up.y >= 0 and not visited.has(_v2key(up)):
			candidates.append(up)
		if down.y < grid_rows and not visited.has(_v2key(down)):
			candidates.append(down)

		if candidates.is_empty():
			current = Vector2i(current.x + 1, current.y)
			if not visited.has(_v2key(current)):
				path.append(current)
				visited[_v2key(current)] = true
			continue

		var chosen: Vector2i
		var has_right := false
		for c in candidates:
			if c.x > current.x:
				has_right = true
				break

		if has_right and randf() < 0.5:
			chosen = right
		else:
			chosen = candidates[randi() % candidates.size()]

		current = chosen
		path.append(current)
		visited[_v2key(current)] = true

	_drain_row = current.y
	return path


func _count_bends(path: Array) -> int:
	if path.size() < 3:
		return 0
	var bends := 0
	for i in range(2, path.size()):
		var p0: Vector2i = path[i - 2]
		var p1: Vector2i = path[i - 1]
		var p2: Vector2i = path[i]
		if (p1.x - p0.x != p2.x - p1.x) or (p1.y - p0.y != p2.y - p1.y):
			bends += 1
	return bends


func _create_branch_path(main_path: Array) -> Array:
	var div_min: int = maxi(1, main_path.size() * 3 / 10)
	var div_max: int = mini(main_path.size() - 2, main_path.size() * 6 / 10)
	if div_max <= div_min:
		return []

	for _try in range(20):
		var div_idx: int = div_min + randi() % (div_max - div_min + 1)
		var div_cell: Vector2i = main_path[div_idx]

		var visited: Dictionary = {}
		for i in range(main_path.size()):
			if i != div_idx:
				visited[_v2key(main_path[i])] = true
		visited[_v2key(div_cell)] = true

		var branch: Array = [div_cell]
		var current: Vector2i = div_cell

		while current.x < grid_cols - 1:
			var right := Vector2i(current.x + 1, current.y)
			var up := Vector2i(current.x, current.y - 1)
			var down := Vector2i(current.x, current.y + 1)

			var candidates: Array = []
			if right.x < grid_cols and not visited.has(_v2key(right)):
				candidates.append(right)
			if up.y >= 0 and not visited.has(_v2key(up)):
				candidates.append(up)
			if down.y < grid_rows and not visited.has(_v2key(down)):
				candidates.append(down)

			if candidates.is_empty():
				current = Vector2i(current.x + 1, current.y)
				if not visited.has(_v2key(current)):
					branch.append(current)
					visited[_v2key(current)] = true
				continue

			var chosen: Vector2i
			var has_right := false
			for c in candidates:
				if c.x > current.x:
					has_right = true
					break

			if has_right and randf() < 0.5:
				chosen = right
			else:
				chosen = candidates[randi() % candidates.size()]

			current = chosen
			branch.append(current)
			visited[_v2key(current)] = true

		if current.y != _drain_row:
			return branch

	return []


func _find_pipe_for_connections(connections: Array) -> Dictionary:
	if connections.size() < 2:
		return {"type": PipeType.STRAIGHT, "rotation": 0}

	var s: Dictionary = {}
	for conn in connections:
		s[conn] = true

	var n: int = connections.size()

	if n == 2:
		if s.has(Side.UP) and s.has(Side.DOWN):
			return {"type": PipeType.STRAIGHT, "rotation": 0}
		if s.has(Side.LEFT) and s.has(Side.RIGHT):
			return {"type": PipeType.STRAIGHT, "rotation": 1}
		if s.has(Side.DOWN) and s.has(Side.RIGHT):
			return {"type": PipeType.ELBOW, "rotation": 0}
		if s.has(Side.LEFT) and s.has(Side.DOWN):
			return {"type": PipeType.ELBOW, "rotation": 1}
		if s.has(Side.UP) and s.has(Side.LEFT):
			return {"type": PipeType.ELBOW, "rotation": 2}
		if s.has(Side.UP) and s.has(Side.RIGHT):
			return {"type": PipeType.ELBOW, "rotation": 3}

	if n == 3:
		if s.has(Side.DOWN) and s.has(Side.LEFT) and s.has(Side.RIGHT):
			return {"type": PipeType.T_JUNCTION, "rotation": 0}
		if s.has(Side.LEFT) and s.has(Side.UP) and s.has(Side.DOWN):
			return {"type": PipeType.T_JUNCTION, "rotation": 1}
		if s.has(Side.UP) and s.has(Side.LEFT) and s.has(Side.RIGHT):
			return {"type": PipeType.T_JUNCTION, "rotation": 2}
		if s.has(Side.UP) and s.has(Side.RIGHT) and s.has(Side.DOWN):
			return {"type": PipeType.T_JUNCTION, "rotation": 3}

	if n == 4:
		return {"type": PipeType.CROSS, "rotation": 0}

	return {"type": PipeType.STRAIGHT, "rotation": 0}


func _get_effective_connections(pipe_type: int, rotation: int) -> Array:
	var base: Array = []
	match pipe_type:
		PipeType.STRAIGHT:
			base = [Side.UP, Side.DOWN]
		PipeType.ELBOW:
			base = [Side.DOWN, Side.RIGHT]
		PipeType.T_JUNCTION:
			base = [Side.DOWN, Side.LEFT, Side.RIGHT]
		PipeType.CROSS:
			base = [Side.UP, Side.RIGHT, Side.DOWN, Side.LEFT]

	var result: Array = []
	for side in base:
		result.append((side + rotation) % 4)
	return result


func _side_to_dir(side: int) -> Vector2i:
	match side:
		Side.UP:
			return Vector2i(0, -1)
		Side.RIGHT:
			return Vector2i(1, 0)
		Side.DOWN:
			return Vector2i(0, 1)
		Side.LEFT:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


func _bfs_from_source() -> Dictionary:
	var visited: Dictionary = {}
	var order: Array = []
	var source_cell: Dictionary = grid[_source_row][0]
	var source_conns: Array = _get_effective_connections(source_cell["type"], source_cell["rotation"])

	var has_left := false
	for conn in source_conns:
		if conn == Side.LEFT:
			has_left = true
	if not has_left:
		return {"reaches_drain": false, "cells": order}

	var queue: Array = [Vector2i(0, _source_row)]
	visited[_v2key(Vector2i(0, _source_row))] = true

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		order.append(current)
		var cell: Dictionary = grid[current.y][current.x]
		var conns: Array = _get_effective_connections(cell["type"], cell["rotation"])

		for side in conns:
			var neighbor := current + _side_to_dir(side)
			if neighbor.x < 0 or neighbor.x >= grid_cols or neighbor.y < 0 or neighbor.y >= grid_rows:
				continue
			if visited.has(_v2key(neighbor)):
				continue
			var neighbor_cell: Dictionary = grid[neighbor.y][neighbor.x]
			var neighbor_conns: Array = _get_effective_connections(neighbor_cell["type"], neighbor_cell["rotation"])
			var opposite_side: int = (side + 2) % 4
			var found := false
			for conn in neighbor_conns:
				if conn == opposite_side:
					found = true
			if found:
				visited[_v2key(neighbor)] = true
				queue.append(neighbor)

	var reaches := true
	for drain_y in _drain_rows:
		var drain_cell: Dictionary = grid[drain_y][grid_cols - 1]
		var drain_conns: Array = _get_effective_connections(drain_cell["type"], drain_cell["rotation"])
		var drain_has_right := false
		for conn in drain_conns:
			if conn == Side.RIGHT:
				drain_has_right = true
		if not visited.has(_v2key(Vector2i(grid_cols - 1, drain_y))) or not drain_has_right:
			reaches = false
			break

	return {"reaches_drain": reaches, "cells": order}


func _cell_center(row: int, col: int) -> Vector2:
	return _grid_origin + Vector2(col * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0, row * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0)


func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	var grid_w := grid_cols * TILE_SIZE + (grid_cols - 1) * TILE_GAP
	var grid_h := grid_rows * TILE_SIZE + (grid_rows - 1) * TILE_GAP

	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.05, 0.08, 0.98)
	_bg.size = vp
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_dynamic_nodes.append(_bg)

	var vignette := ColorRect.new()
	vignette.color = Color(0, 0, 0, 0)
	vignette.size = vp
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	_dynamic_nodes.append(vignette)
	var vig_tween := create_tween()
	vig_tween.set_loops()
	vig_tween.tween_property(vignette, "color:a", 0.15, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vig_tween.tween_property(vignette, "color:a", 0.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_grid_origin = Vector2((vp.x - grid_w) / 2.0, (vp.y - grid_h) / 2.0 - 10.0)

	var panel_margin := 18.0
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.85)
	panel_style.border_color = Color(0.15, 0.35, 0.45, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(_grid_origin.x - panel_margin, _grid_origin.y - panel_margin)
	panel.size = Vector2(grid_w + panel_margin * 2, grid_h + panel_margin * 2)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_dynamic_nodes.append(panel)

	var title_bg := ColorRect.new()
	title_bg.color = Color(0.02, 0.04, 0.07, 0.95)
	title_bg.position = Vector2(0, 0)
	title_bg.size = Vector2(vp.x, 70)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_bg)
	_dynamic_nodes.append(title_bg)

	_round_label = Label.new()
	_round_label.text = "RESEAU " + str(_current_round) + " / " + str(TOTAL_ROUNDS)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 13)
	_round_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.8))
	_round_label.position = Vector2(0, 4)
	_round_label.size = Vector2(vp.x, 20)
	_round_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_round_label)
	_dynamic_nodes.append(_round_label)

	_status_label = Label.new()
	_status_label.text = "Connectez les tuyaux vers la sortie"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.95))
	_status_label.position = Vector2(0, 26)
	_status_label.size = Vector2(vp.x, 38)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	_dynamic_nodes.append(_status_label)

	var source_y := _grid_origin.y + _source_row * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0

	var source_glow := ColorRect.new()
	source_glow.color = Color(0.1, 0.8, 0.3, 0.25)
	source_glow.position = Vector2(_grid_origin.x - 14, source_y - 18)
	source_glow.size = Vector2(12, 36)
	source_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(source_glow)
	_dynamic_nodes.append(source_glow)
	var src_tween := create_tween()
	src_tween.set_loops()
	src_tween.tween_property(source_glow, "color:a", 0.5, 1.2).set_trans(Tween.TRANS_SINE)
	src_tween.tween_property(source_glow, "color:a", 0.15, 1.2).set_trans(Tween.TRANS_SINE)

	var source_label := Label.new()
	source_label.text = "IN"
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_label.add_theme_font_size_override("font_size", 15)
	source_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4))
	source_label.position = Vector2(_grid_origin.x - 32, source_y - 10)
	source_label.size = Vector2(24, 20)
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(source_label)
	_dynamic_nodes.append(source_label)

	for drain_idx in range(_drain_rows.size()):
		var dy: int = _drain_rows[drain_idx]
		var drain_y_pos := _grid_origin.y + dy * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0

		var drain_glow := ColorRect.new()
		drain_glow.color = Color(0.9, 0.3, 0.1, 0.25)
		drain_glow.position = Vector2(_grid_origin.x + grid_w + 2, drain_y_pos - 18)
		drain_glow.size = Vector2(12, 36)
		drain_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(drain_glow)
		_dynamic_nodes.append(drain_glow)
		var drn_tween := create_tween()
		drn_tween.set_loops()
		drn_tween.tween_property(drain_glow, "color:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
		drn_tween.tween_property(drain_glow, "color:a", 0.15, 1.0).set_trans(Tween.TRANS_SINE)

		var drain_label := Label.new()
		if _drain_rows.size() > 1:
			drain_label.text = "OUT" + str(drain_idx + 1)
		else:
			drain_label.text = "OUT"
		drain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		drain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		drain_label.add_theme_font_size_override("font_size", 15)
		drain_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.15))
		drain_label.position = Vector2(_grid_origin.x + grid_w + 16, drain_y_pos - 10)
		drain_label.size = Vector2(30, 20)
		drain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(drain_label)
		_dynamic_nodes.append(drain_label)

	_pipe_sprites.clear()
	_pipe_sprites.resize(grid_rows)
	_cell_bg.clear()
	_cell_bg.resize(grid_rows)
	for r in range(grid_rows):
		_pipe_sprites[r] = []
		_cell_bg[r] = []
		for c in range(grid_cols):
			var cell_pos := Vector2(
				_grid_origin.x + c * (TILE_SIZE + TILE_GAP),
				_grid_origin.y + r * (TILE_SIZE + TILE_GAP)
			)

			var bg := ColorRect.new()
			bg.color = Color(0.08, 0.10, 0.14)
			bg.position = cell_pos
			bg.size = Vector2(TILE_SIZE, TILE_SIZE)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(bg)
			_cell_bg[r].append(bg)
			_dynamic_nodes.append(bg)

			var border := ColorRect.new()
			border.color = Color(0.2, 0.25, 0.3, 0.4)
			border.position = cell_pos - Vector2(1, 1)
			border.size = Vector2(TILE_SIZE + 2, TILE_SIZE + 2)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(border)
			border.z_index = -1
			_dynamic_nodes.append(border)

			var sprite := Sprite2D.new()
			sprite.texture = _get_texture_for_type(grid[r][c]["type"])
			sprite.position = cell_pos + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
			sprite.rotation_degrees = grid[r][c]["rotation"] * 90.0
			var scale_factor := TILE_SIZE / 285.0 * 0.85
			sprite.scale = Vector2(scale_factor, scale_factor)
			add_child(sprite)
			_pipe_sprites[r].append(sprite)
			_dynamic_nodes.append(sprite)

	var btn_width := 240.0
	var btn_height := 48.0
	_send_btn = Button.new()
	_send_btn.text = ">>  Envoyer le fluide"
	_send_btn.position = Vector2(vp.x / 2.0 - btn_width / 2.0, vp.y - 85)
	_send_btn.size = Vector2(btn_width, btn_height)
	_send_btn.add_theme_font_size_override("font_size", 17)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.45, 0.35)
	btn_style.border_color = Color(0.2, 0.75, 0.55)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(10)
	_send_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.12, 0.55, 0.42)
	_send_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.05, 0.3, 0.22)
	_send_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_send_btn.pressed.connect(_on_send_fluid)
	_send_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_send_btn)
	_dynamic_nodes.append(_send_btn)

	_retry_btn = Button.new()
	_retry_btn.text = ">>  Reessayer"
	_retry_btn.position = Vector2(vp.x / 2.0 - btn_width / 2.0, vp.y - 85)
	_retry_btn.size = Vector2(btn_width, btn_height)
	_retry_btn.add_theme_font_size_override("font_size", 17)
	var retry_style := StyleBoxFlat.new()
	retry_style.bg_color = Color(0.55, 0.18, 0.08)
	retry_style.border_color = Color(0.8, 0.35, 0.15)
	retry_style.set_border_width_all(2)
	retry_style.set_corner_radius_all(10)
	_retry_btn.add_theme_stylebox_override("normal", retry_style)
	var retry_hover: StyleBoxFlat = retry_style.duplicate()
	retry_hover.bg_color = Color(0.65, 0.25, 0.1)
	_retry_btn.add_theme_stylebox_override("hover", retry_hover)
	var retry_pressed: StyleBoxFlat = retry_style.duplicate()
	retry_pressed.bg_color = Color(0.4, 0.12, 0.05)
	_retry_btn.add_theme_stylebox_override("pressed", retry_pressed)
	_retry_btn.pressed.connect(_on_retry)
	_retry_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_retry_btn.visible = false
	add_child(_retry_btn)
	_dynamic_nodes.append(_retry_btn)

	_hint_label = Label.new()
	_hint_label.text = "Clic : tourner  |  ESC : quitter"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.35, 0.4, 0.45))
	_hint_label.position = Vector2(0, vp.y - 30)
	_hint_label.size = Vector2(vp.x, 18)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	_dynamic_nodes.append(_hint_label)


func _get_texture_for_type(pipe_type: int) -> Texture2D:
	match pipe_type:
		PipeType.STRAIGHT:
			return _tex_straight
		PipeType.ELBOW:
			return _tex_elbow
		PipeType.T_JUNCTION:
			return _tex_t_junction
		PipeType.CROSS:
			return _tex_cross
	return _tex_straight


func _update_sprites() -> void:
	for r in range(grid_rows):
		for c in range(grid_cols):
			if r < _pipe_sprites.size() and c < _pipe_sprites[r].size() and is_instance_valid(_pipe_sprites[r][c]):
				var sprite: Sprite2D = _pipe_sprites[r][c]
				sprite.texture = _get_texture_for_type(grid[r][c]["type"])
				sprite.rotation_degrees = grid[r][c]["rotation"] * 90.0
				sprite.modulate = Color(1, 1, 1)


func _input(event: InputEvent) -> void:
	if not is_instance_valid(self):
		return
	if _phase == Phase.EXITING:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_phase = Phase.EXITING
		done.emit(false)
		call_deferred("queue_free")
		return

	if _phase != Phase.PLAYING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos: Vector2 = event.position - _grid_origin
		var col := int(local_pos.x / (TILE_SIZE + TILE_GAP))
		var row := int(local_pos.y / (TILE_SIZE + TILE_GAP))
		if col >= 0 and col < grid_cols and row >= 0 and row < grid_rows:
			var tile_x := local_pos.x - col * (TILE_SIZE + TILE_GAP)
			var tile_y := local_pos.y - row * (TILE_SIZE + TILE_GAP)
			if tile_x <= TILE_SIZE and tile_y <= TILE_SIZE:
				_on_cell_clicked(row, col)
				get_viewport().set_input_as_handled()


func _on_cell_clicked(row: int, col: int) -> void:
	if row < 0 or row >= grid_rows or col < 0 or col >= grid_cols:
		return
	if row >= _pipe_sprites.size() or _pipe_sprites[row].size() <= col:
		return
	grid[row][col]["rotation"] = (grid[row][col]["rotation"] + 1) % 4
	var sprite: Sprite2D = _pipe_sprites[row][col]
	if not is_instance_valid(sprite):
		return
	sprite.modulate = Color(1.2, 1.2, 1.0)
	var target_rot: float = grid[row][col]["rotation"] * 90.0
	var current_rot: float = sprite.rotation_degrees
	while target_rot <= current_rot:
		target_rot += 360.0
	var tween := create_tween()
	tween.tween_property(sprite, "rotation_degrees", target_rot, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_reset_rotation.bind(row, col))
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	_update_neighbor_highlights()


func _reset_rotation(row: int, col: int) -> void:
	if row < 0 or row >= _pipe_sprites.size() or col < 0 or col >= _pipe_sprites[row].size():
		return
	var sprite: Sprite2D = _pipe_sprites[row][col]
	if is_instance_valid(sprite):
		sprite.rotation_degrees = grid[row][col]["rotation"] * 90.0


func _update_neighbor_highlights() -> void:
	pass


func _on_send_fluid() -> void:
	if _phase != Phase.PLAYING:
		return
	if not is_instance_valid(self):
		return

	_phase = Phase.ANIMATING
	if is_instance_valid(_send_btn):
		_send_btn.visible = false
	if is_instance_valid(_retry_btn):
		_retry_btn.visible = false
	if is_instance_valid(_status_label):
		_status_label.text = "Fluide en cours..."
		_status_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.9))

	var result := _bfs_from_source()
	var cells: Array = result["cells"]
	var reaches_drain: bool = result["reaches_drain"]

	var tween := create_tween()
	for i in range(cells.size()):
		var pos: Vector2i = cells[i]
		tween.tween_callback(_highlight_cell.bind(pos.y, pos.x))
		tween.tween_interval(FLUID_SPEED)
		if i % 4 == 3:
			tween.tween_interval(0.02)

	tween.tween_interval(0.5)

	if not reaches_drain:
		tween.tween_callback(_on_fluid_blocked)
	elif _current_round < TOTAL_ROUNDS:
		tween.tween_callback(_on_round_success)
	else:
		tween.tween_callback(_show_leak)


func _highlight_cell(row: int, col: int) -> void:
	if row < 0 or row >= _cell_bg.size() or col < 0 or col >= _cell_bg[row].size():
		return
	var bg: ColorRect = _cell_bg[row][col]
	if not is_instance_valid(bg):
		return
	bg.color = Color(0.05, 0.28, 0.22)
	if row >= _pipe_sprites.size() or col >= _pipe_sprites[row].size():
		return
	var sprite: Sprite2D = _pipe_sprites[row][col]
	if not is_instance_valid(sprite):
		return
	sprite.modulate = Color(0.4, 1.0, 0.75)

	var center := _cell_center(row, col)
	for i in range(FLUID_DOT_COUNT):
		var dot := ColorRect.new()
		dot.color = Color(0.2, 0.9, 0.7, 0.7)
		var offset_x := (i - 1) * 6.0
		dot.position = center + Vector2(offset_x - 3, -3)
		dot.size = Vector2(6, 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_fluid_dots.append(dot)
		_dynamic_nodes.append(dot)

		var glow_tween := create_tween()
		glow_tween.tween_property(dot, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		glow_tween.tween_callback(dot.queue_free)


func _on_fluid_blocked() -> void:
	_phase = Phase.BLOCKED
	_status_label.text = "Fluide bloque ! Tournez les tuyaux."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.15))

	for r in range(grid_rows):
		for c in range(grid_cols):
			if r < _cell_bg.size() and c < _cell_bg[r].size() and is_instance_valid(_cell_bg[r][c]):
				_cell_bg[r][c].color = Color(0.15, 0.06, 0.04)

	_retry_btn.visible = true


func _on_retry() -> void:
	if _phase != Phase.BLOCKED:
		return
	_phase = Phase.ROUND_TRANSITION
	call_deferred("_init_round", _current_round)


func _on_round_success() -> void:
	_phase = Phase.ROUND_TRANSITION
	_status_label.text = "Bien ! Passons au reseau suivant..."
	_status_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.6))

	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(_next_round)


func _next_round() -> void:
	_init_round(_current_round + 1)


func _show_leak() -> void:
	_phase = Phase.LEAK

	var vp := get_viewport().get_visible_rect().size

	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.6, 0.0, 0.0)
	flash.size = vp
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	_dynamic_nodes.append(flash)

	var flash_tween := create_tween()
	flash_tween.tween_property(flash, "color:a", 0.6, 0.08).set_trans(Tween.TRANS_LINEAR)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.15).set_trans(Tween.TRANS_LINEAR)
	flash_tween.tween_property(flash, "color:a", 0.8, 0.06).set_trans(Tween.TRANS_LINEAR)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.2).set_trans(Tween.TRANS_LINEAR)

	var leak_x: float = _grid_origin.x + (grid_cols - 1) * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0

	var all_sparks: Array = []
	for drain_y in _drain_rows:
		var dy: int = drain_y
		var leak_y: float = _grid_origin.y + dy * (TILE_SIZE + TILE_GAP) + TILE_SIZE / 2.0

		var spark1 := CPUParticles2D.new()
		spark1.position = Vector2(leak_x + 40.0, leak_y - 10.0)
		spark1.emitting = true
		spark1.one_shot = false
		spark1.amount = 25
		spark1.lifetime = 0.8
		spark1.explosiveness = 0.7
		spark1.direction = Vector2(1, -1)
		spark1.spread = 30.0
		spark1.initial_velocity_min = 80.0
		spark1.initial_velocity_max = 250.0
		spark1.gravity = Vector2(0, 100)
		spark1.scale_amount_min = 1.0
		spark1.scale_amount_max = 3.0
		spark1.color = Color(1.0, 0.7, 0.2)
		add_child(spark1)
		_dynamic_nodes.append(spark1)
		all_sparks.append(spark1)

		var spark2 := CPUParticles2D.new()
		spark2.position = Vector2(leak_x + 40.0, leak_y + 15.0)
		spark2.emitting = true
		spark2.one_shot = false
		spark2.amount = 15
		spark2.lifetime = 1.0
		spark2.explosiveness = 0.5
		spark2.direction = Vector2(1, 1)
		spark2.spread = 25.0
		spark2.initial_velocity_min = 50.0
		spark2.initial_velocity_max = 150.0
		spark2.gravity = Vector2(0, 120)
		spark2.scale_amount_min = 0.8
		spark2.scale_amount_max = 2.5
		spark2.color = Color(0.4, 0.7, 1.0)
		add_child(spark2)
		_dynamic_nodes.append(spark2)
		all_sparks.append(spark2)

		var drain_cell_bg: ColorRect = _cell_bg[drain_y][grid_cols - 1]
		var drain_tween := create_tween()
		drain_tween.set_loops(6)
		drain_tween.tween_property(drain_cell_bg, "color", Color(0.5, 0.15, 0.05), 0.08)
		drain_tween.tween_property(drain_cell_bg, "color", Color(0.05, 0.28, 0.22), 0.08)

	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(_on_leak_stop_all_sparks.bind(all_sparks))
	tween.tween_callback(_on_leak_message)
	tween.tween_interval(3.0)
	tween.tween_callback(_on_leak_finish)


func _on_leak_stop_all_sparks(sparks: Array) -> void:
	for spark in sparks:
		if is_instance_valid(spark):
			spark.emitting = false


func _on_leak_message() -> void:
	_status_label.text = "Court-circuit ! L'electricite est coupee !"
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))

	var vp := get_viewport().get_visible_rect().size
	var gen_label := Label.new()
	gen_label.text = "Les generateurs de secours sont en marche..."
	gen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gen_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gen_label.add_theme_font_size_override("font_size", 14)
	gen_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	gen_label.position = Vector2(0, vp.y - 55)
	gen_label.size = Vector2(vp.x, 22)
	gen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gen_label)
	_dynamic_nodes.append(gen_label)


func _on_leak_finish() -> void:
	_phase = Phase.EXITING
	done.emit(true)
	call_deferred("queue_free")
