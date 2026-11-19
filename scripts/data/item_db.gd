class_name ItemDB
## Banco de dados de itens e plantações.
## Para adicionar um item novo: crie a entrada aqui e desenhe o ícone em icons.png.

const ICONS := preload("res://assets/sprites/icons.png")
const ICON_SIZE := 16
const ICON_COLUMNS := 16
## Ícones em alta resolução (32x32), gerados por tools/import_icons.py.
## Itens com "hd" usam este atlas no lugar de icons.png.
const ICONS_HD := preload("res://assets/sprites/items_hd.png")
const HD_SIZE := 32
const HD_COLUMNS := 16

## Ícones de interface (índices em icons.png)
const UI_ICON := {
	"coin": 16, "sun": 17, "rain": 18, "heart": 19, "bolt": 20,
	"backpack": 21, "hand": 22, "bubble": 23, "moon": 24, "cloud": 25,
}

## type: tool | seed | crop | resource | product | fish | bait | placeable
const ITEMS := {
	"watering_can": {"name": "Regador", "icon": 0, "hd": 0, "type": "tool", "desc": "Rega a terra arada. Encha na água do lago."},
	"hoe": {"name": "Enxada", "icon": 1, "hd": 1, "type": "tool", "desc": "Ara a grama para plantar."},
	"axe": {"name": "Machado", "icon": 2, "hd": 2, "type": "tool", "desc": "Corta árvores e tocos."},
	"pickaxe": {"name": "Picareta", "icon": 3, "hd": 3, "type": "tool", "desc": "Quebra pedras e desfaz a terra arada."},
	"scythe": {"name": "Foice", "icon": 4, "hd": 4, "type": "tool", "desc": "Corta mato e colhe plantações."},

	"wood": {"name": "Madeira", "icon": 5, "type": "resource", "sell": 2, "desc": "Material de construção."},
	"stone": {"name": "Pedra", "icon": 6, "type": "resource", "sell": 2, "desc": "Material de construção."},
	"fiber": {"name": "Fibra", "icon": 7, "hd": 5, "type": "resource", "sell": 1, "desc": "Usada em artesanato."},

	"carrot": {"name": "Cenoura-Lunar", "icon": 8, "hd": 31, "type": "crop", "sell": 45, "desc": "Crocante e levemente brilhante."},
	"tomato": {"name": "Tomate-Rubi", "icon": 9, "hd": 34, "type": "crop", "sell": 70, "desc": "Vermelho como uma pedra preciosa."},
	"kale": {"name": "Couve-Musgo", "icon": 10, "type": "crop", "sell": 35, "desc": "Folhas macias como musgo."},
	"starflower": {"name": "Flor-Estrela", "icon": 11, "type": "crop", "sell": 110, "desc": "Brilha suavemente à noite."},

	"milk": {"name": "Leite de Moombor", "icon": 26, "hd": 37, "type": "product", "sell": 60, "desc": "Cremoso, com cheirinho de capim."},
	"egg": {"name": "Ovo de Piuplum", "icon": 27, "hd": 39, "type": "product", "sell": 30, "desc": "Cada ovo tem uma pintinha diferente."},
	"wool": {"name": "Lã de Fofrança", "icon": 28, "hd": 38, "type": "product", "sell": 80, "desc": "Macia como nuvem, com cheiro de flor."},
	"truffle": {"name": "Trufa da Floresta", "icon": 29, "hd": 40, "type": "product", "sell": 120, "desc": "Farejada pelo Catarrápio."},

	"seed_carrot": {"name": "Sementes de Cenoura-Lunar", "icon": 12, "hd": 10, "type": "seed", "crop": "carrot", "buy": 20, "desc": "Cresce em 3 dias."},
	"seed_tomato": {"name": "Sementes de Tomate-Rubi", "icon": 13, "hd": 11, "type": "seed", "crop": "tomato", "buy": 30, "desc": "Cresce em 4 dias."},
	"seed_kale": {"name": "Sementes de Couve-Musgo", "icon": 14, "hd": 9, "type": "seed", "crop": "kale", "buy": 15, "desc": "Cresce em 2 dias."},
	"seed_starflower": {"name": "Sementes de Flor-Estrela", "icon": 15, "hd": 12, "type": "seed", "crop": "starflower", "buy": 45, "desc": "Cresce em 5 dias."},

	# produtos fabricados
	"cheese": {"name": "Queijo de Moombor", "tex": "res://assets/sprites/craft/icon_cheese.png", "type": "product", "sell": 170, "desc": "Feito na prensa com leite de Moombor."},
	"cloth": {"name": "Tecido de Fofrança", "tex": "res://assets/sprites/craft/icon_cloth.png", "type": "product", "sell": 220, "desc": "Tecido macio feito no tear."},
	"jam": {"name": "Geleia Caseira", "tex": "res://assets/sprites/craft/icon_jam.png", "type": "product", "sell": 140, "desc": "Feita no pote de conserva com qualquer colheita."},
	"hay": {"name": "Feno", "tex": "res://assets/sprites/craft/icon_hay.png", "type": "resource", "sell": 1, "desc": "Coloque no comedouro do pasto. Cada animal come 1 por dia."},

	# objetos que dá para construir (type "placeable"; ver PLACEABLES)
	"workbench": {"name": "Bancada de Trabalho", "tex": "res://assets/sprites/craft/icon_workbench.png", "type": "placeable", "desc": "Onde se fabrica tudo."},
	"feeder": {"name": "Comedouro", "tex": "res://assets/sprites/craft/icon_feeder.png", "type": "placeable", "desc": "Ponha feno aqui para alimentar os animais."},
	"cheese_press": {"name": "Prensa de Queijo", "tex": "res://assets/sprites/craft/icon_cheese_press.png", "type": "placeable", "desc": "Leite vira queijo em 1 dia."},
	"loom": {"name": "Tear", "tex": "res://assets/sprites/craft/icon_loom.png", "type": "placeable", "desc": "Lã vira tecido em 1 dia."},
	"preserves_jar": {"name": "Pote de Conserva", "tex": "res://assets/sprites/craft/icon_preserves_jar.png", "type": "placeable", "desc": "Qualquer colheita vira geleia em 2 dias."},
	"fence": {"name": "Cerca de Madeira", "tex": "res://assets/sprites/craft/icon_fence.png", "type": "placeable", "desc": "Decoração. Bloqueia a passagem."},
	"stone_path": {"name": "Caminho de Pedra", "tex": "res://assets/sprites/craft/icon_stone_path.png", "type": "placeable", "desc": "Chão decorativo."},
	"scarecrow": {"name": "Espantalho", "tex": "res://assets/sprites/craft/icon_scarecrow.png", "type": "placeable", "desc": "Decoração com cara de amigo."},
	"barn": {"name": "Celeiro", "tex": "res://assets/sprites/craft/icon_barn.png", "type": "placeable", "desc": "Abriga +4 animais grandes (Moombor, Fofrança, Catarrápio)."},
	"coop": {"name": "Galinheiro", "tex": "res://assets/sprites/craft/icon_coop.png", "type": "placeable", "desc": "Abriga +6 Piuplum."},

	"fishing_rod": {"name": "Vara de Pesca", "icon": 0, "hd": 7, "type": "tool", "buy": 100, "desc": "Use na água do lago. Coloque uma isca para pescar melhor."},

	"fish_orange": {"name": "Peixinho-Brasa", "icon": 0, "hd": 41, "type": "fish", "sell": 25, "desc": "Listrado como brasa de fogueira."},
	"fish_mackerel": {"name": "Cavala-Azul", "icon": 0, "hd": 42, "type": "fish", "sell": 30, "desc": "Nada em cardumes perto da margem."},
	"fish_goldfish": {"name": "Kinguio-Véu", "icon": 0, "hd": 43, "type": "fish", "sell": 60, "desc": "A cauda parece um véu de seda."},
	"fish_perch": {"name": "Perca-Musgo", "icon": 0, "hd": 44, "type": "fish", "sell": 28, "desc": "Cresce entre as algas do fundo."},
	"fish_catfish": {"name": "Bagre-Barbudo", "icon": 0, "hd": 45, "type": "fish", "sell": 70, "desc": "Sai da toca nas noites de chuva."},
	"fish_silver": {"name": "Prateadinho", "icon": 0, "hd": 46, "type": "fish", "sell": 20, "desc": "O mais comum do lago."},
	"fish_puffer": {"name": "Baiacu-Bolota", "icon": 0, "hd": 47, "type": "fish", "sell": 65, "desc": "Incha quando é pescado. Não aperte!"},
	"fish_angel": {"name": "Acará-Listrado", "icon": 0, "hd": 48, "type": "fish", "sell": 75, "desc": "Elegante e desconfiado."},
	"fish_snapper": {"name": "Pargo-Rubi", "icon": 0, "hd": 49, "type": "fish", "sell": 80, "desc": "Vermelho como o Tomate-Rubi."},
	"fish_eel": {"name": "Enguia-Lunar", "icon": 0, "hd": 50, "type": "fish", "sell": 150, "desc": "Brilha de leve sob a lua."},
	"fish_shark": {"name": "Tubarãozinho-do-Lago", "icon": 0, "hd": 51, "type": "fish", "sell": 180, "desc": "Pequeno, mas cheio de dentes."},
	"fish_clown": {"name": "Peixe-Palhaço", "icon": 0, "hd": 52, "type": "fish", "sell": 70, "desc": "Sempre parece estar sorrindo."},
	"fish_sword": {"name": "Espadarte-Junco", "icon": 0, "hd": 53, "type": "fish", "sell": 160, "desc": "Rápido como uma flecha."},
	"fish_axolotl": {"name": "Axolote-Rosado", "icon": 0, "hd": 54, "type": "fish", "sell": 200, "desc": "Adora dias de chuva."},
	"fish_yellow": {"name": "Perca-Dourada", "icon": 0, "hd": 55, "type": "fish", "sell": 35, "desc": "Fica dourada ao sol da tarde."},
	"fish_betta": {"name": "Betta-Celeste", "icon": 0, "hd": 56, "type": "fish", "sell": 90, "desc": "Briguento, mas lindo."},
	"fish_angler": {"name": "Peixe-Lanterna", "icon": 0, "hd": 57, "type": "fish", "sell": 220, "desc": "Usa a luz para atrair outros peixes."},
	"fish_ghost": {"name": "Peixe-Fantasma", "icon": 0, "hd": 58, "type": "fish", "sell": 400, "desc": "Dizem que é a alma do lago."},
	"fish_lion": {"name": "Peixe-Leão", "icon": 0, "hd": 59, "type": "fish", "sell": 170, "desc": "Cuidado com os espinhos."},
	"fish_sunfish": {"name": "Peixe-Lua", "icon": 0, "hd": 60, "type": "fish", "sell": 450, "desc": "Raríssimo. Aparece em dias calmos."},

	"bait_worm": {"name": "Minhoca", "icon": 0, "hd": 61, "type": "bait", "buy": 5, "desc": "Isca básica. Às vezes aparece ao arar a terra."},
	"bait_corn": {"name": "Bolinha de Milho", "icon": 0, "hd": 62, "type": "bait", "buy": 6, "desc": "Os peixes mordem bem rápido."},
	"bait_cricket": {"name": "Grilo Saltador", "icon": 0, "hd": 63, "type": "bait", "buy": 12, "desc": "Atrai peixes incomuns."},
	"bait_mushroom": {"name": "Cogumelo Brilhante", "icon": 0, "hd": 64, "type": "bait", "buy": 25, "desc": "Brilha no escuro. Ótima à noite e para peixes raros."},
	"bait_fly": {"name": "Mosca de Fibra", "icon": 0, "hd": 65, "type": "bait", "buy": 40, "desc": "Isca artesanal. A melhor para peixes raros e lendários."},
}

