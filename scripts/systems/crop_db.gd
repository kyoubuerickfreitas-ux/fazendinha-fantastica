class_name CropDB
## Catálogo de plantas e estações, lido de data/crops/*.tres e data/seasons/*.tres.
## Também registra no ItemDB os itens de semente e de colheita de cada planta.

const CROPS_DIR := "res://data/crops/"
const SEASONS := ["spring", "summer", "autumn", "winter"]

static var crops := {}        # id -> CropData
static var seasons := {}      # id -> SeasonData
static var _seed_to_crop := {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for s in SEASONS:
		seasons[s] = load("res://data/seasons/%s.tres" % s)
	var hd_index := {}
	var f := FileAccess.open("res://data/items_hd.json", FileAccess.READ)
	if f:
		hd_index = JSON.parse_string(f.get_as_text())
	for file in _list(CROPS_DIR):
		var c: CropData = load(CROPS_DIR + file)
		if c == null or c.id == "":
			continue
		crops[c.id] = c
		_seed_to_crop[c.seed_id()] = c.id
		_register_items(c, hd_index)


static func _list(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for file in d.get_files():
		file = file.trim_suffix(".remap")    # no APK os .tres viram .remap
		if file.ends_with(".tres") and not out.has(file):
			out.append(file)
	out.sort()
	return out


static func _season_names(c: CropData) -> String:
	var n := []
	for s in c.seasons:
		n.append(seasons[s].name if seasons.has(s) else s)
	return ", ".join(n)


static func _register_items(c: CropData, hd_index: Dictionary) -> void:
	var info := "%s · %d dias" % [_season_names(c), c.total_days()]
	if c.harvest_type == "regrow":
		info += ", depois a cada %d" % c.regrow_days
	var seed := {"name": c.seed_name if c.seed_name != "" else "Sementes de " + c.name, "type": "seed",
		"crop": c.id, "buy": c.seed_price, "desc": "%s. %s" % [info, c.description]}
	var base_seed: Dictionary = ItemDB.ITEMS.get(c.seed_id(), {})
	if base_seed.has("hd"):
		seed["hd"] = base_seed["hd"]
		seed["icon"] = base_seed.get("icon", 0)
	elif hd_index.has(c.seed_id()):
		seed["hd"] = int(hd_index[c.seed_id()])
	else:
		seed["hd"] = int(hd_index.get("seed_bag", 8))
	ItemDB.register(c.seed_id(), seed)
	if not ItemDB.ITEMS.has(c.produce_id()):
		var prod := {"name": c.produce_name if c.produce_name != "" else c.name, "type": "crop",
			"sell": c.sell_price, "desc": c.description}
		if c.produce_icon_hd >= 0:
			prod["hd"] = c.produce_icon_hd
		ItemDB.register(c.produce_id(), prod)


static func get_crop(id: String) -> CropData:
	ensure_loaded()
	return crops.get(id)


static func crop_for_seed(seed_id: String) -> CropData:
	ensure_loaded()
	return crops.get(_seed_to_crop.get(seed_id, ""))


static func season(id: String) -> SeasonData:
	ensure_loaded()
	return seasons[id]


## Sementes à venda: as que crescem na estação atual.
static func seeds_for(season_id: String) -> Array:
	ensure_loaded()
	var out := []
	for id in crops:
		var c: CropData = crops[id]
		if c.grows_in(season_id) and c.unlock == "":
			out.append(c.seed_id())
	out.sort_custom(func(a, b): return ItemDB.get_item(a).get("buy", 0) < ItemDB.get_item(b).get("buy", 0))
	return out
