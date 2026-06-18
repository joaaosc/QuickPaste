# Como colar uma imagem na nota

## Passos
1. Copie uma imagem para o clipboard — por exemplo, tire um print com **⇧⌘4** (vai para a área de
   transferência) ou copie uma imagem de outro app.
2. Abra a nota (clique no ícone da barra de menus ou **⌃⌥Espaço**) e clique no editor para focá-lo.
3. Pressione **⌘V**.

A imagem aparece como **anexo no topo da nota**. Para removê-la, clique no **×** sobre a imagem, ou
use a lixeira (🗑) para limpar tudo.

## Como funciona
O editor é um `NSTextView` cujo `paste(_:)` verifica o clipboard: se houver **uma imagem e nenhum
texto**, a imagem é anexada; caso contrário, o ⌘V cola texto normalmente. Assim, colar texto comum
continua funcionando como antes.

## Limitações atuais
- **Uma imagem por vez** (colar outra substitui a anterior).
- **A tradução ignora imagens** — traduz apenas o texto da nota.
- Se o clipboard tiver imagem **e** texto, o ⌘V cola o texto (não sequestra o paste de texto).

A imagem é salva localmente (PNG em `UserDefaults`) e restaurada ao reabrir o app.
