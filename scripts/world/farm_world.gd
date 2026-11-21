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
signal stove_used
signal villager_used(npc_id: String)
signal mine_entrance_used
signal workbench_used
signal untill_requested(c: Vector2i)
## Bancada logo à direita da porta de casa (saves antigos com a bancada em (11, 9) são mudados para cá)
const WORKBENCH_AT := Vector2i(8, 9)
signal baby_born(record: AnimalRecord)
signal animal_card_requested(record: AnimalRecord)
signal animal_list_requested(records: Array, title: String, building: Placeable)

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
var _enclosures := {}     # chave da construção -> {"rect": Rect2, "cells": {Vector2i: true}}
const SILO_CAPACITY := 240

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
	# rio: desce da floresta (nordeste) até o lago
	for y in range(2, 22):
		var bend := int(round(sin(y * 0.45) * 0.8))
		for x in [46 + bend, 47 + bend]:
			ground[y * W + x] = Ground.WATER
	# laguinho no sul
	for y in H:
		for x in W:
			var px := (x - 9.0) / 2.6
			var py := (y - 34.0) / 1.6
			if px * px + py * py <= 1.0:
				ground[y * W + x] = Ground.WATER
	# caminhos
	_path_rect(5, 7, 5, 12)
	_path_rect(3, 12, 44, 12)
	_path_rect(30, 12, 30, 18)
	_path_rect(14, 11, 14, 12)

	_build_static_scenery()
	_build_world_bounds()
	_build_water_collision()

	if saved.has("placeables"):
		for d in saved["placeables"]:
			if d is Dictionary and ItemDB.PLACEABLES.has(str(d.get("kind", ""))):
				var pl := place(str(d["kind"]), Vector2i(int(d["x"]), int(d["y"])), true)
				if pl:
					pl.restore(d)
	else:
		# começo: bancada perto de casa e comedouro com feno no pasto
		place("workbench", WORKBENCH_AT, true)
		var f := place("feeder", Vector2i(PASTURE.position.x + 1, PASTURE.position.y), true)
		if f:
			f.hay = 10
			f.refresh()

	_move_old_workbench()

	if saved.has("props"):
		for p in saved["props"]:
			_spawn_prop(str(p[0]), Vector2i(int(p[1]), int(p[2])), int(p[3]), int(p[4]) if p.size() > 4 else 0)
	else:
		_generate_props(rng)

	var has_grass := false
	for c in props:
		if props[c].kind == "grass":
			has_grass = true
			break
	if not has_grass:
		_grow_grass(0.4)
	_spawn_animals(saved.get("animals", []))
	for pk in saved.get("pickups", []):
		if pk is Dictionary and ItemDB.has(str(pk.get("id", ""))):
			_spawn_pickup(str(pk["id"]), int(pk.get("q", 0)), Vector2(float(pk["x"]), float(pk["y"])), str(pk.get("finder", "")))

	soil.clear()
	if saved.has("soil"):
		for s in saved["soil"]:
			var cell = s.get("cell", s)
			var sc := Vector2i(int(s["x"]), int(s["y"]))
			if ground_at(sc) == Ground.WATER:
				continue   # o mapa ganhou água ali (rio/laguinho)
			var mc := Agri.migrate(cell if cell is Dictionary else {})
			if not mc.has("biome"):
				mc["biome"] = biome_at(sc)
				mc["soil"] = soil_at(sc)
				mc["fert"] = CropDB.soil(mc["soil"]).fertility
			soil[sc] = mc

	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	_ground_layer.queue_redraw()
	_soil_layer.queue_redraw()


func _path_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			ground[y * W + x] = Ground.PATH


## Região para a pesca e outros sistemas ("farm"; a mina devolve "mine"/"mine_deep").
func region_id() -> String:
	return "farm"


