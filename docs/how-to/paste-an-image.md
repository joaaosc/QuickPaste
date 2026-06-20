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

## Reconhecer o texto da imagem

O OCR é opcional e vem desligado. Ative **Configurações ▸ Avançado ▸ "Reconhecer texto em imagens
(OCR)"** para analisar automaticamente novas imagens coladas.

O texto reconhecido é anexado ao fim da nota e a imagem original permanece inline. Para tentar OCR
manualmente, clique com o botão direito sobre uma imagem e escolha **Reconhecer texto (OCR)**. Use
essa ação quando o fluxo automático não encontrar texto.

Durante o processamento, a faixa OCR permite cancelar a operação. Desativar o OCR também cancela o
trabalho atual e limpa imagens pendentes na fila. Consulte a
[referência completa do OCR](../reference/ocr.md).

## Como funciona
O editor é um `NSTextView` rich text cujo `paste(_:)` verifica o clipboard: se houver **uma imagem e
nenhum texto**, ela é inserida como anexo (`NSTextAttachment`) inline; caso contrário, o ⌘V cola
texto normalmente. O conteúdo é salvo como **RTFD** (que embute as imagens) em `UserDefaults` e
restaurado ao reabrir o app.

## Limitações atuais
- **A tradução ignora imagens** — traduz apenas o texto (o caractere de anexo é descartado).
- Se o clipboard tiver imagem **e** texto, o ⌘V cola o texto (não sequestra o paste de texto).
- A qualidade do OCR depende do tamanho, contraste, inclinação e nitidez da imagem.
- Fórmulas matemáticas ainda não são convertidas para LaTeX.
- Para remover uma imagem, selecione-a no editor e apague (Delete), ou use a lixeira (🗑) para
  limpar tudo.
