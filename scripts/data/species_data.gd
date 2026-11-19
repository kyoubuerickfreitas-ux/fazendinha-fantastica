class_name SpeciesData
extends Resource
## Ficha de uma espécie de animal (data/animals/<id>.tres).
## Para criar uma espécie nova: copie uma ficha e ponha a folha de sprites
## em assets/sprites/animals/<id>.png (4x4 quadros de 64x64).

@export var id := ""
@export var name := ""
@export_multiline var description := ""
## grupo de capacidade: big (celeiro) | bird (galinheiro)
@export var group := "big"
## construção onde dorme: barn | coop
@export var housing := "barn"
@export var price := 800

@export_group("Crescimento")
@export var baby_days := 4
@export var young_days := 4
@export var baby_scale := 0.62
@export var young_scale := 0.82

@export_group("Comida")
@export var food := "hay"
## come o capim do pasto durante o dia (não precisa do comedouro nesse dia)
@export var grazes := true
@export var favorite_foods := PackedStringArray()

@export_group("Produção")
## hand = coletar com a mão | shears = tosquiar (precisa de tesoura) | forage = fareja e deixa no chão
@export var produce_mode := "hand"
@export var product := "milk"
@export var product_interval := 1     # dias entre produtos (lã: dias para crescer)
@export var product_min := 1
@export var product_max := 1
## farejar: itens possíveis e pesos; chance base por dia
@export var forage_items := PackedStringArray()
@export var forage_weights := PackedFloat32Array()
@export_range(0.0, 1.0) var forage_chance := 0.35

@export_group("Reprodução")
## mamíferos: chance por noite de ficar prenhe (no alojamento, feliz e com vaga) e dias de gestação
@export_range(0.0, 1.0) var breed_chance := 0.06
@export var gestation_days := 6
## aves: chance de o ovo vir fértil (vai para a incubadora)
@export_range(0.0, 1.0) var fertile_egg_chance := 0.0
@export var fertile_item := ""

@export_group("Conforto")
@export var temp_min := 0
@export var temp_max := 32

@export_group("Movimento")
@export var speed := 22.0
@export var anim_fps := 5.0
@export var body := Vector2(26, 10)

@export_group("Personalidade")
@export var personalities := PackedStringArray(["curioso", "calmo", "brincalhão", "preguiçoso", "sociável"])
@export var default_names := PackedStringArray()


func sprite_path() -> String:
	return "res://assets/sprites/animals/%s.png" % id