func _build_mine_entrance() -> void:
	# entrada da mina no norte do mapa (ocupa x 29..31, y 0..2)
	var ent := StaticBody2D.new()
	ent.position = Vector2(30 * TILE + TILE / 2, 2 * TILE + 30)
	var es := Sprite2D.new()
	es.texture = load("res://assets/sprites/mine/entrance.png")
	es.position = Vector2(0, -es.texture.get_height() / 2.0 + 2)
	ent.add_child(es)
	_add_rect_collision(ent, Vector2(30, 14), Vector2(-33, -7))
	_add_rect_collision(ent, Vector2(30, 14), Vector2(33, -7))
	entities.add_child(ent)
	for y in range(0, 6):
		for x in range(28, 33):
			blocked[Vector2i(x, y)] = true      # entrada e a frente dela livres (sem árvores nem pedras)
	var door := Interactable.new()
	door.label = "Entrar na mina"
	door.reach = 30.0
	door.position = Vector2(30 * TILE + TILE / 2, 3 * TILE + 4)
	door.interacted.connect(func(_w): mine_entrance_used.emit())
	entities.add_child(door)
	mine_entrance_pos = Vector2(30 * TILE + TILE / 2, 3 * TILE + 24)


func _build_static_scenery() -> void:
	_build_mine_entrance()
	# casa (ocupa x 4..8, y 3..7). A porta fica no meio.
	var house := StaticBody2D.new()
	house.position = Vector2(6 * TILE + TILE / 2, 7 * TILE + 4)
	var hs := Sprite2D.new()
	hs.texture = HOUSE_TEX
	hs.position = Vector2(-32, -52)      # a porta (meio da arte) fica em frente ao caminho
	house.add_child(hs)
	_add_rect_collision(house, Vector2(104, 30), Vector2(-30, -17))
	entities.add_child(house)
	for y in range(3, 8):
		for x in range(3, 9):
			blocked[Vector2i(x, y)] = true

	var door := Interactable.new()
	door.label = "Entrar em casa"
	door.reach = 26.0
	door.position = house.position + Vector2(-32, 6)     # porta no meio da arte (tools/import_buildings.py)
	door.interacted.connect(func(_w): house_door_used.emit())
	house_door = door
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
	sell_bin = bin
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
	fungo = npc
	entities.add_child(npc)
	blocked[npc_cell] = true

	player_start = Vector2(5 * TILE + TILE / 2, 9 * TILE + 8)
	_spawn_villagers.call_deferred()
	if Game.tractor.get("owned", false):
		var p := Vector2(float(Game.tractor["x"]), float(Game.tractor["y"]))
		spawn_tractor(p if p != Vector2.ZERO else TRACTOR_PARK)


## Coloca o trator estacionado no mapa (comprado agora ou vindo do save).
func spawn_tractor(pos: Vector2) -> Tractor:
	var t := Tractor.new()
	t.name = "Tractor"
	t.position = pos
	t.mount_requested.connect(func():
		if player:
			player.mount(t)
			tractor = null)
	entities.add_child(t)
	tractor = t
	Game.tractor["x"] = pos.x
	Game.tractor["y"] = pos.y
	if Game.trailer.get("owned", false):
		spawn_trailer(t)
	return t


## Engata a caçamba no trator (comprada agora ou vinda do save).
func spawn_trailer(t: Tractor) -> Trailer:
	if trailer:
		return trailer
	var c := Trailer.new()
	c.name = "Trailer"
	c.open_requested.connect(func(): trailer_open_requested.emit())
	entities.add_child(c)
	trailer = c
	t.attach_trailer(c)
	return c

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


## Água não dá para atravessar (nem a pé nem de trator): uma faixa de colisão por linha de água.
## A margem de cima fica um pouco livre para você chegar bem na beira e pescar.
func _build_water_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Water"
	add_child(body)
	for y in H:
		var run_start := -1
		for x in W + 1:
			var wet := x < W and ground[y * W + x] == Ground.WATER
			if wet and run_start < 0:
				run_start = x
			elif not wet and run_start >= 0:
				var w := (x - run_start) * TILE - 6
				var top := 8.0 if y == 0 or ground[(y - 1) * W + run_start] != Ground.WATER else 0.0
				_add_rect_collision(body, Vector2(w, TILE - top), Vector2(run_start * TILE + 3 + w / 2.0, y * TILE + top + (TILE - top) / 2.0))
				run_start = -1


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


