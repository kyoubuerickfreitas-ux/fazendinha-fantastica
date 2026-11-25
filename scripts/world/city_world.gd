class_name CityWorld
extends FarmWorld
## A cidade: um mapa à parte (como a mina e a casa), aonde se chega pela estrada leste da fazenda
## (entra-se pelo oeste da cidade). Vila em volta de uma praça calçada (poço, bancos, canteiros): a
## Pousada no alto, lojas em volta (Ferraria, Restaurante, Feira com a horta, Peixaria junto do rio,
## Roupas embaixo), casas em grupos, um coreto e o moinho. Caminhos de terra que fazem curva ligam
## tudo; o rio corre na borda leste, com cais. Arte: tools/import_city.py (assets/sprites/city/).
## Não se ara, não se planta e não se constrói aqui.

signal exit_used                       ## saiu pela estrada de volta à fazenda
signal building_used(kind: String)     ## tocou na porta de uma loja/casa (ver BUILDINGS)

const DIR := "res://assets/sprites/city/"
const PLAZA_TEX := preload("res://assets/sprites/city/plaza.png")
const CURB := Color(0.22, 0.15, 0.1, 0.55)

## Caminhos de terra: linhas por pontos (em quadrados), com 2 quadrados de largura
const PATHS := [
	[Vector2(0, 17.5), Vector2(7, 17.5), Vector2(13, 17.2), Vector2(19, 16.2)],          # estrada da fazenda
	[Vector2(25.5, 11), Vector2(25.5, 9)],                                                # praça -> Pousada
	[Vector2(20, 11.5), Vector2(17, 9.8), Vector2(12, 10.2), Vector2(8.5, 9.8), Vector2(3.5, 9)],
	[Vector2(31, 11.5), Vector2(36, 10.3), Vector2(41, 9.8)],                             # -> Restaurante
	[Vector2(31, 15.5), Vector2(36, 16.8), Vector2(40, 17.6), Vector2(43, 19.6)],         # -> Peixaria e cais
	[Vector2(25.5, 19.5), Vector2(26.2, 24), Vector2(26, 27.6), Vector2(25, 32), Vector2(24.2, 37.5)],
	[Vector2(11, 17.5), Vector2(11.5, 21), Vector2(12, 23.8)],
	[Vector2(2, 23.9), Vector2(8, 24.1), Vector2(17.5, 23.9), Vector2(21, 22.5), Vector2(23.5, 19.5)],
	[Vector2(12, 24), Vector2(12.5, 28), Vector2(12, 33.8)],
	[Vector2(4, 33.9), Vector2(12, 33.9), Vector2(19.5, 34.1), Vector2(25, 33)],
	[Vector2(31, 19.5), Vector2(33.5, 22.5), Vector2(34, 26.7), Vector2(39, 26.9), Vector2(42, 29.5),
		Vector2(43.5, 32.6)],
]
## Praça central (piso de lajotas) e os canteiros de flores dela
const PLAZA := Rect2i(19, 11, 13, 9)
const BEDS := [Rect2i(19, 11, 2, 2), Rect2i(30, 11, 2, 2), Rect2i(19, 18, 2, 2), Rect2i(30, 18, 2, 2)]
## Rio na borda leste: a margem faz curva (x da margem em cada linha) e os cais entram nele
const RIVER_X := 45
const DOCKS := [Rect2i(43, 19, 5, 2), Rect2i(43, 32, 4, 2)]
## Horta ao lado da Feira (terra arada com fileiras de verduras)
const FIELD := Rect2i(2, 11, 6, 5)
const FIELD_CROPS := ["carrot", "kale", "beet", "pumpkin", "radish"]

