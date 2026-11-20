class_name MineWorld
extends FarmWorld
## Um andar da Mina. Reaproveita o mundo da fazenda (rochas, picareta, mira, pesca, coleta)
## com outro mapa: caverna gerada a cada visita, minérios que mudam com a profundidade,
## escada escondida debaixo de uma rocha, baú às vezes e laguinho subterrâneo a cada 3 andares.

signal ladder_down_used
signal exit_used

const TEX := preload("res://assets/sprites/mine/tiles.png")
const T_FLOOR := [0, 1, 2]
const T_WALL := 3
const T_WALL_FACE := 4
## área da caverna dentro do mapa (o resto é rocha)
const AREA := Rect2i(8, 6, 32, 22)

var level := 1
var walls := {}
var spawn_pos := Vector2.ZERO
var ladder_cell := Vector2i(-1, -1)
var _ladder_found := false
var _rng := RandomNumberGenerator.new()


func region_id() -> String:
	return "mine_deep" if level >= 10 else "mine"


func water_kind(c: Vector2i) -> String:
	return "cave" if ground_at(c) == Ground.WATER else ""


func water_depth(_c: Vector2i) -> String:
	return "deep"


func _is_free_grass(_c: Vector2i) -> bool:
	return false      # não se ara chão de caverna


func can_place(_kind: String, _target: Vector2i) -> bool:
	return false      # nada de construir dentro da mina


# ------------------------------------------------------------------ geração
func generate(saved: Dictionary) -> void:
	level = int(saved.get("level", 1))
	_rng.seed = hash([level, Game.day, Game.minutes / 60])
	ground.resize(W * H)
	variant.resize(W * H)
	var start := Vector2i(-1, -1)
	for attempt in 12:
		_carve_cave()
		start = _pick_start()
		if start.x >= 0 and _keep_connected(start) >= 160:
			break
	if level % 3 == 0:
		_carve_pond(start)
	for c in walls:
		blocked[c] = true
	_build_wall_collision()

	# escada de saída (sobe para a fazenda) no começo
	var up := _interactable("ladder_up", start, "Subir para a fazenda")
	up.interacted.connect(func(_w): exit_used.emit())
	blocked[start] = true
	var below := start + Vector2i(0, 1)
	spawn_pos = cell_center(below if not walls.has(below) else nearest_passable(below))
	_spawn_rocks(start)
	if _rng.randf() < 0.18:
		_spawn_chest(start)
	_ground_layer.queue_redraw()


func _carve_cave() -> void:
	walls.clear()
	var wall_grid := {}
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			ground[y * W + x] = Ground.GRASS
			variant[y * W + x] = _rng.randi() % 3
			wall_grid[c] = not AREA.grow(-1).has_point(c) or _rng.randf() < 0.42
	for _it in 4:
		var next := {}
		for y in H:
			for x in W:
				var c := Vector2i(x, y)
				if not AREA.grow(-1).has_point(c):
					next[c] = true
					continue
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and wall_grid.get(c + Vector2i(dx, dy), true):
							n += 1
				next[c] = n >= 5 or (n <= 1 and _rng.randf() < 0.3)
		wall_grid = next
	# tira pedrinhas de parede soltas no meio do chão (deixa a caverna mais limpa)
	for c in wall_grid.keys():
		if wall_grid[c] and AREA.grow(-1).has_point(c):
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if wall_grid.get(c + d, true):
					n += 1
			if n <= 1:
				wall_grid[c] = false
	for c in wall_grid:
		if wall_grid[c]:
			walls[c] = true


func _pick_start() -> Vector2i:
	# o chão mais à esquerda, perto do meio
	for x in range(AREA.position.x, AREA.end.x):
		for dy in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
			var c := Vector2i(x, AREA.position.y + AREA.size.y / 2 + dy)
			if not walls.has(c) and not walls.has(c + Vector2i(0, 1)):
				return c
	return Vector2i(-1, -1)