# =================================================================== pasto
func eat_grass(c: Vector2i) -> bool:
	var p: Prop = props.get(c)
	if p == null or p.kind != "grass":
		return false
	props.erase(c)
	p.queue_free()
	return true


func nearest_grass(pos: Vector2, max_dist: float, within: Rect2) -> Vector2:
	var best := Vector2.INF
	var bd := max_dist
	for c in props:
		var p: Prop = props[c]
		if p.kind != "grass" or not within.has_point(p.position):
			continue
		var d := p.position.distance_to(pos)
		if d < bd:
			bd = d
			best = p.position + Vector2(0, -2)
	return best


## Quadrados onde o capim nasce: o pasto principal + pastos cercados.
func _pasture_cells() -> Array:
	var out := {}
	for y in range(PASTURE.position.y, PASTURE.end.y):
		for x in range(PASTURE.position.x, PASTURE.end.x):
			out[Vector2i(x, y)] = true
	for k in _enclosures:
		for c in _enclosures[k]["cells"]:
			out[c] = true
	return out.keys()


func _grow_grass(chance: float) -> int:
	var n := 0
	for c in _pasture_cells():
		if _is_free_grass(c) and randf() < chance:
			_spawn_prop("grass", c, -1, randi())
			n += 1
	return n


func _silos() -> Array:
	return placeables.filter(func(p): return p.kind == "silo")


## Guarda feno nos silos. Retorna quanto coube.
func store_hay(n: int) -> int:
	var stored := 0
	for s in _silos():
		var room: int = SILO_CAPACITY - s.hay
		var add := mini(room, n - stored)
		if add > 0:
			s.hay += add
			stored += add
			s.refresh()
	return stored


func take_hay_from_silos(n: int) -> int:
	var got := 0
	for s in _silos():
		var take := mini(s.hay, n - got)
		if take > 0:
			s.hay -= take
			got += take
			s.refresh()
	return got


## Área cercada a partir da porta da construção (até 500 quadrados). {} se não for fechada.
func _enclosure_for(b: Placeable) -> Dictionary:
	var start := Vector2i(b.origin.x + b.size.x / 2, b.origin.y + b.size.y)
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		if seen.size() > 500 or c.x < 2 or c.y < 2 or c.x > W - 3 or c.y > H - 3:
			return {}
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not _passable(n):
				continue
			seen[n] = true
			q.append(n)
	var r := Rect2i(start, Vector2i.ONE)
	for c in seen:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return {"rect": Rect2(r.position * TILE, r.size * TILE).grow(-6), "cells": seen}


# ------------------------------------------------------------------ moradores
var villagers: Array[NPC] = []
## referências para o tutorial apontar
var house_door: Interactable
var tractor: Tractor            # estacionado (null se não comprou ou se está dirigindo)
var trailer: Trailer
signal trailer_open_requested
const TRACTOR_PARK := Vector2(112, 300)    # onde o trator novo aparece (ao lado da casa)
var sell_bin: Interactable
var fungo: NPC
## onde o jogador aparece ao sair da mina
var mine_entrance_pos := Vector2.ZERO


func _spawn_villagers() -> void:
	for id in Villagers.all_ids():
		var d := Villagers.get_npc(id)
		var npc := NPC.new()
		npc.setup(d, self)
		npc.position = cell_center(nearest_passable(d.home))
		npc.interacted.connect(func(_w): villager_used.emit(id))
		entities.add_child(npc)
		villagers.append(npc)


## Pé do personagem no meio da célula.
func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2, c.y * TILE + TILE - 6)


## A célula andável mais próxima (em espiral).
func nearest_passable(c: Vector2i) -> Vector2i:
	for r in 8:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and _passable(c + Vector2i(dx, dy)):
					return c + Vector2i(dx, dy)
	return c


