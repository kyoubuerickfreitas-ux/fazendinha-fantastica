class_name Cooking
## Cozinha: receitas (data/recipes/*.tres), ingredientes (inclusive grupos como "qualquer peixe"),
## cozinhar no Fogão, comer pratos e bônus temporários.
## Estado no Game: known_recipes (Array), buffs ({tipo: minuto absoluto em que acaba}), dishes_cooked.

const DIR := "res://data/recipes/"
const GROUPS := {"any_fish": "peixe(s) qualquer", "any_fruit": "fruta(s) qualquer",
	"any_vegetable": "legume(s) qualquer", "any_legend": "peixe lendário"}
const SCROLL_ICON := "res://assets/sprites/food/recipe_scroll.png"

static var recipes := {}
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
		if not f.ends_with(".tres"):
			continue
		var r: RecipeData = load(DIR + f)
		if r == null or r.id == "":
			continue
		recipes[r.id] = r
		var desc := "Recupera %d de energia" % r.energy
		if r.health > 0:
			desc += " e %d de vida" % r.health
		if r.buff != "":
			desc += ". %s por %s: %s" % [RecipeData.BUFF_NAMES[r.buff], duration_text(r.buff_minutes), RecipeData.BUFF_DESC[r.buff]]
		ItemDB.register(r.dish_id(), {"name": r.name, "type": "food", "sell": r.sell, "tex": r.icon,
			"desc": desc + ". Segure e toque em usar para comer."})
		if r.unlock == "shop":
			ItemDB.register("recipe_" + r.id, {"name": "Receita: " + r.name, "type": "recipe", "recipe": r.id,
				"buy": r.price, "tex": SCROLL_ICON, "desc": "Segure e toque em usar para aprender. " + r.description})


static func get_recipe(id: String) -> RecipeData:
	ensure_loaded()
	return recipes.get(id)


## Todas, com as conhecidas primeiro e depois por energia.
static func all_ids() -> Array:
	ensure_loaded()
	var ids := recipes.keys()
	ids.sort_custom(func(a, b):
		var ka := is_known(a)
		var kb := is_known(b)
		if ka != kb:
			return ka
		return recipes[a].energy < recipes[b].energy)
	return ids


static func duration_text(minutes: int) -> String:
	return "%dh" % (minutes / 60) if minutes % 60 == 0 else "%dh%02d" % [minutes / 60, minutes % 60]


# ------------------------------------------------------------------ receitas conhecidas
static func is_known(id: String) -> bool:
	return Game.known_recipes.has(id)


static func learn(id: String) -> bool:
	if is_known(id) or get_recipe(id) == null:
		return false
	Game.known_recipes.append(id)
	return true


## Receitas iniciais (jogo novo).
static func starting_recipes() -> Array:
	ensure_loaded()
	return recipes.keys().filter(func(id): return recipes[id].unlock == "start")


static func unlock_hint(r: RecipeData) -> String:
	var parts := r.unlock.split(":")
	match parts[0]:
		"shop":
			var when := "o ano todo" if r.shop_season == "" else "no " + CropDB.season(r.shop_season).name.to_lower()
			return "O Fungo vende a receita (%s)." % when
		"fishing_level":
			return "Chegue ao nível %s de pesca." % parts[1]
		"requests":
			return "Entregue %s pedidos de pesca ao Fungo." % parts[1]
		"cooked":
			return "Cozinhe %s pratos." % parts[1]
		"title":
			return "Pesque um peixe lendário."
	return "Você já sabe esta."


## Desbloqueios por conquista. Retorna o aviso ("" se nada novo).
static func check_unlocks() -> String:
	ensure_loaded()
	var out := []
	for id in recipes:
		var r: RecipeData = recipes[id]
		if is_known(id):
			continue
		var parts := r.unlock.split(":")
		var ok := false
		match parts[0]:
			"start":
				ok = true
			"fishing_level":
				ok = FishDB.level() >= int(parts[1])
			"requests":
				ok = int(Game.fish_flags.get("requests_done", 0)) >= int(parts[1])
			"cooked":
				ok = Game.dishes_cooked >= int(parts[1])
			"title":
				ok = FishDB.titles().has(parts[1])
		if ok and learn(id):
			out.append("Nova receita: %s!" % r.name)
	return "\n".join(out)


## Receitas à venda no Fungo nesta estação (as que você ainda não sabe).
static func shop_scrolls(season: String) -> Array:
	ensure_loaded()
	var out := []
	for id in recipes:
		var r: RecipeData = recipes[id]
		if r.unlock == "shop" and not is_known(id) and (r.shop_season == "" or r.shop_season == season):
			out.append("recipe_" + id)
	return out


# ------------------------------------------------------------------ ingredientes
static func matches(group: String, item_id: String) -> bool:
	var item := ItemDB.get_item(item_id)
	match group:
		"any_fish", "any_legend":
			if item.get("type", "") != "fish":
				return false
			var f := FishDB.get_fish(item_id)
			var legend := f != null and f.is_legendary()
			return legend if group == "any_legend" else not legend
		"any_fruit":
			return CropDB.category_of(item_id) == "fruit"
		"any_vegetable":
			return CropDB.category_of(item_id) == "vegetable"
	return item_id == group


