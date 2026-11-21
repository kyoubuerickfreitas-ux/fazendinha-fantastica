class_name CityWorld
extends FarmWorld
## A cidade: um mapa à parte (como a mina e a casa), aonde se chega pela estrada a oeste da fazenda.
## Praça calçada com o poço no meio, lojas em volta (cada uma abre a sua janela em main.gd) e casas
## de moradores ao sul. Arte: tools/import_city.py (assets/sprites/city/).
## Não se ara, não se planta e não se constrói aqui.

signal exit_used                       ## saiu pela estrada de volta à fazenda
signal building_used(kind: String)     ## tocou na porta de uma loja/casa (ver BUILDINGS)

const DIR := "res://assets/sprites/city/"
const COBBLE_TEX := preload("res://assets/sprites/city/cobble.png")

## Prédios: [arte, centro x (em quadrados), linha da base, tipo, rótulo da porta]
## A base fica na borda de cima da linha (a frente encosta no calçamento).
const BUILDINGS := [
	["restaurant", 16.0, 14, "restaurant", "Restaurante"],
	["bakery", 19.9, 14, "bakery", "Padaria"],
	["blacksmith", 24.0, 14, "smith", "Ferraria"],
	["tailor", 28.3, 14, "tailor", "Ateliê de Roupas"],
	["market", 32.1, 14, "market", "Feira"],
	["fish_shop", 36.4, 14, "fish", "Peixaria"],
	["inn", 17.0, 30, "inn", "Pousada"],
	["house_red", 30.0, 30, "home", "Casa de morador"],
	["barn_house", 34.4, 30, "home", "Casa de morador"],
	["windmill", 38.6, 30, "windmill", "Moinho"],
	["well", 25.0, 19, "well", "Poço"],
	["notice_board", 21.0, 23, "board", "Quadro de avisos"],
	["signpost", 4.0, 16, "sign", "Placa"],
]
## Enfeites: [arte, x, linha da base]
const DECOR := [
	["lamp_post", 14.4, 14], ["lamp_post", 38.8, 14], ["lamp_post", 14.4, 23], ["lamp_post", 38.8, 23],
	["lamp_post", 8.0, 17], ["lamp_post", 23.3, 30], ["lamp_post", 26.7, 30], ["lamp_post", 41.5, 30],
	["banner_post", 39.6, 14], ["bench", 21.5, 20], ["bench", 28.5, 20], ["bench", 30.0, 23],
	["barrel", 40.2, 23], ["crate", 41.0, 23], ["barrel", 13.4, 30], ["crate", 12.6, 30], ["barrel", 43.0, 30],
]
## Remendos de pedra no chão (desenhados com o chão): [arte, x, y] em quadrados
const PATCHES := [["patch_a", 9.0, 24.0], ["patch_b", 44.0, 11.0], ["patch_a", 6.0, 9.0], ["patch_b", 31.0, 33.0]]
## Topo da chaminé de cada prédio na imagem (tools/import_city.py): fumaça animada
const CHIMNEYS := {"house_red": Vector2(94, 11), "restaurant": Vector2(83, 14), "inn": Vector2(114, 14)}
const LAMP_AT := Vector2(10, 15)        # lampião na imagem do poste

## Ruas calçadas (retângulos em quadrados, inclusive)
const STREETS := [
	Rect2i(0, 16, 15, 3),        # estrada que vem da fazenda (oeste)
	Rect2i(14, 14, 25, 9),       # praça
	Rect2i(24, 23, 3, 7),        # rua para as casas
	Rect2i(12, 30, 32, 2),       # rua das casas
]
## Chegar aqui pela estrada oeste e sair por ela
const GATE := Rect2(0, 15 * 32, 2 * 32, 5 * 32)
const ARRIVE := Vector2(3 * 32 + 16, 17 * 32 + 16)

