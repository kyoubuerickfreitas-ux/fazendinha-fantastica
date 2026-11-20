# Fazendinha Fantástica 🌱

Jogo mobile (Android) de fazenda num mundo de fantasia rural, feito em **Godot 4.3** (GDScript).

## Estado atual: v0.1, núcleo da fazenda

- Tela deitada (paisagem), resolução base 640×360 com pixel art nítido
- Joystick virtual dinâmico (aparece onde você toca, lado esquerdo) e movimento em 8 direções
- HUD: retrato, vida, energia, moedas, dia/hora e clima
- Barra rápida de 6 espaços (personalizável pela mochila), botão de usar ferramenta, botão de interagir (mão) e botão da mochila
- Ferramentas: regador (enche no lago), enxada, machado, picareta e foice
- **Agricultura com estações** (20 dias cada): 13 culturas em `data/crops/*.tres`, de colheita única ou recorrente, com dormência, sobrevivência ou morte no fim da estação
- **Umidade do solo**: a terra seca durante a noite conforme a temperatura; abaixo do mínimo da planta o crescimento pausa, e só morre depois de vários dias sem água
- **Clima** (`data/weather/*.tres`): sol, chuva, chuva forte, tempestade, neve, neblina, vento, onda de calor e frio intenso — cada um muda a umidade, a temperatura, as plantas frágeis e os animais
- **Solo e biomas**: solo comum, fértil, arenoso (seca rápido), argiloso (segura água) e pedregoso; beira do lago, borda da floresta e planície — plantas nativas crescem 15% mais rápido
- **Adubos** (bancada): básico, de crescimento, retém-água e de qualidade; colheitas têm qualidade (comum → lendária) pelo cuidado, fertilidade e adubo
- **Ferramentas melhoráveis** na bancada (enxada e regador: 3 em linha, depois 3×3) e **aspersores** (4, 8 ou 24 canteiros) que regam toda manhã
- **Máquinas**: prensa de queijo, batedeira (manteiga), roca (novelo), tear, prensa de óleo (trufa), pote de conserva (fruta → geleia, resto → conserva); o produto herda a qualidade
- **Toque num canteiro com a mão vazia** para ver solo, umidade, adubo e quantos dias faltam
- **Calendário** (toque no relógio): estação, dias restantes, previsão de 3 dias e o que dá tempo de plantar
- Sinais no canteiro: gota (precisa de água), brilho (pronta), z (dormindo), planta seca (morreu — colha com a mão/foice para limpar)
- Limpeza do terreno: mato, pedras, tocos e árvores dão fibra, pedra e madeira
- **Animais** (fichas em `data/animals/*.tres`): cada um tem nome, personalidade, idade (filhote → jovem → adulto), amizade (5 corações), felicidade e saúde
  - Moombor dá leite e Piuplum ovos todo dia; a lã da Fofrança cresce em 3 dias e é tosquiada com a Tesoura; o Catarrápio fareja trufas e achados no pasto (fora do inverno, com tempo bom)
  - Comem capim no pasto durante o dia, ou feno do comedouro/silo; comida favorita na mão dá muito mais amizade
  - Saúde simples: indisposto (fome), resfriado (dormir sem abrigo em tempo severo, passa em 2 dias), sujo (use a escova); Chá de Ervas cura
  - Celeiro e galinheiro com 3 níveis (mais vagas, comedouro automático do silo, aquecedor e coletor automático)
  - Reprodução opcional: filhotes no celeiro, ovo fértil na incubadora; filhotes herdam cor e personalidade
  - Personalidades com comportamento próprio e sons de cada espécie
  - Produtos têm qualidade (comum, prata, ouro, lendário) pela amizade e felicidade; vale mais na venda
  - À noite vão para o celeiro/galinheiro (ou dormem no pasto); ícones mostram o que precisam
  - Toque num animal já cuidado para ver o cartão (e mudar o nome); toque no celeiro/galinheiro para ver a lista