## Prédios: [arte, centro x (em quadrados), linha da base, tipo, rótulo da porta]
## A base fica na borda de cima da linha (a porta dá para o caminho).
const BUILDINGS := [
	["windmill", 3.6, 8, "windmill", "Moinho"],
	["house_red_green", 8.6, 9, "home", "Casa de morador"],
	["blacksmith", 16.6, 9, "smith", "Ferraria"],
	["inn", 25.5, 9, "inn", "Pousada"],
	["notice_board", 30.6, 9, "board", "Quadro de avisos"],
	["restaurant", 41.0, 9, "restaurant", "Restaurante"],
	["market", 11.0, 16, "market", "Feira"],
	["well", 25.5, 16, "well", "Poço"],
	["fish_shop", 39.6, 17, "fish", "Peixaria"],
	["house_red", 4.4, 23, "home", "Casa de morador"],
	["house_red_blue", 9.0, 23, "home", "Casa de morador"],
	["barn_house", 15.6, 23, "home", "Casa de morador"],
	["tailor", 26.0, 27, "tailor", "Ateliê de Roupas"],
	["bakery", 34.0, 26, "bakery", "Padaria"],
	["house_red_purple", 39.2, 26, "home", "Casa de morador"],
	["barn_house_red", 5.6, 33, "home", "Casa de morador"],
	["inn_red", 19.0, 33, "home", "Casa grande"],
	["barn_house_blue", 35.6, 33, "home", "Casa de morador"],
	["signpost", 3.2, 17, "sign", "Placa"],
]
## Enfeites: [arte, x, linha da base]
const DECOR := [
	# praça: bancos em volta do poço e postes nos cantos
	["bench", 22.4, 15], ["bench", 28.6, 15], ["bench", 23.0, 19], ["bench", 28.0, 19],
	["lamp_post", 21.6, 11], ["lamp_post", 29.4, 11], ["lamp_post", 21.6, 18], ["lamp_post", 29.4, 18],
	# coreto (a barraca vermelha) com bancos e o jardim em volta
	["market_red", 12.6, 31], ["bench", 9.6, 31], ["bench", 15.6, 31],
	# na frente das lojas e das casas
	["barrel", 14.0, 9], ["crate", 19.2, 9], ["barrel", 19.8, 9],
	["bench", 37.8, 9], ["barrel", 43.8, 9], ["crate", 44.3, 9],
	["crate", 8.6, 16], ["barrel", 13.6, 16], ["crate", 14.2, 16],
	["barrel", 36.9, 17], ["crate", 42.4, 17], ["barrel", 43.0, 17],
	["banner_post", 22.8, 27], ["barrel", 29.2, 27], ["crate", 31.8, 26],
	["lamp_post", 6.8, 17], ["lamp_post", 14.0, 24], ["lamp_post", 34.0, 20], ["lamp_post", 24.0, 24],
	["lamp_post", 23.0, 34], ["lamp_post", 41.0, 20], ["lamp_post", 2.0, 24], ["lamp_post", 37.0, 11],
	["bench", 44.0, 31],
]
## Flores (último estágio da planta): [planta, x, y] em quadrados (canteiros, jardins e o coreto)
const FLOWERS := [
	["tulip", 19.6, 11.9], ["rose", 20.4, 12.6], ["daisy", 19.5, 12.9], ["lavender", 20.5, 11.7],
	["sunflower", 30.6, 11.9], ["hydrangea", 31.4, 12.6], ["tulip", 30.5, 12.9], ["pink_tulip", 31.5, 11.8],
	["rose", 19.6, 18.9], ["lavender", 20.4, 19.6], ["pink_tulip", 19.5, 19.9], ["daisy", 20.5, 18.7],
	["hydrangea", 30.6, 18.9], ["sunflower", 31.4, 19.6], ["daisy", 30.5, 19.9], ["tulip", 31.5, 18.7],
	["rose", 10.0, 33.4], ["tulip", 11.0, 34.6], ["daisy", 14.0, 34.6], ["lavender", 15.2, 33.4],
	["pink_tulip", 8.6, 35.2], ["hydrangea", 16.4, 35.2],
	["tulip", 2.4, 21.6], ["daisy", 6.8, 21.6], ["rose", 11.2, 21.6], ["lavender", 13.2, 21.6],
	["sunflower", 21.6, 27.4], ["sunflower", 30.4, 27.4], ["pink_tulip", 37.0, 24.4], ["rose", 41.6, 24.4],
	["daisy", 27.8, 9.4], ["tulip", 23.0, 9.4], ["hydrangea", 6.6, 9.6], ["rose", 38.6, 33.4],
]
## Bosques (árvores e arbustos sorteados): o resto da grama, longe dos caminhos e dos prédios
const PARKS := [Rect2i(0, 0, 50, 38)]
## Topo da chaminé na imagem (tools/import_city.py): fumaça animada. As variações de cor usam a mesma.
const CHIMNEYS := {"house_red": Vector2(94, 11), "restaurant": Vector2(83, 14), "inn": Vector2(114, 14)}
const LAMP_AT := Vector2(10, 15)        # lampião na imagem do poste
const ROW_DECOR := ["bench", "barrel", "crate"]

