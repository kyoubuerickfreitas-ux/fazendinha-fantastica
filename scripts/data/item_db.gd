class_name ItemDB
## Banco de dados de itens e plantações.
## Para adicionar um item novo: crie a entrada aqui e desenhe o ícone em icons.png.

const ICONS := preload("res://assets/sprites/icons.png")
const ICON_SIZE := 16
const ICON_COLUMNS := 16
## Ícones em alta resolução (32x32), gerados por tools/import_icons.py.
## Itens com "hd" usam este atlas no lugar de icons.png.
const ICONS_HD := preload("res://assets/sprites/items_hd.png")
const HD_SIZE := 32
const HD_COLUMNS := 16

## Ícones de interface (índices em icons.png)
const UI_ICON := {
	"coin": 16, "sun": 17, "rain": 18, "heart": 19, "bolt": 20,
	"backpack": 21, "hand": 22, "bubble": 23, "moon": 24, "cloud": 25,
	"heavy_rain": 30, "storm": 31, "snow": 32, "fog": 33, "wind": 34, "heat": 35, "cold": 36, "book": 37,
}

## type: tool | seed | crop | resource | product | fish | bait | placeable
const ITEMS := {
	"watering_can": {"name": "Regador", "icon": 0, "hd": 0, "type": "tool", "desc": "Rega a terra arada. Encha na água do lago."},
	"hoe": {"name": "Enxada", "icon": 1, "hd": 1, "type": "tool", "desc": "Ara a grama para plantar."},
	"axe": {"name": "Machado", "icon": 2, "hd": 2, "type": "tool", "desc": "Corta árvores e tocos."},
	"pickaxe": {"name": "Picareta", "icon": 3, "hd": 3, "type": "tool", "desc": "Quebra pedras e desfaz a terra arada."},
	"scythe": {"name": "Foice", "icon": 4, "hd": 4, "type": "tool", "desc": "Corta mato e colhe plantações."},

	"wood": {"name": "Madeira", "icon": 5, "type": "resource", "sell": 2, "desc": "Material de construção."},
	"stone": {"name": "Pedra", "icon": 6, "type": "resource", "sell": 2, "desc": "Material de construção."},
	"fiber": {"name": "Fibra", "icon": 7, "hd": 5, "type": "resource", "sell": 1, "desc": "Usada em artesanato."},

	"carrot": {"name": "Cenoura-Lunar", "icon": 8, "hd": 31, "type": "crop", "sell": 45, "desc": "Crocante e levemente brilhante."},
	"tomato": {"name": "Tomate-Rubi", "icon": 9, "hd": 34, "type": "crop", "sell": 70, "desc": "Vermelho como uma pedra preciosa."},
	"kale": {"name": "Couve-Musgo", "icon": 10, "type": "crop", "sell": 35, "desc": "Folhas macias como musgo."},
	"starflower": {"name": "Flor-Estrela", "icon": 11, "type": "crop", "sell": 110, "desc": "Brilha suavemente à noite."},

	"milk": {"name": "Leite de Moombor", "icon": 26, "hd": 37, "type": "product", "sell": 60, "desc": "Cremoso, com cheirinho de capim."},
	"egg": {"name": "Ovo de Piuplum", "icon": 27, "hd": 39, "type": "product", "sell": 30, "desc": "Cada ovo tem uma pintinha diferente."},
	"wool": {"name": "Lã de Fofrança", "icon": 28, "hd": 38, "type": "product", "sell": 80, "desc": "Macia como nuvem, com cheiro de flor."},
	"truffle": {"name": "Trufa da Floresta", "icon": 29, "hd": 40, "type": "product", "sell": 120, "desc": "Farejada pelo Catarrápio."},

	"seed_carrot": {"name": "Sementes de Cenoura-Lunar", "icon": 12, "hd": 10, "type": "seed", "crop": "carrot", "buy": 20, "desc": "Cresce em 3 dias."},
	"seed_tomato": {"name": "Sementes de Tomate-Rubi", "icon": 13, "hd": 11, "type": "seed", "crop": "tomato", "buy": 30, "desc": "Cresce em 4 dias."},
	"seed_kale": {"name": "Sementes de Couve-Musgo", "icon": 14, "hd": 9, "type": "seed", "crop": "kale", "buy": 15, "desc": "Cresce em 2 dias."},
	"seed_starflower": {"name": "Sementes de Flor-Estrela", "icon": 15, "hd": 12, "type": "seed", "crop": "starflower", "buy": 45, "desc": "Cresce em 5 dias."},

	# produtos fabricados
	"cheese": {"name": "Queijo de Moombor", "tex": "res://assets/sprites/craft/icon_cheese.png", "type": "product", "sell": 170, "desc": "Feito na prensa com leite de Moombor."},
	"cloth": {"name": "Tecido de Fofrança", "tex": "res://assets/sprites/craft/icon_cloth.png", "type": "product", "sell": 220, "desc": "Tecido macio feito no tear."},
	"jam": {"name": "Geleia Caseira", "tex": "res://assets/sprites/craft/icon_jam.png", "type": "product", "sell": 140, "desc": "Feita no pote de conserva com qualquer colheita."},
	"hay": {"name": "Feno", "tex": "res://assets/sprites/craft/icon_hay.png", "type": "resource", "sell": 1, "desc": "Coloque no comedouro do pasto. Cada animal come 1 por dia."},

	# objetos que dá para construir (type "placeable"; ver PLACEABLES)
	"workbench": {"name": "Bancada de Trabalho", "tex": "res://assets/sprites/craft/icon_workbench.png", "type": "placeable", "desc": "Onde se fabrica tudo."},
	"feeder": {"name": "Comedouro", "tex": "res://assets/sprites/craft/icon_feeder.png", "type": "placeable", "desc": "Ponha feno aqui para alimentar os animais."},
	"cheese_press": {"name": "Prensa de Queijo", "tex": "res://assets/sprites/craft/icon_cheese_press.png", "type": "placeable", "desc": "Leite vira queijo em 1 dia."},
	"loom": {"name": "Tear", "tex": "res://assets/sprites/craft/icon_loom.png", "type": "placeable", "desc": "Lã vira tecido em 1 dia."},
	"preserves_jar": {"name": "Pote de Conserva", "tex": "res://assets/sprites/craft/icon_preserves_jar.png", "type": "placeable", "desc": "Qualquer colheita vira geleia em 2 dias."},
	"fence": {"name": "Cerca de Madeira", "tex": "res://assets/sprites/craft/icon_fence.png", "type": "placeable", "desc": "Decoração. Bloqueia a passagem."},
	"stone_path": {"name": "Caminho de Pedra", "tex": "res://assets/sprites/craft/icon_stone_path.png", "type": "placeable", "desc": "Chão decorativo."},
	"scarecrow": {"name": "Espantalho", "tex": "res://assets/sprites/craft/icon_scarecrow.png", "type": "placeable", "desc": "Decoração com cara de amigo."},
	"fertile_egg": {"name": "Ovo Fértil de Piuplum", "tex": "res://assets/sprites/craft/icon_fertile_egg.png", "type": "product", "sell": 45, "desc": "Coloque na incubadora para chocar um filhote."},
	"incubator": {"name": "Incubadora", "tex": "res://assets/sprites/craft/icon_incubator.png", "type": "placeable", "desc": "Choca ovos férteis em 4 dias (precisa de vaga no galinheiro)."},
	"fert_basic": {"name": "Adubo Básico", "tex": "res://assets/sprites/craft/icon_fert_basic.png", "type": "fertilizer", "sell": 5, "desc": "Use num canteiro: +fertilidade e um pouco mais de qualidade. Dura até a colheita."},
	"fert_growth": {"name": "Adubo de Crescimento", "tex": "res://assets/sprites/craft/icon_fert_growth.png", "type": "fertilizer", "sell": 15, "desc": "Use num canteiro: a planta cresce 25% mais rápido."},
	"fert_water": {"name": "Adubo Retém-Água", "tex": "res://assets/sprites/craft/icon_fert_water.png", "type": "fertilizer", "sell": 10, "desc": "Use num canteiro: a terra seca pela metade durante a noite."},
	"fert_quality": {"name": "Adubo de Qualidade", "tex": "res://assets/sprites/craft/icon_fert_quality.png", "type": "fertilizer", "sell": 40, "desc": "Use num canteiro: muito mais chance de colheita prata, ouro e lendária."},
	"butter": {"name": "Manteiga", "tex": "res://assets/sprites/craft/icon_butter.png", "type": "product", "sell": 130, "desc": "Feita na batedeira com leite."},
	"yarn": {"name": "Novelo de Lã", "tex": "res://assets/sprites/craft/icon_yarn.png", "type": "product", "sell": 140, "desc": "Fiado na roca com lã de Fofrança."},
	"truffle_oil": {"name": "Óleo de Trufa", "tex": "res://assets/sprites/craft/icon_truffle_oil.png", "type": "product", "sell": 320, "desc": "Feito na prensa de óleo com trufas."},
	"pickles": {"name": "Conserva", "tex": "res://assets/sprites/craft/icon_pickles.png", "type": "product", "sell": 120, "desc": "Legumes, cogumelos ou flores no pote de conserva."},
	"butter_churn": {"name": "Batedeira", "tex": "res://assets/sprites/craft/icon_butter_churn.png", "type": "placeable", "desc": "Leite vira manteiga em 1 dia."},
	"spinning_wheel": {"name": "Roca", "tex": "res://assets/sprites/craft/icon_spinning_wheel.png", "type": "placeable", "desc": "Lã vira novelo em 1 dia."},
	"oil_press": {"name": "Prensa de Óleo", "tex": "res://assets/sprites/craft/icon_oil_press.png", "type": "placeable", "desc": "Trufa vira óleo de trufa em 2 dias."},
	"sprinkler": {"name": "Aspersor", "tex": "res://assets/sprites/craft/icon_sprinkler.png", "type": "placeable", "desc": "Rega toda manhã os 4 canteiros ao lado (cima, baixo, esquerda, direita)."},
	"sprinkler_q": {"name": "Aspersor de Cobre", "tex": "res://assets/sprites/craft/icon_sprinkler_q.png", "type": "placeable", "desc": "Rega toda manhã os 8 canteiros em volta."},
	"sprinkler_c": {"name": "Aspersor de Cristal", "tex": "res://assets/sprites/craft/icon_sprinkler_c.png", "type": "placeable", "desc": "Rega toda manhã um quadrado 5×5 (24 canteiros)."},
	"silo": {"name": "Silo", "tex": "res://assets/sprites/craft/icon_silo.png", "type": "placeable", "desc": "Guarda até 240 feno. O capim cortado com a foice vai direto para cá."},
	"barn": {"name": "Celeiro", "tex": "res://assets/sprites/craft/icon_barn.png", "type": "placeable", "desc": "Abriga +4 animais grandes (Moombor, Fofrança, Catarrápio)."},
	"trophy_moss_king": {"name": "Troféu do Rei-Musgo", "tex": "res://assets/sprites/craft/icon_trophy_moss_king.png", "type": "placeable", "desc": "Prova de que você pescou o Rei-Musgo. Decoração."},
	"trophy_silver_moon": {"name": "Troféu da Lua-de-Prata", "tex": "res://assets/sprites/craft/icon_trophy_silver_moon.png", "type": "placeable", "desc": "Prova de que você pescou a Lua-de-Prata. Decoração."},
	"trophy_winter_heart": {"name": "Troféu do Coração-de-Inverno", "tex": "res://assets/sprites/craft/icon_trophy_winter_heart.png", "type": "placeable", "desc": "Prova de que você pescou o Coração-de-Inverno. Decoração."},
	"trophy_guardian": {"name": "Troféu do Guardião do Lago", "tex": "res://assets/sprites/craft/icon_trophy_guardian.png", "type": "placeable", "desc": "Prova de que você pescou o Guardião do Lago. Decoração."},
	"trophy_dream": {"name": "Troféu do Peixe-Sonho", "tex": "res://assets/sprites/craft/icon_trophy_dream.png", "type": "placeable", "desc": "Ninguém vai acreditar. Mas o troféu está aí. Decoração."},
	"trophy_tournament": {"name": "Taça do Lago", "tex": "res://assets/sprites/craft/icon_trophy_tournament.png", "type": "placeable", "desc": "Campeão do Torneio do Lago! Decoração."},
	"aquarium_small": {"name": "Aquário Pequeno", "tex": "res://assets/sprites/craft/icon_aquarium_small.png", "type": "placeable", "desc": "Segure um peixe e toque para colocar (cabe 1). Toque de mão vazia para tirar."},
	"aquarium_large": {"name": "Aquário Grande", "tex": "res://assets/sprites/craft/icon_aquarium_large.png", "type": "placeable", "desc": "Cabem 3 peixes. Segure um peixe e toque para colocar."},
	"fish_pond": {"name": "Laguinho Ornamental", "tex": "res://assets/sprites/craft/icon_fish_pond.png", "type": "placeable", "desc": "Cabem 5 peixes, nadando ao ar livre."},
	"smoker": {"name": "Defumador", "tex": "res://assets/sprites/craft/icon_smoker.png", "type": "placeable", "desc": "Qualquer peixe vira peixe defumado (vale o dobro) em 1 dia."},
	"fert_fish": {"name": "Adubo de Peixe", "tex": "res://assets/sprites/craft/icon_fert_fish.png", "type": "fertilizer", "sell": 12, "desc": "Use num canteiro: muita fertilidade e cresce 10% mais rápido."},
	"stove": {"name": "Fogão", "tex": "res://assets/sprites/craft/icon_stove.png", "type": "placeable", "desc": "Toque para cozinhar as receitas que você sabe."},
	"coop": {"name": "Galinheiro", "tex": "res://assets/sprites/craft/icon_coop.png", "type": "placeable", "desc": "Abriga +6 Piuplum."},

	"brush": {"name": "Escova", "tex": "res://assets/sprites/craft/icon_brush.png", "type": "tool", "buy": 120, "desc": "Segure e toque num animal para escová-lo (1x por dia). Deixa limpo e feliz."},
	"herbal_tea": {"name": "Chá de Ervas", "tex": "res://assets/sprites/craft/icon_herbal_tea.png", "type": "resource", "sell": 20, "desc": "Segure e toque num animal doente ou indisposto para curá-lo."},
	"shears": {"name": "Tesoura de Tosquia", "tex": "res://assets/sprites/craft/icon_shears.png", "type": "tool", "buy": 150, "desc": "Com ela na mochila, toque na Fofrança de lã crescida para tosquiar."},
	"fishing_rod": {"name": "Vara de Pesca", "icon": 0, "hd": 7, "type": "tool", "buy": 100, "desc": "Use na água do lago. Coloque uma isca para pescar melhor."},

	"fish_orange": {"name": "Peixinho-Brasa", "icon": 0, "hd": 41, "type": "fish", "sell": 25, "desc": "Listrado como brasa de fogueira."},
	"fish_mackerel": {"name": "Cavala-Azul", "icon": 0, "hd": 42, "type": "fish", "sell": 30, "desc": "Nada em cardumes perto da margem."},
	"fish_goldfish": {"name": "Kinguio-Véu", "icon": 0, "hd": 43, "type": "fish", "sell": 60, "desc": "A cauda parece um véu de seda."},
	"fish_perch": {"name": "Perca-Musgo", "icon": 0, "hd": 44, "type": "fish", "sell": 28, "desc": "Cresce entre as algas do fundo."},
	"fish_catfish": {"name": "Bagre-Barbudo", "icon": 0, "hd": 45, "type": "fish", "sell": 70, "desc": "Sai da toca nas noites de chuva."},
	"fish_silver": {"name": "Prateadinho", "icon": 0, "hd": 46, "type": "fish", "sell": 20, "desc": "O mais comum do lago."},
	"fish_puffer": {"name": "Baiacu-Bolota", "icon": 0, "hd": 47, "type": "fish", "sell": 65, "desc": "Incha quando é pescado. Não aperte!"},
	"fish_angel": {"name": "Acará-Listrado", "icon": 0, "hd": 48, "type": "fish", "sell": 75, "desc": "Elegante e desconfiado."},
	"fish_snapper": {"name": "Pargo-Rubi", "icon": 0, "hd": 49, "type": "fish", "sell": 80, "desc": "Vermelho como o Tomate-Rubi."},
	"fish_eel": {"name": "Enguia-Lunar", "icon": 0, "hd": 50, "type": "fish", "sell": 150, "desc": "Brilha de leve sob a lua."},
	"fish_shark": {"name": "Tubarãozinho-do-Lago", "icon": 0, "hd": 51, "type": "fish", "sell": 180, "desc": "Pequeno, mas cheio de dentes."},
	"fish_clown": {"name": "Peixe-Palhaço", "icon": 0, "hd": 52, "type": "fish", "sell": 70, "desc": "Sempre parece estar sorrindo."},
	"fish_sword": {"name": "Espadarte-Junco", "icon": 0, "hd": 53, "type": "fish", "sell": 160, "desc": "Rápido como uma flecha."},
	"fish_axolotl": {"name": "Axolote-Rosado", "icon": 0, "hd": 54, "type": "fish", "sell": 200, "desc": "Adora dias de chuva."},
	"fish_yellow": {"name": "Perca-Dourada", "icon": 0, "hd": 55, "type": "fish", "sell": 35, "desc": "Fica dourada ao sol da tarde."},
	"fish_betta": {"name": "Betta-Celeste", "icon": 0, "hd": 56, "type": "fish", "sell": 90, "desc": "Briguento, mas lindo."},
	"fish_angler": {"name": "Peixe-Lanterna", "icon": 0, "hd": 57, "type": "fish", "sell": 220, "desc": "Usa a luz para atrair outros peixes."},
	"fish_ghost": {"name": "Peixe-Fantasma", "icon": 0, "hd": 58, "type": "fish", "sell": 400, "desc": "Dizem que é a alma do lago."},
	"fish_lion": {"name": "Peixe-Leão", "icon": 0, "hd": 59, "type": "fish", "sell": 170, "desc": "Cuidado com os espinhos."},
	"fish_sunfish": {"name": "Peixe-Lua", "icon": 0, "hd": 60, "type": "fish", "sell": 450, "desc": "Raríssimo. Aparece em dias calmos."},

	"bait_worm": {"name": "Minhoca", "icon": 0, "hd": 61, "type": "bait", "buy": 5, "desc": "Isca básica. Às vezes aparece ao arar a terra."},
	"bait_corn": {"name": "Bolinha de Milho", "icon": 0, "hd": 62, "type": "bait", "buy": 6, "desc": "Os peixes mordem bem rápido."},
	"bait_cricket": {"name": "Grilo Saltador", "icon": 0, "hd": 63, "type": "bait", "buy": 12, "desc": "Atrai peixes incomuns."},
	"bait_mushroom": {"name": "Cogumelo Brilhante", "icon": 0, "hd": 64, "type": "bait", "buy": 25, "desc": "Brilha no escuro. Ótima à noite e para peixes raros."},
	"bait_treasure": {"name": "Isca Reluzente", "tex": "res://assets/sprites/fishing/bait_treasure.png", "type": "bait", "buy": 80, "desc": "Brilha como moeda. Fisga muito mais tesouros (e menos peixes)."},
	"bait_fly": {"name": "Mosca de Fibra", "icon": 0, "hd": 65, "type": "bait", "buy": 40, "desc": "Isca artesanal. A melhor para peixes raros e lendários."},
}

