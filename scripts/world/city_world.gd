class_name CityWorld
extends FarmWorld
## A cidade: um mapa à parte (como a mina e a casa), aonde se chega pela estrada leste da fazenda
## (entra-se pelo oeste da cidade). Malha de ruas calçadas com meio-fio: a rua das lojas no norte,
## a praça central (poço, Feira e barracas, canteiros), duas ruas de casas ao sul, avenidas dos lados,
## um parque com laguinho a leste e bosques nos cantos. Arte: tools/import_city.py (assets/sprites/city/).
## Não se ara, não se planta e não se constrói aqui.

signal exit_used                       ## saiu pela estrada de volta à fazenda
signal building_used(kind: String)     ## tocou na porta de uma loja/casa (ver BUILDINGS)

const DIR := "res://assets/sprites/city/"
const COBBLE_TEX := preload("res://assets/sprites/city/cobble.png")
const PLAZA_TEX := preload("res://assets/sprites/city/plaza.png")
const CURB := Color(0.22, 0.15, 0.1, 0.55)

## Ruas calçadas (retângulos em quadrados)
const STREETS := [
	Rect2i(0, 17, 13, 2),        # estrada que vem da fazenda (oeste)
	Rect2i(11, 9, 2, 25),        # avenida oeste
	Rect2i(37, 9, 2, 25),        # avenida leste
	Rect2i(11, 9, 28, 2),        # rua das lojas (norte)
	Rect2i(2, 26, 46, 2),        # rua das casas 1
	Rect2i(2, 32, 46, 2),        # rua das casas 2
	Rect2i(23, 22, 4, 4),        # passagem da praça para a rua das casas
	Rect2i(39, 17, 9, 2),        # caminho do parque (vai até a beira do laguinho)
]
## Praça central (piso de lajotas) e os canteiros de flores dela
const PLAZA := Rect2i(15, 11, 20, 11)
const BEDS := [Rect2i(15, 11, 2, 2), Rect2i(33, 11, 2, 2), Rect2i(15, 20, 2, 2), Rect2i(33, 20, 2, 2),
	Rect2i(24, 14, 2, 1)]
## Laguinho do parque (elipse: centro e raios em quadrados)
const POND_C := Vector2(43.5, 21.5)
const POND_R := Vector2(3.3, 2.3)