## Células alcançáveis a pé a partir de c (busca em largura).
func walkable_from(c: Vector2i) -> Dictionary:
	var seen := {c: true}
	var q := [c]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if not seen.has(n) and _passable(n):
				seen[n] = true
				q.append(n)
	return seen


## Dá para andar em linha reta de a até b?
func straight_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 8.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		if not _passable(Vector2i(int(p.x) / TILE, int(p.y) / TILE)):
			return false
	return true


func _passable(c: Vector2i) -> bool:
	if not is_inside(c) or ground_at(c) == Ground.WATER or blocked.has(c):
		return false
	if occupied.has(c) and ItemDB.PLACEABLES[occupied[c].kind].get("solid", true):
		return false
	var p: Prop = props.get(c)
	return p == null or p.kind in ["grass", "weed"]


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


## Uma noite de reprodução. Retorna quantos nasceram.
func _process_breeding() -> int:
	var born := 0
	# gestações em andamento
	for an in animals.duplicate():
		var r: AnimalRecord = an.record
		if r.pregnant_days <= 0:
			continue
		r.pregnant_days -= 1
		if r.pregnant_days == 0:
			var baby := AnimalRecord.born_from(r)
			var a := _spawn_actor(baby)
			a.position = r.pos + Vector2(12, 4)
			baby_born.emit(baby)
			born += 1
	# novas gestações: uma chance por construção por noite
	for b in placeables:
		if not (b.kind in ["barn", "coop"]) or not b.allow_babies:
			continue
		var k := _key(b)
		var residents := records().filter(func(x): return x.home == k)
		if residents.size() >= ItemDB.building_capacity(b.kind, b.level):
			continue
		if residents.any(func(x): return x.pregnant_days > 0):
			continue
		var candidates := residents.filter(func(x): return x.is_adult() and x.happiness >= 60 \
			and x.health == "ok" and x.data().breed_chance > 0.0)
		if candidates.is_empty():
			continue
		var mom: AnimalRecord = candidates[randi() % candidates.size()]
		if randf() < mom.data().breed_chance:
			mom.pregnant_days = mom.data().gestation_days
	assign_homes()
	return born


func _store_in(b: Placeable, id: String, qty: int, q: int) -> void:
	for it in b.storage:
		if it["id"] == id and int(it.get("q", 0)) == q:
			it["qty"] += qty
			b.refresh()
			return
	b.storage.append({"id": id, "qty": qty, "q": q})
	b.refresh()


## Pega tudo que o coletor guardou. Retorna quantos itens foram para a mochila.
func collect_storage(b: Placeable) -> int:
	var n := 0
	var left: Array = []
	for it in b.storage:
		var rest := Game.add_item(it["id"], int(it["qty"]), int(it.get("q", 0)))
		n += int(it["qty"]) - rest
		if rest > 0:
			left.append({"id": it["id"], "qty": rest, "q": it.get("q", 0)})
	b.storage = left
	b.refresh()
	return n


## Melhora o celeiro/galinheiro para o próximo nível. Retorna mensagem.
func upgrade_building(b: Placeable) -> String:
	var levels: Array = ItemDB.BUILDING_LEVELS[b.kind]
	if b.level >= levels.size():
		return "Já está no nível máximo."
	var cost: Dictionary = levels[b.level]["cost"]
	if not ItemDB.can_afford(cost):
		return "Faltam materiais: %s." % ItemDB.missing_text(cost)
	for k in cost:
		if k == "money":
			Game.add_money(-int(cost[k]))
		else:
			Game.remove_item(k, int(cost[k]))
	b.level += 1
	b.refresh()
	FX.spawn(self, "harvest", b.position + Vector2(0, -40))
	assign_homes()
	var perks := {2: "comedouro automático (usa o silo)", 3: "aquecedor e coletor automático"}
	return "%s agora é nível %d: %s!" % [ItemDB.item_name(b.kind), b.level, perks.get(b.level, "")]


