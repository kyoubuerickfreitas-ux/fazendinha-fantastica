class_name FishQuests
## Pedidos de pesca do Fungo e o Torneio do Lago.
## Tudo fica em Game.fish_flags (vai no save):
##   "request"        pedido atual (Dictionary, vazio = nenhum)
##   "requests_done"  quantos pedidos já entregues
##   "tour"           torneio de hoje {"day", "best", "fish", "done"}
##   "tour_wins", "tour_played", "tour_last"

# ------------------------------------------------------------------ pedidos
const REQUEST_DAYS := 5
const REWARD_ITEMS := [["bait_fly", 3], ["bait_treasure", 2], ["fert_quality", 1], ["bait_mushroom", 4]]


static func request() -> Dictionary:
	var r = Game.fish_flags.get("request", {})
	return r if r is Dictionary else {}


static func requests_done() -> int:
	return int(Game.fish_flags.get("requests_done", 0))


## Peixes que fazem sentido pedir agora (desta estação, do nível do jogador, nada lendário).
static func _candidates(max_rarity: int) -> Array:
	var season := Game.season_id()
	var lvl := FishDB.level()
	return FishDB.all_ids().filter(func(id):
		var f: FishData = FishDB.get_fish(id)
		return f.rarity <= max_rarity and f.min_level <= lvl and f.special == "" \
			and (f.seasons.is_empty() or f.seasons.has(season)))


## Cria um pedido novo (se não houver um). Retorna o texto do pedido ou "".
static func ensure_request() -> String:
	if not request().is_empty():
		return ""
	var lvl := FishDB.level()
	var max_r := clampi(1 + lvl / 3, 1, 3)
	var cands := _candidates(max_r)
	if cands.is_empty():
		return ""
	var fid: String = cands[randi() % cands.size()]
	var f := FishDB.get_fish(fid)
	var sell := ItemDB.sell_price(fid)
	var types := ["deliver", "deliver", "big", "quality", "rare", "lost"]
	var kind: String = types[randi() % types.size()]
	if kind == "rare" and lvl < 3:
		kind = "deliver"
	var r := {"type": kind, "deadline": Game.day + REQUEST_DAYS, "progress": 0, "xp": 20 + f.rarity * 10}
	match kind:
		"deliver":
			r["fish"] = fid
			r["qty"] = clampi(3 - f.rarity, 1, 3)
			r["money"] = int(sell * r["qty"] * 1.6) + 30
			r["text"] = "Traga %d %s." % [r["qty"], f.name]
		"big":
			r["fish"] = fid
			r["qty"] = 1
			r["size"] = snappedf(lerpf(f.size_min, f.size_max, 0.6), 1.0)
			r["money"] = sell * 3 + 80
			r["text"] = "Pesque um %s de pelo menos %.0f cm e venha me contar." % [f.name, r["size"]]
		"quality":
			r["qty"] = 2 + lvl / 4
			r["money"] = 150 + r["qty"] * 40
			r["text"] = "Traga %d peixes de qualidade prata ou melhor (qualquer espécie)." % r["qty"]
		"rare":
			r["rarity"] = mini(2 + lvl / 5, 4)
			r["qty"] = 1
			r["money"] = 140 * r["rarity"]
			r["xp"] = 30 + 15 * r["rarity"]
			r["text"] = "Pesque um peixe de raridade \"%s\" ou acima e venha me contar." % FishData.RARITY_NAMES[r["rarity"]]
		"lost":
			var lost: String = ["old_coin", "relic_shell", "pearl"][randi() % (1 + mini(lvl / 3, 2))]
			r["item"] = lost
			r["qty"] = 1
			r["money"] = ItemDB.sell_price(lost) * 2 + 60
			r["text"] = "Perdi um(a) %s no lago anos atrás. Se pescar um, me traga!" % ItemDB.item_name(lost)
	if randf() < 0.35:
		var ri: Array = REWARD_ITEMS[randi() % REWARD_ITEMS.size()]
		r["reward_item"] = ri[0]
		r["reward_qty"] = ri[1]
	Game.fish_flags["request"] = r
	return "Fungo tem um pedido de pesca: " + r["text"]