## Objetos construíveis. size = células (largura, altura); a célula mirada é a de baixo, no meio.
## solid = bloqueia a passagem; floor = desenhado no chão; machine = máquina de produção.
const PLACEABLES := {
	"workbench": {"size": Vector2i(2, 1), "solid": true, "pad": 4},
	"feeder": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"cheese_press": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"loom": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"preserves_jar": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"fence": {"size": Vector2i(1, 1), "solid": true, "pad": 1},
	"stone_path": {"size": Vector2i(1, 1), "solid": false, "floor": true, "pad": 0},
	"scarecrow": {"size": Vector2i(1, 1), "solid": true, "pad": 3},
	"silo": {"size": Vector2i(2, 2), "solid": true, "pad": 2, "fixed": true},
	"incubator": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"butter_churn": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"spinning_wheel": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"oil_press": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"sprinkler": {"size": Vector2i(1, 1), "solid": true, "pad": 4, "sprinkler": 1},
	"sprinkler_q": {"size": Vector2i(1, 1), "solid": true, "pad": 4, "sprinkler": 2},
	"sprinkler_c": {"size": Vector2i(1, 1), "solid": true, "pad": 4, "sprinkler": 3},
	"trophy_moss_king": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"trophy_silver_moon": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"trophy_winter_heart": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"trophy_guardian": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"trophy_dream": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"trophy_tournament": {"size": Vector2i(1, 1), "solid": true, "pad": 2},
	"aquarium_small": {"size": Vector2i(1, 1), "solid": true, "pad": 2, "aquarium": 1, "tank": Rect2(-13, -28, 25, 15)},
	"aquarium_large": {"size": Vector2i(2, 1), "solid": true, "pad": 2, "aquarium": 3, "tank": Rect2(-29, -32, 57, 19)},
	"fish_pond": {"size": Vector2i(2, 2), "solid": true, "pad": 2, "aquarium": 5, "tank": Rect2(-18, -34, 35, 22)},
	"smoker": {"size": Vector2i(1, 1), "solid": true, "pad": 3, "machine": true},
	"stove": {"size": Vector2i(1, 1), "solid": true, "pad": 3},
	"barn": {"size": Vector2i(4, 3), "solid": true, "pad": 2, "fixed": true},
	"coop": {"size": Vector2i(3, 2), "solid": true, "pad": 2, "fixed": true},
}

