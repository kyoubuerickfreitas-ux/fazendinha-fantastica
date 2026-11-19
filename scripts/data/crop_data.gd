class_name CropData
extends Resource
## Ficha de uma planta (data/crops/<id>.tres). Para criar uma planta nova basta
## criar um arquivo .tres com este script e um sprite em assets/sprites/crops/<id>.png
## (tira horizontal de quadros: um por estágio, o último = pronta para colher).

@export var id := ""
@export var name := ""
@export_multiline var description := ""
## vegetable | fruit | flower | grain | fungus
@export var category := "vegetable"

@export_group("Itens")
@export var seed_item := ""          # gerado automaticamente se vazio: "seed_<id>"
@export var seed_name := ""
@export var seed_price := 20
@export var produce_item := ""       # item colhido (pode ser um item já existente)
@export var produce_name := ""
@export var sell_price := 40
@export var produce_icon_hd := -1    # índice em items_hd.png (se o item for criado aqui)

@export_group("Crescimento")
## dias para avançar de cada estágio (quadros do sprite = tamanho + 1)
@export var stage_days := PackedInt32Array([1, 1, 1])
@export var seasons := PackedStringArray(["spring"])
## o que acontece quando a estação acaba: die | dormant | survive
@export var season_end := "die"
@export var biomes := PackedStringArray(["plains"])

@export_group("Água e temperatura")
## umidade mínima para crescer (0..1). Abaixo disso o crescimento pausa.
@export_range(0.0, 1.0) var water_min := 0.45
## umidade acima da qual a planta "encharca" e cresce mais devagar
@export_range(0.0, 1.0) var water_max := 1.0
## dias seguidos sem água que a planta aguenta antes de morrer
@export var drought_tolerance := 4
@export var temp_min := 5
@export var temp_max := 32

@export_group("Colheita")
## single = colhe uma vez | regrow = fica no canteiro e produz de novo
@export var harvest_type := "single"
@export var regrow_days := 3
@export var max_harvests := 0        # 0 = ilimitado (enquanto saudável e na estação)
@export var yield_min := 1
@export var yield_max := 1
@export_range(0.0, 1.0) var extra_seed_chance := 0.0

@export_group("Outros")
@export var rarity := 0              # 0 comum, 1 incomum, 2 raro
@export var unlock := ""             # requisito de desbloqueio (futuro)

@export_group("Visual")
@export var sprite_height := 32      # 32 ou 48 (plantas altas)


func frames() -> int:
	return stage_days.size() + 1


func total_days() -> int:
	var t := 0
	for d in stage_days:
		t += d
	return t


func grows_in(season: String) -> bool:
	return seasons.has(season)


func seed_id() -> String:
	return seed_item if seed_item != "" else "seed_" + id


func produce_id() -> String:
	return produce_item if produce_item != "" else id