static func reward_text(r: Dictionary) -> String:
	var t := "%d moedas, %d XP de pesca" % [int(r["money"]), int(r["xp"])]
	if r.has("reward_item"):
		t += ", %d %s" % [int(r["reward_qty"]), ItemDB.item_name(r["reward_item"])]
	return t


static func days_left() -> int:
	var r := request()
	return int(r.get("deadline", 0)) - Game.day if not r.is_empty() else 0


## Progresso para mostrar: "1/2"
static func progress_text() -> String:
	var r := request()
	if r.is_empty():
		return ""
	match r["type"]:
		"deliver":
			return "%d/%d na mochila" % [mini(Game.count_item(r["fish"]), int(r["qty"])), int(r["qty"])]
		"quality":
			return "%d/%d na mochila" % [mini(_quality_fish_count(), int(r["qty"])), int(r["qty"])]
		"lost":
			return "%d/1 na mochila" % mini(Game.count_item(r["item"]), 1)
	return "feito! fale com o Fungo" if int(r["progress"]) >= 1 else "ainda não"


static func _quality_fish_count() -> int:
	var n := 0
	for s in Game.inventory:
		if s != null and ItemDB.get_item(s["id"]).get("type", "") == "fish" and int(s.get("q", 0)) >= 1:
			n += int(s["qty"])
	return n


static func is_ready() -> bool:
	var r := request()
	if r.is_empty():
		return false
	match r["type"]:
		"deliver":
			return Game.count_item(r["fish"]) >= int(r["qty"])
		"quality":
			return _quality_fish_count() >= int(r["qty"])
		"lost":
			return Game.count_item(r["item"]) >= 1
	return int(r["progress"]) >= 1


## Conversa com o Fungo: entrega o pedido se estiver pronto. Retorna o texto ou "".
static func try_deliver() -> String:
	if not is_ready():
		return ""
	var r := request()
	match r["type"]:
		"deliver":
			Game.remove_item(r["fish"], int(r["qty"]))
		"lost":
			Game.remove_item(r["item"], 1)
		"quality":
			var need := int(r["qty"])
			for i in Game.INV_SIZE:
				var s = Game.inventory[i]
				if need > 0 and s != null and ItemDB.get_item(s["id"]).get("type", "") == "fish" and int(s.get("q", 0)) >= 1:
					var take := mini(need, int(s["qty"]))
					Game.remove_from_slot(i, take)
					need -= take
	Game.add_money(int(r["money"]))
	var lvl_up := FishDB.add_xp(int(r["xp"]))
	if r.has("reward_item"):
		Game.add_item(r["reward_item"], int(r["reward_qty"]))
	Game.fish_flags["requests_done"] = requests_done() + 1
	Game.fish_flags["request"] = {}
	var t := "Fungo: Muito obrigado! Pedido entregue: " + reward_text(r) + "."
	if lvl_up > 0:
		t += "\nNível de pesca %d!" % lvl_up
	return t


# ------------------------------------------------------------------ torneio
const TOURNAMENT_DAY := 13          # dia da estação
const TOUR_START := 8 * 60
const TOUR_END := 16 * 60
const RIVALS := ["Dona Carpa", "Seu Anzol", "Pipoca"]
const PRIZES := [800, 400, 150, 0]


static func is_tournament_day(day: int = -1) -> bool:
	return Calendar.day_of_season(Game.day if day < 0 else day) == TOURNAMENT_DAY


static func tournament_active() -> bool:
	return is_tournament_day() and Game.minutes >= TOUR_START and Game.minutes < TOUR_END \
		and not _tour().get("done", false)


static func _tour() -> Dictionary:
	var t = Game.fish_flags.get("tour", {})
	if not (t is Dictionary) or int(t.get("day", -1)) != Game.day:
		return {}
	return t


## Pontos de uma captura: o tamanho conta, e peixes mais raros valem mais.
static func points(id: String, size: float) -> int:
	return int(round(size * (1.0 + 0.5 * FishDB.get_fish(id).rarity)))


## Pontos dos rivais (fixos para cada torneio, crescem um pouco com os anos).
static func rival_scores(day: int = -1) -> Array:
	var d := Game.day if day < 0 else day
	var rng := RandomNumberGenerator.new()
	rng.seed = d * 7919
	var grow := 1.0 + 0.15 * (Calendar.year(d) - 1)
	return [int(rng.randi_range(25, 70) * grow), int(rng.randi_range(45, 110) * grow), int(rng.randi_range(70, 150) * grow)]


