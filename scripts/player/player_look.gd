class_name PlayerLook
## Aparência do jogador (criação de personagem): tom de pele, penteado, cor do cabelo, camisa e calção.
## O corpo base é pintado pelo shader player_look.gdshader (máscara de classes) e o cabelo é uma
## folha em cinza, do mesmo tamanho da do corpo, tingida com a cor escolhida.
## Camadas geradas por tools/make_player_layers.py.

const SHADER := preload("res://assets/shaders/player_look.gdshader")
const MASK_WALK := preload("res://assets/sprites/player/look_mask.png")
const MASK_ACTIONS := preload("res://assets/sprites/player/look_mask_actions.png")
const DIR := "res://assets/sprites/player/"

const SKINS := [["Pêssego", "f2d2b6"], ["Areia", "e3b38c"], ["Caramelo", "c98c60"], ["Canela", "a46a45"],
	["Cacau", "7a4a31"], ["Ébano", "4f3124"], ["Lilás (fada)", "b9a2d8"], ["Musgo (duende)", "93b37a"]]
const HAIR_STYLES := [["careca", "Careca"], ["curto", "Curto"], ["comprido", "Comprido"], ["rabo", "Rabo de cavalo"],
	["coque", "Coque"], ["cacheado", "Cacheado"], ["espetado", "Espetado"]]
const HAIR_COLORS := [["Preto", "2e2422"], ["Castanho", "6e4428"], ["Ruivo", "b8532c"], ["Loiro", "e3bd55"],
	["Grisalho", "d9d4cc"], ["Rosa", "e891b2"], ["Azul", "5f8fd6"], ["Verde", "6fb36a"]]
const SHIRTS := [["Creme", "e8dcc0"], ["Vermelha", "c8483a"], ["Azul", "4f7fc4"], ["Verde", "5f9e4a"],
	["Amarela", "e8c44a"], ["Roxa", "8a5cb0"], ["Rosa", "e88aa8"], ["Preta", "3d3636"]]
const PANTS := [["Oliva", "7a6a3a"], ["Jeans", "3f5f8f"], ["Marrom", "6b4a2e"], ["Cinza", "707070"],
	["Preto", "2f2a2a"], ["Verde", "4f6e3a"]]

const NAMES := ["Lia", "Davi", "Nina", "Caio", "Malu", "Théo", "Bia", "Rafa", "Luna", "Pedro", "Clara", "Joca",
	"Íris", "Tito", "Duda", "Juca", "Mel", "Benê", "Cora", "Zeca"]
const FARM_NAMES := ["Recanto Verde", "Sítio do Orvalho", "Vale das Abóboras", "Cantinho do Sol", "Sítio Cogumelo",
	"Fazenda Arco-Íris", "Pé de Feijão", "Chácara Vagalume", "Sítio Girassol", "Fazenda Estrelinha"]


static func default_look() -> Dictionary:
	return {"skin": 1, "hair": 1, "hair_color": 1, "shirt": 0, "pants": 0}


static func random_look() -> Dictionary:
	return {"skin": randi() % SKINS.size(), "hair": randi() % HAIR_STYLES.size(),
		"hair_color": randi() % HAIR_COLORS.size(), "shirt": randi() % SHIRTS.size(), "pants": randi() % PANTS.size()}


static func random_name() -> String:
	return NAMES[randi() % NAMES.size()]


static func random_farm() -> String:
	return FARM_NAMES[randi() % FARM_NAMES.size()]


## Corrige um visual vindo do save (índices fora da lista voltam ao padrão).
static func sanitize(look) -> Dictionary:
	var out := default_look()
	if look is Dictionary:
		var sizes := {"skin": SKINS.size(), "hair": HAIR_STYLES.size(), "hair_color": HAIR_COLORS.size(),
			"shirt": SHIRTS.size(), "pants": PANTS.size()}
		for k in out:
			var v := int(look.get(k, out[k]))
			if v >= 0 and v < int(sizes[k]):
				out[k] = v
	return out


static func color(list: Array, i: int) -> Color:
	return Color(list[clampi(i, 0, list.size() - 1)][1])


static func hair_color(look: Dictionary) -> Color:
	return color(HAIR_COLORS, int(look.get("hair_color", 0)))


## Os cabelos antigos foram desenhados para o corpo antigo; o corpo novo (tools/import_player_v2.py)
## fica careca até os cabelos novos serem encaixados nele.
const HAIR_READY := false


## Folha do cabelo (null = careca).
static func hair_texture(look: Dictionary, actions: bool) -> Texture2D:
	if not HAIR_READY:
		return null
	var style: String = HAIR_STYLES[clampi(int(look.get("hair", 0)), 0, HAIR_STYLES.size() - 1)][0]
	if style == "careca":
		return null
	return load(DIR + "hair_%s%s.png" % [style, "_actions" if actions else ""])


static func make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("look_mask", MASK_WALK)
	return m


## Aplica as cores ao material (actions = folha das animações de ferramenta).
static func apply(m: ShaderMaterial, look: Dictionary, actions: bool = false) -> void:
	m.set_shader_parameter("look_mask", MASK_ACTIONS if actions else MASK_WALK)
	m.set_shader_parameter("skin_color", color(SKINS, int(look.get("skin", 0))))
	m.set_shader_parameter("shirt_color", color(SHIRTS, int(look.get("shirt", 0))))
	m.set_shader_parameter("pants_color", color(PANTS, int(look.get("pants", 0))))
