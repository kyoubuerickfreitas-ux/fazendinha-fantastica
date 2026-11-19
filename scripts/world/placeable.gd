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
## comedouro: quantidade de feno
var hay := 0

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
	return kind == "workbench" or kind == "feeder" or is_machine()


func is_machine() -> bool:
	return ItemDB.PLACEABLES[kind].get("machine", false)


func can_pick_up() -> bool:
	if ItemDB.PLACEABLES[kind].get("fixed", false):
		return false
	return job.is_empty() and hay == 0


func job_ready() -> bool:
	return not job.is_empty() and Game.day >= int(job["ready"])


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
		"feeder":
			_interact.label = "Comedouro (%d)" % hay
		_:
			if job_ready():
				_interact.label = "Coletar"
			elif job.is_empty():
				_interact.label = "Colocar"
			else:
				_interact.label = "Trabalhando..."
	_bubble.visible = is_machine() and job_ready()
	if _bubble.visible:
		_bubble.texture = ItemDB.icon(job["output"])
		_bubble.scale = Vector2.ONE * (16.0 / _bubble.texture.get_width())
		_bubble.position = Vector2(0, _sprite.offset.y - 8)


func _process(_d: float) -> void:
	if _bubble and _bubble.visible:
		_bubble.position.y = _sprite.offset.y - 8 + sin(Time.get_ticks_msec() / 300.0) * 1.5


# ------------------------------------------------------------------ máquinas
## Tenta colocar o item na máquina. Retorna mensagem.
func insert(item_id: String) -> String:
	var m: Dictionary = ItemDB.MACHINES[kind]
	var ok := false
	if m.has("input"):
		ok = item_id == m["input"]
	elif m.has("input_type"):
		ok = ItemDB.get_item(item_id).get("type", "") == m["input_type"]
	if not ok:
		var need: String = ItemDB.item_name(m["input"]) if m.has("input") else "uma colheita"
		return "Precisa de %s na mão." % need
	if not Game.remove_item(item_id, 1):
		return ""
	job = {"input": item_id, "output": m["output"], "ready": Game.day + int(m["days"])}
	refresh()
	return "%s começou a trabalhar. Fica pronto em %d dia(s)." % [ItemDB.item_name(kind), int(m["days"])]


func collect() -> String:
	var out: String = job["output"]
	if Game.add_item(out, 1) > 0:
		return ""
	job = {}
	refresh()
	return "+1 %s" % ItemDB.item_name(out)


# ------------------------------------------------------------------ salvar
func serialize() -> Dictionary:
	return {"kind": kind, "x": origin.x, "y": origin.y, "job": job, "hay": hay}


func restore(d: Dictionary) -> void:
	var j = d.get("job", {})
	job = j if j is Dictionary else {}
	hay = int(d.get("hay", 0))
	refresh()