## Posição (1..4) de um placar contra os rivais.
static func rank_of(score: int) -> int:
	var r := 1
	for s in rival_scores():
		if s >= score:
			r += 1
	return r


## Chamado a cada peixe pescado. Retorna texto extra para o aviso ("" se nada).
static func on_catch(id: String, m: Dictionary) -> String:
	var parts := []
	var r := request()
	if not r.is_empty() and int(r["progress"]) < 1:
		var f := FishDB.get_fish(id)
		if r["type"] == "big" and id == r["fish"] and float(m["size"]) >= float(r["size"]):
			r["progress"] = 1
			parts.append("Pedido do Fungo cumprido! Vá contar a ele.")
		elif r["type"] == "rare" and f.rarity >= int(r["rarity"]):
			r["progress"] = 1
			parts.append("Pedido do Fungo cumprido! Vá contar a ele.")
	if tournament_active():
		var t := _tour()
		if t.is_empty():
			t = {"day": Game.day, "best": 0, "fish": "", "done": false}
		var pts := points(id, float(m["size"]))
		if pts > int(t["best"]):
			t["best"] = pts
			t["fish"] = id
			parts.append("Torneio: %d pts! (%dº lugar agora)" % [pts, rank_of(pts)])
		Game.fish_flags["tour"] = t
	return "\n".join(parts)


## Fecha o torneio (às 16h, ou ao dormir). Retorna o resultado ou "".
static func finish_tournament() -> String:
	var t := _tour()
	if not is_tournament_day() or t.get("done", false):
		return ""
	if t.is_empty() or int(t["best"]) <= 0:
		Game.fish_flags["tour"] = {"day": Game.day, "best": 0, "fish": "", "done": true}
		return "O Torneio do Lago acabou. Você não pescou nada para inscrever desta vez."
	t["done"] = true
	Game.fish_flags["tour"] = t
	Game.fish_flags["tour_played"] = int(Game.fish_flags.get("tour_played", 0)) + 1
	var rank := rank_of(int(t["best"]))
	var rivals := rival_scores()
	var text := "Fim do Torneio do Lago! Você: %d pts com %s · %s %d, %s %d, %s %d.\n" % [int(t["best"]),
		FishDB.get_fish(t["fish"]).name, RIVALS[0], rivals[0], RIVALS[1], rivals[1], RIVALS[2], rivals[2]]
	var prize: int = PRIZES[rank - 1]
	if prize > 0:
		Game.add_money(prize)
	match rank:
		1:
			Game.fish_flags["tour_wins"] = int(Game.fish_flags.get("tour_wins", 0)) + 1
			text += "1º LUGAR! Prêmio: %d moedas" % prize
			if not Game.fish_flags.get("got_trophy_tournament", false) and Game.add_item("trophy_tournament", 1) == 0:
				Game.fish_flags["got_trophy_tournament"] = true
				text += " e a Taça do Lago"
			else:
				Game.add_item("bait_fly", 5)
				text += " e 5 Moscas de Fibra"
			text += "!"
		2, 3:
			text += "%dº lugar! Prêmio: %d moedas." % [rank, prize]
		_:
			Game.add_item("bait_worm", 5)
			text += "4º lugar. Ganhou 5 minhocas pela participação. Na próxima vai!"
	Game.fish_flags["tour_last"] = {"day": Game.day, "rank": rank, "best": int(t["best"])}
	return text


# ------------------------------------------------------------------ novo dia
## Chamado ao começar um novo dia. Retorna avisos ("" se nada).
static func on_new_day() -> String:
	var notes := []
	var r := request()
	if not r.is_empty() and Game.day > int(r["deadline"]):
		Game.fish_flags["request"] = {}
		notes.append("O pedido de pesca do Fungo expirou.")
	if request().is_empty() and Game.day % 2 == 0:
		var t := ensure_request()
		if t != "":
			notes.append(t)
	if is_tournament_day():
		notes.append("Hoje tem Torneio do Lago (8h às 16h): o maior peixe vence! Peixes raros valem mais pontos.")
	elif is_tournament_day(Game.day + 1):
		notes.append("Amanhã tem Torneio do Lago!")
	return "\n".join(notes)
