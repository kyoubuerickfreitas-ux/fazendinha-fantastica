class_name WeatherData
extends Resource
## Ficha de um clima (data/weather/<id>.tres). As chances de cada clima ficam em SeasonData.

@export var id := "sunny"
@export var name := "Sol"
@export var icon := "sun"              # ícone de interface (ItemDB.UI_ICON)
## umidade que o clima deixa no solo (0..1); < 0 = não molha
@export var soil_water := -1.0
@export var evap_mult := 1.0           # multiplica a secagem noturna
@export var temp_offset := 0.0         # soma na temperatura do dia
## chance de estragar o progresso de plantas frágeis (tempestade)
@export_range(0.0, 1.0) var crop_damage := 0.0
@export var wet := false               # conta como chuva (peixes de chuva, regar automático)
@export var animals_inside := false    # animais com casa ficam dentro o dia todo
@export var forage_ok := true          # o farejador consegue farejar
@export var particles := ""            # rain | heavy | storm | snow | fog | wind | heat
@export var light := Color(1, 1, 1)    # cor aplicada à luz do dia
@export_multiline var tip := ""        # dica mostrada na previsão
