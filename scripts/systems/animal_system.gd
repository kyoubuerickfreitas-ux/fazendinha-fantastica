class_name AnimalSystem
## Regras dos animais: espécies (data/animals/*.tres), virada do dia, produção e qualidade.
## Os registros (AnimalRecord) ficam no FarmWorld; aqui só há lógica.

const DIR := "res://data/animals/"
const QUALITY_NAMES := ["comum", "prata", "ouro", "lendário"]

static var _species := {}
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
			var s: SpeciesData = load(DIR + f)
			if s and s.id != "":
				_species[s.id] = s


static func species(id: String) -> SpeciesData:
	ensure_loaded()
	return _species.get(id)


static func all_species() -> Array:
	ensure_loaded()
	var ids := _species.keys()
	ids.sort_custom(func(a, b): return _species[a].price < _species[b].price)
	return ids


# ------------------------------------------------------------------ qualidade
## 0 comum, 1 prata, 2 ouro, 3 lendário. Amizade e felicidade pesam mais.
static func roll_quality(r: AnimalRecord) -> int:
	var score := r.friendship / 1000.0 * 0.5 + r.happiness / 100.0 * 0.3 + randf() * 0.25
	if score >= 0.95 and r.friendship >= 900:
		return 3
	if score >= 0.72:
		return 2
	if score >= 0.5:
		return 1
	return 0


# ------------------------------------------------------------------ virada do dia
## Ordem (§19): abrigo -> comida -> fome -> felicidade -> amizade -> saúde ->
## idade/estágio -> produção (lã, farejar). Retorna os itens farejados [{item, pos}].
## `food` = Callable(r: AnimalRecord) -> bool que tenta alimentar (comedouro).
static func process_day(records: Array, food: Callable, sheltered: Callable, weather: Variant,
		temp: float, season: String) -> Dictionary:
	ensure_loaded()
	var wd: WeatherData = weather if weather is WeatherData else CropDB.weather("rain" if weather else "sunny")
	var raining := wd.wet or wd.id == "snow"
	var result := {"forage": [], "hungry": 0, "grown": 0}
	for r: AnimalRecord in records:
		var s := r.data()
		if s == null:
			continue
		var was_baby := r.stage()
		# abrigo e conforto
		var inside: bool = sheltered.call(r)
		var mood := 0
		if not inside and (raining or temp < s.temp_min):
			mood -= 12
		if temp > s.temp_max:
			mood -= 6
		# comida
		# comida: pasto > comida na mão > comedouro
		r.fed_today = r.ate_grass or r.hand_fed or food.call(r)
		if r.ate_grass:
			mood += 5
		if r.fed_today:
			r.hunger_days = 0
			mood += 12
		else:
			r.hunger_days += 1
			result["hungry"] += 1
			mood -= 20
		# carinho de ontem
		if r.petted_today:
			mood += 10
			r.friendship += 15
		else:
			r.friendship -= 2
		if r.hunger_days >= 2:
			r.friendship -= 8
		r.friendship = clampi(r.friendship, 0, 1000)
		# humor puxa devagar para 60, mais os efeitos do dia
		r.happiness = clampi(int(lerpf(r.happiness, 60.0, 0.2)) + mood, 0, 100)
		# saúde: só fica indisposto por fome continuada; melhora comendo
		if r.hunger_days >= 3:
			r.health = "indisposto"
		elif r.fed_today:
			r.health = "ok"
		r.petted_today = false
		r.ate_grass = false
		r.hand_fed = false
		# idade
		r.age += 1
		if was_baby != r.stage():
			result["grown"] += 1
		# produção
		if r.is_adult() and r.fed_today and r.health == "ok" and not r.product_ready:
			_produce(r, s, not wd.forage_ok, season, result)
	return result


static func _produce(r: AnimalRecord, s: SpeciesData, raining: bool, season: String, result: Dictionary) -> void:
	match s.produce_mode:
		"forage":
			if season == "winter" or raining:
				return
			var chance := s.forage_chance + r.friendship / 1000.0 * 0.35 + (r.happiness - 50) / 100.0 * 0.2
			if randf() < chance:
				result["forage"].append({"item": _pick(s.forage_items, s.forage_weights), "q": roll_quality(r), "rec": r})
				r.produced_total += 1
		_:
			r.prod_days += 1
			if r.prod_days >= s.product_interval:
				r.prod_days = 0
				r.product_ready = true
				r.product_quality = roll_quality(r)


static func _pick(items: PackedStringArray, weights: PackedFloat32Array) -> String:
	var total := 0.0
	for w in weights:
		total += w
	var x := randf() * total
	for i in items.size():
		x -= weights[i] if i < weights.size() else 0.0
		if x <= 0.0:
			return items[i]
	return items[0]


## Coleta o produto pronto. Retorna {"item", "qty", "q"} ou {} (ou {"error": msg}).
static func collect(r: AnimalRecord) -> Dictionary:
	var s := r.data()
	if not r.product_ready:
		return {}
	if s.produce_mode == "shears" and Game.count_item("shears") == 0:
		return {"error": "Precisa de uma Tesoura de Tosquia (barraca do Fungo)."}
	var qty := randi_range(s.product_min, s.product_max)
	r.product_ready = false
	r.produced_total += qty
	r.best_quality = maxi(r.best_quality, r.product_quality)
	return {"item": s.product, "qty": qty, "q": r.product_quality}


## Texto de humor para o cartão.
static func mood_text(r: AnimalRecord) -> String:
	if r.happiness >= 75:
		return "Muito feliz"
	if r.happiness >= 50:
		return "Contente"
	if r.happiness >= 25:
		return "Chateado"
	return "Triste"


## Dica do que o animal precisa agora (para o cartão).
static func need_text(r: AnimalRecord) -> String:
	var s := r.data()
	if r.health == "indisposto":
		return "Está indisposto: precisa comer bem (feno no comedouro)."
	if r.hunger_days > 0:
		return "Ficou com fome ontem. Deixe capim no pasto ou feno no comedouro."
	if r.product_ready:
		return "Tem %s pronto para coletar!" % ItemDB.item_name(s.product) if s.produce_mode != "shears" \
			else "A lã está pronta: tosquie (precisa da tesoura)."
	if not r.petted_today:
		return "Quer carinho hoje."
	if not r.is_adult():
		var left := s.baby_days + s.young_days - r.age
		return "Crescendo: adulto em %d dia(s)." % left
	match s.produce_mode:
		"forage":
			return "De dia, com tempo bom, fareja coisas no pasto."
		"shears":
			return "Lã crescendo: pronta em %d dia(s)." % (s.product_interval - r.prod_days)
	return "Produz amanhã se comer e estiver bem."
