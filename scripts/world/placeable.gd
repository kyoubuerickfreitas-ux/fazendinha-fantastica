class_name Placeable
extends StaticBody2D
## Objeto construído pelo jogador (bancada, máquina, comedouro, cerca, celeiro...).
## Ocupa um retângulo de células; a origem do nó fica na base, no meio do retângulo.
## Definições em ItemDB.PLACEABLES e ItemDB.MACHINES.

signal used(p: Placeable)

const SPRITES := "res://assets/sprites/craft/%s.png"

var kind := ""
var origin := Vector2i.ZERO      # célula de cima à esquerda
var size := Vector2i.ONE
## máquina: {"input": id, "output": id, "ready": dia} ou {}
var job := {}
## comedouro/silo: quantidade de feno
var hay := 0
## celeiro/galinheiro: nível (1..3) e produtos guardados pelo coletor automático
var level := 1
var storage: Array = []
var allow_babies := true
## aquário: peixes dentro [{"id", "q"}]
var fish: Array = []
var _swimmers: Array = []

var _sprite: Sprite2D
var _bubble: Sprite2D
var _interact: Interactable


static func footprint(p_kind: String, target: Vector2i) -> Rect2i:
	var sz: Vector2i = ItemDB.PLACEABLES[p_kind]["size"]
	return Rect2i(Vector2i(target.x - (sz.x - 1) / 2, target.y - (sz.y - 1)), sz)


func setup(p_kind: String, p_origin: Vector2i, tile: int) -> void:
	kind = p_kind
	origin = p_origin
	var def: Dictionary = ItemDB.PLACEABLES[kind]
	size = def["size"]
	position = Vector2((origin.x + size.x / 2.0) * tile, (origin.y + size.y) * tile - 2)

	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)
	_refresh_texture()

	if def.get("floor", false):
		z_index = -9          # caminho: desenhado no chão, por baixo de tudo
		collision_layer = 0
	elif def.get("solid", true):
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var h := 10.0 if size.y == 1 else size.y * tile * 0.75
		rect.size = Vector2(size.x * tile - 6, h)
		col.shape = rect
		col.position = Vector2(0, -h / 2.0)
		add_child(col)

	if is_interactive():
		_interact = Interactable.new()
		_interact.reach = 22.0 + size.x * 8.0
		_interact.position = Vector2(0, -6)
		_interact.interacted.connect(func(_w): used.emit(self))
		add_child(_interact)
		_bubble = Sprite2D.new()
		_bubble.visible = false
		add_child(_bubble)
	refresh()


func is_interactive() -> bool:
	return kind in ["workbench", "feeder", "barn", "coop", "silo", "stove"] or is_machine() or is_aquarium()


func is_aquarium() -> bool:
	return ItemDB.PLACEABLES[kind].has("aquarium")


func aquarium_capacity() -> int:
	return int(ItemDB.PLACEABLES[kind].get("aquarium", 0))


func is_machine() -> bool:
	return ItemDB.PLACEABLES[kind].get("machine", false)


func can_pick_up() -> bool:
	if ItemDB.PLACEABLES[kind].get("fixed", false):
		return false
	return job.is_empty() and hay == 0 and fish.is_empty()


func job_ready() -> bool:
	return not job.is_empty() and Game.day >= int(job["ready"])


# ------------------------------------------------------------------ fogo da fornalha
## Máquinas com fogo: ponto da boca e da chaminé em pixels da arte (fogo e fumaça só enquanto trabalham).
const FIRE_AT := {"furnace": [Vector2(17, 32), Vector2(17, 1)]}
var _fire: FX
var _smoke: FX


func _update_fire() -> void:
	if not FIRE_AT.has(kind):
		return
	var working := not job.is_empty() and not job_ready()
	if working and (_fire == null or not is_instance_valid(_fire)):
		var pts: Array = FIRE_AT[kind]
		_fire = FX.spawn_loop(self, "fire_small", _sprite.offset + pts[0])
		_smoke = FX.spawn_loop(self, "smoke", _sprite.offset + pts[1] + Vector2(0, -10))
		_fire.z_index = 1          # na frente da fornalha, mas atrás do que está na frente dela
		_smoke.z_index = 1
	elif not working and _fire and is_instance_valid(_fire):
		_fire.queue_free()
		_smoke.queue_free()
		_fire = null
		_smoke = null


