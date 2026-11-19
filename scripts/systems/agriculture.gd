class_name Agri
## Sistema agrícola: regras de solo, água, crescimento, estações e colheita.
## Os canteiros ficam em FarmWorld.soil (Vector2i -> Dictionary); aqui só há lógica,
## para o mapa continuar responsável apenas por desenhar e receber as ações.
##
## Canteiro: {"moist": 0..1, "fert": 1.0, "soil": "common", "fertilizer": "", "crop": {} }
## Planta:   {"id", "stage", "prog", "stress", "harvests", "regrow", "state", "care"}
##           state = growing | ready | dormant | dead

const MOIST_STATES := [
	[0.15, "Seco"], [0.45, "Pouca umidade"], [0.75, "Umidade adequada"], [0.95, "Úmido"], [9.0, "Encharcado"],
]
const RAIN_MOISTURE := 1.0


# ------------------------------------------------------------------ solo
static func new_cell(raining: bool) -> Dictionary:
	return {"moist": RAIN_MOISTURE if raining else 0.1, "fert": 1.0, "soil": "common", "fertilizer": "", "crop": {}}


static func moisture_label(m: float) -> String:
	for s in MOIST_STATES:
		if m < s[0]:
			return s[1]
	return MOIST_STATES[-1][1]


static func needs_water(cell: Dictionary) -> bool:
	return cell["moist"] < 0.95


static func water(cell: Dictionary) -> void:
	cell["moist"] = 1.0


## Quanto o solo seca numa noite, pela temperatura e umidade do ar da estação.
static func evaporation(temp: float, season: SeasonData) -> float:
	var e := clampf(0.3 + temp * 0.02, 0.3, 0.95) * (1.2 - season.air_humidity * 0.4)
	return clampf(e, 0.2, 0.95)


# ------------------------------------------------------------------ plantio e estado
static func has_crop(cell: Dictionary) -> bool:
	return not cell["crop"].is_empty()


static func crop_data(cell: Dictionary) -> CropData:
	return CropDB.get_crop(cell["crop"]["id"]) if has_crop(cell) else null


static func is_ready(cell: Dictionary) -> bool:
	return has_crop(cell) and cell["crop"]["state"] == "ready"


static func is_dead(cell: Dictionary) -> bool:
	return has_crop(cell) and cell["crop"]["state"] == "dead"


## Retorna "" se pode plantar, ou o motivo.
static func can_plant(cell: Dictionary, seed_id: String, day: int) -> String:
	var c := CropDB.crop_for_seed(seed_id)
	if c == null:
		return "Semente desconhecida."
	if has_crop(cell):
		return "Já tem algo plantado."
	var season := Calendar.season_id(day)
	if not c.grows_in(season):
		return "%s só cresce em: %s." % [c.name, CropDB._season_names(c)]
	return ""


static func plant(cell: Dictionary, seed_id: String) -> void:
	var c := CropDB.crop_for_seed(seed_id)
	cell["crop"] = {"id": c.id, "stage": 0, "prog": 0.0, "stress": 0, "harvests": 0,
		"regrow": false, "state": "growing", "care": 0}


## Quadro do sprite a desenhar.
static func frame(cell: Dictionary) -> int:
	var cr: Dictionary = cell["crop"]
	var c := crop_data(cell)
	if c == null:
		return 0
	return clampi(int(cr["stage"]), 0, c.frames() - 1)


# ------------------------------------------------------------------ colheita
## Colhe a planta pronta. Retorna {"item", "qty", "seeds"} ou {} se não está pronta.
static func harvest(cell: Dictionary) -> Dictionary:
	if not is_ready(cell):
		return {}
	var c := crop_data(cell)
	var cr: Dictionary = cell["crop"]
	var qty := randi_range(c.yield_min, c.yield_max)
	var seeds := 1 if randf() < c.extra_seed_chance else 0
	cr["harvests"] += 1
	if c.harvest_type == "regrow" and (c.max_harvests == 0 or cr["harvests"] < c.max_harvests):
		cr["state"] = "growing"
		cr["regrow"] = true
		cr["stage"] = c.frames() - 2
		cr["prog"] = 0.0
	else:
		cell["crop"] = {}
	return {"item": c.produce_id(), "qty": qty, "seeds": seeds, "seed_item": c.seed_id()}


## Remove planta morta (ou qualquer planta, com a picareta).
static func clear_crop(cell: Dictionary) -> void:
	cell["crop"] = {}