## Prédios: [arte, centro x (em quadrados), linha da base, tipo, rótulo da porta]
## A base fica na borda de cima da linha (a frente encosta na rua).
const BUILDINGS := [
	# rua das lojas
	["restaurant", 15.0, 9, "restaurant", "Restaurante"],
	["bakery", 18.7, 9, "bakery", "Padaria"],
	["blacksmith", 22.6, 9, "smith", "Ferraria"],
	["tailor", 26.9, 9, "tailor", "Ateliê de Roupas"],
	["fish_shop", 31.2, 9, "fish", "Peixaria"],
	# praça: a Feira (Vó Raiz), o poço e o quadro de avisos
	["market", 19.0, 15, "market", "Feira"],
	["well", 25.0, 18, "well", "Poço"],
	["notice_board", 31.0, 21, "board", "Quadro de avisos"],
	# rua das casas 1
	["house_red", 4.6, 26, "home", "Casa de morador"],
	["barn_house", 8.7, 26, "home", "Casa de morador"],
	["inn", 17.6, 26, "inn", "Pousada"],
	["house_red_green", 29.6, 26, "home", "Casa de morador"],
	["barn_house_blue", 33.9, 26, "home", "Casa de morador"],
	# rua das casas 2
	["windmill", 4.2, 32, "windmill", "Moinho"],
	["house_red_purple", 8.6, 32, "home", "Casa de morador"],
	["house_red_blue", 15.7, 32, "home", "Casa de morador"],
	["barn_house_red", 19.9, 32, "home", "Casa de morador"],
	["inn_red", 30.0, 32, "home", "Casa grande"],
	["barn_house", 34.4, 32, "home", "Casa de morador"],
	["signpost", 4.0, 17, "sign", "Placa"],
]
## Enfeites: [arte, x, linha da base]
const DECOR := [
	# barracas da feira (só enfeite) e o que fica em volta delas
	["market_red", 31.0, 15], ["market_green", 19.0, 20], ["crate", 21.0, 15], ["barrel", 21.6, 15],
	["crate", 29.0, 15], ["barrel", 33.0, 15], ["crate", 21.0, 20],
	# bancos em volta do poço
	["bench", 22.0, 17], ["bench", 28.0, 17], ["bench", 22.0, 20], ["bench", 28.0, 20],
	# postes: cantos da praça, ruas e avenidas
	["lamp_post", 14.6, 11], ["lamp_post", 35.4, 11], ["lamp_post", 14.6, 22], ["lamp_post", 35.4, 22],
	["lamp_post", 6.0, 17], ["lamp_post", 10.6, 26], ["lamp_post", 22.5, 26], ["lamp_post", 27.5, 26],
	["lamp_post", 39.4, 26], ["lamp_post", 10.6, 32], ["lamp_post", 25.0, 32], ["lamp_post", 39.4, 32],
	["lamp_post", 10.6, 9], ["lamp_post", 39.4, 9], ["lamp_post", 40.5, 17],
	# na frente das lojas e das casas
	["banner_post", 34.0, 9], ["barrel", 35.2, 9], ["crate", 36.0, 9],
	["barrel", 13.4, 26], ["crate", 21.6, 26], ["barrel", 36.0, 26],
	["crate", 12.8, 32], ["barrel", 22.2, 32], ["crate", 27.2, 32], ["barrel", 36.2, 32],
	["bench", 44.0, 26], ["bench", 41.0, 32], ["bench", 45.0, 32],
]
## Flores (último estágio da planta): [planta, x, y] em quadrados (no meio dos canteiros e no parque)
const FLOWERS := [
	["tulip", 15.6, 11.9], ["rose", 16.4, 12.6], ["daisy", 15.5, 12.9], ["lavender", 16.5, 11.7],
	["sunflower", 33.6, 11.9], ["hydrangea", 34.4, 12.6], ["tulip", 33.5, 12.9], ["pink_tulip", 34.5, 11.8],
	["rose", 15.6, 20.9], ["lavender", 16.4, 21.6], ["pink_tulip", 15.5, 21.9], ["daisy", 16.5, 20.7],
	["hydrangea", 33.6, 20.9], ["sunflower", 34.4, 21.6], ["daisy", 33.5, 21.9], ["tulip", 34.5, 20.7],
	["rose", 24.3, 14.5], ["tulip", 25.0, 14.4], ["pink_tulip", 25.7, 14.5],
	["daisy", 41.0, 19.5], ["tulip", 46.2, 20.0], ["lavender", 45.8, 24.4], ["rose", 40.8, 23.8],
	["sunflower", 24.0, 29.2], ["sunflower", 26.0, 29.2], ["hydrangea", 25.0, 30.0],
]
## Parques e bosques (árvores e arbustos sorteados)
const PARKS := [Rect2i(2, 2, 9, 15), Rect2i(2, 19, 9, 4), Rect2i(39, 2, 9, 14), Rect2i(39, 19, 9, 6),
	Rect2i(39, 28, 9, 4), Rect2i(23, 28, 4, 3)]
## Topo da chaminé na imagem (tools/import_city.py): fumaça animada. As variações de cor usam a mesma.
const CHIMNEYS := {"house_red": Vector2(94, 11), "restaurant": Vector2(83, 14), "inn": Vector2(114, 14)}
const LAMP_AT := Vector2(10, 15)        # lampião na imagem do poste
const ROW_DECOR := ["bench", "barrel", "crate"]

## Chegar aqui pela estrada oeste e sair por ela
const GATE := Rect2(0, 16 * 32, 2 * 32, 4 * 32)
const ARRIVE := Vector2(3 * 32 + 16, 17 * 32 + 26)

## Moradores que passeiam pela cidade (os que não cuidam de loja) e onde cada um gosta de ficar
const STROLL := {"carpa": Vector2i(43, 17), "pipoca": Vector2i(21, 17), "estrelo": Vector2i(29, 13),
	"raiz": Vector2i(6, 20)}

var spawn_pos := ARRIVE
var doors := {}        # tipo do prédio -> posição da porta (para voltar da loja)
var _plaza_cells := {}


func region_id() -> String:
	return "city"


func water_kind(_c: Vector2i) -> String:
	return ""


func _is_free_grass(_c: Vector2i) -> bool:
	return false        # não se ara na cidade


func can_place(_kind: String, _target: Vector2i) -> bool:
	return false


## Saída da cidade: perto da borda oeste, na estrada.
func exit_at(pos: Vector2) -> String:
	return "farm" if GATE.has_point(pos) else ""