## Máquinas: entrada (item ou tipo "crop") -> saída, em dias.
const MACHINES := {
	"cheese_press": {"input": "milk", "output": "cheese", "days": 1},
	"loom": {"input": "wool", "output": "cloth", "days": 1},
	"preserves_jar": {"input_type": "crop", "output": "jam", "days": 2,
		"rules": [{"category": "fruit", "output": "jam"}, {"category": "*", "output": "pickles"}]},
	"butter_churn": {"input": "milk", "output": "butter", "days": 1},
	"spinning_wheel": {"input": "wool", "output": "yarn", "days": 1},
	"oil_press": {"input": "truffle", "output": "truffle_oil", "days": 2},
	"incubator": {"input": "fertile_egg", "output": "hatch:piuplum", "days": 4},
	"smoker": {"input_type": "fish", "prefix": "smoked_", "days": 1},
}

## Melhorias de ferramenta (na bancada): custo para o nível 2 e 3.
## Nível 2: age em 3 canteiros em linha; nível 3: área 3x3. Regador: +20 de água por nível.
const TOOL_UPGRADES := {
	"watering_can": [{"stone": 25, "money": 800}, {"stone": 60, "truffle": 1, "money": 2500}],
	"hoe": [{"stone": 25, "money": 600}, {"stone": 60, "money": 2000}],
	"fishing_rod": [{"wood": 20, "fiber": 10, "money": 700}, {"stone": 40, "pearl": 1, "money": 2200}],
}