## row: linha em crops.png (colunas = estágios 0..3)
const CROPS := {
	"carrot": {"row": 0, "days": 3, "produce": "carrot", "amount": 1},
	"tomato": {"row": 1, "days": 4, "produce": "tomato", "amount": 2},
	"kale": {"row": 2, "days": 2, "produce": "kale", "amount": 1},
	"starflower": {"row": 3, "days": 5, "produce": "starflower", "amount": 1},
}

## Objetos construíveis. size = células (largura, altura); a célula mirada é a de baixo, no meio.
## solid = bloqueia a passagem; floor = desenhado no chão; machine = máquina de produção.
const PLACEABLES := {
	"workbench": {"size": Vector2i(2, 1), "solid": true, "pad": 4},
	"feeder": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"cheese_press": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"loom": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"preserves_jar": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"fence": {"size": Vector2i(1, 1), "solid": true, "pad": 1},
	"stone_path": {"size": Vector2i(1, 1), "solid": false, "floor": true, "pad": 0},
	"scarecrow": {"size": Vector2i(1, 1), "solid": true, "pad": 3},
	"barn": {"size": Vector2i(4, 3), "solid": true, "pad": 2, "fixed": true},
	"coop": {"size": Vector2i(3, 2), "solid": true, "pad": 2, "fixed": true},
}

