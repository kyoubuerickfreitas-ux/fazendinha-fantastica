class_name FarmWorld
extends Node2D
## O mapa da fazenda: chão em grade, terra arada, plantações e objetos.
## O chão é desenhado direto (sem TileMap) para ficar simples de gerar e salvar.

const TILE := 32
const W := 50
const H := 38

const TILES_TEX := preload("res://assets/sprites/tiles.png")
const HOUSE_TEX := preload("res://assets/sprites/house.png")
const BIN_TEX := preload("res://assets/sprites/forest/crate_veggies.png")
const SHOP_TEX := preload("res://assets/sprites/shop.png")

enum Ground { GRASS, PATH, WATER }
# Índices em tiles.png
const T_GRASS := [0, 1, 2]
const T_PATH := 3
const T_TILLED := 4
const T_TILLED_WET := 5
const T_WATER := 6
const T_WATER_BANK := 7

## Quanto subir cada estágio da plantação (semente, broto, crescendo, pronta) para centralizar
const CROP_LIFT := [9.0, 7.0, 4.0, 3.0]
const ENERGY_COST := {"hoe": 2.0, "watering_can": 1.0, "axe": 3.0, "pickaxe": 3.0, "scythe": 1.0, "seed": 0.0}

signal house_door_used
signal shop_requested
signal bin_used
signal workbench_used
signal animal_card_requested(record: AnimalRecord)
signal animal_list_requested(records: Array, title: String)

var ground := PackedByteArray()
var variant := PackedByteArray()
var blocked := {}        # células onde não se pode arar (casa, caixa, NPC)
var soil := {}           # Vector2i -> canteiro (formato em scripts/systems/agriculture.gd)
var _crop_tex := {}
var props := {}          # Vector2i -> Prop
var placeables: Array[Placeable] = []
var occupied := {}       # Vector2i -> Placeable (células ocupadas por objetos construídos)
var player: Node2D

var entities: Node2D     # contêiner com Y-sort (jogador, objetos, NPCs)
var animals: Array[Animal] = []
var pickups: Array = []

## Pasto dos animais (em células): x 32..45, y 13..18
const PASTURE := Rect2i(32, 13, 14, 6)
const STARTING_ANIMALS := ["moombor", "fofranca", "catarrapio", "piuplum", "piuplum"]
var player_start := Vector2.ZERO

var _ground_layer := Node2D.new()
var _soil_layer := Node2D.new()
var _cursor := Node2D.new()
var _cursor_cell := Vector2i(-1, -1)
var _cursor_visible := false
var _cursor_valid := true
var _cursor_size := Vector2i.ONE
var _cursor_origin := Vector2i(-1, -1)


func _ready() -> void:
	_ground_layer.z_index = -10
	_soil_layer.z_index = -9
	_cursor.z_index = -8
	add_child(_ground_layer)
	add_child(_soil_layer)
	add_child(_cursor)
	_ground_layer.draw.connect(_draw_ground)
	_soil_layer.draw.connect(_draw_soil)
	_cursor.draw.connect(_draw_cursor)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)


# =================================================================== geração
func generate(saved: Dictionary) -> void:
	ground.resize(W * H)
	variant.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261118

	for y in H:
		for x in W:
			var i := y * W + x
			ground[i] = Ground.GRASS
			var r := rng.randf()
			variant[i] = 1 if r < 0.06 else (2 if r < 0.16 else 0)

	# lago
	var pond_c := Vector2(40, 24)
	for y in H:
		for x in W:
			var dx := (x - pond_c.x) / 6.5
			var dy := (y - pond_c.y) / 4.2
			if dx * dx + dy * dy <= 1.0:
				ground[y * W + x] = Ground.WATER
	# caminhos
	_path_rect(5, 7, 5, 12)
	_path_rect(3, 12, 44, 12)
	_path_rect(30, 12, 30, 18)
	_path_rect(14, 11, 14, 12)

	_build_static_scenery()
	_build_world_bounds()

	if saved.has("placeables"):
		for d in saved["placeables"]:
			if d is Dictionary and ItemDB.PLACEABLES.has(str(d.get("kind", ""))):
				var pl := place(str(d["kind"]), Vector2i(int(d["x"]), int(d["y"])), true)
				if pl:
					pl.restore(d)
	else:
		# começo: bancada perto de casa e comedouro com feno no pasto
		place("workbench", Vector2i(11, 9), true)
		var f := place("feeder", Vector2i(PASTURE.position.x + 1, PASTURE.position.y), true)
		if f:
			f.hay = 10
			f.refresh()

	if saved.has("props"):
		for p in saved["props"]:
			_spawn_prop(str(p[0]), Vector2i(int(p[1]), int(p[2])), int(p[3]), int(p[4]) if p.size() > 4 else 0)
	else:
		_generate_props(rng)

	_spawn_animals(saved.get("animals", []))
	for pk in saved.get("pickups", []):
		if pk is Dictionary and ItemDB.has(str(pk.get("id", ""))):
			_spawn_pickup(str(pk["id"]), int(pk.get("q", 0)), Vector2(float(pk["x"]), float(pk["y"])), str(pk.get("finder", "")))

	soil.clear()
	if saved.has("soil"):
		for s in saved["soil"]:
			var cell = s.get("cell", s)
			soil[Vector2i(int(s["x"]), int(s["y"]))] = Agri.migrate(cell if cell is Dictionary else {})

	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	_ground_layer.queue_redraw()
	_soil_layer.queue_redraw()