## Adubos: efeitos no canteiro (duram até a colheita).
const FERTILIZERS := {
	"fert_basic": {"fert": 0.15, "quality": 0.08},
	"fert_growth": {"speed": 1.25},
	"fert_water": {"retention": 0.5},
	"fert_quality": {"quality": 0.2, "fert": 0.05},
	"fert_fish": {"fert": 0.25, "speed": 1.1},
}

## Receitas da bancada. cost: item -> quantidade ("money" = moedas).
const RECIPES := [
	{"result": "hay", "qty": 3, "cost": {"fiber": 2}},
	{"result": "feeder", "qty": 1, "cost": {"wood": 10}},
	{"result": "fert_basic", "qty": 4, "cost": {"fiber": 3, "hay": 2}},
	{"result": "fert_water", "qty": 3, "cost": {"stone": 3, "fiber": 2}},
	{"result": "fert_growth", "qty": 2, "cost": {"fiber": 4, "kale": 1}},
	{"result": "fert_quality", "qty": 2, "cost": {"truffle": 1, "fiber": 4, "stone": 2}},
	{"result": "herbal_tea", "qty": 2, "cost": {"fiber": 3, "mushroom": 1}},
	{"result": "fence", "qty": 4, "cost": {"wood": 5}},
	{"result": "stone_path", "qty": 4, "cost": {"stone": 3}},
	{"result": "bait_fly", "qty": 2, "cost": {"fiber": 4, "wood": 1}},
	{"result": "stove", "qty": 1, "cost": {"stone": 15, "wood": 10}},
	{"result": "fert_fish", "qty": 3, "cost": {"any_fish": 1, "fiber": 2}},
	{"result": "smoker", "qty": 1, "cost": {"wood": 20, "stone": 15}},
	{"result": "aquarium_small", "qty": 1, "cost": {"wood": 8, "stone": 4}},
	{"result": "aquarium_large", "qty": 1, "cost": {"wood": 20, "stone": 12, "relic_shell": 1}},
	{"result": "fish_pond", "qty": 1, "cost": {"stone": 40, "pearl": 1}},
	{"result": "bait_treasure", "qty": 3, "cost": {"old_coin": 1, "fiber": 3}},
	{"result": "fiber", "qty": 4, "cost": {"old_boot": 1}},
	{"result": "scarecrow", "qty": 1, "cost": {"wood": 15, "fiber": 10}},
	{"result": "cheese_press", "qty": 1, "cost": {"wood": 20, "stone": 10}},
	{"result": "loom", "qty": 1, "cost": {"wood": 25, "fiber": 15}},
	{"result": "preserves_jar", "qty": 1, "cost": {"wood": 15, "stone": 10}},
	{"result": "workbench", "qty": 1, "cost": {"wood": 30}},
	{"result": "incubator", "qty": 1, "cost": {"wood": 25, "stone": 15, "money": 400}},
	{"result": "butter_churn", "qty": 1, "cost": {"wood": 20, "stone": 5}},
	{"result": "spinning_wheel", "qty": 1, "cost": {"wood": 30, "fiber": 10}},
	{"result": "oil_press", "qty": 1, "cost": {"wood": 25, "stone": 25, "money": 600}},
	{"result": "sprinkler", "qty": 1, "cost": {"stone": 10, "wood": 5}},
	{"result": "sprinkler_q", "qty": 1, "cost": {"stone": 25, "wood": 10, "money": 300}},
	{"result": "sprinkler_c", "qty": 1, "cost": {"stone": 50, "truffle": 1, "money": 1500}},
	{"result": "silo", "qty": 1, "cost": {"wood": 50, "stone": 30, "money": 300}},
	{"result": "coop", "qty": 1, "cost": {"wood": 80, "stone": 40, "money": 500}},
	{"result": "barn", "qty": 1, "cost": {"wood": 120, "stone": 60, "money": 1000}},
]

