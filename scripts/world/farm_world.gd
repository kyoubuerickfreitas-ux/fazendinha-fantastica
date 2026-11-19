class_name FarmWorld
extends Node2D
## O mapa da fazenda: chão em grade, terra arada, plantações e objetos.
## O chão é desenhado direto (sem TileMap) para ficar simples de gerar e salvar.

const TILE := 32
const W := 50
const H := 38

const TILES_TEX := preload("res://assets/sprites/tiles.png")
const CROPS_TEX := preload("res://assets/sprites/crops.png")
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

var ground := PackedByteArray()
var variant := PackedByteArray()
var blocked := {}        # células onde não se pode arar (casa, caixa, NPC)
var soil := {}           # Vector2i -> {"wet": bool, "crop": String, "growth": int}
var props := {}          # Vector2i -> Prop

var entities: Node2D     # contêiner com Y-sort (jogador, objetos, NPCs)
var animals: Array[Animal] = []

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

	if saved.has("props"):
		for p in saved["props"]:
			_spawn_prop(str(p[0]), Vector2i(int(p[1]), int(p[2])), int(p[3]), int(p[4]) if p.size() > 4 else 0)
	else:
		_generate_props(rng)

	_spawn_animals(saved.get("animals", []))

	soil.clear()
	if saved.has("soil"):
		for s in saved["soil"]:
			soil[Vector2i(int(s["x"]), int(s["y"]))] = {
				"wet": bool(s["wet"]), "crop": str(s["crop"]), "growth": int(s["growth"])}

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


func _spawn_animals(saved: Array) -> void:
	var area := Rect2(PASTURE.position * TILE, PASTURE.size * TILE).grow(-12)
	for i in STARTING_ANIMALS.size():
		var a := Animal.new()
		var pos := area.position + Vector2(area.size.x * (0.15 + 0.18 * i), area.size.y * (0.3 + 0.4 * (i % 2)))
		a.setup(STARTING_ANIMALS[i], area, pos)
		entities.add_child(a)
		if i < saved.size() and saved[i] is Dictionary and saved[i].get("species", "") == STARTING_ANIMALS[i]:
			a.restore(saved[i])
		animals.append(a)


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
		and not props.has(c) and not soil.has(c)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func world_size() -> Vector2:
	return Vector2(W * TILE, H * TILE)


func set_cursor(c: Vector2i, visible_: bool, valid: bool = true) -> void:
	if c != _cursor_cell or visible_ != _cursor_visible or valid != _cursor_valid:
		_cursor_cell = c
		_cursor_visible = visible_
		_cursor_valid = valid
		_cursor.queue_redraw()


## Ponto que representa o alvo de uma célula (a base do objeto, se houver um).
func target_anchor(c: Vector2i) -> Vector2:
	if props.has(c):
		return props[c].position
	return _cell_center(c)


## O item faria alguma coisa nesta célula?
func would_act(item_id: String, c: Vector2i) -> bool:
	if item_id == "":
		return can_interact_cell(c)
	var item := ItemDB.get_item(item_id)
	var prop: Prop = props.get(c)
	if item.get("type", "") == "seed":
		return soil.has(c) and soil[c]["crop"] == "" and prop == null
	match item_id:
		"hoe":
			return prop == null and _is_free_grass(c)
		"fishing_rod":
			return ground_at(c) == Ground.WATER
		"watering_can":
			return ground_at(c) == Ground.WATER or (soil.has(c) and not soil[c]["wet"])
		"axe", "pickaxe", "scythe":
			if prop:
				return prop.required_tool() == item_id
			if item_id == "scythe" and soil.has(c) and soil[c]["crop"] != "":
				return ItemDB.crop_stage(soil[c]["crop"], soil[c]["growth"]) == 3
			if item_id == "pickaxe" and soil.has(c):
				return soil[c]["crop"] == ""
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
			soil[c] = {"wet": Game.weather == "rain", "crop": "", "growth": 0}
			FX.spawn(self, "till", _cell_center(c))
			if randf() < 0.08 and Game.add_item("bait_worm", 1) == 0:
				_popup("+1 Minhoca", _cell_center(c))
			_soil_layer.queue_redraw()
		"watering_can":
			if ground_at(c) == Ground.WATER:
				Game.water = Game.WATER_CAPACITY
				Game.inventory_changed.emit()
				return "Regador cheio!"
			if not soil.has(c) or soil[c]["wet"]:
				return ""
			if Game.water <= 0:
				return "Regador vazio! Encha no lago."
			if not Game.use_energy(ENERGY_COST["watering_can"]):
				return ""
			Game.water -= 1
			soil[c]["wet"] = true
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
			if item_id == "scythe" and soil.has(c) and soil[c]["crop"] != "":
				return _harvest(c, true)
			if item_id == "pickaxe" and soil.has(c) and soil[c]["crop"] == "":
				if not Game.use_energy(ENERGY_COST["pickaxe"]):
					return ""
				soil.erase(c)
				FX.spawn(self, "till", _cell_center(c))
				_soil_layer.queue_redraw()
	return ""