## Quantos itens da mochila servem para este ingrediente.
static func have(key: String) -> int:
	if not GROUPS.has(key):
		return Game.count_item(key)
	var n := 0
	for s in Game.inventory:
		if s != null and matches(key, s["id"]):
			n += int(s["qty"])
	return n


static func ingredient_name(key: String) -> String:
	return GROUPS[key] if GROUPS.has(key) else ItemDB.item_name(key)


static func can_cook(id: String) -> bool:
	var r := get_recipe(id)
	if r == null or not is_known(id):
		return false
	# itens fixos primeiro; os grupos não podem contar o mesmo item duas vezes
	var reserved := {}
	for key in r.ingredients:
		if not GROUPS.has(key):
			if Game.count_item(key) < int(r.ingredients[key]):
				return false
			reserved[key] = int(r.ingredients[key])
	for key in r.ingredients:
		if GROUPS.has(key):
			var n := 0
			for s in Game.inventory:
				if s != null and matches(key, s["id"]):
					n += int(s["qty"]) - int(reserved.get(s["id"], 0))
			if n < int(r.ingredients[key]):
				return false
	return true


## Cozinha (gasta os ingredientes e põe o prato na mochila). Retorna a mensagem.
static func cook(id: String) -> String:
	if not can_cook(id):
		return "Faltam ingredientes."
	var r := get_recipe(id)
	if Game.inventory.all(func(s): return s != null) and Game.count_item(r.dish_id()) == 0:
		return "A mochila está cheia."
	for key in r.ingredients:
		if not GROUPS.has(key):
			Game.remove_item(key, int(r.ingredients[key]))
	for key in r.ingredients:
		if GROUPS.has(key):
			_take_group(key, int(r.ingredients[key]))
	Game.add_item(r.dish_id(), 1)
	Game.dishes_cooked += 1
	var t := "Cozinhou %s!" % r.name
	var u := check_unlocks()
	return t + ("\n" + u if u != "" else "")


## Gasta itens de um grupo, os mais baratos primeiro.
static func _take_group(key: String, qty: int) -> void:
	for n in qty:
		var best := -1
		for i in Game.INV_SIZE:
			var s = Game.inventory[i]
			if s != null and matches(key, s["id"]):
				if best < 0 or ItemDB.sell_price(s["id"]) < ItemDB.sell_price(Game.inventory[best]["id"]):
					best = i
		if best >= 0:
			Game.remove_from_slot(best, 1)


# ------------------------------------------------------------------ comer e bônus
static func now_abs() -> int:
	return Game.day * 1440 + Game.minutes


## Come o prato da mão. Retorna a mensagem.
static func eat(dish_id: String) -> String:
	ensure_loaded()
	var r: RecipeData = null
	for id in recipes:
		if recipes[id].dish_id() == dish_id:
			r = recipes[id]
	if r == null:
		return ""
	if Game.energy >= Game.max_energy and Game.health >= Game.max_health and r.buff == "":
		return "Você está cheio de energia agora."
	if not Game.remove_item(dish_id, 1):
		return ""
	Game.energy = minf(Game.max_energy, Game.energy + r.energy)
	Game.bump("eaten")
	Game.health = minf(Game.max_health, Game.health + r.health)
	var t := "Comeu %s. +%d energia" % [r.name, r.energy]
	if r.health > 0:
		t += ", +%d vida" % r.health
	if r.buff != "":
		var types: Array = ["speed", "stamina", "fishing", "animal"] if r.buff == "all" else [r.buff]
		for b in types:
			Game.buffs[b] = maxi(int(Game.buffs.get(b, 0)), now_abs() + r.buff_minutes)
		t += "\n%s por %s: %s." % [RecipeData.BUFF_NAMES[r.buff], duration_text(r.buff_minutes), RecipeData.BUFF_DESC[r.buff]]
	Game.stats_changed.emit()
	return t


static func has_buff(b: String) -> bool:
	return int(Game.buffs.get(b, 0)) > now_abs()


## Texto curto para a HUD: "Passo Leve 1h30 · Fôlego 2h"
static func buffs_text() -> String:
	var parts := []
	for b in Game.buffs:
		var left := int(Game.buffs[b]) - now_abs()
		if left > 0:
			parts.append("%s %s" % [RecipeData.BUFF_NAMES[b], duration_text(left)])
	return " · ".join(parts)


## Multiplicadores usados pelos outros sistemas.
static func speed_mult() -> float:
	return 1.25 if has_buff("speed") else 1.0


static func energy_mult() -> float:
	return 0.6 if has_buff("stamina") else 1.0


static func friendship_mult() -> float:
	return 1.5 if has_buff("animal") else 1.0


static func fishing_luck() -> float:
	return 1.6 if has_buff("fishing") else 1.0