## Espaço para animais: o pasto comporta BASE; cada construção soma a sua capacidade.
const BASE_CAPACITY := {"big": 3, "bird": 2}
const BUILDING_CAPACITY := {"barn": 4, "coop": 6}   # nível 1 (use building_capacity())

## Níveis dos alojamentos: capacidade e custo para chegar a cada nível.
## Nível 2: comedouro automático (puxa feno do silo). Nível 3: aquecedor + coletor automático.
const BUILDING_LEVELS := {
	"barn": [
		{"capacity": 4},
		{"capacity": 8, "cost": {"wood": 150, "stone": 80, "money": 2000}},
		{"capacity": 12, "cost": {"wood": 200, "stone": 120, "money": 5000}},
	],
	"coop": [
		{"capacity": 6},
		{"capacity": 10, "cost": {"wood": 100, "stone": 60, "money": 1200}},
		{"capacity": 14, "cost": {"wood": 150, "stone": 90, "money": 3000}},
	],
}


static func building_capacity(kind: String, level: int) -> int:
	return int(BUILDING_LEVELS[kind][clampi(level, 1, 3) - 1]["capacity"])

const SHOP_SEEDS := ["seed_kale", "seed_carrot", "seed_tomato", "seed_starflower"]
## Iscas: speed = rapidez da fisgada; bonus = multiplicador de chance por raridade [comum, incomum, raro, lendário]
const BAITS := {
	"": {"speed": 0.6, "bonus": [1.0, 0.5, 0.2, 0.0]},   # sem isca
	"bait_worm": {"speed": 1.0, "bonus": [1.0, 1.2, 0.8, 0.3]},
	"bait_corn": {"speed": 1.7, "bonus": [1.4, 0.9, 0.5, 0.2]},
	"bait_cricket": {"speed": 1.1, "bonus": [0.8, 2.0, 1.1, 0.5]},
	"bait_mushroom": {"speed": 1.0, "bonus": [0.7, 1.0, 1.8, 1.2], "night": 2.0},
	"bait_fly": {"speed": 0.9, "bonus": [0.5, 1.2, 2.2, 2.5]},
	"bait_treasure": {"speed": 1.0, "bonus": [1.0, 1.0, 1.0, 1.0], "treasure": 0.3},
}