## Interação com a célula usando a mão (colher, arrancar mato).
func interact_cell(c: Vector2i) -> String:
	if soil.has(c) and soil[c]["crop"] != "":
		return _harvest(c, false)
	var prop: Prop = props.get(c)
	if prop and prop.kind == "weed":
		_destroy_prop(prop)
		return ""
	return ""


func can_interact_cell(c: Vector2i) -> bool:
	if soil.has(c) and soil[c]["crop"] != "":
		var s: Dictionary = soil[c]
		return ItemDB.crop_stage(s["crop"], s["growth"]) == 3
	var prop: Prop = props.get(c)
	return prop != null and prop.kind == "weed"


func _plant(seed_id: String, c: Vector2i) -> String:
	if not soil.has(c):
		return "Are a terra antes de plantar."
	if soil[c]["crop"] != "":
		return ""
	soil[c]["crop"] = ItemDB.get_item(seed_id)["crop"]
	soil[c]["growth"] = 0
	Game.remove_from_slot(Game.selected_slot, 1)
	FX.spawn(self, "plant", _cell_center(c) + Vector2(0, 6))
	_soil_layer.queue_redraw()
	return ""


func _harvest(c: Vector2i, with_scythe: bool) -> String:
	var s: Dictionary = soil[c]
	var crop: String = s["crop"]
	if ItemDB.crop_stage(crop, s["growth"]) < 3:
		return "Ainda não está pronta." if not with_scythe else ""
	var def: Dictionary = ItemDB.CROPS[crop]
	var left := Game.add_item(def["produce"], def["amount"])
	if left > 0:
		return ""
	s["crop"] = ""
	s["growth"] = 0
	_popup("+%d %s" % [def["amount"], ItemDB.item_name(def["produce"])], _cell_center(c))
	FX.spawn(self, "harvest", _cell_center(c))
	_soil_layer.queue_redraw()
	return ""


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
func on_new_day() -> void:
	var rain := Game.weather == "rain"
	for c in soil:
		var s: Dictionary = soil[c]
		if s["crop"] != "" and s["wet"]:
			s["growth"] += 1
		s["wet"] = rain
	# o mato volta a crescer aos pouquinhos
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for a in animals:
		a.new_day()
	for i in 3:
		var c := Vector2i(rng.randi_range(5, 24), rng.randi_range(14, 30))
		if _is_free_grass(c):
			_spawn_prop("weed", c, -1, rng.randi())
	_soil_layer.queue_redraw()


# =================================================================== salvar
func serialize() -> Dictionary:
	var p := []
	for c in props:
		var prop: Prop = props[c]
		p.append([prop.kind, c.x, c.y, prop.hp, prop.variant])
	var s := []
	for c in soil:
		var d: Dictionary = soil[c]
		s.append({"x": c.x, "y": c.y, "wet": d["wet"], "crop": d["crop"], "growth": d["growth"]})
	var an := []
	for a in animals:
		an.append(a.serialize())
	return {"props": p, "soil": s, "animals": an}


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


func _draw_soil() -> void:
	for c in soil:
		var s: Dictionary = soil[c]
		var dest := Rect2(c.x * TILE, c.y * TILE, TILE, TILE)
		_soil_layer.draw_texture_rect_region(TILES_TEX, dest,
			_tile_rect(T_TILLED_WET if s["wet"] else T_TILLED))
		if s["crop"] != "":
			var row: int = ItemDB.CROPS[s["crop"]]["row"]
			var stage := ItemDB.crop_stage(s["crop"], s["growth"])
			# a arte tem a base no pé do quadro; sobe para a planta ficar no meio do canteiro
			var lift: float = CROP_LIFT[stage]
			_soil_layer.draw_texture_rect_region(CROPS_TEX, Rect2(dest.position - Vector2(0, lift), dest.size),
				Rect2(stage * TILE, row * TILE, TILE, TILE))


func _draw_cursor() -> void:
	if not _cursor_visible:
		return
	var r := Rect2(_cursor_cell.x * TILE + 1, _cursor_cell.y * TILE + 1, TILE - 2, TILE - 2)
	if _cursor_valid:
		_cursor.draw_rect(r, Color(0.71, 0.79, 0.58, 0.28), true)
		_cursor.draw_rect(r, Color(0.86, 0.95, 0.66, 0.95), false, 2.0)
	else:
		_cursor.draw_rect(r, Color(0.98, 0.95, 0.82, 0.10), true)
		_cursor.draw_rect(r, Color(0.98, 0.95, 0.82, 0.45), false, 1.0)