var spawn_pos := ARRIVE
var doors := {}        # tipo do prédio -> posição da porta (para voltar da loja)
var _patch_tex := {}


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
	rng.seed = 20261121
	for i in W * H:
		ground[i] = Ground.GRASS
		var r := rng.randf()
		variant[i] = 1 if r < 0.06 else (2 if r < 0.16 else 0)
	for r in STREETS:
		_path_rect(r.position.x, r.position.y, r.end.x - 1, r.end.y - 1)
	for p in PATCHES:
		if not _patch_tex.has(p[0]):
			_patch_tex[p[0]] = load(DIR + p[0] + ".png")
	_build_world_bounds()
	for b in BUILDINGS:
		_add_building(b[0], b[1], b[2], b[3], b[4])
	for d in DECOR:
		_add_decor(d[0], d[1], d[2])
	_add_trees(rng)
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
	var deep := 22.0 if kind in ["well", "board", "sign"] else 30.0
	_add_rect_collision(holder, Vector2(w - 14, deep), Vector2(0, -deep / 2.0 - 2))
	var c0 := int(floor(cx - w / 2.0 / TILE))
	var c1 := int(ceil(cx + w / 2.0 / TILE)) - 1
	for y in range(base_row - 2, base_row):
		for x in range(c0, c1 + 1):
			blocked[Vector2i(x, y)] = true
	if CHIMNEYS.has(art):
		var sm := FX.spawn_loop(s, "chimney", _img_pt(s, CHIMNEYS[art] + Vector2(0, -12)))
		sm.z_index = 1
	if art == "well":
		for lx in [12.0, 69.0]:
			add_glow(s, _img_pt(s, Vector2(lx, 24)), 30.0)
	var door := Interactable.new()
	door.label = label
	door.reach = 30.0
	door.position = holder.position + Vector2(0, 8 if kind in ["well", "board", "sign"] else 4)
	door.interacted.connect(func(_w): building_used.emit(kind))
	doors[kind] = door.position
	entities.add_child(door)


func _add_decor(art: String, cx: float, base_row: int) -> void:
	var hs := _sprite_at(art, cx, base_row)
	var holder: StaticBody2D = hs[0]
	var s: Sprite2D = hs[1]
	var w := s.texture.get_width()
	_add_rect_collision(holder, Vector2(maxf(8.0, w - 6.0), 8), Vector2(0, -6))
	blocked[Vector2i(int(cx), base_row - 1)] = true
	if art == "lamp_post":
		add_glow(s, _img_pt(s, LAMP_AT), 48.0)


## Árvores e arbustos em volta, longe das ruas e dos prédios (não podem ser cortados aqui).
func _add_trees(rng: RandomNumberGenerator) -> void:
	for x in range(0, W, 3):
		_spawn_prop("old_tree", Vector2i(x, 0), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x + 1, 1), -1, rng.randi())
		_spawn_prop("old_tree", Vector2i(x + 1, H - 1), -1, rng.randi())
		_spawn_prop("pine", Vector2i(x, H - 2), -1, rng.randi())
	for y in range(2, H - 2, 2):
		if y < 14 or y > 20:          # a estrada oeste fica livre
			_spawn_prop("pine", Vector2i(0, y), -1, rng.randi())
		_spawn_prop("pine", Vector2i(W - 1, y + 1), -1, rng.randi())
	for y in range(3, H - 3):
		for x in range(2, W - 2):
			var c := Vector2i(x, y)
			if ground_at(c) != Ground.GRASS or blocked.has(c) or _near_street(c, 2) or _in_town(c):
				continue
			var r := rng.randf()
			if r < 0.07 and _can_place_tree(c, 2):
				_spawn_prop("tree", c, -1, rng.randi())
			elif r < 0.11:
				_spawn_prop("bush", c, -1, rng.randi())


## Área ocupada pelos prédios e seus arredores (sem árvores).
func _in_town(c: Vector2i) -> bool:
	return Rect2i(11, 9, 33, 24).has_point(c)


func _near_street(c: Vector2i, d: int) -> bool:
	for r in STREETS:
		if (r as Rect2i).grow(d).has_point(c):
			return true
	return false


func _draw_ground() -> void:
	for y in H:
		for x in W:
			var i := y * W + x
			var dest := Rect2(x * TILE, y * TILE, TILE, TILE)
			if ground[i] == Ground.PATH:
				_ground_layer.draw_texture_rect_region(COBBLE_TEX, dest, dest)
			else:
				_ground_layer.draw_texture_rect_region(TILES_TEX, dest, _tile_rect(T_GRASS[variant[i]]))
	for p in PATCHES:
		var t: Texture2D = _patch_tex[p[0]]
		_ground_layer.draw_texture(t, Vector2(p[1] * TILE, p[2] * TILE) - t.get_size() / 2.0)


## Ferramentas não fazem nada na cidade (as árvores e o chão daqui não são seus).
func would_act(item_id: String, c: Vector2i) -> bool:
	return item_id == "" and can_interact_cell(c)


func use_item(item_id: String, c: Vector2i) -> String:
	if item_id == "":
		return interact_cell(c)
	if ItemDB.get_item(item_id).get("type", "") in ["tool", "seed", "placeable", "fertilizer"]:
		return "Na cidade não dá para usar isso."
	return ""