## Chegar aqui pela estrada oeste e sair por ela
const GATE := Rect2(0, 16 * 32, 2 * 32, 4 * 32)
const ARRIVE := Vector2(3 * 32 + 16, 17 * 32 + 26)

## Moradores que passeiam pela cidade (os que não cuidam de loja) e onde cada um gosta de ficar
const STROLL := {"carpa": Vector2i(44, 20), "pipoca": Vector2i(23, 13), "estrelo": Vector2i(13, 32),
	"raiz": Vector2i(8, 17)}

var spawn_pos := ARRIVE
var doors := {}        # tipo do prédio -> posição da porta (para voltar da loja)
var _plaza_cells := {}
var _dock_cells := {}
var _field_cells := {}


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
	for line in PATHS:
		_dirt_line(line)
	for y in range(PLAZA.position.y, PLAZA.end.y):
		for x in range(PLAZA.position.x, PLAZA.end.x):
			ground[y * W + x] = Ground.PATH
			_plaza_cells[Vector2i(x, y)] = true
	for b in BEDS:
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				ground[y * W + x] = Ground.GRASS
				_plaza_cells.erase(Vector2i(x, y))
				blocked[Vector2i(x, y)] = true
	for y in H:
		for x in range(river_edge(y), W):
			ground[y * W + x] = Ground.WATER
		ground[y * W + river_edge(y) - 1] = Ground.PATH          # prainha de terra na beira do rio
	for d in DOCKS:
		for y in range(d.position.y, d.end.y):
			for x in range(d.position.x, d.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) == Ground.WATER:
					_dock_cells[c] = true
				ground[y * W + x] = Ground.PATH
	for y in range(FIELD.position.y, FIELD.end.y):
		for x in range(FIELD.position.x, FIELD.end.x):
			_field_cells[Vector2i(x, y)] = true
			blocked[Vector2i(x, y)] = true
	_build_world_bounds()
	_build_water_collision()
	for b in BUILDINGS:
		_add_building(b[0], b[1], b[2], b[3], b[4])
	for d in DECOR:
		_add_decor(d[0], d[1], d[2])
	for f in FLOWERS:
		_add_flower(f[0], f[1], f[2])
	for y in range(FIELD.position.y, FIELD.end.y):          # horta: uma fileira de cada verdura
		var crop: String = FIELD_CROPS[(y - FIELD.position.y) % FIELD_CROPS.size()]
		for x in range(FIELD.position.x, FIELD.end.x):
			_add_flower(crop, x + 0.5, y + 0.85)
	_add_trees(rng)
	_spawn_strollers.call_deferred()
	if Game.tractor.get("owned", false) and Game.tractor.get("where", "farm") == "city":
		spawn_tractor(Vector2(float(Game.tractor["x"]), float(Game.tractor["y"])))     # ficou estacionado aqui
	_ground_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground_layer.modulate = CropDB.season(Game.season_id()).tint
	_ground_layer.queue_redraw()


## Margem do rio (primeira coluna de água) na linha y: faz uma curva suave.
func river_edge(y: int) -> int:
	return RIVER_X + int(round(sin(y / 5.0) * 1.2 + sin(y / 2.3) * 0.4))


## Caminho de terra por uma linha de pontos (2 quadrados de largura).
func _dirt_line(pts: Array) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) * 3.0)) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			for dy in [-1, 0]:
				for dx in [-1, 0]:
					var c := Vector2i(int(floor(p.x + dx + 0.5)), int(floor(p.y + dy + 0.5)))
					if is_inside(c):
						ground[c.y * W + c.x] = Ground.PATH


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


