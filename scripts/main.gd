extends Node2D

const GRID_ORIGIN := Vector2(70, 170)
const CELL_SIZE := 64
const GRID_WIDTH := 10
const GRID_HEIGHT := 8
const INTERVALS_PER_TURN := 6
const INTERVAL_SECONDS := 0.42
const PANEL_ORIGIN := Vector2(760, 110)
const PANEL_SIZE := Vector2(500, 690)
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

const COVER := [
	Vector2i(4, 2), Vector2i(5, 2),
	Vector2i(4, 5), Vector2i(5, 5),
	Vector2i(3, 3), Vector2i(6, 4),
]

const BLUE := Color("#72c7ff")
const BLUE_DARK := Color("#244c69")
const RED := Color("#ff8279")
const RED_DARK := Color("#69363c")
const INK := Color("#e8edf4")
const MUTED := Color("#a0acbc")
const ACCENT := Color("#e5bd73")

var units: Array[Dictionary] = []
var selected_id := 1
var planning := true
var finished := false
var mode := "move"
var round_number := 1
var interval_number := 0
var event_lines: Array[String] = []

var hud: Control
var phase_label: Label
var phase_detail: Label
var selected_label: Label
var selected_stats: Label
var order_list: Label
var event_label: Label
var help_label: Label
var move_button: Button
var attack_button: Button
var guard_button: Button
var resolve_button: Button


func _ready() -> void:
	_build_squad()
	_build_hud()
	_refresh_enemy_orders()
	_refresh_hud()
	queue_redraw()


func _build_squad() -> void:
	units.clear()
	var blue_roster := [
		["Mara", "Éclaireuse", Vector2i(1, 1), 5, 2],
		["Ivo", "Tireur", Vector2i(1, 3), 4, 2],
		["Sana", "Fusilière", Vector2i(1, 5), 4, 2],
		["Lev", "Brècheur", Vector2i(2, 2), 3, 3],
		["Tess", "Médecin", Vector2i(2, 6), 4, 1],
	]
	var red_roster := [
		["Kade", "Éclaireur", Vector2i(8, 1), 4, 2],
		["Nox", "Tireur", Vector2i(8, 3), 4, 2],
		["Vera", "Fusilière", Vector2i(8, 5), 4, 2],
		["Rook", "Brècheur", Vector2i(7, 2), 3, 3],
		["Eli", "Médecin", Vector2i(7, 6), 4, 1],
	]
	var next_id := 1
	for entry in blue_roster:
		units.append(_make_unit(next_id, entry, 0))
		next_id += 1
	for entry in red_roster:
		units.append(_make_unit(next_id, entry, 1))
		next_id += 1
	selected_id = 1
	planning = true
	finished = false
	mode = "move"
	round_number = 1
	interval_number = 0
	event_lines.clear()
	event_lines.append("Le contact est imminent. Donnez vos ordres.")