func generate(_saved: Dictionary) -> void:
	ground.resize(W * H)
	variant.resize(W * H)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for i in W * H:
		ground[i] = Ground.GRASS
		var r := rng.randf()
		variant[i] = 1 if r < 0.06 else (2 if r < 0.16 else 0)
	for r in STREETS:
		_path_rect(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1)
	_path_rect(PLAZA.position.x, PLAZA.position.y, PLAZA.end.x - 1, PLAZA.end.y - 1)
	for y in range(PLAZA.position.y, PLAZA.end.y):
		for x in range(PLAZA.position.x, PLAZA.end.x):
			_plaza_cells[Vector2i(x, y)] = true
	for b in BEDS:
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				ground[y * W + x] = Ground.GRASS
				_plaza_cells.erase(Vector2i(x, y))
				blocked[Vector2i(x, y)] = true
	for y in H:
		for x in W:
			var d := (Vector2(x + 0.5, y + 0.5) - POND_C) / POND_R
			if d.length_squared() <= 1.0:
				ground[y * W + x] = Ground.WATER
	_build_world_bounds()
	_build_water_collision()
	for b in BUILDINGS:
		_add_building(b[0], b[1], b[2], b[3], b[4])
	for d in DECOR:
		_add_decor(d[0], d[1], d[2])
	for f in FLOWERS:
		_add_flower(f[0], f[1], f[2])
	_add_trees(rng)
	_spawn_strollers.call_deferred()
	if Game.tractor.get("owned", false) and Game.tractor.get("where", "farm") == "city":
		spawn_tractor(Vector2(float(Game.tractor["x"]), float(Game.tractor["y"])))     # ficou estacionado aqui
	_ground_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	_ground_layer.queue_redraw()


func _sprite_at(art: String, cx: float, base_row: int) -> Array:
	var holder := StaticBody2D.new()
	holder.position = Vector2(cx * TILE, base_row * TILE)
	var s := Sprite2D.new()
	s.texture = load(DIR + art + ".png")
	s.position = Vector2(0, -s.texture.get_height() / 2.0 + 2)
	holder.add_child(s)
	entities.add_child(holder)
	return [holder, s]


func _add_building(art: String, cx: float, base_row: int, kind: String, label: String) -> void:
	var hs := _sprite_at(art, cx, base_row)
	var holder: StaticBody2D = hs[0]
	var s: Sprite2D = hs[1]
	var w := s.texture.get_width()
	var h := s.texture.get_height()
	var small := kind in ["well", "board", "sign"] or art.begins_with("market")
	var deep := 22.0 if small else 30.0
	_add_rect_collision(holder, Vector2(w - 14, deep), Vector2(0, -deep / 2.0 - 2))
	var c0 := int(floor(cx - w / 2.0 / TILE))
	var c1 := int(ceil(cx + w / 2.0 / TILE)) - 1
	for y in range(base_row - int(ceil(h / float(TILE))), base_row):
		for x in range(c0, c1 + 1):
			blocked[Vector2i(x, y)] = true       # nada de árvore atrás do prédio
	for key in CHIMNEYS:
		if art.begins_with(key):
			var sm := FX.spawn_loop(s, "chimney", _img_pt(s, CHIMNEYS[key] + Vector2(0, -12)))
			sm.z_index = 1
	if art == "well":
		for lx in [12.0, 69.0]:
			add_glow(s, _img_pt(s, Vector2(lx, 24)), 30.0)
	var door := Interactable.new()
	door.label = label
	door.reach = 30.0
	door.position = holder.position + Vector2(0, 8 if small else 4)
	door.interacted.connect(func(_w): building_used.emit(kind))
	if not doors.has(kind):
		doors[kind] = door.position
	entities.add_child(door)


func _add_decor(art: String, cx: float, base_row: int) -> void:
	var hs := _sprite_at(art, cx, base_row)
	var holder: StaticBody2D = hs[0]
	var s: Sprite2D = hs[1]
	var w := s.texture.get_width()
	var h := s.texture.get_height()
	if art.begins_with("market"):
		_add_rect_collision(holder, Vector2(w - 14, 22), Vector2(0, -13))
		for y in range(base_row - int(ceil(h / float(TILE))), base_row):
			for x in range(int(floor(cx - w / 2.0 / TILE)), int(ceil(cx + w / 2.0 / TILE))):
				blocked[Vector2i(x, y)] = true
	else:
		_add_rect_collision(holder, Vector2(maxf(8.0, w - 6.0), 8), Vector2(0, -6))
		blocked[Vector2i(int(cx), base_row - 1)] = true
	if art == "lamp_post":
		add_glow(s, _img_pt(s, LAMP_AT), 48.0)