func _path_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			ground[y * W + x] = Ground.PATH


func _build_static_scenery() -> void:
	# casa (ocupa x 4..8, y 3..7). A porta fica à esquerda do centro.
	var house := StaticBody2D.new()
	house.position = Vector2(6 * TILE + TILE / 2, 7 * TILE + 4)
	var hs := Sprite2D.new()
	hs.texture = HOUSE_TEX
	hs.position = Vector2(0, -52)
	house.add_child(hs)
	_add_rect_collision(house, Vector2(104, 30), Vector2(2, -17))
	entities.add_child(house)
	for y in range(3, 8):
		for x in range(4, 9):
			blocked[Vector2i(x, y)] = true

	var door := Interactable.new()
	door.label = "Dormir"
	door.reach = 26.0
	door.position = house.position + Vector2(-20, 6)
	door.interacted.connect(func(_w): house_door_used.emit())
	entities.add_child(door)

	# caixa de vendas
	var bin := Interactable.new()
	bin.label = "Vender"
	bin.reach = 30.0
	var bin_cell := Vector2i(10, 6)
	bin.position = Vector2(bin_cell.x * TILE + TILE / 2, bin_cell.y * TILE + TILE - 4)
	var bs := Sprite2D.new()
	bs.texture = BIN_TEX
	bs.position = Vector2(0, -16)
	bin.add_child(bs)
	var bb := StaticBody2D.new()
	_add_rect_collision(bb, Vector2(22, 8), Vector2(0, -4))
	bin.add_child(bb)
	bin.interacted.connect(func(_w): bin_used.emit())
	entities.add_child(bin)
	blocked[bin_cell] = true

	# barraca do Fungo (ocupa x 13..18, y 6..9)
	var shop := StaticBody2D.new()
	shop.position = Vector2(15 * TILE + TILE / 2, 9 * TILE + 26)
	var ss := Sprite2D.new()
	ss.texture = SHOP_TEX
	ss.position = Vector2(0, -56)
	shop.add_child(ss)
	_add_rect_collision(shop, Vector2(104, 34), Vector2(0, -17))
	entities.add_child(shop)
	for y in range(6, 10):
		for x in range(13, 19):
			blocked[Vector2i(x, y)] = true

	# Fungo, o vendedor de sementes
	var npc := NPC.new()
	var npc_cell := Vector2i(15, 10)
	npc.position = Vector2(npc_cell.x * TILE + TILE / 2, npc_cell.y * TILE + TILE - 4)
	npc.interacted.connect(func(_w): shop_requested.emit())
	entities.add_child(npc)
	blocked[npc_cell] = true

	player_start = Vector2(5 * TILE + TILE / 2, 9 * TILE + 8)

	# água bloqueia passagem
	var water_body := StaticBody2D.new()
	add_child(water_body)
	for y in H:
		var run_start := -1
		for x in W + 1:
			var is_w := x < W and ground[y * W + x] == Ground.WATER
			if is_w and run_start == -1:
				run_start = x
			elif not is_w and run_start != -1:
				var w := (x - run_start) * TILE
				_add_rect_collision(water_body, Vector2(w, TILE - 8),
					Vector2(run_start * TILE + w / 2.0, y * TILE + TILE / 2.0 + 4))
				run_start = -1


func _build_world_bounds() -> void:
	var walls := StaticBody2D.new()
	add_child(walls)
	var ww := W * TILE
	var wh := H * TILE
	_add_rect_collision(walls, Vector2(ww, 64), Vector2(ww / 2.0, TILE * 1.5 - 32))
	_add_rect_collision(walls, Vector2(ww, 64), Vector2(ww / 2.0, wh - TILE + 32))
	_add_rect_collision(walls, Vector2(64, wh), Vector2(TILE * 1.5 - 32, wh / 2.0))
	_add_rect_collision(walls, Vector2(64, wh), Vector2(ww - TILE * 1.5 + 32, wh / 2.0))


func _add_rect_collision(body: Node, size: Vector2, pos: Vector2) -> void:
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	col.position = pos
	body.add_child(col)


