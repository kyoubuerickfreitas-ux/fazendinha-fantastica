class_name RecipeData
extends Resource
## Receita da cozinha (data/recipes/*.tres). O prato vira um item "food" que se come
## com o botão de usar: recupera energia/vida e pode dar um bônus por um tempo.

const BUFF_NAMES := {"speed": "Passo Leve", "stamina": "Fôlego", "fishing": "Sorte na Pesca",
	"animal": "Amigo dos Bichos", "all": "Banquete"}
const BUFF_DESC := {"speed": "anda 25% mais rápido", "stamina": "ferramentas gastam 40% menos energia",
	"fishing": "peixes raros e lendários aparecem mais", "animal": "+50% de amizade com os animais",
	"all": "todos os bônus"}

@export var id := ""
@export var name := ""
@export_multiline var description := ""
## item -> quantidade. Também aceita grupos: any_fish, any_fruit, any_vegetable, any_legend
@export var ingredients := {}
@export var energy := 30
@export var health := 0
## "" | speed | stamina | fishing | animal | all
@export var buff := ""
@export var buff_minutes := 0            # minutos do jogo
@export var sell := 100
## como se aprende: start | shop | fishing_level:N | requests:N | cooked:N | title:<id>
@export var unlock := "start"
## loja: estação em que o Fungo vende a receita ("" = o ano todo) e o preço
@export var shop_season := ""
@export var price := 150
@export_file("*.png") var icon := ""


func dish_id() -> String:
	return "dish_" + id