- **Bancada de trabalho** (ao lado da casa): fabrique feno, comedouro, cercas, caminho de pedra, espantalho, Mosca de Fibra, máquinas, galinheiro e celeiro com madeira, pedra e fibra
- **Construir**: selecione o objeto na barra; o quadrado verde mostra onde cabe. Toque para construir. Machado ou picareta desmontam (máquinas vazias e objetos pequenos)
- **Máquinas**: Prensa de Queijo (leite → queijo, 1 dia), Tear (lã → tecido, 1 dia), Pote de Conserva (qualquer colheita → geleia, 2 dias). Segure o item e toque na máquina
- **Alimentação**: cada animal come 1 feno por dia do comedouro do pasto; sem comer, não produz
- **Celeiro** (+4 animais grandes) e **Galinheiro** (+6 Piuplum); compre animais na barraca do Fungo
- **Pesca** (botão de usar com a vara: lançar, esperar o "!", fisgar e puxar tocando rápido)
  - 25 peixes em fichas de dados (`data/fish/*.tres`): lago (raso e fundo), rio e laguinho; estação, horário e clima
  - 7 raridades (Comum → Secreto); iscas mudam a chance de cada raridade; pistas no livro em vez de pura sorte
  - Tamanho e peso de cada exemplar (grandes valem mais: qualidade prata/ouro), recordes e **nível de pesca** (1–10)
  - **Livro de Pesca** (botão do livro): silhuetas dos não descobertos, ficha com onde/quando/clima/recorde/lenda
  - **Lendários**: Rei-Musgo, Lua-de-Prata, Coração-de-Inverno, Guardião do Lago (precisa do mapa) e o secreto Peixe-Sonho; cada um dá um **troféu** de decoração
  - **Tesouros** (`data/treasures/*.tres`): baús, moedas antigas, garrafas com mensagens/pistas, 4 pedaços de mapa, relíquias, pérola, objetos perdidos. A Isca Reluzente puxa mais tesouros
  - **Pedidos do Fungo** (espécie, tamanho, qualidade, raridade, objeto perdido) e o **Torneio do Lago** no dia 13 de cada estação (8h–16h) contra 3 rivais
  - **Aquário pequeno/grande e laguinho ornamental** (peixes nadando), **Defumador** (peixe → defumado, vale o dobro), **Adubo de Peixe**, **vara melhorada** na bancada e **10 títulos** com recompensas
- **Cozinha** (Fogão, fabricado na bancada): 20 receitas em `data/recipes/*.tres` com ingredientes da horta, dos animais e da pesca (aceita grupos como "qualquer peixe" ou "qualquer fruta")
  - Segure o prato e toque em usar para comer: recupera energia e vida; alguns dão bônus até dormir (Passo Leve, Fôlego, Sorte na Pesca, Amigo dos Bichos, Banquete)
  - 4 receitas no começo; as outras se compram com o Fungo (algumas só em certas estações) ou se ganham com conquistas (nível de pesca, pedidos, pratos feitos, pescar um lendário)
- Fungo, o vendedor de sementes (compra e venda), e a caixa de vendas ao lado da casa
- Ciclo de dia e noite, chuva (rega tudo sozinha) e energia
- Dormir na porta de casa passa o dia e **salva o jogo**; o jogo também salva ao minimizar o app

## Mira

- **Mira automática:** o botão de usar escolhe sozinho o alvo mais próximo em que a ferramenta da mão faz algo (machado → árvore, regador → terra seca, sementes → canteiro vazio...). A direção em que você anda desempata. O quadrado **verde** mostra o alvo; quadrado apagado = nada para fazer ali.
- **Tocar para usar:** toque direto numa árvore, pedra, canteiro, animal ou personagem perto de você para usar a ferramenta/interagir exatamente ali.

## Como abrir