## Mantém só o chão ligado ao começo. Retorna quantas células sobraram.
func _keep_connected(start: Vector2i) -> int:
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if is_inside(n) and not walls.has(n) and not seen.has(n):
				seen[n] = true
				q.append(n)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if not seen.has(c):
				walls[c] = true
	return seen.size()


func _carve_pond(start: Vector2i) -> void:
	var floor_cells := _floor_cells().filter(func(c): return c.distance_to(start) > 8)
	if floor_cells.is_empty():
		return
	var center: Vector2i = floor_cells[_rng.randi() % floor_cells.size()]
	for dy in range(-2, 3):
		for dx in range(-3, 4):
			var c := center + Vector2i(dx, dy)
			if float(dx * dx) / 9.0 + float(dy * dy) / 4.0 <= 1.0 and AREA.grow(-2).has_point(c):
				walls.erase(c)
				ground[c.y * W + c.x] = Ground.WATER
	# margem andável em volta do laguinho
	for dy in range(-3, 4):
		for dx in range(-4, 5):
			var c := center + Vector2i(dx, dy)
			if AREA.grow(-1).has_point(c) and ground_at(c) != Ground.WATER:
				walls.erase(c)


func _floor_cells() -> Array:
	var out := []
	for y in range(AREA.position.y, AREA.end.y):
		for x in range(AREA.position.x, AREA.end.x):
			var c := Vector2i(x, y)
			if not walls.has(c) and ground_at(c) != Ground.WATER:
				out.append(c)
	return out


## Pedras e minérios: a mistura muda com a profundidade.
func _rock_table() -> Array:
	if level < 5:
		return [["mine_rock", 70], ["ore_copper", 26], ["gem_rock", 4]]
	if level < 10:
		return [["mine_rock", 55], ["ore_copper", 20], ["ore_iron", 19], ["gem_rock", 6]]
	return [["mine_rock", 45], ["ore_copper", 8], ["ore_iron", 24], ["ore_crystal", 14], ["gem_rock", 9]]


func _spawn_rocks(start: Vector2i) -> void:
	var table := _rock_table()
	var total := 0
	for t in table:
		total += int(t[1])
	var rock_cells := []
	for c in _floor_cells():
		if c.distance_to(start) < 2.5 or blocked.has(c) or _rng.randf() > 0.26:
			continue
		var pick := _rng.randi() % total
		var kind := "mine_rock"
		for t in table:
			pick -= int(t[1])
			if pick < 0:
				kind = t[0]
				break
		_spawn_prop(kind, c, -1, _rng.randi())
		rock_cells.append(c)
	# a escada para o próximo andar fica escondida debaixo de uma rocha, longe do começo
	var far := rock_cells.filter(func(c): return c.distance_to(start) > 8)
	var pool := far if not far.is_empty() else rock_cells
	if not pool.is_empty():
		ladder_cell = pool[_rng.randi() % pool.size()]


func _spawn_chest(start: Vector2i) -> void:
	var cells := _floor_cells().filter(func(c): return not props.has(c) and not blocked.has(c) and c.distance_to(start) > 4)
	if cells.is_empty():
		return
	var c: Vector2i = cells[_rng.randi() % cells.size()]
	var chest := _interactable("chest", c, "Abrir baú")
	blocked[c] = true
	chest.interacted.connect(func(_w):
		Game.toast.emit(_open_chest())
		blocked.erase(c)
		chest.queue_free())


func _open_chest() -> String:
	var money := 40 + level * 15 + _rng.randi_range(0, 60)
	Game.add_money(money)
	var loot: Array
	if level < 5:
		loot = [["copper_ore", _rng.randi_range(5, 10)], ["amethyst", 1], ["bait_mushroom", 3]]
	elif level < 10:
		loot = [["iron_ore", _rng.randi_range(5, 8)], ["copper_bar", 2], ["ruby", 1]]
	else:
		loot = [["iron_bar", 2], ["crystal", 2], ["emerald", 1], ["moonstone", 1]]
	var it: Array = loot[_rng.randi() % loot.size()]
	var t := "Baú da mina: %d moedas" % money
	if Game.add_item(it[0], it[1]) == 0:
		t += " e %d %s" % [it[1], ItemDB.item_name(it[0])]
	return t + "!"


