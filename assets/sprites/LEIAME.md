# Sprites (arte provisória)

Todos estes PNGs são **provisórios**, gerados por `tools/generate_placeholder_art.py`.
Para colocar a arte definitiva, substitua o arquivo mantendo **o mesmo nome, tamanho e organização dos quadros**. O código não precisa mudar.

| Arquivo | Tamanho | Organização |
|---|---|---|
| `player.png` | 576×256 | 9×4 quadros de 64×64. Linhas: baixo, esquerda, direita, cima. Coluna 0 = parado, 1–8 = caminhada. Pés em y=58. Gerado por `tools/import_protagonist.py` a partir de `assets/source/protagonist/` (PixelLab). |
| `npc_fungo.png` | 128×64 | 2 quadros de 64×64 (animação parado). |
| `tiles.png` | 256×32 | Peças de 32×32: grama, grama c/ flores, grama c/ trevos, caminho, terra arada, terra molhada, água, água com margem. |
| `crops.png` | 128×128 | Linhas: cenoura, tomate, couve, flor-estrela. Colunas: estágios 0 (semente) a 3 (pronta). 32×32 cada. |
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
`items_hd.png`: ícones 32×32, 16 por linha (ferramentas, fibra, broto, vara de pesca, sacos de sementes e 24 frutas/legumes; a lista completa está em `ORDER`), gerados por `tools/import_icons.py` a partir de `assets/source/icons/`. Itens com o campo `hd` em `item_db.gd` usam este atlas.