func _generate_props(rng: RandomNumberGenerator) -> void:
	# decoração fixa (antes do resto, para garantir o lugar)
	for d in [
		["mushroom", 20, 9, 2], ["mushroom", 19, 10, 3], ["mushroom", 34, 4, 0],
		["mushroom", 46, 15, 1], ["mushroom", 26, 33, 0], ["mushroom", 3, 31, 3],
		["boulder", 33, 27, 0], ["boulder", 47, 21, 2], ["boulder", 27, 4, 3],
		["tent", 39, 7, 0], ["campfire", 39, 10, 0], ["barrel", 35, 8, 0],
		["fence", 43, 9, 0], ["fence", 44, 9, 0],
		["barrel", 11, 5, 0],
	]:
		_spawn_prop(d[0], Vector2i(d[1], d[2]), -1, d[3])

	# borda: árvores antigas em cima e embaixo, pinheiros nas laterais (não podem ser cortadas)
	for x in range(0, W, 3):
		_spawn_prop("old_tree", Vector2i(x, 0), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x + 1, 1), -1, rng.randi())
		_spawn_prop("old_tree", Vector2i(x + 1, H - 1), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x, H - 2), -1, rng.randi())
	for y in range(2, H - 2, 2):
		_spawn_prop("pine", Vector2i(0, y), -1, rng.randi())
		_spawn_prop("pine", Vector2i(W - 1, y + 1), -1, rng.randi())

	for y in range(3, H - 3):
		for x in range(2, W - 2):
			var c := Vector2i(x, y)
			if not _is_free_grass(c) or _near_path(c) or PASTURE.grow(1).has_point(c):
				continue
			var r := rng.randf()
			var in_farm := x >= 5 and x <= 24 and y >= 14 and y <= 30
			var in_forest := (x >= 25 and (y <= 10 or y >= 30)) or x <= 3 or y >= 31
			if in_farm:
				if r < 0.10: _spawn_prop("weed", c, -1, rng.randi())
				elif r < 0.15: _spawn_prop("rock", c)
				elif r < 0.18 and _can_place_tree(c, 1): _spawn_prop("sapling", c, -1, rng.randi())
			elif in_forest:
				if r < 0.20 and _can_place_tree(c, 2): _spawn_prop("tree", c, -1, rng.randi())
				elif r < 0.26: _spawn_prop("bush", c, -1, rng.randi())
				elif r < 0.32: _spawn_prop("weed", c, -1, rng.randi())
			else:
				if r < 0.03 and _can_place_tree(c, 2): _spawn_prop("tree", c, -1, rng.randi())
				elif r < 0.05: _spawn_prop("bush", c, -1, rng.randi())
				elif r < 0.09: _spawn_prop("weed", c, -1, rng.randi())
				elif r < 0.10: _spawn_prop("rock", c)


const TALL := ["tree", "old_tree", "pine", "sapling", "mushroom", "boulder", "tent"]


func _pasture_area() -> Rect2:
	return Rect2(PASTURE.position * TILE, PASTURE.size * TILE).grow(-12)


func _spawn_animals(saved: Array) -> void:
	var list: Array = []
	for d in saved:
		if d is Dictionary and AnimalSystem.species(str(d.get("species", ""))) != null:
			list.append(AnimalRecord.restore(d))
	if list.is_empty():
		for sp in STARTING_ANIMALS:
			list.append(AnimalRecord.create(sp, true))
	var area := _pasture_area()
	for i in list.size():
		var r: AnimalRecord = list[i]
		if r.pos == Vector2.ZERO or not area.grow(64).has_point(r.pos):
			r.pos = area.position + Vector2(area.size.x * fmod(0.15 + 0.18 * i, 0.9), area.size.y * (0.3 + 0.4 * (i % 2)))
		_spawn_actor(r)
	assign_homes()


func _spawn_actor(r: AnimalRecord) -> Animal:
	var a := Animal.new()
	a.setup(r, _pasture_area(), r.pos)
	a.card_requested.connect(func(an): animal_card_requested.emit(an.record))
	entities.add_child(a)
	animals.append(a)
	return a


## Compra/nascimento: cria o registro e o boneco. adult=false chega como filhote.
func add_animal(species: String, adult: bool = true) -> Animal:
	var r := AnimalRecord.create(species, adult)
	var area := _pasture_area()
	r.pos = area.get_center() + Vector2(randf_range(-60, 60), randf_range(-20, 20))
	var a := _spawn_actor(r)
	assign_homes()
	return a


func records() -> Array:
	return animals.map(func(a): return a.record)


func refresh_animals() -> void:
	for a in animals:
		a.refresh()


## Distribui os animais sem casa nas construções com vaga (celeiro: grandes, galinheiro: aves).
func assign_homes() -> void:
	var used := {}
	for a in animals:
		if a.record.home != "":
			used[a.record.home] = used.get(a.record.home, 0) + 1
	for a in animals:
		var r: AnimalRecord = a.record
		var b := _building_at_key(r.home)
		if b == null:
			r.home = ""
		if r.home == "":
			for p in placeables:
				if p.kind == r.data().housing and used.get(_key(p), 0) < ItemDB.BUILDING_CAPACITY[p.kind]:
					r.home = _key(p)
					used[r.home] = used.get(r.home, 0) + 1
					break
		var home := _building_at_key(r.home)
		a.home_door = home.position + Vector2(0, 10) if home else Vector2.INF


