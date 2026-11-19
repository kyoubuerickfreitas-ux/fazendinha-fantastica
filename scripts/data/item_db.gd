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

## type: tool | seed | crop | resource | product
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
	"truffle": {"name": "Trufa da Floresta", "icon": 29, "type": "product", "sell": 120, "desc": "Farejada pelo Catarrápio."},

	"seed_carrot": {"name": "Sementes de Cenoura-Lunar", "icon": 12, "hd": 10, "type": "seed", "crop": "carrot", "buy": 20, "desc": "Cresce em 3 dias."},
	"seed_tomato": {"name": "Sementes de Tomate-Rubi", "icon": 13, "hd": 11, "type": "seed", "crop": "tomato", "buy": 30, "desc": "Cresce em 4 dias."},
	"seed_kale": {"name": "Sementes de Couve-Musgo", "icon": 14, "hd": 9, "type": "seed", "crop": "kale", "buy": 15, "desc": "Cresce em 2 dias."},
	"seed_starflower": {"name": "Sementes de Flor-Estrela", "icon": 15, "hd": 12, "type": "seed", "crop": "starflower", "buy": 45, "desc": "Cresce em 5 dias."},
}

## row: linha em crops.png (colunas = estágios 0..3)
const CROPS := {
	"carrot": {"row": 0, "days": 3, "produce": "carrot", "amount": 1},
	"tomato": {"row": 1, "days": 4, "produce": "tomato", "amount": 2},
	"kale": {"row": 2, "days": 2, "produce": "kale", "amount": 1},
	"starflower": {"row": 3, "days": 5, "produce": "starflower", "amount": 1},
}

const SHOP_SEEDS := ["seed_kale", "seed_carrot", "seed_tomato", "seed_starflower"]

const MAX_STACK := 99


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


static func icon(id: String) -> AtlasTexture:
	var item := get_item(id)
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