## Uma flor (o último estágio da planta) plantada no canteiro, sem colisão.
func _add_flower(id: String, x: float, y: float) -> void:
	var tex: Texture2D = load("res://assets/sprites/crops/%s.png" % id)
	if tex == null:
		return
	var at := AtlasTexture.new()
	at.atlas = tex
	var n := int(tex.get_width() / 32)
	at.region = Rect2((n - 1) * 32, 0, 32, tex.get_height())
	var s := Sprite2D.new()
	s.texture = at
	s.centered = false
	s.offset = Vector2(-16, -tex.get_height())
	s.position = Vector2(x * TILE, y * TILE + 6)
	entities.add_child(s)


## Árvores e arbustos: na borda do mapa e nos parques (não podem ser cortados aqui).
func _add_trees(rng: RandomNumberGenerator) -> void:
	for x in range(0, W, 3):
		_spawn_prop("old_tree", Vector2i(x, 0), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x + 1, 1), -1, rng.randi())
		# embaixo: pinheiros e arbustos baixos (as árvores grandes cobririam as casas da rua 2)
		_spawn_prop("pine", Vector2i(x + 1, H - 1), -1, rng.randi())
		_spawn_prop("bush", Vector2i(x, H - 2), -1, rng.randi())
	for y in range(2, H - 2, 2):
		if y < 15 or y > 20:          # a estrada oeste fica livre
			_spawn_prop("pine", Vector2i(0, y), -1, rng.randi())
		_spawn_prop("pine", Vector2i(W - 1, y + 1), -1, rng.randi())
	for park in PARKS:
		for y in range(park.position.y, park.end.y):
			for x in range(park.position.x, park.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) != Ground.GRASS or blocked.has(c) or _covers_street(c):
					continue
				var r := rng.randf()
				if r < 0.16 and _can_place_tree(c, 1):
					_spawn_prop("tree", c, -1, rng.randi())
				elif r < 0.26:
					_spawn_prop("bush", c, -1, rng.randi())
	# cerquinha na beira do laguinho
	for x in [41, 42, 45, 46]:
		_spawn_prop("fence", Vector2i(x, 24), -1, 0)


## Árvore aqui cobriria a rua com a copa (rua logo acima) ou ficaria colada nela?
func _covers_street(c: Vector2i) -> bool:
	for dy in range(-3, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if is_inside(n) and ground_at(n) == Ground.PATH:
				return true
	return false


func _draw_ground() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			match ground[i]:
				Ground.PATH:
					var tex: Texture2D = PLAZA_TEX if _plaza_cells.has(Vector2i(x, y)) else COBBLE_TEX
					_ground_layer.draw_texture_rect_region(tex, dest, dest)
				Ground.WATER:
					var up := y > 0 and ground[i - W] != Ground.WATER
					_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_WATER_BANK if up else T_WATER))
				_:
					_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_GRASS[variant[i]]))
	# meio-fio: uma beirada escura onde o calçamento encontra a grama
	for y in H:
		for x in W:
			if ground[y * W + x] != Ground.PATH:
				continue
			var p := Vector2(x * TILE, y * TILE)
			if y > 0 and ground[(y - 1) * W + x] != Ground.PATH:
				_ground_layer.draw_rect(Rect2(p, Vector2(TILE, 2)), CURB)
			if y < H - 1 and ground[(y + 1) * W + x] != Ground.PATH:
				_ground_layer.draw_rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 3)), CURB)
			if x > 0 and ground[y * W + x - 1] != Ground.PATH:
				_ground_layer.draw_rect(Rect2(p, Vector2(2, TILE)), CURB)
			if x < W - 1 and ground[y * W + x + 1] != Ground.PATH:
				_ground_layer.draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), CURB)


func _spawn_strollers() -> void:
	for id in Villagers.all_ids():
		var d := Villagers.get_npc(id)
		if d.shop != "":
			continue
		var npc := NPC.new()
		npc.setup(d, self)
		npc.home_cell = STROLL.get(id, Vector2i(25, 24))
		npc.position = cell_center(nearest_passable(npc.home_cell))
		npc.interacted.connect(func(_w): villager_used.emit(id))
		entities.add_child(npc)
		villagers.append(npc)


## Ferramentas não fazem nada na cidade (as árvores e o chão daqui não são seus).
func would_act(item_id: String, c: Vector2i) -> bool:
	return item_id == "" and can_interact_cell(c)


func use_item(item_id: String, c: Vector2i) -> String:
	if item_id == "":
		return interact_cell(c)
	if ItemDB.get_item(item_id).get("type", "") in ["tool", "seed", "placeable", "fertilizer"]:
		return "Na cidade não dá para usar isso."
	return ""