func _key(p: Placeable) -> String:
	return "%d,%d" % [p.origin.x, p.origin.y]


func _building_at_key(k: String) -> Placeable:
	if k == "":
		return null
	for p in placeables:
		if _key(p) == k:
			return p
	return null


## Quantos animais cabem: grupo "big" (Moombor, Fofrança, Catarrápio) ou "bird" (Piuplum).
func capacity(group: String) -> int:
	var cap: int = ItemDB.BASE_CAPACITY[group]
	for p in placeables:
		if group == "big" and p.kind == "barn":
			cap += ItemDB.BUILDING_CAPACITY["barn"]
		elif group == "bird" and p.kind == "coop":
			cap += ItemDB.BUILDING_CAPACITY["coop"]
	return cap


func count_animals(group: String) -> int:
	var n := 0
	for a in animals:
		if a.record.data().group == group:
			n += 1
	return n


# =================================================================== construção
## Pode construir `kind` mirando a célula `target`? (célula de baixo, no meio)
func can_place(kind: String, target: Vector2i) -> bool:
	var r := Placeable.footprint(kind, target)
	var pc := cell_of(player.position) if player else Vector2i(-99, -99)
	var floor_obj: bool = ItemDB.PLACEABLES[kind].get("floor", false)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			if not is_inside(c) or ground_at(c) == Ground.WATER:
				return false
			if props.has(c) or soil.has(c) or blocked.has(c) or occupied.has(c):
				return false
			if not floor_obj and c == pc:
				return false
			if x < 2 or y < 2 or x > W - 3 or y > H - 3:
				return false
	return true


## Constrói na posição de cima à esquerda `origin` (force = sem checar, para carregar o save).
func place(kind: String, origin: Vector2i, force: bool = false) -> Placeable:
	var sz: Vector2i = ItemDB.PLACEABLES[kind]["size"]
	if not force:
		var target := Vector2i(origin.x + (sz.x - 1) / 2, origin.y + sz.y - 1)
		if not can_place(kind, target):
			return null
	var p := Placeable.new()
	p.setup(kind, origin, TILE)
	p.used.connect(_on_placeable_used)
	entities.add_child(p)
	placeables.append(p)
	for y in range(origin.y, origin.y + sz.y):
		for x in range(origin.x, origin.x + sz.x):
			occupied[Vector2i(x, y)] = p
	return p


func remove_placeable(p: Placeable) -> void:
	for c in occupied.keys():
		if occupied[c] == p:
			occupied.erase(c)
	placeables.erase(p)
	FX.spawn(self, "break_wood", p.position + Vector2(0, -10))
	p.queue_free()


func _on_placeable_used(p: Placeable) -> void:
	var held := Game.selected_item_id()
	var msg := ""
	match p.kind:
		"workbench":
			workbench_used.emit()
		"barn", "coop":
			var k := _key(p)
			var list := records().filter(func(r): return r.home == k)
			animal_list_requested.emit(list, "%s (%d/%d)" % [ItemDB.item_name(p.kind), list.size(),
				ItemDB.BUILDING_CAPACITY[p.kind]])
		"feeder":
			if held == "hay":
				var n: int = mini(Game.count_item("hay"), 30 - p.hay)
				if n <= 0:
					msg = "O comedouro está cheio."
				else:
					Game.remove_item("hay", n)
					p.hay += n
					p.refresh()
					msg = "Colocou %d feno. (%d no comedouro)" % [n, p.hay]
			else:
				msg = "Comedouro: %d feno. Segure feno e toque para encher." % p.hay
		_:
			if p.job_ready():
				msg = p.collect()
				FX.spawn(self, "harvest", p.position + Vector2(0, -16))
			elif not p.job.is_empty():
				msg = "Ainda trabalhando... pronto no dia %d." % int(p.job["ready"])
			else:
				msg = p.insert(held)
	if msg != "":
		Game.toast.emit(msg)


func _can_place_tree(c: Vector2i, spread: int) -> bool:
	for dy in range(-spread - 1, spread + 1):
		for dx in range(-spread, spread + 1):
			var n := c + Vector2i(dx, dy)
			if props.has(n) and props[n].kind in TALL:
				return false
	return true


