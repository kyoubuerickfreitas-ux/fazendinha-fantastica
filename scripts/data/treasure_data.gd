class_name TreasureData
extends Resource
## Tesouro ou objeto que pode vir na linha de pesca (data/treasures/*.tres).
## kind: chest (abre na hora e dá a recompensa), item (vai para a mochila), message (garrafa: lê uma
## mensagem), map (pedaço de mapa), material (vira outro item na hora), junk (lixo)

const RARITY_NAMES := ["Comum", "Incomum", "Raro", "Muito raro", "Épico"]

@export var id := ""
@export var name := ""
@export_multiline var description := ""
@export var kind := "item"
@export_range(0, 4) var rarity := 0
## peso no sorteio entre os tesouros possíveis
@export var weight := 10.0
@export var waters: PackedStringArray = PackedStringArray(["lake", "river", "pond"])
@export var depth := "any"
@export var min_level := 1
## só aparece uma vez no jogo todo (ex.: objeto perdido do Fungo)
@export var unique := false
@export var sell := 0
## material: vira este item, nesta quantidade
@export var gives := ""
@export var gives_qty := 1


func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, 4)]