const SHOP_ITEMS := ["seed_kale", "seed_carrot", "seed_tomato", "seed_starflower",
	"fishing_rod", "brush", "shears", "bait_worm", "bait_corn", "bait_cricket", "bait_mushroom", "bait_fly", "bait_treasure"]

const MAX_STACK := 99


## Itens criados em tempo de execução (sementes e colheitas vindas de data/crops).
static var _extra := {}


static func register(id: String, data: Dictionary) -> void:
	_extra[id] = data


## Produto da máquina para esta entrada (regras por categoria, ex.: fruta -> geleia).
static func machine_output(machine: String, item_id: String) -> String:
	var m: Dictionary = MACHINES[machine]
	if m.has("prefix"):
		return m["prefix"] + item_id
	for rule in m.get("rules", []):
		var cat: String = rule.get("category", "*")
		if cat == "*" or CropDB.category_of(item_id) == cat:
			return rule["output"]
	return m["output"]


## "any_fish" no custo = qualquer peixe comum (gasta os mais baratos primeiro; nunca lendários)
static func can_afford(cost: Dictionary) -> bool:
	for k in cost:
		if k == "any_fish":
			if _cheap_fish_slots().size() < int(cost[k]):
				return false
		elif k == "money":
			if Game.money < int(cost[k]):
				return false
		elif Game.count_item(k) < int(cost[k]):
			return false
	return true