func _near_path(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if is_inside(n) and ground[n.y * W + n.x] != Ground.GRASS:
				return true
	return c.distance_to(Vector2i(6, 9)) < 3


## variant < 0 ou grande: escolhe uma variante a partir do número (aleatório).
func _spawn_prop(kind: String, c: Vector2i, hp: int = -1, variant: int = 0) -> void:
	if kind == "tree_big":
		kind = "pine"   # saves antigos
	if not is_inside(c) or props.has(c) or blocked.has(c) or not Prop.DEFS.has(kind):
		return
	if ground_at(c) == Ground.WATER:
		return
	var p := Prop.new()
	p.setup(kind, c, TILE, hp, absi(variant) % Prop.variant_count(kind))
	entities.add_child(p)
	props[c] = p


# =================================================================== consultas
func is_inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func ground_at(c: Vector2i) -> int:
	return ground[c.y * W + c.x] if is_inside(c) else Ground.WATER


func _is_free_grass(c: Vector2i) -> bool:
	return is_inside(c) and ground_at(c) == Ground.GRASS and not blocked.has(c) \
		and not props.has(c) and not soil.has(c) and not occupied.has(c)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func world_size() -> Vector2:
	return Vector2(W * TILE, H * TILE)


func set_cursor(c: Vector2i, visible_: bool, valid: bool = true) -> void:
	# com um objeto construível na mão, o cursor mostra o tamanho dele
	var held := Game.selected_item_id()
	var r := Rect2i(c, Vector2i.ONE)
	if ItemDB.PLACEABLES.has(held):
		r = Placeable.footprint(held, c)
	if c != _cursor_cell or visible_ != _cursor_visible or valid != _cursor_valid or r.position != _cursor_origin or r.size != _cursor_size:
		_cursor_cell = c
		_cursor_visible = visible_
		_cursor_valid = valid
		_cursor_origin = r.position
		_cursor_size = r.size
		_cursor.queue_redraw()


## Ponto que representa o alvo de uma célula (a base do objeto, se houver um).
func target_anchor(c: Vector2i) -> Vector2:
	if props.has(c):
		return props[c].position
	if occupied.has(c) and not ItemDB.PLACEABLES[occupied[c].kind].get("floor", false):
		return occupied[c].position
	return _cell_center(c)


## O item faria alguma coisa nesta célula?
func would_act(item_id: String, c: Vector2i) -> bool:
	if item_id == "":
		return can_interact_cell(c)
	var item := ItemDB.get_item(item_id)
	var prop: Prop = props.get(c)
	if item.get("type", "") == "placeable":
		return can_place(item_id, c)
	if item_id in ["axe", "pickaxe"] and occupied.has(c) and occupied[c].can_pick_up():
		return true
	if item.get("type", "") == "seed":
		return soil.has(c) and prop == null and Agri.can_plant(soil[c], item_id, Game.day) == ""
	match item_id:
		"hoe":
			return prop == null and _is_free_grass(c)
		"fishing_rod":
			return ground_at(c) == Ground.WATER
		"watering_can":
			return ground_at(c) == Ground.WATER or (soil.has(c) and Agri.needs_water(soil[c]))
		"axe", "pickaxe", "scythe":
			if prop:
				return prop.required_tool() == item_id
			if item_id == "scythe" and soil.has(c):
				return Agri.is_ready(soil[c]) or Agri.is_dead(soil[c])
			if item_id == "pickaxe" and soil.has(c):
				return not Agri.has_crop(soil[c]) or Agri.is_dead(soil[c])
	return false


## Penalidade na mira automática (para preferir o alvo mais útil).
func target_penalty(item_id: String, c: Vector2i) -> float:
	if item_id == "watering_can" and ground_at(c) == Ground.WATER:
		return 0.0 if Game.water <= 0 else 60.0   # só mira na água se precisar encher
	if item_id == "pickaxe" and soil.has(c):
		return 40.0   # prefere pedras a desfazer canteiros
	return 0.0


## Objeto cuja imagem contém o ponto (o que estiver mais à frente).
func prop_at_point(p: Vector2) -> Prop:
	var best: Prop = null
	for c in props:
		var prop: Prop = props[c]
		if prop.contains_point(p) and (best == null or prop.position.y > best.position.y):
			best = prop
	return best


# =================================================================== ações
## Usa o item selecionado na célula. Retorna uma mensagem curta (ou "").
func use_item(item_id: String, c: Vector2i) -> String:
	if item_id == "":
		return interact_cell(c)
	var item := ItemDB.get_item(item_id)
	if item.get("type", "") == "placeable":
		return _build(item_id, c)
	if item_id in ["axe", "pickaxe"] and occupied.has(c) and not props.has(c):
		var p: Placeable = occupied[c]
		if not p.can_pick_up():
			return "Esvazie antes de desmontar." if not ItemDB.PLACEABLES[p.kind].get("fixed", false) else "Construções não podem ser desmontadas."
		if Game.add_item(p.kind, 1) > 0:
			return ""
		remove_placeable(p)
		assign_homes()
		return "%s guardado na mochila." % ItemDB.item_name(p.kind)
	if item.get("type", "") == "seed":
		return _plant(item_id, c)
	if item.get("type", "") != "tool":
		return "Isso não é uma ferramenta."

	var prop: Prop = props.get(c)
	match item_id:
		"hoe":
			if prop:
				return "Tem algo no caminho."
			if soil.has(c):
				return ""
			if not _is_free_grass(c):
				return "Não dá para arar aqui."
			if not Game.use_energy(ENERGY_COST["hoe"]):
				return ""
			soil[c] = Agri.new_cell(Game.weather_data().soil_water >= 0.9)
			FX.spawn(self, "till", _cell_center(c))
			if randf() < 0.08 and Game.add_item("bait_worm", 1) == 0:
				_popup("+1 Minhoca", _cell_center(c))
			_soil_layer.queue_redraw()
		"watering_can":
			if ground_at(c) == Ground.WATER:
				Game.water = Game.WATER_CAPACITY
				Game.inventory_changed.emit()
				return "Regador cheio!"
			if not soil.has(c) or not Agri.needs_water(soil[c]):
				return ""
			if Game.water <= 0:
				return "Regador vazio! Encha no lago."
			if not Game.use_energy(ENERGY_COST["watering_can"]):
				return ""
			Game.water -= 1
			Agri.water(soil[c])
			FX.spawn(self, "water", _cell_center(c))
			Game.inventory_changed.emit()
			_soil_layer.queue_redraw()
		"axe", "pickaxe", "scythe":
			if prop:
				if prop.required_tool() != item_id:
					return "Precisa de outra ferramenta." if prop.required_tool() != "" else "Isso não sai daqui."
				if not Game.use_energy(ENERGY_COST[item_id]):
					return ""
				FX.spawn(self, "hit", prop.position + Vector2(0, -12))
				if prop.hit():
					_destroy_prop(prop)
				return ""
			if item_id == "scythe" and soil.has(c) and Agri.has_crop(soil[c]):
				return _harvest(c, true)
			if item_id == "pickaxe" and soil.has(c) and (not Agri.has_crop(soil[c]) or Agri.is_dead(soil[c])):
				if not Game.use_energy(ENERGY_COST["pickaxe"]):
					return ""
				soil.erase(c)
				FX.spawn(self, "till", _cell_center(c))
				_soil_layer.queue_redraw()
	return ""


## Interação com a célula usando a mão (colher, arrancar mato).
func interact_cell(c: Vector2i) -> String:
	if soil.has(c) and Agri.has_crop(soil[c]):
		return _harvest(c, false)
	var prop: Prop = props.get(c)
	if prop and prop.kind == "weed":
		_destroy_prop(prop)
		return ""
	return ""


func can_interact_cell(c: Vector2i) -> bool:
	if soil.has(c) and Agri.has_crop(soil[c]):
		return Agri.is_ready(soil[c]) or Agri.is_dead(soil[c])
	var prop: Prop = props.get(c)
	return prop != null and prop.kind == "weed"


func _build(kind: String, target: Vector2i) -> String:
	if not can_place(kind, target):
		return "Não dá para construir aqui."
	var r := Placeable.footprint(kind, target)
	var p := place(kind, r.position)
	if p == null:
		return "Não dá para construir aqui."
	Game.remove_from_slot(Game.selected_slot, 1)
	FX.spawn(self, "hit", p.position + Vector2(0, -8))
	if kind in ["barn", "coop"]:
		assign_homes()
	return "%s construído!" % ItemDB.item_name(kind) if kind in ["barn", "coop"] else ""


func _plant(seed_id: String, c: Vector2i) -> String:
	if not soil.has(c):
		return "Are a terra antes de plantar."
	var why := Agri.can_plant(soil[c], seed_id, Game.day)
	if why != "":
		return why if not Agri.has_crop(soil[c]) else ""
	Agri.plant(soil[c], seed_id)
	Game.remove_from_slot(Game.selected_slot, 1)
	FX.spawn(self, "plant", _cell_center(c) + Vector2(0, 6))
	_soil_layer.queue_redraw()
	return ""


func _harvest(c: Vector2i, with_scythe: bool) -> String:
	var cell: Dictionary = soil[c]
	if Agri.is_dead(cell):
		Agri.clear_crop(cell)
		Game.add_item("fiber", 1)
		_popup("+1 Fibra", _cell_center(c))
		FX.spawn(self, "weed", _cell_center(c))
		_soil_layer.queue_redraw()
		return ""
	if not Agri.is_ready(cell):
		if with_scythe:
			return ""
		var cr: Dictionary = cell["crop"]
		if cr["state"] == "dormant":
			return "Dormindo até a estação certa."
		return "Ainda não está pronta."
	var r := Agri.harvest(cell)
	if Game.add_item(r["item"], r["qty"]) > 0:
		return ""
	var text := "+%d %s" % [r["qty"], ItemDB.item_name(r["item"])]
	if r["seeds"] > 0 and Game.add_item(r["seed_item"], r["seeds"]) == 0:
		text += " +1 semente"
	_popup(text, _cell_center(c))
	FX.spawn(self, "harvest", _cell_center(c))
	_soil_layer.queue_redraw()
	return ""


## Item no chão (farejado): toque para pegar.
func _spawn_pickup(id: String, q: int, pos: Vector2, finder: String) -> void:
	var it := Interactable.new()
	it.label = "Pegar"
	it.reach = 26.0
	it.position = pos
	var sp := Sprite2D.new()
	sp.texture = ItemDB.icon(id)
	sp.scale = Vector2.ONE * (16.0 / sp.texture.get_width())
	sp.position = Vector2(0, -8)
	it.add_child(sp)
	it.interacted.connect(func(_w):
		if Game.add_item(id, 1, q) == 0:
			_popup("+1 %s (achado por %s)" % [ItemDB.item_name(id), finder], it.position + Vector2(0, -16))
			it.queue_free())
	it.set_meta("save", {"id": id, "q": q, "x": pos.x, "y": pos.y, "finder": finder})
	entities.add_child(it)
	pickups.append(it)


func _destroy_prop(prop: Prop) -> void:
	var d: Array = prop.drops()
	if d.size() == 2:
		Game.add_item(d[0], d[1])
		_popup("+%d %s" % [d[1], ItemDB.item_name(d[0])], prop.position + Vector2(0, -20))
	props.erase(prop.cell)
	var fx_name := "break_wood"
	if prop.kind in ["weed", "bush"]:
		fx_name = "weed"
	elif prop.kind == "rock":
		fx_name = "break_stone"
	FX.spawn(self, fx_name, prop.position + Vector2(0, -10))
	var tw := prop.create_tween()
	tw.tween_property(prop, "modulate:a", 0.0, 0.15)
	tw.tween_callback(prop.queue_free)


func _cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2, c.y * TILE + TILE / 2)