func _refresh_texture() -> void:
	var name := kind
	if kind == "feeder" and hay > 0:
		name = "feeder_full"
	var tex: Texture2D = load(SPRITES % name)
	_sprite.texture = tex
	var pad: int = ItemDB.PLACEABLES[kind].get("pad", 2)
	_sprite.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + pad)


func refresh() -> void:
	if not is_inside_tree() or _sprite == null:
		return
	_refresh_texture()
	if _interact == null:
		return
	match kind:
		"workbench":
			_interact.label = "Fabricar"
		"stove":
			_interact.label = "Cozinhar"
		"barn", "coop":
			var n := 0
			for it in storage:
				n += int(it["qty"])
			_interact.label = "Animais · Nv %d%s" % [level, (" (%d)" % n) if n > 0 else ""]
		"silo":
			_interact.label = "Silo (%d)" % hay
		"feeder":
			_interact.label = "Comedouro (%d)" % hay
		"aquarium_small", "aquarium_large", "fish_pond":
			_interact.label = "%s (%d/%d)" % [ItemDB.item_name(kind), fish.size(), aquarium_capacity()]
			_build_swimmers()
		_:
			if job_ready():
				_interact.label = "Coletar"
			elif job.is_empty():
				_interact.label = "Colocar"
			else:
				_interact.label = "Trabalhando..."
	_update_fire()
	_bubble.visible = is_machine() and job_ready()
	if _bubble.visible:
		var out: String = job["output"]
		_bubble.texture = ItemDB.icon("fertile_egg" if out.begins_with("hatch:") else out)
		_bubble.scale = Vector2.ONE * (16.0 / _bubble.texture.get_width())
		_bubble.position = Vector2(0, _sprite.offset.y - 8)


func _process(_d: float) -> void:
	if not _swimmers.is_empty():
		_animate_swimmers()
	if _bubble and _bubble.visible:
		_bubble.position.y = _sprite.offset.y - 8 + sin(Time.get_ticks_msec() / 300.0) * 1.5


# ------------------------------------------------------------------ máquinas
## Tenta colocar o item na máquina. Retorna mensagem.
func insert(item_id: String) -> String:
	var m: Dictionary = ItemDB.MACHINES[kind]
	if m.has("inputs"):
		return _insert_batch(m, item_id)
	var ok := false
	if m.has("input"):
		ok = item_id == m["input"]
	elif m.has("input_type"):
		ok = ItemDB.get_item(item_id).get("type", "") == m["input_type"]
	if not ok:
		var need: String = ItemDB.item_name(m["input"]) if m.has("input") else ("um peixe" if m["input_type"] == "fish" else "uma colheita")
		return "Precisa de %s na mão." % need
	var slot = Game.inventory[Game.selected_slot]
	var q: int = int(slot.get("q", 0)) if slot != null and slot["id"] == item_id else 0
	if slot != null and slot["id"] == item_id:
		Game.remove_from_slot(Game.selected_slot, 1)
	elif not Game.remove_item(item_id, 1):
		return ""
	job = {"input": item_id, "output": ItemDB.machine_output(kind, item_id), "ready": Game.day + int(m["days"]), "q": q}
	refresh()
	return "%s começou a trabalhar. Fica pronto em %d dia(s)." % [ItemDB.item_name(kind), int(m["days"])]


## Máquina de lote (Fornalha): N do mesmo item -> 1 produto, vários de uma vez.
func _insert_batch(m: Dictionary, item_id: String) -> String:
	var inputs: Dictionary = m["inputs"]
	var need := int(m.get("input_qty", 1))
	if not inputs.has(item_id):
		var names := []
		for k in inputs:
			names.append(ItemDB.item_name(k))
		return "Precisa de %d %s na mão." % [need, " ou ".join(names)]
	var n := mini(Game.count_item(item_id) / need, int(m.get("max_batch", 1)))
	if n <= 0:
		return "Precisa de %d %s (você tem %d)." % [need, ItemDB.item_name(item_id), Game.count_item(item_id)]
	Game.remove_item(item_id, n * need)
	job = {"input": item_id, "output": inputs[item_id], "ready": Game.day + int(m["days"]), "q": 0, "qty": n}
	refresh()
	return "%s começou: %d %s. Pronto amanhã." % [ItemDB.item_name(kind), n, ItemDB.item_name(inputs[item_id])]


