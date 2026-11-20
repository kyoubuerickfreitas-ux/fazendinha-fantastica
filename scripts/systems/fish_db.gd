class_name FishDB
## Catálogo de peixes (data/fish/*.tres), sorteio pelas condições do lugar e do momento,
## medidas (tamanho/peso/qualidade), Livro de Pesca (registro) e nível de pesca.
## O registro e o XP ficam no Game (Game.fish_log, Game.fishing_xp) para irem no save.

const DIR := "res://data/fish/"
## peso de cada raridade no sorteio (lendário/secreto têm regra própria)
const RARITY_WEIGHT := [60.0, 25.0, 10.0, 4.0, 1.6, 0.0, 0.0]
## chance de um lendário/secreto aparecer por fisgada quando TODAS as condições batem
const LEGEND_CHANCE := 0.12
const MAX_LEVEL := 10

static var fish := {}
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
			var fd: FishData = load(DIR + f)
			if fd and fd.id != "":
				fish[fd.id] = fd
				# peixes só de dados (lendários): vira item da mochila
				if not ItemDB.ITEMS.has(fd.id):
					var item := {"name": fd.name, "type": "fish", "sell": fd.sell, "desc": fd.description}
					if fd.icon != "":
						item["tex"] = fd.icon
					ItemDB.register(fd.id, item)
				# peixe defumado (Defumador): vale o dobro do peixe + 15
				var base_sell: int = int(ItemDB.ITEMS[fd.id]["sell"]) if ItemDB.ITEMS.has(fd.id) else fd.sell
				ItemDB.register("smoked_" + fd.id, {"name": fd.name + " Defumado", "type": "product", "sell": base_sell * 2 + 15,
					"tex": "res://assets/sprites/fishing/smoked_fish.png", "desc": "Defumado no capricho. Dura muito e vale o dobro."})


static func get_fish(id: String) -> FishData:
	ensure_loaded()
	return fish.get(id)


static func all_ids() -> Array:
	ensure_loaded()
	var ids := fish.keys()
	ids.sort_custom(func(a, b):
		var fa: FishData = fish[a]
		var fb: FishData = fish[b]
		return fa.rarity < fb.rarity or (fa.rarity == fb.rarity and fa.name < fb.name))
	return ids


# ------------------------------------------------------------------ momento
static func time_of_day(minutes: int) -> String:
	var h := (minutes / 60) % 24
	if h < 6 or h >= 24:
		return "dawn"
	if h < 12:
		return "morning"
	if h < 18:
		return "afternoon"
	return "night"


## Contexto atual para um lugar: {water, depth, season, time, weather, level, bait, region}
static func context(water: String, depth: String, bait: String) -> Dictionary:
	return {"water": water, "depth": depth, "season": Game.season_id(), "time": time_of_day(Game.minutes),
		"weather": Game.weather, "level": level(), "bait": bait, "region": "farm"}


## Este peixe pode aparecer neste contexto?
static func available(f: FishData, ctx: Dictionary) -> bool:
	if not f.waters.has(ctx["water"]) or not f.regions.has(ctx.get("region", "farm")):
		return false
	if f.depth != "any" and f.depth != ctx["depth"]:
		return false
	if not f.seasons.is_empty() and not f.seasons.has(ctx["season"]):
		return false
	if not f.times.is_empty() and not f.times.has(ctx["time"]):
		return false
	if not f.weathers.is_empty() and not f.weathers.has(ctx["weather"]):
		return false
	if ctx["level"] < f.min_level:
		return false
	if f.special != "" and not special_met(f.special):
		return false
	return true


static func special_met(cond: String) -> bool:
	match cond:
		"map_complete":
			return bool(Game.fish_flags.get("map_complete", false))
		"species_15":
			return discovered_count() >= 15
	return true