func _popup(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("fdf6e3"))
	l.add_theme_color_override("font_outline_color", Color("2b2118"))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos + Vector2(-40, -10)
	l.size = Vector2(80, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.z_index = 50
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# =================================================================== novo dia
## Processa o novo dia (chamado depois de Game.start_new_day). Retorna avisos curtos.
func on_new_day() -> String:
	var notes := []
	var r := Agri.process_day(soil, Game.day - 1, Game.day, Game.temperature_yesterday,
		Game.temperature, Game.weather_data())
	if Calendar.day_of_season(Game.day) == 1:
		notes.append("Começou o %s!" % Calendar.season_name(Game.day))
	if r["ready"] > 0:
		notes.append("%d plantação(ões) pronta(s)" % r["ready"])
	if r["dry"] > 0:
		notes.append("%d sem água" % r["dry"])
	if r["storm"] > 0:
		notes.append("a tempestade estragou %d planta(s)" % r["storm"])
	if r["died"] > 0:
		notes.append("%d morreu(ram)" % r["died"])
	if r["dormant"] > 0:
		notes.append("%d dormindo até a próxima estação" % r["dormant"])
	# o mato volta a crescer aos pouquinhos
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# animais (ordem da §19 dos animais em AnimalSystem.process_day)
	var feeders: Array = placeables.filter(func(p): return p.kind == "feeder")
	var eat := func(_r: AnimalRecord) -> bool:
		for f in feeders:
			if f.hay > 0:
				f.hay -= 1
				return true
		return false
	var housed := func(r: AnimalRecord) -> bool: return r.home != ""
	var ar := AnimalSystem.process_day(records(), eat, housed, Game.weather_data(), Game.temperature, Game.season_id())
	var hungry: int = ar["hungry"]
	for item in ar["forage"]:
		var finder: AnimalRecord = item["rec"]
		_spawn_pickup(item["item"], item["q"], finder.pos + Vector2(randf_range(-30, 30), randf_range(-14, 14)), finder.name)
	if ar["forage"].size() > 0:
		notes.append("o farejador achou %d coisa(s) no pasto" % ar["forage"].size())
	if ar["grown"] > 0:
		notes.append("%d animal(is) cresceu(ram)" % ar["grown"])
	for an in animals:
		an.wake_up()
	for f in feeders:
		f.refresh()
	for p in placeables:
		p.refresh()
	if hungry > 0:
		notes.append("%d animal(is) com fome" % hungry)
	for i in CropDB.season(Game.season_id()).weed_regrow:
		var c := Vector2i(rng.randi_range(5, 24), rng.randi_range(14, 30))
		if _is_free_grass(c):
			_spawn_prop("weed", c, -1, rng.randi())
	_soil_layer.queue_redraw()
	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	return " · ".join(notes)


# =================================================================== salvar
func serialize() -> Dictionary:
	var p := []
	for c in props:
		var prop: Prop = props[c]
		p.append([prop.kind, c.x, c.y, prop.hp, prop.variant])
	var s := []
	for c in soil:
		var d: Dictionary = soil[c]
		s.append({"x": c.x, "y": c.y, "cell": d})
	var an := []
	for a in animals:
		an.append(a.record.serialize())
	var pl := []
	for x in placeables:
		pl.append(x.serialize())
	var pk := []
	for it in pickups:
		if is_instance_valid(it) and not it.is_queued_for_deletion():
			pk.append(it.get_meta("save"))
	return {"props": p, "soil": s, "animals": an, "placeables": pl, "pickups": pk}


# =================================================================== desenho
func _tile_rect(index: int) -> Rect2:
	return Rect2(index * TILE, 0, TILE, TILE)


func _draw_ground() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var t: int
			match ground[i]:
				Ground.PATH:
					t = T_PATH
				Ground.WATER:
					t = T_WATER_BANK if y > 0 and ground[i - W] != Ground.WATER else T_WATER
				_:
					t = T_GRASS[variant[i]]
			_ground_layer.draw_texture_rect_region(TILES_TEX,
				Rect2(x * TILE, y * TILE, TILE, TILE), _tile_rect(t))


func _crop_texture(id: String) -> Texture2D:
	if not _crop_tex.has(id):
		_crop_tex[id] = load("res://assets/sprites/crops/%s.png" % id)
	return _crop_tex[id]


func _draw_soil() -> void:
	for c in soil:
		var cell: Dictionary = soil[c]
		var dest := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		# terra seca por baixo e a molhada por cima, mais forte quanto mais úmida
		_soil_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_TILLED))
		var m: float = cell["moist"]
		if m > 0.12:
			_soil_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_TILLED_WET),
				Color(1, 1, 1, clampf(0.35 + m * 0.65, 0.0, 1.0)))
		if not Agri.has_crop(cell):
			continue
		var cd := Agri.crop_data(cell)
		if cd == null:
			continue
		var cr: Dictionary = cell["crop"]
		var tex := _crop_texture(cd.id)
		var stage := Agri.frame(cell)
		var h := cd.sprite_height
		var lift: float = CROP_LIFT[mini(stage, 3)] if stage < cd.frames() - 1 else 3.0
		var tint := Color.WHITE
		match cr["state"]:
			"dead":
				tint = Color(0.62, 0.48, 0.32)
			"dormant":
				tint = Color(0.72, 0.72, 0.78)
			_:
				if cr["stress"] > 0:
					tint = Color(1.0, 0.92, 0.65)   # murchinha
		_soil_layer.draw_texture_rect_region(tex,
			Rect2(dest.position + Vector2(0, TILE - h - lift), Vector2(TILE, h)),
			Rect2(stage * TILE, 0, TILE, h), tint)
		_draw_crop_marker(dest, cell, cd)


