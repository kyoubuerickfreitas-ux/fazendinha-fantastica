class_name TreasureDB
## Tesouros e objetos da pesca (data/treasures/*.tres): chance de vir um tesouro em vez de peixe,
## sorteio pelo lugar e nível, e o que acontece ao pescar cada tipo.
## O registro fica em Game.treasure_log {id: quantas vezes}; o mapa e as mensagens em Game.fish_flags.

const DIR := "res://data/treasures/"
const MAP_PIECES := 4

## Mensagens das garrafas, lidas em ordem. Algumas dão pistas dos lendários.
const MESSAGES := [
	"\"Se alguém achar esta garrafa: o lago é mais fundo do que parece. Não pesque só na beirinha!\" — um pescador",
	"\"Na chuva de primavera, vi uma sombra coberta de musgo do tamanho de um barco. Ninguém acredita em mim.\"",
	"\"Rasguei o mapa do Guardião em quatro e joguei na água. Quem merecer, que junte de novo.\"",
	"\"Minhoca para o dia a dia, grilo para os incomuns, cogumelo brilhante para a noite. Mosca para os teimosos.\"",
	"\"Noite limpa de outono. O rio ficou prateado e alguma coisa pulou sem fazer barulho.\"",
	"\"Quando neva, o laguinho bate. Juro que ouvi um coração debaixo do gelo.\"",
	"\"Fungo, se você ler isto: seus óculos caíram na água. De nada. — Ninguém\"",
	"\"Dizem que quem conhece quinze peixes começa a sonhar com um sexto que não existe. Ao amanhecer.\"",
]

static var treasures := {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			var td: TreasureData = load(DIR + f)
			if td and td.id != "":
				treasures[td.id] = td
				if td.kind in ["item", "junk"]:
					ItemDB.register(td.id, {"name": td.name, "type": "treasure", "sell": td.sell,
						"desc": td.description, "tex": icon_path(td.id)})


static func icon_path(id: String) -> String:
	return "res://assets/sprites/fishing/%s.png" % id


static func get_treasure(id: String) -> TreasureData:
	ensure_loaded()
	return treasures.get(id)


static func all_ids() -> Array:
	ensure_loaded()
	var ids := treasures.keys()
	ids.sort_custom(func(a, b):
		var ta: TreasureData = treasures[a]
		var tb: TreasureData = treasures[b]
		return ta.rarity < tb.rarity or (ta.rarity == tb.rarity and ta.name < tb.name))
	return ids


static func found_count(id: String) -> int:
	return int(Game.treasure_log.get(id, 0))


static func map_pieces() -> int:
	return int(Game.fish_flags.get("map_pieces", 0))


static func messages_read() -> int:
	return int(Game.fish_flags.get("messages", 0))


# ------------------------------------------------------------------ sorteio
## Chance de a fisgada ser um tesouro em vez de peixe.
static func chance(ctx: Dictionary) -> float:
	var bdef: Dictionary = ItemDB.BAITS.get(ctx.get("bait", ""), ItemDB.BAITS[""])
	return 0.05 + 0.006 * int(ctx.get("level", 1)) + float(bdef.get("treasure", 0.0))


static func available(t: TreasureData, ctx: Dictionary) -> bool:
	if not t.waters.has(ctx["water"]) or int(ctx["level"]) < t.min_level:
		return false
	if t.depth != "any" and t.depth != ctx["depth"]:
		return false
	if t.unique and found_count(t.id) > 0:
		return false
	if t.kind == "map" and (map_pieces() >= MAP_PIECES or Game.fish_flags.get("map_complete", false)):
		return false
	return true


## Sorteia se vem tesouro; retorna o id ou "".
static func maybe_roll(ctx: Dictionary) -> String:
	if randf() >= chance(ctx):
		return ""
	return roll(ctx)


static func roll(ctx: Dictionary) -> String:
	ensure_loaded()
	var treasure_bait: bool = ItemDB.BAITS.get(ctx.get("bait", ""), {}).has("treasure")
	var weights := {}
	var total := 0.0
	for id in treasures:
		var t: TreasureData = treasures[id]
		if not available(t, ctx):
			continue
		var w := t.weight
		if treasure_bait:
			w *= 0.25 if t.kind in ["junk", "material"] else 1.0 + 0.4 * t.rarity
		weights[id] = w
		total += w
	if weights.is_empty():
		return ""
	var pick := randf() * total
	for id in weights:
		pick -= weights[id]
		if pick <= 0.0:
			return id
	return weights.keys()[0]


# ------------------------------------------------------------------ pescou!
## Aplica o tesouro (mochila, baú, mensagem, mapa...) e devolve o texto para o aviso.
## Retorna "" se não coube na mochila (nada é registrado).
static func collect(id: String) -> String:
	var t := get_treasure(id)
	var text := ""
	match t.kind:
		"item", "junk":
			if Game.add_item(id, 1) > 0:
				return ""
			text = "Pescou %s!" % t.name
		"material":
			if Game.add_item(t.gives, t.gives_qty) > 0:
				return ""
			text = "Pescou %s: +%d %s" % [t.name, t.gives_qty, ItemDB.item_name(t.gives)]
		"chest":
			text = "Abriu um %s: %s" % [t.name, _open_chest(t)]
		"message":
			var n := messages_read()
			if n < MESSAGES.size():
				Game.fish_flags["messages"] = n + 1
				text = "Garrafa com mensagem!\n" + MESSAGES[n]
			else:
				Game.money += 40
				text = "Garrafa vazia... mas tinha 40 moedas dentro."
		"map":
			var p := map_pieces() + 1
			Game.fish_flags["map_pieces"] = p
			text = "Pedaço de mapa (%d/%d)!" % [p, MAP_PIECES]
			if p >= MAP_PIECES:
				Game.fish_flags["map_complete"] = true
				text += "\nO mapa está completo: um X no meio do lago, no fundo. Algo enorme dorme lá à noite..."
	Game.treasure_log[id] = found_count(id) + 1
	return text


## Recompensa do baú: dinheiro + itens úteis (pode vir pedaço de mapa).
static func _open_chest(t: TreasureData) -> String:
	var gold := t.id == "chest_gold"
	var parts := []
	var money := randi_range(200, 500) if gold else randi_range(30, 120)
	Game.money += money
	parts.append("%d moedas" % money)
	var pool := ["wood", "stone", "fiber", "bait_worm", "bait_cricket", "bait_mushroom"]
	if gold:
		pool = ["fert_quality", "bait_fly", "bait_treasure", "relic_shell", "pearl", "old_coin"]
	var item: String = pool[randi() % pool.size()]
	var qty := 1 if gold else randi_range(2, 5)
	if Game.add_item(item, qty) == 0:
		parts.append("%d %s" % [qty, ItemDB.item_name(item)])
	if map_pieces() < MAP_PIECES and not Game.fish_flags.get("map_complete", false) and randf() < (0.35 if gold else 0.12):
		var p := map_pieces() + 1
		Game.fish_flags["map_pieces"] = p
		parts.append("um pedaço de mapa (%d/%d)" % [p, MAP_PIECES])
		if p >= MAP_PIECES:
			Game.fish_flags["map_complete"] = true
	return ", ".join(parts)