## Paga um custo (moedas e itens). Use depois de can_afford.
static func pay(cost: Dictionary) -> void:
	for k in cost:
		if k == "money":
			Game.add_money(-int(cost[k]))
		elif k == "any_fish":
			for i in int(cost[k]):
				var slots := _cheap_fish_slots()
				if not slots.is_empty():
					Game.remove_from_slot(slots[0], 1)
		else:
			Game.remove_item(k, int(cost[k]))


## Índices da mochila com peixes não lendários, do mais barato ao mais caro (um índice por unidade).
static func _cheap_fish_slots() -> Array:
	var out := []
	for i in Game.INV_SIZE:
		var s = Game.inventory[i]
		if s != null and get_item(s["id"]).get("type", "") == "fish":
			var f := FishDB.get_fish(s["id"])
			if f == null or not f.is_legendary():
				for n in int(s["qty"]):
					out.append(i)
	out.sort_custom(func(a, b): return sell_price(Game.inventory[a]["id"]) < sell_price(Game.inventory[b]["id"]))
	return out


static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in cost:
		if k == "any_fish":
			parts.append("%d peixe(s) qualquer" % int(cost[k]))
		elif k == "money":
			parts.append("%d moedas" % int(cost[k]))
		else:
			parts.append("%d %s" % [int(cost[k]), item_name(k)])
	return ", ".join(parts)