## Máquinas: entrada (item ou tipo "crop") -> saída, em dias.
const MACHINES := {
	"cheese_press": {"input": "milk", "output": "cheese", "days": 1},
	"loom": {"input": "wool", "output": "cloth", "days": 1},
	"preserves_jar": {"input_type": "crop", "output": "jam", "days": 2},
}

## Receitas da bancada. cost: item -> quantidade ("money" = moedas).
const RECIPES := [
	{"result": "hay", "qty": 3, "cost": {"fiber": 2}},
	{"result": "feeder", "qty": 1, "cost": {"wood": 10}},
	{"result": "fence", "qty": 4, "cost": {"wood": 5}},
	{"result": "stone_path", "qty": 4, "cost": {"stone": 3}},
	{"result": "bait_fly", "qty": 2, "cost": {"fiber": 4, "wood": 1}},
	{"result": "scarecrow", "qty": 1, "cost": {"wood": 15, "fiber": 10}},
	{"result": "cheese_press", "qty": 1, "cost": {"wood": 20, "stone": 10}},
	{"result": "loom", "qty": 1, "cost": {"wood": 25, "fiber": 15}},
	{"result": "preserves_jar", "qty": 1, "cost": {"wood": 15, "stone": 10}},
	{"result": "workbench", "qty": 1, "cost": {"wood": 30}},
	{"result": "coop", "qty": 1, "cost": {"wood": 80, "stone": 40, "money": 500}},
	{"result": "barn", "qty": 1, "cost": {"wood": 120, "stone": 60, "money": 1000}},
]

