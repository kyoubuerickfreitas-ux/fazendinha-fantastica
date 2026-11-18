# Fazendinha Fantástica 🌱

Jogo mobile (Android) de fazenda num mundo de fantasia rural, feito em **Godot 4.3** (GDScript).

## Estado atual: v0.1, núcleo da fazenda

- Tela deitada (paisagem), resolução base 640×360 com pixel art nítido
- Joystick virtual dinâmico (aparece onde você toca, lado esquerdo) e movimento em 8 direções
- HUD: retrato, vida, energia, moedas, dia/hora e clima
- Barra rápida de 6 espaços (personalizável pela mochila), botão de usar ferramenta, botão de interagir (mão) e botão da mochila
- Ferramentas: regador (enche no lago), enxada, machado, picareta e foice
- Plantações: Couve-Musgo, Cenoura-Lunar, Tomate-Rubi e Flor-Estrela. Arar, plantar, regar, crescer por dia e colher
- Limpeza do terreno: mato, pedras, tocos e árvores dão fibra, pedra e madeira
- Animais no pasto (a leste): **Moombor** (leite), **Fofrança** (lã), **Catarrápio** (trufa) e **Piuplum** (ovos). Faça carinho uma vez por dia e no dia seguinte colete o produto
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
scripts/data/item_db.gd     itens, plantações e preços  ← adicionar conteúdo aqui
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

1. Arte definitiva do personagem e dos tiles
2. Animais: alimentação, filhotes, celeiro e galinheiro
3. Criação de personagem (espécie, cores, chapéus, roupas)
4. Construções (celeiro, abrigos) e expansão do terreno
5. Pesca, mineração e novas regiões
