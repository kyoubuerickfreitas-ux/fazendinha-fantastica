# Sprites (arte provisória)

Todos estes PNGs são **provisórios**, gerados por `tools/generate_placeholder_art.py`.
Para colocar a arte definitiva, substitua o arquivo mantendo **o mesmo nome, tamanho e organização dos quadros**. O código não precisa mudar.

| Arquivo | Tamanho | Organização |
|---|---|---|
| `player.png` | 576×256 | Jogador (corpo base). 9×4 quadros de 64×64: coluna 0 parado, 1–8 caminhada. Linhas: baixo, esquerda, direita, cima. |
| `player_farmer.png` | 576×256 | Fazendeiro de chapéu (skin guardada), mesmo formato. |
| `player_actions.png` | 576×1280 | Animações de ferramenta: 9 quadros por linha; linha = ferramenta×4 + direção (machado, enxada, picareta, regador, foice). Direções vazias usam o golpe simples. |
| `npc_fungo.png` | 128×64 | 2 quadros de 64×64 (animação parado). |
| `tiles.png` | 256×32 | Peças de 32×32: grama, grama c/ flores, grama c/ trevos, caminho, terra arada, terra molhada, água, água com margem. |
| `crops/<id>.png` | 32·N × 32 | Uma tira por planta: um quadro de 32×32 por estágio (dias em `stage_days` + 1). O último quadro é a planta pronta. Provisórios de `tools/generate_crop_art.py`. |
| `stump.png` | 32×32 | Base em y≈28 (só para saves antigos). |
| `house.png` | 128×128 | Casa do jogador. Base em y≈116, porta em x≈44. |
| `shop.png` | 128×128 | Barraca do Fungo (asset do projeto idle). Base em y≈120. |
| `icons.png` | 256×32 | Ícones 16×16, índices definidos em `scripts/data/item_db.gd`. |

Fundo sempre transparente. Paleta: madeira #765137, madeira clara #A8784F, verde #78945B, verde claro #B6C995, creme #E9DDBB, terra #776B52.

Efeitos ficam em `assets/fx/` (quadros de 64×64, 9 linhas de cores). Para trocar qual efeito aparece em cada ação, edite `PRESETS` em `scripts/world/fx.gd`.

## Forest Map Kit
Árvores, pinheiros, pedras, arbustos, mato, cogumelos gigantes e decoração de acampamento ficam em `forest/`. São gerados a partir dos originais em `assets/source/forest_kit/` por `tools/import_forest_kit.py` (redução para 60%, para combinar com o tamanho do personagem). As variantes de cada tipo estão em `DEFS` de `scripts/world/prop.gd`.

## Animais
`animals/<nome>.png`: 256×256, 4×4 quadros de 64×64. Linhas: baixo, esquerda, direita (espelho da esquerda), cima. Colunas: 4 quadros de caminhada. Pés em y=58.
São gerados a partir das folhas originais em `assets/source/animals/` por `tools/import_animals.py`, que encontra cada quadro sozinho, remove fundo xadrez pintado e reduz para a escala do jogo (altura alvo por animal no próprio script).

## Ícones HD
`items_hd.png`: ícones 32×32, 16 por linha (ferramentas, fibra, broto, vara de pesca, sacos de sementes, 24 frutas/legumes, produtos dos animais e 20 peixes; a lista completa está em `ORDER`), gerados por `tools/import_icons.py` a partir de `assets/source/icons/`. Itens com o campo `hd` em `item_db.gd` usam este atlas.

## Fabricação e construção
`craft/`: construções, máquinas, ícones e troféus. Arte definitiva importada de `assets/source/props_sheet.png` por `tools/import_props_sheet.py` (fundo verde, peças na ordem da lista ORDER), junto com as comidas (`food/`) e os itens de pesca (`fishing/`). Se rodar os geradores provisórios (`generate_craft_art.py`, `generate_food_art.py`, `generate_fishing_art.py`), rode o importador depois. Para trocar, substitua o PNG com o mesmo nome (o tamanho pode mudar; a base da imagem fica na base do objeto).

## HUD
`ui/hud/`: retrato, barras, painel de dinheiro/hora/clima, barra rápida, joystick e botões redondos, recortados do
modelo `assets/source/hud_mockup.png` por `tools/import_hud.py` (que também gera `scripts/ui/hud_layout.gd` com a
posição de cada coisa dentro das peças). `ui/weather/`: ícones de clima, sol/lua e temperatura
(`tools/import_weather_icons.py`, de `assets/source/weather_sheet.png`).