static func has(id: String) -> bool:
	_ensure_dynamic()
	return _extra.has(id) or ITEMS.has(id)


## Registra os itens que vêm de dados (plantas, peixes lendários, tesouros).
static func _ensure_dynamic() -> void:
	CropDB.ensure_loaded()
	FishDB.ensure_loaded()
	TreasureDB.ensure_loaded()
	Cooking.ensure_loaded()


static func get_item(id: String) -> Dictionary:
	if _extra.has(id):
		return _extra[id]
	if ITEMS.has(id):
		return ITEMS[id]
	_ensure_dynamic()
	return _extra.get(id, {})


static func item_name(id: String) -> String:
	return get_item(id).get("name", id)


static func is_stackable(id: String) -> bool:
	return get_item(id).get("type", "") != "tool"


const QUALITY_MULT := [1.0, 1.25, 1.5, 2.0]
const QUALITY_COLORS := [Color(0, 0, 0, 0), Color("c9d1d9"), Color("f2c14e"), Color("c58cf2")]


static func sell_price(id: String, q: int = 0) -> int:
	return int(round(int(get_item(id).get("sell", 0)) * QUALITY_MULT[clampi(q, 0, 3)]))


static func icon_index_texture(index: int) -> AtlasTexture:
	var t := AtlasTexture.new()
	t.atlas = ICONS
	t.region = Rect2(
		(index % ICON_COLUMNS) * ICON_SIZE,
		(index / ICON_COLUMNS) * ICON_SIZE,
		ICON_SIZE, ICON_SIZE)
	return t


static var _tex_cache := {}


static func icon(id: String) -> Texture2D:
	var item := get_item(id)
	if item.has("tex"):
		var path: String = item["tex"]
		if not _tex_cache.has(path):
			_tex_cache[path] = load(path)
		return _tex_cache[path]
	if item.has("hd"):
		var t := AtlasTexture.new()
		t.atlas = ICONS_HD
		var i := int(item["hd"])
		t.region = Rect2((i % HD_COLUMNS) * HD_SIZE, (i / HD_COLUMNS) * HD_SIZE, HD_SIZE, HD_SIZE)
		return t
	return icon_index_texture(int(item.get("icon", 0)))


static func ui_icon(name: String) -> AtlasTexture:
	return icon_index_texture(int(UI_ICON.get(name, 0)))



