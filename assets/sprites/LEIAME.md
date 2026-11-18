# Sprites (arte provisória)

Todos estes PNGs são **provisórios**, gerados por `tools/generate_placeholder_art.py`.
Para colocar a arte definitiva, substitua o arquivo mantendo **o mesmo nome, tamanho e organização dos quadros**. O código não precisa mudar.

| Arquivo | Tamanho | Organização |
|---|---|---|
| `player.png` | 256×256 | 4×4 quadros de 64×64. Linhas: baixo, esquerda, direita, cima. Colunas: 4 quadros de caminhada (o 1º é o parado). Pés em y≈58 do quadro. |
| `npc_fungo.png` | 128×64 | 2 quadros de 64×64 (animação parado). |
| `tiles.png` | 256×32 | Peças de 32×32: grama, grama c/ flores, grama c/ trevos, caminho, terra arada, terra molhada, água, água com margem. |
| `crops.png` | 128×128 | Linhas: cenoura, tomate, couve, flor-estrela. Colunas: estágios 0 (semente) a 3 (pronta). 32×32 cada. |
| `tree.png` / `tree_big.png` | 64×96 | Base do tronco em y≈92. |
| `stump.png`, `rock.png`, `weed.png`, `shipping_bin.png` | 32×32 | Base em y≈28. |
| `house.png` | 160×144 | Porta centralizada embaixo. |
| `shop.png` | 128×128 | Barraca do Fungo (asset do projeto idle). Base em y≈120. |
| `icons.png` | 256×32 | Ícones 16×16, índices definidos em `scripts/data/item_db.gd`. |

Fundo sempre transparente. Paleta: madeira #765137, madeira clara #A8784F, verde #78945B, verde claro #B6C995, creme #E9DDBB, terra #776B52.

Efeitos ficam em `assets/fx/` (quadros de 64×64, 9 linhas de cores). Para trocar qual efeito aparece em cada ação, edite `PRESETS` em `scripts/world/fx.gd`.