## Animais à venda no Fungo: precisam de espaço (celeiro/galinheiro).
const ANIMAL_SHOP := {"moombor": 800, "fofranca": 900, "catarrapio": 1000, "piuplum": 300}
const BIRDS := ["piuplum"]
const BASE_CAPACITY := {"big": 3, "bird": 2}
const BUILDING_CAPACITY := {"barn": 4, "coop": 6}

const SHOP_SEEDS := ["seed_kale", "seed_carrot", "seed_tomato", "seed_starflower"]
## Peixes: raridade 0 comum, 1 incomum, 2 raro, 3 lendário; time: day | night | any; rain: aparece mais na chuva
const FISH := {
	"fish_orange": {"rarity": 0, "time": "any", "rain": false},
	"fish_mackerel": {"rarity": 0, "time": "day", "rain": false},
	"fish_goldfish": {"rarity": 1, "time": "day", "rain": false},
	"fish_perch": {"rarity": 0, "time": "any", "rain": false},
	"fish_catfish": {"rarity": 1, "time": "night", "rain": true},
	"fish_silver": {"rarity": 0, "time": "any", "rain": false},
	"fish_puffer": {"rarity": 1, "time": "any", "rain": false},
	"fish_angel": {"rarity": 1, "time": "day", "rain": false},
	"fish_snapper": {"rarity": 1, "time": "day", "rain": false},
	"fish_eel": {"rarity": 2, "time": "night", "rain": false},
	"fish_shark": {"rarity": 2, "time": "any", "rain": true},
	"fish_clown": {"rarity": 1, "time": "day", "rain": false},
	"fish_sword": {"rarity": 2, "time": "day", "rain": false},
	"fish_axolotl": {"rarity": 2, "time": "any", "rain": true},
	"fish_yellow": {"rarity": 0, "time": "day", "rain": false},
	"fish_betta": {"rarity": 1, "time": "any", "rain": false},
	"fish_angler": {"rarity": 2, "time": "night", "rain": false},
	"fish_ghost": {"rarity": 3, "time": "night", "rain": false},
	"fish_lion": {"rarity": 2, "time": "any", "rain": false},
	"fish_sunfish": {"rarity": 3, "time": "day", "rain": false},
}

