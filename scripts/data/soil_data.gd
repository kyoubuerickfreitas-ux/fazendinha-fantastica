class_name SoilData
extends Resource
## Tipo de solo (data/soils/<id>.tres). Cada canteiro guarda o tipo do lugar onde foi arado.

@export var id := "common"
@export var name := "Comum"
@export_multiline var description := ""
## multiplica a secagem noturna (menor = segura mais água)
@export var evap_mult := 1.0
## fertilidade inicial (multiplica o crescimento e ajuda na qualidade)
@export var fertility := 1.0
