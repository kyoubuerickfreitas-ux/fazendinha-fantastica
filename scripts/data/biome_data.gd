class_name BiomeData
extends Resource
## Bioma (data/biomes/<id>.tres). Plantas nativas (CropData.biomes) crescem mais rápido
## no próprio bioma. Novas regiões do mundo usam os mesmos dados.

@export var id := "plains"
@export var name := "Planície"
@export_multiline var description := ""
@export var temp_offset := 0.0
@export var default_soil := "common"
## bônus de crescimento para plantas nativas
@export var native_bonus := 1.15