## Iscas: speed = rapidez da fisgada; bonus = multiplicador de chance por raridade [comum, incomum, raro, lendário]
const BAITS := {
	"": {"speed": 0.6, "bonus": [1.0, 0.5, 0.2, 0.0]},   # sem isca
	"bait_worm": {"speed": 1.0, "bonus": [1.0, 1.2, 0.8, 0.3]},
	"bait_corn": {"speed": 1.7, "bonus": [1.4, 0.9, 0.5, 0.2]},
	"bait_cricket": {"speed": 1.1, "bonus": [0.8, 2.0, 1.1, 0.5]},
	"bait_mushroom": {"speed": 1.0, "bonus": [0.7, 1.0, 1.8, 1.2], "night": 2.0},
	"bait_fly": {"speed": 0.9, "bonus": [0.5, 1.2, 2.2, 2.5]},
}

const RARITY_NAMES := ["comum", "incomum", "raro", "lendário"]
const RARITY_WEIGHT := [60.0, 25.0, 10.0, 2.0]

const SHOP_ITEMS := ["seed_kale", "seed_carrot", "seed_tomato", "seed_starflower",
	"fishing_rod", "bait_worm", "bait_corn", "bait_cricket", "bait_mushroom", "bait_fly"]

const MAX_STACK := 99


static func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if k == "money":
			if Game.money < int(cost[k]):
				return false
		elif Game.count_item(k) < int(cost[k]):
			return false
	return true


static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		if k == "money":
			parts.append("%d moedas" % int(cost[k]))
		else:
			parts.append("%d %s" % [int(cost[k]), item_name(k)])
	return ", ".join(parts)


static func has(id: String) -> bool:
	return ITEMS.has(id)


static func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func item_name(id: String) -> String:
	return ITEMS.get(id, {}).get("name", id)


static func is_stackable(id: String) -> bool:
	return get_item(id).get("type", "") != "tool"


static func sell_price(id: String) -> int:
	return int(get_item(id).get("sell", 0))


static func icon_index_texture(index: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ICONS
	t.region = Rect2(
		(index % ICON_COLUMNS) * ICON_SIZE,
		(index / ICON_COLUMNS) * ICON_SIZE,
		ICON_SIZE, ICON_SIZE)
	return t


static var _tex_cache := {}


static func icon(id: String) -> Texture2D:
	var item := get_item(id)
	if item.has("tex"):
		var path: String = item["tex"]
		if not _tex_cache.has(path):
			_tex_cache[path] = load(path)
		return _tex_cache[path]
	if item.has("hd"):
		var t := AtlasTexture.new()
		t.atlas = ICONS_HD
		var i := int(item["hd"])
		t.region = Rect2((i % HD_COLUMNS) * HD_SIZE, (i / HD_COLUMNS) * HD_SIZE, HD_SIZE, HD_SIZE)
		return t
	return icon_index_texture(int(item.get("icon", 0)))


static func ui_icon(name: String) -> AtlasTexture:
	return icon_index_texture(int(UI_ICON.get(name, 0)))


## Estágio visual (0 = semente, 3 = pronta) a partir dos dias de crescimento.
static func crop_stage(crop: String, growth: int) -> int:
	var days: int = CROPS[crop]["days"]
	if growth <= 0:
		return 0
	if growth >= days:
		return 3
	return clampi(1 + int(2.0 * growth / days), 1, 2)
