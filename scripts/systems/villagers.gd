class_name Villagers
## Moradores (data/npcs/*.tres) e amizade: conversar 1x por dia, presentear 1x por dia,
## aniversários e recompensas a cada 2 corações.
## Estado: Game.friends = {id: {"pts", "talk_day", "gift_day", "rewards": [corações], "known": {item: reação}}}

const DIR := "res://data/npcs/"
const PTS_PER_HEART := 100
const MAX_HEARTS := 10
const TALK_PTS := 20
## reação -> pontos
const GIFT_PTS := {"love": 80, "like": 45, "neutral": 20, "dislike": -30}
const BIRTHDAY_MULT := 3
const REACTION_NAMES := {"love": "Adora", "like": "Gosta", "neutral": "Tanto faz", "dislike": "Não gosta"}

static var npcs := {}
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
			var n: NPCData = load(DIR + f)
			if n and n.id != "":
				npcs[n.id] = n


static func get_npc(id: String) -> NPCData:
	ensure_loaded()
	return npcs.get(id)


static func all_ids() -> Array:
	ensure_loaded()
	var ids := npcs.keys()
	ids.sort()
	return ids


# ------------------------------------------------------------------ amizade
static func rec(id: String) -> Dictionary:
	if not Game.friends.has(id):
		Game.friends[id] = {"pts": 0, "talk_day": -1, "gift_day": -1, "rewards": [], "known": {}}
	return Game.friends[id]


static func points(id: String) -> int:
	return int(rec(id)["pts"])


static func hearts(id: String) -> int:
	return mini(MAX_HEARTS, points(id) / PTS_PER_HEART)


static func _add(id: String, n: int) -> void:
	var r := rec(id)
	r["pts"] = clampi(int(r["pts"]) + n, 0, MAX_HEARTS * PTS_PER_HEART)


static func is_birthday(id: String, day: int = -1) -> bool:
	var n := get_npc(id)
	var d := Game.day if day < 0 else day
	return Calendar.season_id(d) == n.birthday_season and Calendar.day_of_season(d) == n.birthday_day


static func birthday_text(id: String) -> String:
	var n := get_npc(id)
	return "%d de %s" % [n.birthday_day, CropDB.season(n.birthday_season).name]


## Uma fala conforme os corações e o momento.
static func line(id: String) -> String:
	var n := get_npc(id)
	var pool: Array = []
	if is_birthday(id) and n.lines.has("birthday"):
		pool = n.lines["birthday"]
	elif Game.is_wet() and n.lines.has("rain") and randf() < 0.5:
		pool = n.lines["rain"]
	else:
		var h := hearts(id)
		var key := "0"
		for k in ["3", "6", "9"]:
			if h >= int(k) and n.lines.has(k):
				key = k
		pool = n.lines.get(key, ["..."])
	return pool[randi() % pool.size()]


## Conversa (ganha amizade 1x por dia) e entrega recompensas de coração. Retorna o texto.
static func talk(id: String) -> String:
	var r := rec(id)
	var t := line(id)
	if int(r["talk_day"]) != Game.day:
		r["talk_day"] = Game.day
		_add(id, TALK_PTS)
	var reward := _check_reward(id)
	if reward != "":
		t += "\n" + reward
	return t


## Recompensa do próximo marco de corações alcançado (uma por conversa).
static func _check_reward(id: String) -> String:
	var n := get_npc(id)
	var r := rec(id)
	var keys := n.rewards.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		if hearts(id) >= int(k) and not (r["rewards"] as Array).has(int(k)):
			var rw: Dictionary = n.rewards[k]
			if Game.add_item(rw["item"], int(rw["qty"])) > 0:
				return "(%s quer te dar algo, mas a mochila está cheia.)" % n.name
			(r["rewards"] as Array).append(int(k))
			return "%s: \"%s\" (+%d %s)" % [n.name, rw["line"], int(rw["qty"]), ItemDB.item_name(rw["item"])]
	return ""


static func _matches(key: String, item_id: String) -> bool:
	if key == "any_dish":
		return ItemDB.get_item(item_id).get("type", "") == "food"
	if key.begins_with("any_"):
		return Cooking.matches(key, item_id)
	return key == item_id


static func reaction(id: String, item_id: String) -> String:
	var n := get_npc(id)
	for group in [["love", n.loves], ["like", n.likes], ["dislike", n.dislikes]]:
		for key in group[1]:
			if _matches(key, item_id):
				return group[0]
	return "neutral"


static func can_gift(item_id: String) -> bool:
	return item_id != "" and not ItemDB.get_item(item_id).get("type", "") in ["tool", "placeable", "recipe", "bait"]


## Dá o item da mão. Retorna o texto (ou "" se não deu).
static func gift(id: String, item_id: String) -> String:
	var n := get_npc(id)
	var r := rec(id)
	if int(r["gift_day"]) == Game.day:
		return "%s: \"Você já me deu um presente hoje. Obrigada!\"" % n.name
	if not Game.remove_item(item_id, 1):
		return ""
	var re := reaction(id, item_id)
	var pts: int = GIFT_PTS[re]
	var bday := is_birthday(id)
	if bday and pts > 0:
		pts *= BIRTHDAY_MULT
	_add(id, pts)
	r["gift_day"] = Game.day
	(r["known"] as Dictionary)[item_id] = re
	var said: String = {"love": "\"%s? É o meu favorito! Como você sabia?!\"",
		"like": "\"%s! Que gentileza, obrigada.\"",
		"neutral": "\"Ah, %s. Obrigada.\"",
		"dislike": "\"%s...? Hm. Não é bem o meu gosto.\""}[re] % ItemDB.item_name(item_id)
	var t := "%s: %s" % [n.name, said]
	if bday:
		t += " (presente de aniversário!)"
	var reward := _check_reward(id)
	return t + ("\n" + reward if reward != "" else "")


## Presentes que você já descobriu (para a ficha do morador).
static func known_text(id: String) -> String:
	var known: Dictionary = rec(id)["known"]
	var parts := []
	for re in ["love", "like", "dislike"]:
		var items := known.keys().filter(func(k): return known[k] == re)
		if not items.is_empty():
			parts.append("%s: %s" % [REACTION_NAMES[re], ", ".join(items.map(func(k): return ItemDB.item_name(k)))])
	return " · ".join(parts) if parts.size() > 0 else "Dê presentes para descobrir do que gosta."


## Avisos do novo dia (aniversários).
static func on_new_day() -> String:
	var out := []
	for id in all_ids():
		if is_birthday(id):
			out.append("Hoje é aniversário de %s! Presentes valem o triplo." % get_npc(id).name)
		elif is_birthday(id, Game.day + 1):
			out.append("Amanhã é aniversário de %s." % get_npc(id).name)
	return "\n".join(out)