## Sinais no canteiro: gota (precisa de água), brilho (pronta), zzz (dormindo), x (morta).
func _draw_crop_marker(dest: Rect2, cell: Dictionary, cd: CropData) -> void:
	var cr: Dictionary = cell["crop"]
	var p := dest.position + Vector2(TILE - 7, 5)
	var ink := Color("2b2118")
	match cr["state"]:
		"ready":
			for v in [Vector2(0, -4), Vector2(0, 4), Vector2(-4, 0), Vector2(4, 0)]:
				_soil_layer.draw_line(p, p + v, ink, 3.0)
			for v in [Vector2(0, -3), Vector2(0, 3), Vector2(-3, 0), Vector2(3, 0)]:
				_soil_layer.draw_line(p, p + v, Color("f6e7a8"), 1.0)
		"dormant":
			var f := ThemeDB.fallback_font
			_soil_layer.draw_string_outline(f, p + Vector2(-4, 3), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, ink)
			_soil_layer.draw_string(f, p + Vector2(-4, 3), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("dfe6f2"))
		"growing":
			if cell["moist"] < cd.water_min:
				_soil_layer.draw_circle(p + Vector2(0, 1), 3.5, ink)
				_soil_layer.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(-3, 0), p + Vector2(3, 0)]), ink)
				_soil_layer.draw_circle(p + Vector2(0, 1), 2.5, Color("7db4c9"))
				_soil_layer.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(-2, 0), p + Vector2(2, 0)]), Color("7db4c9"))


func _draw_cursor() -> void:
	if not _cursor_visible:
		return
	var r := Rect2(_cursor_origin.x * TILE + 1, _cursor_origin.y * TILE + 1, _cursor_size.x * TILE - 2, _cursor_size.y * TILE - 2)
	if _cursor_valid:
		_cursor.draw_rect(r, Color(0.71, 0.79, 0.58, 0.28), true)
		_cursor.draw_rect(r, Color(0.86, 0.95, 0.66, 0.95), false, 2.0)
	else:
		_cursor.draw_rect(r, Color(0.98, 0.95, 0.82, 0.10), true)
		_cursor.draw_rect(r, Color(0.98, 0.95, 0.82, 0.45), false, 1.0)