func collect() -> String:
	var out: String = job["output"]
	var qty := int(job.get("qty", 1))
	if Game.add_item(out, qty, int(job.get("q", 0))) > 0:
		return ""
	job = {}
	refresh()
	return "+%d %s" % [qty, ItemDB.item_name(out)]


# ------------------------------------------------------------------ aquário
## Segurando um peixe: coloca. Senão: tira o último. Retorna mensagem.
func aquarium_use(held: String) -> String:
	if held != "" and ItemDB.get_item(held).get("type", "") == "fish":
		if fish.size() >= aquarium_capacity():
			return "%s está cheio (%d/%d)." % [ItemDB.item_name(kind), fish.size(), aquarium_capacity()]
		var slot = Game.inventory[Game.selected_slot]
		var q: int = int(slot.get("q", 0)) if slot != null else 0
		Game.remove_from_slot(Game.selected_slot, 1)
		fish.append({"id": held, "q": q})
		refresh()
		return "Colocou %s no %s." % [ItemDB.item_name(held), ItemDB.item_name(kind).to_lower()]
	if fish.is_empty():
		return "Segure um peixe e toque para colocar no %s." % ItemDB.item_name(kind).to_lower()
	var f: Dictionary = fish.back()
	if Game.add_item(f["id"], 1, int(f.get("q", 0))) > 0:
		return "A mochila está cheia."
	fish.pop_back()
	refresh()
	return "Tirou %s do %s." % [ItemDB.item_name(f["id"]), ItemDB.item_name(kind).to_lower()]


func _build_swimmers() -> void:
	for s in _swimmers:
		s["node"].queue_free()
	_swimmers.clear()
	var tank: Rect2 = ItemDB.PLACEABLES[kind]["tank"]
	for i in fish.size():
		var spr := Sprite2D.new()
		spr.texture = ItemDB.icon(fish[i]["id"])
		var px := 14.0 if kind == "fish_pond" else 11.0
		spr.scale = Vector2.ONE * (px / spr.texture.get_width())
		add_child(spr)
		var lane := tank.position.y + tank.size.y * (0.3 + 0.5 * float(i % 3) / 2.0)
		_swimmers.append({"node": spr, "phase": randf() * TAU, "speed": randf_range(0.35, 0.7), "lane": lane})
	_animate_swimmers()


func _animate_swimmers() -> void:
	var tank: Rect2 = ItemDB.PLACEABLES[kind]["tank"]
	var t := Time.get_ticks_msec() / 1000.0
	for s in _swimmers:
		var a: float = t * s["speed"] + s["phase"]
		var spr: Sprite2D = s["node"]
		var half := spr.texture.get_width() * spr.scale.x / 2.0
		spr.position = Vector2(tank.position.x + half + (sin(a) * 0.5 + 0.5) * (tank.size.x - half * 2.0),
			s["lane"] + sin(a * 3.0) * 1.0)
		spr.flip_h = cos(a) > 0.0      # vira para o lado em que nada


# ------------------------------------------------------------------ salvar
func serialize() -> Dictionary:
	return {"kind": kind, "x": origin.x, "y": origin.y, "job": job, "hay": hay, "level": level, "storage": storage,
		"babies": allow_babies, "fish": fish}


func restore(d: Dictionary) -> void:
	var j = d.get("job", {})
	job = j if j is Dictionary else {}
	hay = int(d.get("hay", 0))
	level = int(d.get("level", 1))
	allow_babies = bool(d.get("babies", true))
	var st = d.get("storage", [])
	storage = st if st is Array else []
	var fl = d.get("fish", [])
	fish = fl if fl is Array else []
	refresh()
