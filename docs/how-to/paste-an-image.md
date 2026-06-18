# Como colar uma imagem na nota

## Passos
1. Copie uma imagem para o clipboard — por exemplo, tire um print com **⇧⌘4** ou copie uma imagem
   de outro app.
2. Abra a nota (engrenagem/ícone da barra de menus ou **⌃⌥Espaço**) e clique no editor para focá-lo.
3. Posicione o cursor onde quer a imagem e pressione **⌘V**.

A imagem é inserida **inline, no corpo do texto**, na posição do cursor (redimensionada para caber na
largura). Você pode continuar digitando antes/depois dela.

## Uma ou várias imagens
Por padrão a nota guarda **uma** imagem (colar outra substitui a anterior). Para permitir **várias**,
ative **Configurações ▸ Avançado ▸ "Permitir colar mais de uma imagem"**.

## Como funciona
O editor é um `NSTextView` rich text cujo `paste(_:)` verifica o clipboard: se houver **uma imagem e
nenhum texto**, ela é inserida como anexo (`NSTextAttachment`) inline; caso contrário, o ⌘V cola
texto normalmente. O conteúdo é salvo como **RTFD** (que embute as imagens) em `UserDefaults` e
restaurado ao reabrir o app.

## Limitações atuais
- **A tradução ignora imagens** — traduz apenas o texto (o caractere de anexo é descartado).
- Se o clipboard tiver imagem **e** texto, o ⌘V cola o texto (não sequestra o paste de texto).
- Para remover uma imagem, selecione-a no editor e apague (Delete), ou use a lixeira (🗑) para
  limpar tudo.