func _interactable(sprite: String, c: Vector2i, label: String) -> Interactable:
	var it := Interactable.new()
	it.label = label
	it.reach = 30.0
	it.position = cell_center(c)
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/mine/%s.png" % sprite)
	s.position = Vector2(0, -s.texture.get_height() / 2.0 + 4)
	it.add_child(s)
	entities.add_child(it)
	return it


func _build_wall_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	# só as paredes que encostam no chão precisam de colisão (uma faixa por linha)
	for y in H:
		var run_start := -1
		for x in W + 1:
			var c := Vector2i(x, y)
			var edge := x < W and walls.has(c) and _touches_floor(c)
			if edge and run_start < 0:
				run_start = x
			elif not edge and run_start >= 0:
				var w := (x - run_start) * TILE
				_add_rect_collision(body, Vector2(w, TILE), Vector2(run_start * TILE + w / 2.0, y * TILE + TILE / 2.0))
				run_start = -1


func _touches_floor(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if is_inside(n) and not walls.has(n):
				return true
	return false


# ------------------------------------------------------------------ quebrar rochas
func _destroy_prop(prop: Prop) -> void:
	var c := prop.cell
	var d: Array = prop.drops()
	if prop.kind == "gem_rock":
		d = [_gem_for_depth(), 1]
	elif prop.kind == "mine_rock" and _rng.randf() < 0.06:
		d = ["copper_ore", 1] if level < 5 else ["iron_ore", 1]      # às vezes vem um minério escondido
	if d.size() == 2 and Game.add_item(d[0], d[1]) == 0:
		_popup("+%d %s" % [d[1], ItemDB.item_name(d[0])], prop.position + Vector2(0, -20))
	props.erase(c)
	FX.spawn(self, "break_stone", prop.position + Vector2(0, -10))
	var tw := prop.create_tween()
	tw.tween_property(prop, "modulate:a", 0.0, 0.15)
	tw.tween_callback(prop.queue_free)
	Game.bump("rocks_broken")
	if c == ladder_cell and not _ladder_found:
		_reveal_ladder()


func _gem_for_depth() -> String:
	var r := _rng.randf()
	if level < 5:
		return "amethyst"
	if level < 10:
		return "amethyst" if r < 0.5 else ("ruby" if r < 0.8 else "emerald")
	return "ruby" if r < 0.35 else ("emerald" if r < 0.8 else "moonstone")


func _reveal_ladder() -> void:
	_ladder_found = true
	var lad := _interactable("ladder_down", ladder_cell, "Descer (andar %d)" % (level + 1))
	blocked[ladder_cell] = true
	lad.interacted.connect(func(_w): ladder_down_used.emit())
	Game.toast.emit("Achou a escada para o andar %d!" % (level + 1))


## Para testes: onde está a escada.
func ladder_visible() -> bool:
	return _ladder_found


# ------------------------------------------------------------------ desenho
func _draw_ground() -> void:
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			if walls.has(c):
				var below := Vector2i(x, y + 1)
				var t := T_WALL_FACE if is_inside(below) and not walls.has(below) else T_WALL
				_ground_layer.draw_texture_rect_region(TEX, dest, Rect2(t * TILE, 0, TILE, TILE))
			elif ground[y * W + x] == Ground.WATER:
				var up := y > 0 and ground[(y - 1) * W + x] != Ground.WATER
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_WATER_BANK if up else T_WATER),
					Color(0.6, 0.75, 0.95))
			else:
				_ground_layer.draw_texture_rect_region(TEX, dest, Rect2(T_FLOOR[variant[y * W + x]] * TILE, 0, TILE, TILE))
