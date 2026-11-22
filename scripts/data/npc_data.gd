class_name NPCData
extends Resource
## Morador do vale (data/npcs/*.tres): quem é, onde fica, aniversário, presentes e falas.

@export var id := ""
@export var name := ""
@export var role := ""
@export_multiline var description := ""
@export_file("*.png") var sheet := ""      # 2 quadros de 64x64 (parado/respirando)
@export var home := Vector2i.ZERO           # célula onde fica durante o dia
@export var wander := 3                     # quantos quadrados anda em volta de casa
@export var scale := 1.0
## loja da cidade que cuida (fish, smith, bakery, market, restaurant, tailor); "" = passeia pela cidade
@export var shop := ""
@export var birthday_season := "spring"
@export var birthday_day := 1
## presentes: item, prato (dish_<receita>) ou grupo (any_fish, any_fruit, any_vegetable, any_dish)
@export var loves := PackedStringArray()
@export var likes := PackedStringArray()
@export var dislikes := PackedStringArray()
## falas por amizade ("0", "3", "6", "9" corações) e situações ("rain", "birthday")
@export var lines := {}
## recompensas por coração: {"2": {"item", "qty", "line"}}
@export var rewards := {}