## Sorteia um peixe para o contexto. "" se nada morder.
static func roll(ctx: Dictionary) -> String:
	ensure_loaded()
	var bait: String = ctx.get("bait", "")
	var bdef: Dictionary = ItemDB.BAITS.get(bait, ItemDB.BAITS[""])
	var bonus: Array = bdef["bonus"]
	# lendários/secretos: se todas as condições batem, uma chance fixa por fisgada
	for id in fish:
		var lf: FishData = fish[id]
		if lf.rarity >= 5 and available(lf, ctx) and randf() < LEGEND_CHANCE * Cooking.fishing_luck():
			return id
	var weights := {}
	var total := 0.0
	for id in fish:
		var f: FishData = fish[id]
		if f.rarity >= 5 or not available(f, ctx):
			continue
		var w: float = RARITY_WEIGHT[f.rarity] * float(bonus[mini(f.rarity, bonus.size() - 1)])
		if f.favored_weathers.has(ctx["weather"]):
			w *= 2.0
		if f.baits.has(bait):
			w *= 2.5
		if f.rarity >= 2:
			w *= Cooking.fishing_luck()      # bônus de comida (Sorte na Pesca)
		if ctx["time"] == "night" and f.times.has("night"):
			w *= float(bdef.get("night", 1.0))
		if w > 0.0:
			weights[id] = w
			total += w
	if weights.is_empty():
		return "fish_silver"
	var pick := randf() * total
	for id in weights:
		pick -= weights[id]
		if pick <= 0.0:
			return id
	return weights.keys()[0]


## Peixes possíveis aqui agora (para a dica do lugar).
static func possible_here(ctx: Dictionary) -> Array:
	ensure_loaded()
	return fish.keys().filter(func(id): return fish[id].rarity < 6 and available(fish[id], ctx))


# ------------------------------------------------------------------ medidas
## Tamanho (cm), peso (kg) e qualidade pelo tamanho (exemplares grandes valem mais).
static func measure(f: FishData) -> Dictionary:
	var t := pow(randf(), 1.6)                      # grandes são mais raros
	t = clampf(t + level() * 0.01, 0.0, 1.0)        # nível ajuda um pouquinho
	var size := snappedf(lerpf(f.size_min, f.size_max, t), 0.1)
	var weight := snappedf(lerpf(f.weight_min, f.weight_max, pow(t, 2.2)), 0.01)
	var q := 0
	if t >= 0.92:
		q = 2
	elif t >= 0.72:
		q = 1
	if f.is_legendary():
		q = 3
	return {"size": size, "weight": weight, "q": q}


# ------------------------------------------------------------------ registro (Livro de Pesca)
static func entry(id: String) -> Dictionary:
	return Game.fish_log.get(id, {})


static func is_discovered(id: String) -> bool:
	return Game.fish_log.has(id)


static func discovered_count() -> int:
	return Game.fish_log.size()


## Troféu de um lendário ("" se o peixe não tem)
static func trophy_of(id: String) -> String:
	var t := "trophy_" + id.trim_prefix("fish_")
	return t if ItemDB.PLACEABLES.has(t) else ""


## Registra a captura. Retorna {"new": bool, "record": bool, "xp": int, "level_up": int}
static func register_catch(id: String, m: Dictionary) -> Dictionary:
	var f := get_fish(id)
	var is_new := not Game.fish_log.has(id)
	var e: Dictionary = Game.fish_log.get(id, {"n": 0, "first": Game.day, "max_size": 0.0, "max_weight": 0.0})
	e["n"] = int(e["n"]) + 1
	var record := float(m["size"]) > float(e["max_size"])
	e["max_size"] = maxf(float(e["max_size"]), float(m["size"]))
	e["max_weight"] = maxf(float(e["max_weight"]), float(m["weight"]))
	Game.fish_log[id] = e
	var xp := f.xp_value() * (3 if is_new else 1)
	var lvl_up := add_xp(xp)
	return {"new": is_new, "record": record and not is_new, "xp": xp, "level_up": lvl_up}


# ------------------------------------------------------------------ nível de pesca
## XP total para chegar ao nível l: 0, 60, 180, 360, 600, 900...
static func xp_for_level(l: int) -> int:
	return 30 * l * (l - 1)


static func level() -> int:
	var l := 1
	while l < MAX_LEVEL and Game.fishing_xp >= xp_for_level(l + 1):
		l += 1
	return l


## Soma XP. Retorna o novo nível se subiu, ou 0.
static func add_xp(n: int) -> int:
	var before := level()
	Game.fishing_xp += n
	var after := level()
	return after if after > before else 0


# ------------------------------------------------------------------ textos para a ficha
static func where_text(f: FishData) -> String:
	var w := []
	for x in f.waters:
		w.append(FishData.WATER_NAMES.get(x, x))
	var t := ", ".join(w)
	if f.depth == "deep":
		t += " (fundo)"
	elif f.depth == "shallow":
		t += " (raso)"
	return t