func _make_unit(unit_id: int, entry: Array, team: int) -> Dictionary:
	return {
		"id": unit_id,
		"name": entry[0],
		"role": entry[1],
		"pos": entry[2],
		"team": team,
		"hp": 6,
		"max_hp": 6,
		"range": entry[3],
		"damage": entry[4],
		"cooldown": 0,
		"order": "guard" if team == 0 else "attack",
		"destination": entry[2],
		"target_id": -1,
	}


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)

	_add_label("INTERVALLES", Vector2(70, 36), Vector2(450, 46), 34, INK)
	_add_label("TACTIQUE D’ESCOUADE  /  PROTOTYPE 01", Vector2(72, 82), Vector2(560, 26), 14, MUTED)
	_add_label("10 combattants   ·   6 intervalles par tour", Vector2(70, 716), Vector2(640, 26), 15, MUTED)
	_add_label("CLIC : sélectionner / donner un ordre", Vector2(70, 744), Vector2(640, 25), 14, MUTED)

	var panel := ColorRect.new()
	panel.position = PANEL_ORIGIN
	panel.size = PANEL_SIZE
	panel.color = Color("#101722")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)

	_add_label("OPÉRATION 01   /   CONTACT", PANEL_ORIGIN + Vector2(24, 19), Vector2(440, 25), 13, ACCENT)
	phase_label = _add_label("PLANIFICATION", PANEL_ORIGIN + Vector2(24, 54), Vector2(450, 34), 25, INK)
	phase_detail = _add_label("Tour 1 · choisissez un combattant", PANEL_ORIGIN + Vector2(24, 91), Vector2(450, 24), 15, MUTED)
	_add_rule(PANEL_ORIGIN + Vector2(24, 128), 452)
	_add_label("COMBATTANT SÉLECTIONNÉ", PANEL_ORIGIN + Vector2(24, 146), Vector2(450, 20), 12, MUTED)
	selected_label = _add_label("—", PANEL_ORIGIN + Vector2(24, 172), Vector2(450, 29), 21, INK)
	selected_stats = _add_label("—", PANEL_ORIGIN + Vector2(24, 205), Vector2(450, 25), 14, MUTED)
	_add_rule(PANEL_ORIGIN + Vector2(24, 240), 452)
	_add_label("ORDRE POUR LE COMBATTANT", PANEL_ORIGIN + Vector2(24, 258), Vector2(450, 20), 12, MUTED)

	move_button = _add_button("1   Déplacement", PANEL_ORIGIN + Vector2(24, 287), Vector2(218, 48))
	move_button.pressed.connect(_on_move_mode)
	attack_button = _add_button("2   Attaquer", PANEL_ORIGIN + Vector2(258, 287), Vector2(218, 48))
	attack_button.pressed.connect(_on_attack_mode)
	guard_button = _add_button("3   Garder la position", PANEL_ORIGIN + Vector2(24, 345), Vector2(452, 44))
	guard_button.pressed.connect(_on_guard_order)
	help_label = _add_label("Déplacement : cliquez une case. Attaque : cliquez une cible rouge.", PANEL_ORIGIN + Vector2(24, 396), Vector2(452, 42), 13, MUTED)
	_add_rule(PANEL_ORIGIN + Vector2(24, 443), 452)
	_add_label("ORDRES DE L’ESCOUADE", PANEL_ORIGIN + Vector2(24, 459), Vector2(450, 20), 12, MUTED)
	order_list = _add_label("", PANEL_ORIGIN + Vector2(24, 484), Vector2(452, 91), 14, INK)
	event_label = _add_label("", PANEL_ORIGIN + Vector2(24, 582), Vector2(452, 46), 12, MUTED)
	resolve_button = _add_button("RÉSOUDRE 6 INTERVALLES  →", PANEL_ORIGIN + Vector2(24, 635), Vector2(452, 43))
	resolve_button.pressed.connect(_on_resolve_pressed)


func _add_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(label)
	return label


func _add_rule(position_value: Vector2, width: float) -> void:
	var rule := ColorRect.new()
	rule.position = position_value
	rule.size = Vector2(width, 1)
	rule.color = Color("#273241")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(rule)