# ------------------------------------------------------------------ passagem do dia
## Processa todos os canteiros na virada do dia (ordem da §19):
##   crescimento com a água/temperatura de ontem -> estresse/morte -> evaporação ->
##   chuva de hoje -> mudança de estação (dormência/morte/despertar).
## Retorna um resumo para avisos ao jogador.
static func process_day(soil: Dictionary, prev_day: int, day: int, temp_yesterday: float,
		temp_today: float, weather_today: Variant) -> Dictionary:
	# aceita o id do clima, um WeatherData ou (testes antigos) um bool de chuva
	var wd: WeatherData
	if weather_today is WeatherData:
		wd = weather_today
	elif weather_today is String:
		wd = CropDB.weather(weather_today)
	else:
		wd = CropDB.weather("rain" if weather_today else "sunny")
	CropDB.ensure_loaded()
	var season_y := Calendar.season_id(prev_day)
	var season_t := Calendar.season_id(day)
	var season_changed := season_y != season_t
	var sdata := CropDB.season(season_t)
	var evap := evaporation(temp_today, sdata) * wd.evap_mult
	var summary := {"dry": 0, "died": 0, "ready": 0, "dormant": 0, "woke": 0, "storm": 0}

	for c in soil:
		var cell: Dictionary = soil[c]
		if has_crop(cell):
			_grow(cell, season_y, temp_yesterday, summary)
		# evaporação e o clima de hoje
		cell["moist"] = maxf(0.0, cell["moist"] - evap * cell.get("evap_mult", 1.0))
		if wd.soil_water >= 0.0:
			cell["moist"] = maxf(cell["moist"], wd.soil_water)
		# tempestade: plantas frágeis podem perder o progresso do estágio
		if wd.crop_damage > 0.0 and has_crop(cell) and cell["crop"]["state"] == "growing":
			var cd := crop_data(cell)
			if cd and cd.fragile and randf() < wd.crop_damage:
				cell["crop"]["prog"] = 0.0
				summary["storm"] += 1
		if season_changed and has_crop(cell):
			_season_change(cell, season_t, summary)
	return summary


static func _grow(cell: Dictionary, season: String, temp: float, summary: Dictionary) -> void:
	var c := crop_data(cell)
	var cr: Dictionary = cell["crop"]
	if c == null or cr["state"] in ["dead", "dormant", "ready"]:
		return
	if not c.grows_in(season):
		return   # "survive": fica parada fora da estação
	# água
	var water_f := 1.0
	if cell["moist"] < c.water_min:
		water_f = 0.0
		cr["stress"] += 1
		summary["dry"] += 1
	else:
		cr["stress"] = 0
		if cell["moist"] > c.water_max:
			water_f = 0.7
	# temperatura
	var temp_f := 1.0
	if temp < c.temp_min or temp > c.temp_max:
		var off := maxf(c.temp_min - temp, temp - c.temp_max)
		temp_f = 0.5 if off <= 5.0 else 0.0
	var points: float = water_f * temp_f * float(cell.get("fert", 1.0))
	if points >= 1.0:
		cr["care"] += 1
	if cr["stress"] > c.drought_tolerance:
		cr["state"] = "dead"
		summary["died"] += 1
		return
	cr["prog"] += points
	var last := c.frames() - 1
	while cr["state"] == "growing":
		var need: float = c.regrow_days if cr["regrow"] else float(c.stage_days[mini(cr["stage"], c.stage_days.size() - 1)])
		if cr["prog"] < need:
			break
		cr["prog"] -= need
		cr["stage"] = last if cr["regrow"] else cr["stage"] + 1
		if cr["stage"] >= last:
			cr["stage"] = last
			cr["state"] = "ready"
			cr["regrow"] = false
			cr["prog"] = 0.0
			summary["ready"] += 1


static func _season_change(cell: Dictionary, season: String, summary: Dictionary) -> void:
	var c := crop_data(cell)
	var cr: Dictionary = cell["crop"]
	if c == null or cr["state"] == "dead":
		return
	if c.grows_in(season):
		if cr["state"] == "dormant":
			cr["state"] = "growing"
			cr["regrow"] = cr["stage"] >= c.frames() - 2
			cr["prog"] = 0.0
			summary["woke"] += 1
		return
	match c.season_end:
		"dormant":
			cr["state"] = "dormant"
			cr["stage"] = maxi(0, mini(cr["stage"], c.frames() - 2))
			summary["dormant"] += 1
		"survive":
			pass
		_:
			cr["state"] = "dead"
			summary["died"] += 1


# ------------------------------------------------------------------ save antigo
## Converte um canteiro do formato antigo ({"wet", "crop": id, "growth": dias}).
static func migrate(old: Dictionary) -> Dictionary:
	if old.has("moist"):
		return old
	var cell := new_cell(false)
	cell["moist"] = 1.0 if old.get("wet", false) else 0.1
	var id := str(old.get("crop", ""))
	var c := CropDB.get_crop(id)
	if c:
		cell["crop"] = {"id": id, "stage": 0, "prog": float(old.get("growth", 0)), "stress": 0, "harvests": 0,
			"regrow": false, "state": "growing", "care": 0}
		var cr: Dictionary = cell["crop"]
		var last := c.frames() - 1
		while cr["stage"] < last and cr["prog"] >= c.stage_days[cr["stage"]]:
			cr["prog"] -= c.stage_days[cr["stage"]]
			cr["stage"] += 1
		if cr["stage"] >= last:
			cr["state"] = "ready"
			cr["prog"] = 0.0
	return cell