1. Instale o [Godot 4.3](https://godotengine.org/download) (versão padrão, não a .NET).
2. Abra o Godot → **Importar** → escolha o `project.godot` desta pasta.
3. Aperte **F5** para jogar no PC.

Controles no PC: WASD/setas para andar, Espaço para usar a ferramenta, E para interagir, I/Tab para a mochila e 1–6 para a barra rápida. O mouse simula o toque.

## Baixar o APK pronto (GitHub Actions)

A cada `push`, o GitHub compila o APK de teste sozinho.

**Pelo celular (link direto, sempre a versão mais nova):**
https://github.com/kyoubuerickfreitas-ux/fazendinha-fantastica/releases/download/teste/fazendinha.apk

Ou pela página do release: https://github.com/kyoubuerickfreitas-ux/fazendinha-fantastica/releases/tag/teste

**Pelo PC (artefato):**

1. Abra o repositório no GitHub → aba **Actions** → **Gerar APK (Android)**.
2. Clique na execução mais recente (com ✅) e baixe o artefato **fazendinha-apk-N** em **Artifacts**.
3. Descompacte o `.zip`, copie o `fazendinha.apk` para o celular e instale (permita "instalar apps desconhecidos").

Também dá para rodar na mão: **Actions → Gerar APK (Android) → Run workflow**.
O APK é assinado com a chave de teste fixa de `android_debug/`, então as versões novas instalam **por cima** (o save continua). Serve para testar, não para a Play Store.

## Testar no celular pelo editor

1. No Godot: **Editor → Gerenciar modelos de exportação → Baixar**.
2. Instale o Android SDK e o JDK 17 e configure em **Editor → Configurações do editor → Exportar → Android**. [Guia oficial](https://docs.godotengine.org/pt-br/4.x/tutorials/export/exporting_for_android.html)
3. Ative a depuração USB no celular, conecte no PC e clique no ícone do Android no canto superior direito do editor.

## Publicar na Play Store

A Play Store exige **AAB** assinado:

1. **Projeto → Instalar modelo de compilação Android**.
2. Crie a sua chave de upload (guarde-a muito bem e **nunca** suba para o GitHub):
   ```
   keytool -genkey -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
3. Em **Projeto → Exportar**, use o preset **"Android (Play Store AAB)"**, preencha a keystore de release e troque o `package/unique_name` (ex.: `com.seunome.fazendinha`), que não pode mudar depois de publicado.
4. A cada nova versão, aumente `version/code`.
5. Envie o `.aab` no [Google Play Console](https://play.google.com/console).

## Estrutura

```
scenes/main.tscn            cena inicial
scripts/main.gd             monta mundo, câmera, HUD, dia/noite, chuva, sono, save
scripts/autoload/game.gd    estado global: dinheiro, energia, tempo, inventário, save
scripts/data/item_db.gd     itens, receitas e preços
scripts/systems/            calendário, plantas, agricultura, animais, pesca (fish_db, treasure_db, fish_quests), cozinha (cooking)
data/crops/*.tres           uma ficha por planta  ← para criar uma planta nova, copie uma ficha
data/seasons/*.tres         as 4 estações (temperatura, chuva, cor)
data/fish/*.tres            peixes (FishData)        ← gerados por tools/make_fish_data.py a partir de tools/fish_table.py
data/treasures/*.tres       tesouros (TreasureData)  ← tools/make_treasure_data.py + tools/treasure_table.py
data/recipes/*.tres         receitas (RecipeData)    ← tools/make_recipe_data.py + tools/recipe_table.py
scripts/world/              mapa (farm_world), objetos (prop), NPCs, interações
scripts/player/player.gd    personagem
scripts/ui/                 HUD, joystick, botões de toque, slots, estilo
assets/sprites/             arte (provisória, veja LEIAME.md lá dentro)
tools/                      gerador da arte provisória
tests/smoke_test.gd         teste automático com capturas de tela
```

Teste automático (gera capturas na pasta indicada):
```
godot --path . -s tests/smoke_test.gd -- /caminho/para/capturas
```

## Próximos passos sugeridos

1. Arte definitiva (filhotes, estágios das plantas, máquinas, construções)
2. Novas regiões do mundo (floresta, vilarejo, montanha) usando os biomas já prontos
3. Criação de personagem (corpo base + roupas)
4. Missões e moradores
5. Mineração