## Árvores e arbustos: nas bordas e na grama que sobra (não podem ser cortados aqui).
func _add_trees(rng: RandomNumberGenerator) -> void:
	for x in range(0, river_edge(0) - 1, 3):
		_spawn_prop("old_tree", Vector2i(x, 0), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x + 1, 1), -1, rng.randi())
	for x in range(0, river_edge(H - 1) - 1, 3):
		if ground_at(Vector2i(x, H - 1)) == Ground.GRASS:
			_spawn_prop("pine", Vector2i(x, H - 1), -1, rng.randi())
	for y in range(2, H - 2, 2):
		if y < 15 or y > 20:          # a estrada oeste fica livre
			_spawn_prop("pine", Vector2i(0, y), -1, rng.randi())
	for park in PARKS:
		for y in range(park.position.y, park.end.y):
			for x in range(park.position.x, park.end.x):
				var c := Vector2i(x, y)
				if ground_at(c) != Ground.GRASS or blocked.has(c) or x >= river_edge(y) - 1:
					continue
				var r := rng.randf()
				if not _covers_street(c) and not _near_building(c):
					if r < 0.28 and _can_place_tree(c, 1):
						_spawn_prop("tree", c, -1, rng.randi())
					elif r < 0.42:
						_spawn_prop("bush", c, -1, rng.randi())
				elif r < 0.07 and not _next_to_path(c) and not blocked.has(c + Vector2i.UP):
					_spawn_prop("bush", c, -1, rng.randi())      # arbustinhos entre as casas
	# cerquinha em volta da horta e dos jardins das casas
	for x in range(FIELD.position.x, FIELD.end.x, 1):
		_spawn_prop("fence", Vector2i(x, FIELD.end.y), -1, 0)


func _next_to_path(c: Vector2i) -> bool:
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if is_inside(c + d) and ground_at(c + d) == Ground.PATH:
			return true
	return false


## Perto de um prédio ou da praça (a copa sobe uns 4 quadrados: cobriria a fachada logo acima)?
func _near_building(c: Vector2i) -> bool:
	for dy in range(-5, 2):
		for dx in range(-2, 3):
			var n := c + Vector2i(dx, dy)
			if blocked.has(n) or _plaza_cells.has(n):
				return true
	return false


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
			var c := Vector2i(x, y)
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _plaza_cells.has(c):
				_ground_layer.draw_texture_rect_region(PLAZA_TEX, dest, dest)
			elif _dock_cells.has(c):
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_WATER))
			elif _field_cells.has(c):
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_TILLED))
			else:
				match ground[i]:
					Ground.PATH:
						_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_PATH))
					Ground.WATER:
						var up := y > 0 and ground[i - W] != Ground.WATER and not _dock_cells.has(c + Vector2i.UP)
						_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_WATER_BANK if up else T_WATER))
						if x > 0 and ground[i - 1] != Ground.WATER and not _dock_cells.has(c + Vector2i.LEFT):
							_ground_layer.draw_rect(Rect2(dest.position, Vector2(4, TILE)), Color(0.42, 0.3, 0.17, 0.85))
					_:
						_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_GRASS[variant[i]]))
	for d in _dock_cells:
		_ground_layer.draw_texture(BRIDGE_TEX, Vector2(d.x * TILE, d.y * TILE - 6))
	# beirada escura onde as lajotas da praça encontram a terra ou a grama
	for c in _plaza_cells:
		var p := Vector2(c.x * TILE, c.y * TILE)
		if not _plaza_cells.has(c + Vector2i.UP):
			_ground_layer.draw_rect(Rect2(p, Vector2(TILE, 2)), CURB)
		if not _plaza_cells.has(c + Vector2i.DOWN):
			_ground_layer.draw_rect(Rect2(p + Vector2(0, TILE - 3), Vector2(TILE, 3)), CURB)
		if not _plaza_cells.has(c + Vector2i.LEFT):
			_ground_layer.draw_rect(Rect2(p, Vector2(2, TILE)), CURB)
		if not _plaza_cells.has(c + Vector2i.RIGHT):
			_ground_layer.draw_rect(Rect2(p + Vector2(TILE - 2, 0), Vector2(2, TILE)), CURB)


var passersby: Array[Passerby] = []


func _spawn_strollers() -> void:
	# gente andando pelas ruas (tools/import_townsfolk.py): começa espalhada pelo calçamento
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var street_cells := []
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if ground_at(c) == Ground.PATH and not blocked.has(c) and x > 3:
				street_cells.append(c)
	for i in Passerby.PEOPLE.size():
		var pb := Passerby.new()
		pb.setup(i, self)
		pb.position = cell_center(street_cells[rng.randi() % street_cells.size()])
		entities.add_child(pb)
		passersby.append(pb)

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
