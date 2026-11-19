class_name AnimalRecord
extends RefCounted
## Os dados de UM animal. Existe sempre (mesmo dormindo no celeiro ou fora da tela);
## o boneco no mapa (Animal) só mostra e conversa com este registro.

static var _next_id := 1

var uid := 0
var species := ""
var name := ""
var personality := ""
var born_day := 1            # dia em que nasceu/chegou
var age := 0                 # dias de vida na fazenda
var friendship := 0          # 0..1000 (5 corações = 200 cada)
var happiness := 60          # 0..100, humor de agora
var health := "ok"           # ok | indisposto
var hunger_days := 0         # dias seguidos sem comer
var fed_today := false       # comeu na última noite
var petted_today := false
var ate_grass := false       # pastou hoje
var hand_fed := false        # recebeu comida na mão hoje
var home := ""               # "x,y" da construção onde dorme ("" = dorme no pasto)
var prod_days := 0           # dias acumulados para o próximo produto (lã: crescimento)
var product_ready := false
var product_quality := 0
var produced_total := 0
var best_quality := 0
var pos := Vector2.ZERO


static func create(p_species: String, adult: bool) -> AnimalRecord:
	var r := AnimalRecord.new()
	r.uid = _next_id
	_next_id += 1
	r.species = p_species
	var s := AnimalSystem.species(p_species)
	r.personality = s.personalities[randi() % s.personalities.size()] if s.personalities.size() > 0 else "calmo"
	r.name = s.default_names[randi() % s.default_names.size()] if s.default_names.size() > 0 else s.name
	r.born_day = Game.day
	r.age = s.baby_days + s.young_days if adult else 0
	return r


func data() -> SpeciesData:
	return AnimalSystem.species(species)


## baby | young | adult
func stage() -> String:
	var s := data()
	if age < s.baby_days:
		return "baby"
	if age < s.baby_days + s.young_days:
		return "young"
	return "adult"


func is_adult() -> bool:
	return stage() == "adult"


func hearts() -> int:
	return clampi(friendship / 200, 0, 5)


func serialize() -> Dictionary:
	return {"uid": uid, "species": species, "name": name, "personality": personality, "born": born_day,
		"age": age, "friendship": friendship, "happiness": happiness, "health": health,
		"hunger": hunger_days, "fed": fed_today, "petted": petted_today, "grass": ate_grass, "hand": hand_fed, "home": home,
		"prod_days": prod_days, "ready": product_ready, "quality": product_quality,
		"total": produced_total, "best": best_quality, "x": pos.x, "y": pos.y}


static func restore(d: Dictionary) -> AnimalRecord:
	var r := AnimalRecord.new()
	r.species = str(d.get("species", "moombor"))
	if d.has("uid"):
		r.uid = int(d["uid"])
		r.name = str(d.get("name", ""))
		r.personality = str(d.get("personality", "calmo"))
		r.born_day = int(d.get("born", 1))
		r.age = int(d.get("age", 0))
		r.friendship = int(d.get("friendship", 0))
		r.happiness = int(d.get("happiness", 60))
		r.health = str(d.get("health", "ok"))
		r.hunger_days = int(d.get("hunger", 0))
		r.fed_today = bool(d.get("fed", false))
		r.petted_today = bool(d.get("petted", false))
		r.ate_grass = bool(d.get("grass", false))
		r.hand_fed = bool(d.get("hand", false))
		r.home = str(d.get("home", ""))
		r.prod_days = int(d.get("prod_days", 0))
		r.product_ready = bool(d.get("ready", false))
		r.product_quality = int(d.get("quality", 0))
		r.produced_total = int(d.get("total", 0))
		r.best_quality = int(d.get("best", 0))
	else:
		# save de antes da etapa 2: animal adulto, amizade 0..10 vira 0..1000
		var fresh := AnimalRecord.create(r.species, true)
		fresh.friendship = int(d.get("friendship", 0)) * 100
		fresh.petted_today = bool(d.get("petted", false))
		fresh.product_ready = bool(d.get("product", false))
		r = fresh
	r.pos = Vector2(float(d.get("x", 0)), float(d.get("y", 0)))
	_next_id = maxi(_next_id, r.uid + 1)
	return r
