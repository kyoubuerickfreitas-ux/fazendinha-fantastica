class_name FishData
extends Resource
## Ficha de um peixe (data/fish/<id>.tres). O item de mesmo id (ItemDB) é o peixe na mochila.
## Para um peixe novo: crie a ficha e o item (com ícone); o sorteio e o Livro de Pesca usam a ficha.

const RARITY_NAMES := ["Comum", "Incomum", "Raro", "Muito raro", "Épico", "Lendário", "Secreto"]
const TIME_NAMES := {"dawn": "madrugada", "morning": "manhã", "afternoon": "tarde", "night": "noite"}
const WATER_NAMES := {"lake": "Lago", "river": "Rio", "pond": "Laguinho", "sea": "Mar", "cave": "Caverna"}

@export var id := ""
@export var name := ""
@export_multiline var description := ""
@export_multiline var lore := ""              # lenda/curiosidade (lendários)
@export_range(0, 6) var rarity := 0

@export_group("Onde e quando")
@export var waters := PackedStringArray(["lake"])     # lake | river | pond | sea | cave
@export var depth := "any"                            # shallow | deep | any
@export var regions := PackedStringArray(["farm"])
@export var seasons := PackedStringArray()            # vazio = o ano todo
@export var times := PackedStringArray()              # dawn | morning | afternoon | night (vazio = sempre)
@export var weathers := PackedStringArray()           # obrigatório (vazio = qualquer)
@export var favored_weathers := PackedStringArray()   # aparece mais nesses climas
@export var baits := PackedStringArray()              # iscas preferidas (atraem mais)

@export_group("Captura")
@export var min_level := 1
@export_range(0.0, 1.0) var difficulty := 0.0         # 0 = rarity padrão; >0 sobrepõe a força
@export var special := ""                             # condição extra (ex.: "map_complete")
@export_multiline var hint := ""                      # pista mostrada antes de descobrir

@export_group("Medidas e valor")
@export var size_min := 10.0     # cm
@export var size_max := 30.0
@export var weight_min := 0.1    # kg
@export var weight_max := 1.0
@export var xp := 0              # 0 = calculado pela raridade
@export var uses := PackedStringArray(["Venda", "Defumador", "Aquário", "Adubo de peixe"])
## preço e ícone para peixes que não estão fixos no ItemDB (os lendários): o FishDB registra o item
@export var sell := 0
@export_file("*.png") var icon := ""


func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, 6)]


func is_legendary() -> bool:
	return rarity >= 5


func xp_value() -> int:
	return xp if xp > 0 else 6 + rarity * 12