func _spawn_actor(r: AnimalRecord) -> Animal:
	var a := Animal.new()
	a.world = self
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
	_enclosures.clear()
	for p in placeables:
		if p.kind in ["barn", "coop"]:
			var e := _enclosure_for(p)
			if not e.is_empty():
				_enclosures[_key(p)] = e
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
				if p.kind == r.data().housing and used.get(_key(p), 0) < ItemDB.building_capacity(p.kind, p.level):
					r.home = _key(p)
					used[r.home] = used.get(r.home, 0) + 1
					break
		var home := _building_at_key(r.home)
		a.home_door = home.position + Vector2(0, 10) if home else Vector2.INF
		a.area = _enclosures[r.home]["rect"] if _enclosures.has(r.home) else _pasture_area()


## Espécies diferentes expostas em todos os aquários.
func aquarium_species() -> int:
	var seen := {}
	for p in placeables:
		if is_instance_valid(p) and p.is_aquarium():
			for f in p.fish:
				seen[f["id"]] = true
	return seen.size()


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
		if (group == "big" and p.kind == "barn") or (group == "bird" and p.kind == "coop"):
			cap += ItemDB.building_capacity(p.kind, p.level)
	return cap


func count_animals(group: String) -> int:
	var n := 0
	for a in animals:
		if a.record.data().group == group:
			n += 1
	return n


# =================================================================== construção
## Pode construir `kind` mirando a célula `target`? (célula de baixo, no meio)
## Só dentro de casa (aquários).
func indoor_only(kind: String) -> bool:
	return ItemDB.PLACEABLES.get(kind, {}).has("aquarium")


func can_place(kind: String, target: Vector2i) -> bool:
	if indoor_only(kind) and not is_indoor():
		return false
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
		"stove":
			stove_used.emit()
		"barn", "coop":
			var k := _key(p)
			var list := records().filter(func(r): return r.home == k)
			animal_list_requested.emit(list, "%s nível %d (%d/%d)" % [ItemDB.item_name(p.kind), p.level, list.size(),
				ItemDB.building_capacity(p.kind, p.level)], p)
		"aquarium_small", "aquarium_large", "fish_pond":
			msg = p.aquarium_use(held)
			var t := FishDB.check_titles(aquarium_species())
			if t != "":
				msg += "\n" + t
		"silo":
			if held == "hay":
				var n := store_hay(Game.count_item("hay"))
				Game.remove_item("hay", n)
				msg = "Guardou %d feno. Silo: %d/%d" % [n, p.hay, SILO_CAPACITY] if n > 0 else "O silo está cheio."
			else:
				msg = "Silo: %d/%d feno. Corte capim com a foice para encher." % [p.hay, SILO_CAPACITY]
		"feeder":
			if held != "hay" and p.hay < 30:
				var got := take_hay_from_silos(30 - p.hay)
				if got > 0:
					p.hay += got
					p.refresh()
					Game.toast.emit("Encheu o comedouro com %d feno do silo. (%d)" % [got, p.hay])
					return
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
			if p.job_ready() and str(p.job["output"]).begins_with("hatch:"):
				var sp: String = str(p.job["output"]).trim_prefix("hatch:")
				var grp: String = AnimalSystem.species(sp).group
				if count_animals(grp) >= capacity(grp):
					msg = "O ovo está pronto para chocar, mas falta vaga no galinheiro."
				else:
					p.job = {}
					p.refresh()
					var chick := add_animal(sp, false)
					FX.spawn(self, "harvest", p.position + Vector2(0, -16))
					baby_born.emit(chick.record)
					msg = "Nasceu um filhote de %s!" % AnimalSystem.species(sp).name
			elif p.job_ready():
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


# =================================================================== solo e bioma
## Bioma do lugar: beira do lago (até 3 quadrados da água), borda da floresta (leste/norte) ou planície.
func biome_at(c: Vector2i) -> String:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if ground_at(c + Vector2i(dx, dy)) == Ground.WATER and is_inside(c + Vector2i(dx, dy)):
				return "riverbank"
	if c.x >= 26 or c.y <= 4:
		return "forest_edge"
	return "plains"