static func when_text(f: FishData) -> String:
	var parts := []
	if f.seasons.is_empty():
		parts.append("o ano todo")
	else:
		var s := []
		for x in f.seasons:
			s.append(CropDB.season(x).name)
		parts.append(", ".join(s))
	if not f.times.is_empty():
		var t := []
		for x in f.times:
			t.append(FishData.TIME_NAMES.get(x, x))
		parts.append(" e ".join(t))
	return " · ".join(parts)


static func weather_text(f: FishData) -> String:
	var parts := []
	if not f.weathers.is_empty():
		parts.append("só com " + ", ".join(Array(f.weathers).map(func(w): return CropDB.weather(w).name.to_lower())))
	if not f.favored_weathers.is_empty():
		parts.append("mais com " + ", ".join(Array(f.favored_weathers).map(func(w): return CropDB.weather(w).name.to_lower())))
	return "; ".join(parts) if parts.size() > 0 else "qualquer clima"


# ------------------------------------------------------------------ títulos (metas de longo prazo)
## id, nome, meta, recompensa (moedas + item opcional)
const TITLES := [
	{"id": "novice", "name": "Pescador Iniciante", "goal": "Descobrir 5 espécies", "money": 200},
	{"id": "valley", "name": "Pescador do Vale", "goal": "Descobrir 12 espécies", "money": 600, "item": "bait_fly", "qty": 5},
	{"id": "master", "name": "Mestre Pescador", "goal": "Descobrir 20 espécies", "money": 2000},
	{"id": "legend_hunter", "name": "Caçador de Lendas", "goal": "Pescar um peixe lendário", "money": 500},
	{"id": "lake_legend", "name": "Lenda do Lago", "goal": "Pescar os 4 lendários", "money": 5000},
	{"id": "treasure_hunter", "name": "Caçador de Tesouros", "goal": "Encontrar 8 tipos de tesouro", "money": 800},
	{"id": "fungo_friend", "name": "Amigo do Fungo", "goal": "Entregar 10 pedidos de pesca", "money": 1000, "item": "bait_treasure", "qty": 5},
	{"id": "champion", "name": "Campeão do Lago", "goal": "Vencer um Torneio do Lago", "money": 500},
	{"id": "aquarist", "name": "Aquarista", "goal": "Expor 5 espécies em aquários", "money": 600},
	{"id": "dreamer", "name": "Sonhador", "goal": "Pescar o peixe secreto", "money": 3000},
]


static func _legends_caught() -> int:
	var n := 0
	for id in fish:
		if fish[id].rarity == 5 and is_discovered(id):
			n += 1
	return n


static func title_done(id: String) -> bool:
	match id:
		"novice":
			return discovered_count() >= 5
		"valley":
			return discovered_count() >= 12
		"master":
			return discovered_count() >= 20
		"legend_hunter":
			return _legends_caught() >= 1
		"lake_legend":
			return _legends_caught() >= 4
		"treasure_hunter":
			return Game.treasure_log.size() >= 8
		"fungo_friend":
			return int(Game.fish_flags.get("requests_done", 0)) >= 10
		"champion":
			return int(Game.fish_flags.get("tour_wins", 0)) >= 1
		"aquarist":
			return int(Game.fish_flags.get("aquarium_species", 0)) >= 5
		"dreamer":
			return is_discovered("fish_dream")
	return false


static func titles() -> Array:
	var t = Game.fish_flags.get("titles", [])
	return t if t is Array else []


## Título exibido (o último conquistado) ou "".
static func current_title() -> String:
	var t := titles()
	if t.is_empty():
		return ""
	for d in TITLES:
		if d["id"] == t.back():
			return d["name"]
	return ""


## Confere metas novas, entrega recompensas e devolve o aviso ("" se nada).
## aquarium_species >= 0 atualiza a contagem dos aquários.
static func check_titles(aquarium_species: int = -1) -> String:
	ensure_loaded()
	if aquarium_species >= 0:
		Game.fish_flags["aquarium_species"] = aquarium_species
	var got := titles()
	var out := []
	for d in TITLES:
		if got.has(d["id"]) or not title_done(d["id"]):
			continue
		got.append(d["id"])
		Game.add_money(int(d["money"]))
		var reward := "%d moedas" % int(d["money"])
		if d.has("item"):
			Game.add_item(d["item"], int(d["qty"]))
			reward += " e %d %s" % [int(d["qty"]), ItemDB.item_name(d["item"])]
		out.append("Novo título: %s! (%s) +%s" % [d["name"], d["goal"], reward])
	Game.fish_flags["titles"] = got
	return "\n".join(out)