func _add_button(text_value: String, position_value: Vector2, size_value: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = size_value
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.focus_mode = Control.FOCUS_NONE
	hud.add_child(button)
	return button


func _refresh_hud() -> void:
	if not is_instance_valid(phase_label):
		return
	if finished:
		phase_label.text = "MISSION TERMINÉE"
		if _living_count(0) == 0 and _living_count(1) == 0:
			phase_detail.text = "Égalité · les deux escouades sont neutralisées"
		elif _living_count(1) == 0:
			phase_detail.text = "Victoire · escouade adverse neutralisée"
		else:
			phase_detail.text = "Défaite · escouade neutralisée"
	elif planning:
		phase_label.text = "PLANIFICATION"
		phase_detail.text = "Tour %d · donnez vos ordres" % round_number
	else:
		phase_label.text = "RÉSOLUTION  ·  %d / %d" % [interval_number + 1, INTERVALS_PER_TURN]
		phase_detail.text = "Tour %d · les ordres se jouent ensemble" % round_number

	var selected: Variant = _unit_by_id(selected_id)
	if selected == null:
		selected_label.text = "Aucun combattant sélectionné"
		selected_stats.text = "Cliquez sur un membre de l’escouade bleue."
	else:
		selected_label.text = "%s  ·  %s" % [selected["name"], selected["role"]]
		selected_stats.text = "PV %d/%d     Portée %d cases     Dégâts %d" % [selected["hp"], selected["max_hp"], selected["range"], selected["damage"]]

	var lines := PackedStringArray()
	for unit in units:
		if unit["team"] == 0:
			var state := "KO" if unit["hp"] <= 0 else _order_summary(unit)
			lines.append("%s  ·  %s" % [unit["name"], state])
	order_list.text = "\n".join(lines)
	var recent_events := PackedStringArray()
	for event_index in range(maxi(0, event_lines.size() - 2), event_lines.size()):
		recent_events.append(event_lines[event_index])
	event_label.text = "\n".join(recent_events)

	move_button.disabled = not planning or selected == null or selected["team"] != 0 or finished
	attack_button.disabled = move_button.disabled
	guard_button.disabled = move_button.disabled
	resolve_button.text = "RECOMMENCER L’OPÉRATION" if finished else "RÉSOUDRE 6 INTERVALLES  →"
	resolve_button.disabled = (not planning) and not finished
	_style_button(move_button, mode == "move")
	_style_button(attack_button, mode == "attack")
	_style_button(guard_button, false)
	_style_button(resolve_button, false)
	if finished:
		help_label.text = "Lancez une nouvelle opération pour rejouer."
	elif not planning:
		help_label.text = "Chaque intervalle dure %.2f s. Les dégâts du même intervalle s’appliquent ensemble." % INTERVAL_SECONDS
	elif mode == "attack":
		help_label.text = "Cliquez sur un combattant rouge pour lui assigner une attaque."
	else:
		help_label.text = "Cliquez une case libre pour déplacer le combattant sélectionné."


func _style_button(button: Button, active: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#354a5d") if active else Color("#1b2734")
	style.border_color = Color("#72c7ff") if active else Color("#334354")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)


func _draw() -> void:
	var board := Rect2(GRID_ORIGIN, Vector2(GRID_WIDTH, GRID_HEIGHT) * CELL_SIZE)
	draw_rect(board, Color("#0b1119"), true)
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var cell := Vector2i(x, y)
			var rect := Rect2(GRID_ORIGIN + Vector2(x, y) * CELL_SIZE, Vector2(CELL_SIZE, CELL_SIZE))
			var base := Color("#18232e") if (x + y) % 2 == 0 else Color("#151f29")
			draw_rect(rect, base, true)
			if COVER.has(cell):
				draw_rect(rect.grow(-7), Color("#596271"), true)
				draw_rect(rect.grow(-7), Color("#84909e"), false, 2)
				draw_line(rect.position + Vector2(12, 18), rect.position + Vector2(52, 18), Color("#a6b0ba"), 2)
				draw_line(rect.position + Vector2(12, 46), rect.position + Vector2(52, 46), Color("#414d59"), 2)
	for x in range(GRID_WIDTH + 1):
		var px := GRID_ORIGIN.x + x * CELL_SIZE
		draw_line(Vector2(px, GRID_ORIGIN.y), Vector2(px, GRID_ORIGIN.y + GRID_HEIGHT * CELL_SIZE), Color("#31404e"), 1)
	for y in range(GRID_HEIGHT + 1):
		var py := GRID_ORIGIN.y + y * CELL_SIZE
		draw_line(Vector2(GRID_ORIGIN.x, py), Vector2(GRID_ORIGIN.x + GRID_WIDTH * CELL_SIZE, py), Color("#31404e"), 1)

	for unit in units:
		if unit["hp"] <= 0:
			continue
		var pos: Vector2i = unit["pos"]
		var center := GRID_ORIGIN + (Vector2(pos) + Vector2(0.5, 0.5)) * CELL_SIZE
		var team_color: Color = BLUE if unit["team"] == 0 else RED
		var dark_color: Color = BLUE_DARK if unit["team"] == 0 else RED_DARK
		if unit["order"] == "move":
			var destination: Vector2i = unit["destination"]
			var destination_center := GRID_ORIGIN + (Vector2(destination) + Vector2(0.5, 0.5)) * CELL_SIZE
			draw_line(center, destination_center, Color(team_color.r, team_color.g, team_color.b, 0.42), 2)
			draw_circle(destination_center, 7, team_color, false, 2)
		draw_circle(center, 20, dark_color, true)
		draw_circle(center, 20, team_color, false, 2)
		if unit["id"] == selected_id:
			draw_circle(center, 25, ACCENT, false, 3)
		var number_text := str(unit["id"] if unit["team"] == 0 else unit["id"] - 5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 6), number_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
		var bar_position := center + Vector2(-20, 25)
		draw_rect(Rect2(bar_position, Vector2(40, 5)), Color("#090d12"), true)
		draw_rect(Rect2(bar_position, Vector2(40.0 * unit["hp"] / unit["max_hp"], 5)), Color("#81d6ad") if unit["hp"] > 2 else Color("#f0a36e"), true)


func _unhandled_input(event: InputEvent) -> void:
	if not planning or finished or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var cell := _screen_to_cell(event.position)
	if not _inside_grid(cell):
		return
	var clicked: Variant = _unit_at(cell)
	var selected: Variant = _unit_by_id(selected_id)
	if mode == "attack" and selected != null and selected["team"] == 0 and clicked != null and clicked["team"] == 1:
		selected["order"] = "attack"
		selected["target_id"] = clicked["id"]
		_append_event("%s prend %s pour cible." % [selected["name"], clicked["name"]])
	elif clicked != null and clicked["team"] == 0:
		selected_id = clicked["id"]
	elif clicked == null and mode == "move" and selected != null and selected["team"] == 0:
		if not COVER.has(cell):
			selected["order"] = "move"
			selected["destination"] = cell
			selected["target_id"] = -1
			_append_event("%s reçoit un ordre de déplacement." % selected["name"])
	_refresh_hud()
	queue_redraw()


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var local_position := screen_position - GRID_ORIGIN
	return Vector2i(floori(local_position.x / CELL_SIZE), floori(local_position.y / CELL_SIZE))


func _inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_WIDTH and cell.y < GRID_HEIGHT


func _unit_at(cell: Vector2i) -> Variant:
	for unit in units:
		if unit["hp"] > 0 and unit["pos"] == cell:
			return unit
	return null


func _unit_by_id(unit_id: int) -> Variant:
	for unit in units:
		if unit["id"] == unit_id:
			return unit
	return null


func _living_count(team: int) -> int:
	var count := 0
	for unit in units:
		if unit["team"] == team and unit["hp"] > 0:
			count += 1
	return count


func _on_move_mode() -> void:
	if planning:
		mode = "move"
		_refresh_hud()


func _on_attack_mode() -> void:
	if planning:
		mode = "attack"
		_refresh_hud()


func _on_guard_order() -> void:
	var selected: Variant = _unit_by_id(selected_id)
	if not planning or selected == null or selected["team"] != 0:
		return
	selected["order"] = "guard"
	selected["target_id"] = -1
	_append_event("%s garde sa position." % selected["name"])
	_refresh_hud()
	queue_redraw()


func _on_resolve_pressed() -> void:
	if finished:
		_build_squad()
		_refresh_enemy_orders()
		_refresh_hud()
		queue_redraw()
		return
	_resolve_turn()


func _resolve_turn() -> void:
	if not planning or finished:
		return
	planning = false
	for index in range(INTERVALS_PER_TURN):
		if finished:
			break
		interval_number = index
		_simulate_interval()
		_refresh_hud()
		queue_redraw()
		await get_tree().create_timer(INTERVAL_SECONDS).timeout
	if not finished:
		round_number += 1
		_refresh_enemy_orders()
		planning = true
		interval_number = 0
		_refresh_hud()
		queue_redraw()


func _simulate_interval() -> void:
	for unit in units:
		if unit["hp"] > 0 and unit["cooldown"] > 0:
			unit["cooldown"] -= 1

	var move_intents: Array[Dictionary] = []
	for unit in units:
		if unit["hp"] <= 0:
			continue
		var next_cell: Vector2i = unit["pos"]
		if unit["order"] == "move":
			next_cell = _find_step(unit, unit["destination"], 0)
		elif unit["order"] == "attack":
			var target: Variant = _target_for(unit)
			if target != null and not _can_fire(unit, target):
				next_cell = _find_step(unit, target["pos"], unit["range"])
		if next_cell != unit["pos"]:
			move_intents.append({"id": unit["id"], "cell": next_cell})

	if not move_intents.is_empty():
		var start_index := interval_number % move_intents.size()
		for offset in range(move_intents.size()):
			var intent: Dictionary = move_intents[(start_index + offset) % move_intents.size()]
			var mover: Variant = _unit_by_id(intent["id"])
			if mover != null and mover["hp"] > 0 and _unit_at(intent["cell"]) == null:
				mover["pos"] = intent["cell"]

	var damage_by_target: Dictionary = {}
	var hits: Array[String] = []
	for unit in units:
		if unit["hp"] <= 0 or unit["cooldown"] > 0:
			continue
		var target: Variant = null
		if unit["order"] == "attack":
			target = _target_for(unit)
		elif unit["order"] == "guard":
			target = _nearest_enemy_in_range(unit)
		if target == null or not _can_fire(unit, target):
			continue
		unit["cooldown"] = 2
		damage_by_target[target["id"]] = damage_by_target.get(target["id"], 0) + unit["damage"]
		hits.append("%s → %s" % [unit["name"], target["name"]])

	for target_id in damage_by_target:
		var target: Variant = _unit_by_id(target_id)
		if target == null or target["hp"] <= 0:
			continue
		var damage: int = damage_by_target[target_id]
		target["hp"] = maxi(0, target["hp"] - damage)
		_append_event("%s subit %d dégâts." % [target["name"], damage])
	if not hits.is_empty():
		_append_event("Tirs simultanés : %s." % ", ".join(PackedStringArray(hits)))
	var selected: Variant = _unit_by_id(selected_id)
	if selected != null and selected["hp"] <= 0:
		for unit in units:
			if unit["team"] == 0 and unit["hp"] > 0:
				selected_id = unit["id"]
				break
	if _living_count(0) == 0 or _living_count(1) == 0:
		finished = true
		_append_event("Mission terminée.")


func _find_step(unit: Dictionary, target_cell: Vector2i, stopping_range: int) -> Vector2i:
	var start: Vector2i = unit["pos"]
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var found := Vector2i(-99, -99)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if _manhattan(cell, target_cell) <= stopping_range and _has_line_of_sight(cell, target_cell):
			found = cell
			break
		for direction in DIRECTIONS:
			var next_cell: Vector2i = cell + direction
			if not _inside_grid(next_cell) or COVER.has(next_cell) or previous.has(next_cell):
				continue
			var occupant: Variant = _unit_at(next_cell)
			if occupant != null and occupant["id"] != unit["id"]:
				continue
			previous[next_cell] = cell
			queue.append(next_cell)
	if found == Vector2i(-99, -99) or found == start:
		return start
	var step := found
	while previous[step] != start:
		step = previous[step]
	return step


func _target_for(unit: Dictionary) -> Variant:
	var target: Variant = _unit_by_id(unit["target_id"])
	if target == null or target["hp"] <= 0 or target["team"] == unit["team"]:
		target = _nearest_enemy(unit)
		unit["target_id"] = target["id"] if target != null else -1
	return target


func _nearest_enemy(unit: Dictionary) -> Variant:
	var nearest: Variant = null
	var best_distance := 999
	for candidate in units:
		if candidate["hp"] <= 0 or candidate["team"] == unit["team"]:
			continue
		var distance := _manhattan(unit["pos"], candidate["pos"])
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


func _nearest_enemy_in_range(unit: Dictionary) -> Variant:
	var nearest: Variant = null
	var best_distance := 999
	for candidate in units:
		if candidate["hp"] <= 0 or candidate["team"] == unit["team"] or not _can_fire(unit, candidate):
			continue
		var distance := _manhattan(unit["pos"], candidate["pos"])
		if distance < best_distance:
			best_distance = distance
			nearest = candidate
	return nearest


func _can_fire(attacker: Dictionary, target: Dictionary) -> bool:
	return _manhattan(attacker["pos"], target["pos"]) <= attacker["range"] and _has_line_of_sight(attacker["pos"], target["pos"])


func _manhattan(first: Vector2i, second: Vector2i) -> int:
	return absi(first.x - second.x) + absi(first.y - second.y)


func _has_line_of_sight(first: Vector2i, second: Vector2i) -> bool:
	var x := first.x
	var y := first.y
	var dx := absi(second.x - first.x)
	var dy := absi(second.y - first.y)
	var sx := 1 if first.x < second.x else -1
	var sy := 1 if first.y < second.y else -1
	var error := dx - dy
	while true:
		var cell := Vector2i(x, y)
		if cell != first and cell != second and COVER.has(cell):
			return false
		if x == second.x and y == second.y:
			break
		var doubled_error := 2 * error
		if doubled_error > -dy:
			error -= dy
			x += sx
		if doubled_error < dx:
			error += dx
			y += sy
	return true


func _refresh_enemy_orders() -> void:
	for unit in units:
		if unit["team"] != 1 or unit["hp"] <= 0:
			continue
		var target: Variant = _nearest_enemy(unit)
		unit["order"] = "attack" if target != null else "guard"
		unit["target_id"] = target["id"] if target != null else -1


func _order_summary(unit: Dictionary) -> String:
	match unit["order"]:
		"move":
			return "Va vers %d, %d" % [unit["destination"].x + 1, unit["destination"].y + 1]
		"attack":
			var target: Variant = _unit_by_id(unit["target_id"])
			return "Attaque %s" % (target["name"] if target != null else "cible proche")
		_:
			return "Garde la position"


func _append_event(line: String) -> void:
	event_lines.append(line)
	while event_lines.size() > 8:
		event_lines.pop_front()