## Tipo de solo do lugar: o padrão do bioma, com manchas de fértil, arenoso e pedregoso.
func soil_at(c: Vector2i) -> String:
	var b := biome_at(c)
	if b != "plains":
		return CropDB.biome(b).default_soil
	if c.x <= 12 and c.y >= 22:
		return "fertile"     # o canteiro antigo da família
	if c.y >= 29:
		return "sandy"
	if c.y <= 10:
		return "rocky"
	return "common"


func _is_free_grass(c: Vector2i) -> bool:
	return is_inside(c) and ground_at(c) == Ground.GRASS and not blocked.has(c) \
		and not props.has(c) and not soil.has(c) and not occupied.has(c) and not near_workbench(c)


## Em volta da bancada não dá para arar (o caminho até ela fica sempre livre).
func near_workbench(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p = occupied.get(c + Vector2i(dx, dy))
			if p != null and p.kind == "workbench":
				return true
	return false


## Saves antigos: a bancada que começava longe da casa vem para perto da porta.
func _move_old_workbench() -> void:
	for p in placeables.duplicate():
		if p.kind == "workbench" and _key(p) == "%d,%d" % [11, 9]:
			for x in range(WORKBENCH_AT.x, WORKBENCH_AT.x + 2):
				var c := Vector2i(x, WORKBENCH_AT.y)
				if occupied.has(c) or blocked.has(c):
					return
				soil.erase(c)
				if props.has(c):
					props[c].queue_free()
					props.erase(c)
			for c in occupied.keys():
				if occupied[c] == p:
					occupied.erase(c)
			placeables.erase(p)
			p.queue_free()
			place("workbench", WORKBENCH_AT, true)
			return


## Desfaz um canteiro vazio (volta a ser grama).
func untill(c: Vector2i) -> bool:
	if not soil.has(c) or (Agri.has_crop(soil[c]) and not Agri.is_dead(soil[c])):
		return false
	soil.erase(c)
	FX.spawn(self, "till", _cell_center(c))
	_soil_layer.queue_redraw()
	return true


## Tipo de água: river (rio do nordeste), pond (laguinho do sul) ou lake.
func water_kind(c: Vector2i) -> String:
	if ground_at(c) != Ground.WATER:
		return ""
	if c.y <= 20 and c.x >= 44:
		return "river"
	if c.y >= 31 and c.x <= 14:
		return "pond"
	return "lake"


## Profundidade: fundo no lago quando há água em volta toda (2 quadrados), senão raso.
func water_depth(c: Vector2i) -> String:
	if water_kind(c) != "lake":
		return "shallow"
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if ground_at(c + Vector2i(dx, dy)) != Ground.WATER:
				return "shallow"
	return "deep"


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
	if item.get("type", "") == "fertilizer":
		return soil.has(c) and soil[c].get("fertilizer", "") == ""
	match item_id:
		"hoe":
			return prop == null and _is_free_grass(c)
		"fishing_rod":
			return ground_at(c) == Ground.WATER
		"watering_can":
			return ground_at(c) == Ground.WATER or tool_area("watering_can", c).any(func(cc): return soil.has(cc) and Agri.needs_water(soil[cc]))
		"axe", "pickaxe", "scythe":
			if prop:
				return prop.required_tool() == item_id
			if item_id == "scythe" and soil.has(c):
				return Agri.is_ready(soil[c]) or Agri.is_dead(soil[c])
			if item_id == "pickaxe" and soil.has(c):
				return not Agri.has_crop(soil[c]) or Agri.is_dead(soil[c])
	return false


## Quadrados atingidos pela ferramenta conforme o nível: 1 / 3 em linha / 3x3.
func tool_area(tool: String, c: Vector2i) -> Array:
	var lvl := Game.tool_level(tool)
	if lvl <= 1:
		return [c]
	if lvl == 2:
		var f: Vector2 = player.facing_vector() if player else Vector2.DOWN
		var d := Vector2i(int(f.x), int(f.y))
		return [c, c + d, c + d * 2]
	var out := []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			out.append(c + Vector2i(dx, dy))
	return out


## Aspersores regam de manhã (depois da secagem da noite).
func _run_sprinklers() -> int:
	var n := 0
	for p in placeables:
		var lvl: int = ItemDB.PLACEABLES[p.kind].get("sprinkler", 0)
		if lvl == 0:
			continue
		var r := 2 if lvl == 3 else 1
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx == 0 and dy == 0:
					continue
				if lvl == 1 and absi(dx) + absi(dy) != 1:
					continue
				var cc := p.origin + Vector2i(dx, dy)
				if soil.has(cc):
					Agri.water(soil[cc])
					n += 1
	return n


## Penalidade na mira automática (para preferir o alvo mais útil).
func target_penalty(item_id: String, c: Vector2i) -> float:
	# a mira automática nunca desmonta objetos construídos (só tocando direto neles)
	if item_id in ["axe", "pickaxe"] and occupied.has(c) and not props.has(c):
		return INF
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
	if item.get("type", "") == "fertilizer":
		if not soil.has(c):
			return "Use o adubo num canteiro arado."
		var why := Agri.apply_fertilizer(soil[c], item_id)
		if why != "":
			return why
		Game.remove_from_slot(Game.selected_slot, 1)
		FX.spawn(self, "plant", _cell_center(c))
		_soil_layer.queue_redraw()
		return "%s aplicado." % ItemDB.item_name(item_id)
	if item.get("type", "") != "tool":
		return "Isso não é uma ferramenta."

	var prop: Prop = props.get(c)
	match item_id:
		"hoe":
			if prop:
				return "Tem algo no caminho."
			if not Game.use_energy(ENERGY_COST["hoe"]):
				return ""
			var tilled := 0
			for cc in tool_area("hoe", c):
				if soil.has(cc) or not _is_free_grass(cc) or props.has(cc):
					continue
				soil[cc] = Agri.new_cell(Game.weather_data().soil_water >= 0.9, soil_at(cc), biome_at(cc))
				FX.spawn(self, "till", _cell_center(cc))
				tilled += 1
				if randf() < 0.08 and Game.add_item("bait_worm", 1) == 0:
					_popup("+1 Minhoca", _cell_center(cc))
			_soil_layer.queue_redraw()
			if tilled == 0:
				return "Não dá para arar aqui."
		"watering_can":
			if ground_at(c) == Ground.WATER:
				Game.water = Game.water_capacity()
				Sound.play("fill")
				FX.spawn(self, "fill", target_anchor(c))
				Game.inventory_changed.emit()
				return "Regador cheio!"
			if Game.water <= 0:
				return "Regador vazio! Encha no lago."
			var cells := tool_area("watering_can", c).filter(func(cc): return soil.has(cc) and Agri.needs_water(soil[cc]))
			if cells.is_empty():
				return ""
			if not Game.use_energy(ENERGY_COST["watering_can"]):
				return ""
			for cc in cells:
				if Game.water <= 0:
					break
				Game.water -= 1
				Agri.water(soil[cc])
				FX.spawn(self, "water", _cell_center(cc))
			Game.inventory_changed.emit()
			_soil_layer.queue_redraw()
		"axe", "pickaxe", "scythe":
			if prop:
				if prop.required_tool() != item_id:
					return "Precisa de outra ferramenta." if prop.required_tool() != "" else "Isso não sai daqui."
				if not Game.use_energy(ENERGY_COST[item_id]):
					return ""
				FX.spawn(self, "hit_stone" if item_id == "pickaxe" else "hit", prop.position + Vector2(0, -12))
				Sound.play("pick" if item_id == "pickaxe" else ("weed" if item_id == "scythe" else "chop"), -2.0)
				if prop.hit(Game.tool_level(item_id)):     # picareta melhorada bate mais forte
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
	if soil.has(c):
		if not Agri.has_crop(soil[c]):
			untill_requested.emit(c)        # canteiro vazio, de mão vazia: pergunta se quer desfazer
			return ""
		return Agri.describe(soil[c])
	return ""


func can_interact_cell(c: Vector2i) -> bool:
	if soil.has(c) and Agri.has_crop(soil[c]):
		return Agri.is_ready(soil[c]) or Agri.is_dead(soil[c])
	var prop: Prop = props.get(c)
	return prop != null and prop.kind == "weed"


## A casa (HouseWorld) devolve true.
func is_indoor() -> bool:
	return false


func _build(kind: String, target: Vector2i) -> String:
	if indoor_only(kind) and not is_indoor():
		return "%s só pode ser colocado dentro de casa." % ItemDB.item_name(kind)
	if not can_place(kind, target):
		return "Não dá para construir aqui."
	var r := Placeable.footprint(kind, target)
	var p := place(kind, r.position)
	if p == null:
		return "Não dá para construir aqui."
	Game.remove_from_slot(Game.selected_slot, 1)
	FX.spawn(self, "hit", p.position + Vector2(0, -8))
	Sound.play("build")
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
		return Agri.describe(cell)
	var r := Agri.harvest(cell)
	if Game.add_item(r["item"], r["qty"], r["q"]) > 0:
		return ""
	Game.bump("harvests")
	var text := "+%d %s%s" % [r["qty"], ItemDB.item_name(r["item"]),
		"" if r["q"] == 0 else " (%s)" % AnimalSystem.QUALITY_NAMES[r["q"]]]
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
	if prop.kind == "grass":
		# capim cortado vira feno: no silo, se houver; senão às vezes na mochila
		if store_hay(1) == 1:
			_popup("+1 feno no silo", prop.position + Vector2(0, -20))
		elif randf() < 0.5 and Game.add_item("hay", 1) == 0:
			_popup("+1 Feno", prop.position + Vector2(0, -20))
		d = []
	if d.size() == 2:
		Game.add_item(d[0], d[1])
		_popup("+%d %s" % [d[1], ItemDB.item_name(d[0])], prop.position + Vector2(0, -20))
	props.erase(prop.cell)
	var fx_name := "break_wood"
	if prop.kind in ["weed", "bush"]:
		fx_name = "weed"
	elif prop.kind == "rock" or prop.required_tool() == "pickaxe":
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
	_run_sprinklers()
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
	var eat := func(r: AnimalRecord) -> bool:
		for f in feeders:
			if f.hay > 0:
				f.hay -= 1
				return true
		# nível 2+: comedouro automático puxa do silo
		var home := _building_at_key(r.home)
		if home and home.level >= 2 and take_hay_from_silos(1) == 1:
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
	# nível 3: aquecedor (inverno mais feliz) e coletor automático
	var collected := 0
	for an in animals:
		var rec: AnimalRecord = an.record
		var home := _building_at_key(rec.home)
		if home == null or home.level < 3:
			continue
		if Game.season_id() == "winter":
			rec.happiness = mini(100, rec.happiness + 5)
		if rec.product_ready and rec.data().produce_mode == "hand":
			var res := AnimalSystem.collect(rec)
			if not res.is_empty() and not res.has("error"):
				_store_in(home, res["item"], res["qty"], res["q"])
				collected += res["qty"]
	if collected > 0:
		notes.append("coletor guardou %d produto(s)" % collected)
	# reprodução: gestação nos alojamentos (opcional por construção)
	var births := _process_breeding()
	if births > 0:
		notes.append("nasceu(ram) %d filhote(s)!" % births)
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
	_grow_grass(CropDB.season(Game.season_id()).grass_growth * 0.5)
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
		if cell.get("fertilizer", "") != "":
			var fc: Color = {"fert_basic": Color("c9a86b"), "fert_growth": Color("8fd16b"),
				"fert_water": Color("7db4c9"), "fert_quality": Color("f2c14e")}.get(cell["fertilizer"], Color.WHITE)
			for k in 5:
				var pt := dest.position + Vector2(5 + (k * 7) % 23, 6 + (k * 11) % 21)
				_soil_layer.draw_rect(Rect2(pt, Vector2(2, 2)), fc)
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
