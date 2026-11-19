class_name SeasonData
extends Resource
## Ficha de uma estação (data/seasons/<id>.tres).

@export var id := "spring"
@export var name := "Primavera"
@export var short_name := "Prim."
@export var temp_min := 10
@export var temp_max := 22
## chance de chuva por dia
@export_range(0.0, 1.0) var rain_chance := 0.3
## umidade do ar: reduz a evaporação do solo (0..1)
@export_range(0.0, 1.0) var air_humidity := 0.5
## cor aplicada ao chão/vegetação nessa estação
@export var tint := Color(1, 1, 1)
## quanto o mato cresce de volta por noite
@export var weed_regrow := 3
