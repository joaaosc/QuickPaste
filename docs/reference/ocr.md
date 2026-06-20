# Referência: OCR em imagens

## Visão geral

O QuickPaste usa o framework **Vision** da Apple para reconhecer texto em imagens. O processamento
é local, assíncrono e opcional. Quando o OCR está habilitado, o app pode:

- analisar automaticamente uma imagem colada;
- ignorar imagens sem texto viável antes do reconhecimento mais caro;
- corrigir a perspectiva de documentos fotografados;
- ampliar imagens pequenas dentro de limites definidos;
- usar reconhecimento específico de documentos, com fallback para OCR geral;
- inserir o texto reconhecido sem remover a imagem original;
- processar várias imagens em ordem FIFO;
- mostrar progresso, erro e uma ação de cancelamento;
- reconhecer manualmente uma imagem inline pelo menu de contexto.

O OCR não usa Foundation Models, Core ML, Core AI nem serviços externos. A conversão de fórmulas
para LaTeX não está implementada.

## Requisitos e disponibilidade

| API | Uso | Disponibilidade no macOS |
|---|---|---|
| [`DetectTextRectanglesRequest`](https://developer.apple.com/documentation/vision/detecttextrectanglesrequest) | Detectar regiões de texto | macOS 15+ |
| [`DetectDocumentSegmentationRequest`](https://developer.apple.com/documentation/vision/detectdocumentsegmentationrequest) | Detectar e delimitar documentos | macOS 15+ |
| [`RecognizeTextRequest`](https://developer.apple.com/documentation/vision/recognizetextrequest) | OCR geral | macOS 15+ |
| [`RecognizeDocumentsRequest`](https://developer.apple.com/documentation/vision/recognizedocumentsrequest) | OCR com estrutura de documento | macOS 26+ |

O deployment target atual do QuickPaste é macOS 26.5, portanto todas essas APIs estão disponíveis.

## Ativação

O OCR vem **desabilitado por padrão**.

1. Abra **Configurações**.
2. Selecione a aba **Avançado**.
3. Ative **Reconhecer texto em imagens (OCR)**.

A preferência é aplicada imediatamente e persistida em `UserDefaults` pela chave `ocrEnabled`.
Desativar a opção durante um reconhecimento cancela o trabalho atual, limpa a fila e volta o estado
para `idle`.

## Formas de uso

### OCR automático ao colar

Quando o OCR está habilitado e uma imagem é colada com **⌘V**:

1. o editor insere a imagem inline como `NSTextAttachment`;
2. a imagem é convertida de `NSImage` para `CGImage`;
3. o `EditorModel` adiciona um trabalho automático à fila;
4. o classificador verifica se há texto viável;
5. somente imagens classificadas como texto seguem para preparação e reconhecimento;
6. o resultado é anexado ao **fim da nota**, separado por uma quebra de linha.

A imagem original permanece na nota. Se o classificador retornar `.noText`, nenhuma mensagem de
erro é exibida e nenhum texto é inserido.

### OCR manual pelo menu de contexto

Com o OCR habilitado, clique com o botão direito sobre uma imagem inline e escolha
**Reconhecer texto (OCR)**.

O reconhecimento manual ignora o gate de viabilidade, mas ainda executa preparação, reconhecimento
e pós-processamento. Isso permite tentar OCR em imagens que o fluxo automático considerou fracas.
O menu mantém os comandos contextuais padrão do `NSTextView` e acrescenta a ação OCR ao final.

Quando o OCR está desabilitado, a ação não aparece.

## Estados exibidos

O estado é representado por `OCRState`:

| Estado | Comportamento da interface |
|---|---|
| `idle` | Nenhuma faixa OCR é exibida. |
| `processing(completed:total:)` | Exibe progresso, posição na fila e **Cancelar**. |
| `failed(message:)` | Exibe `OCR falhou: …` e uma ação para dispensar o erro. |

A faixa OCR é independente do cartão de tradução. Cancelar remove os trabalhos pendentes e impede
que um resultado atrasado seja inserido na nota.

## Configurações do usuário

| Configuração | Chave | Default | Efeito |
|---|---|---:|---|
| Reconhecer texto em imagens | `ocrEnabled` | `false` | Habilita OCR automático e a ação contextual. |
| Permitir colar mais de uma imagem | `allowMultipleImages` | `false` | Controla quantas imagens inline podem permanecer na nota; a fila OCR continua FIFO. |

Não existem configurações de idioma, confiança, contraste ou escala na interface. O idioma é
automático ou derivado do idioma já detectado na nota.

## Parâmetros internos

Os valores abaixo são defaults de implementação e não preferências do usuário.

### Gate de viabilidade

`VisionImageTextClassifier` usa:

| Parâmetro | Default | Significado |
|---|---:|---|
| `minimumCharacters` | `3` | Mínimo de caracteres não brancos reconhecidos pela sonda rápida. |
| `minimumConfidence` | `0.3` | Confiança mínima ponderada por caracteres. |
| `minimumPixelDimension` | `24` | Largura e altura mínimas da imagem. |
| `minimumPixelCount` | `1_024` | Área mínima em pixels. |
| `minimumTextCoverage` | `0.0005` | Fração mínima da imagem coberta por regiões de texto. |

Uma imagem precisa satisfazer os limites dimensionais, conter regiões detectadas e atingir os
limites de caracteres e confiança. Erros do Vision são propagados para o estado `failed`; não são
convertidos em `.noText`.

### Preparação da imagem

`VisionOCRImagePreprocessor` usa:

| Parâmetro | Default | Significado |
|---|---:|---|
| `targetLongEdge` | `1_600` | Tamanho desejado para o maior lado de imagens pequenas. |
| `maximumLongEdge` | `2_400` | Limite absoluto do maior lado após ampliação. |
| `maximumScale` | `3.0` | Fator máximo de upscale. |
| `minimumDocumentCoverage` | `0.2` | Cobertura mínima para tratar a detecção como documento. |

Quando um documento ocupa pelo menos 20% da imagem, o preprocessor aplica correção de perspectiva
com `CIPerspectiveCorrection` e seleciona o modo `.document`. Imagens com maior lado abaixo de
1.600 pixels podem receber upscale Lanczos, limitado a 3× e a 2.400 pixels.

## Pipeline técnico

```text
Imagem colada ou ação contextual
        │
        ├─ OCR desligado → encerra sem converter imagem nem criar Task
        │
        ▼
Fila FIFO no EditorModel
        │
        ├─ automático → dimensões → regiões → sonda .fast
        └─ manual ───────────────────────────────────────────┐
                                                            ▼
                      segmentação/correção → upscale limitado
                                                            │
                         ┌─ documento → RecognizeDocumentsRequest
                         │                 └─ vazio/erro → fallback
                         └─ geral ─────→ RecognizeTextRequest .accurate
                                                            │
                          blocos → ordenação → pós-processamento
                                                            │
                          append no fim da nota → RTFD persistido
```

### Idioma

Se `EditorModel.detectedLanguage` possui um idioma suportado, sua `Locale.Language` é enviada como
hint ao Vision. Caso contrário, `automaticallyDetectsLanguage` é habilitado. A correção linguística
permanece ativa no reconhecimento preciso.

### Reconhecimento de documento e fallback

No modo `.document`, `RecognizeDocumentsRequest` fornece parágrafos e linhas. Se essa etapa falhar
ou retornar texto vazio, `VisionTextRecognizer` tenta `RecognizeTextRequest` com nível `.accurate`.
Cancelamento não aciona fallback: ele encerra o trabalho.

### Pós-processamento

`OCRTextAssembler`:

- remove blocos vazios;
- reduz sequências de whitespace a um espaço dentro de cada bloco;
- limita confiança ao intervalo de 0 a 1;
- ordena blocos de cima para baixo e, na mesma linha, da esquerda para a direita;
- preserva parágrafos com duas quebras de linha;
- calcula confiança global ponderada por caracteres não brancos.

O domínio mantém `OCRTextBlock` com texto, confiança, `CGRect` normalizado e índice opcional de
parágrafo. A interface atual insere somente o texto montado; confiança e geometria não são exibidas.

## Fila, concorrência e cancelamento

- `EditorModel` é `@MainActor` e possui a fila e o estado observável.
- Classificador, preprocessor e recognizer live são actors separados.
- Cada imagem vira um `OCRJob` automático ou explícito.
- Trabalhos são removidos da fila na ordem de entrada.
- Falhar um trabalho registra o último erro, mas não impede o processamento dos próximos.
- O código verifica cancelamento antes da classificação, preparação, reconhecimento e inserção.
- Um identificador de geração impede que tarefas antigas insiram texto após cancelamento ou após a
  preferência ser desligada.

## Persistência e interação com outras funções

- O texto reconhecido é editável e passa a fazer parte do `NSAttributedString` da nota.
- A nota completa continua persistida como RTFD em `UserDefaults`.
- Após a inserção, o idioma da nota é detectado novamente.
- Tradução, cópia e contagens usam `plainText`, portanto incluem o texto OCR e ignoram o anexo da
  imagem.
- O tamanho de fonte atual do editor é reaplicado ao conteúdo atualizado.

## Privacidade

- Vision e Core Image executam **on-device**.
- A imagem e o texto reconhecido não são enviados para servidores.
- O app não possui entitlement de rede.
- O conteúdo do clipboard e o resultado OCR não são registrados em logs pela implementação.

## Falhas e comportamento de fallback

| Situação | Resultado |
|---|---|
| OCR desabilitado | Nenhuma conversão, fila ou tarefa OCR. |
| Imagem automática sem texto viável | No-op silencioso; imagem permanece. |
| OCR manual | Ignora o gate e tenta reconhecimento diretamente. |
| Documento vazio ou não reconhecido | Tenta OCR geral `.accurate`. |
| Resultado final vazio | Nenhum texto é inserido. |
| Erro de classificação, preparação ou reconhecimento geral | Estado `failed` com mensagem. |
| Cancelamento | Fila limpa, estado `idle`, sem inserção atrasada. |

## Limitações atuais

- Os limiares internos ainda não foram calibrados com um corpus versionado de imagens reais.
- Não há ajuste de idioma ou confiança na interface.
- Confiança e bounding boxes não são apresentados ao usuário.
- A estrutura de tabelas do Vision não é exportada como tabela; o resultado final é texto linear.
- Fórmulas matemáticas não são convertidas para LaTeX. `FormulaConverting` e `.formula` são apenas
  seams para uma implementação futura.
- Testes unitários não executam Vision real. A qualidade visual depende de smoke tests com imagens
  reais, ainda recomendados para screenshots, fotos de documentos e imagens sem texto.

## Arquitetura e arquivos

| Arquivo | Responsabilidade |
|---|---|
| `Editor/OCR/OCRTypes.swift` | Tipos de domínio, blocos, resultado, modo e estado. |
| `Editor/OCR/OCRServices.swift` | Protocolos, gate Vision e recognizer documento/geral. |
| `Editor/OCR/OCRImagePreprocessor.swift` | Segmentação, perspectiva e upscale Core Image. |
| `Editor/OCR/OCRTextAssembler.swift` | Ordenação e pós-processamento puros. |
| `Editor/EditorModel.swift` | Fila, estado, cancelamento, erros e inserção. |
| `EditorView.swift` | Feature flag, conversão `NSImage` → `CGImage` e faixa de status. |
| `Editor/NoteTextEditor.swift` | Paste de imagem e ação no menu contextual nativo. |
| `QuickPasteTests/OCR/` | Fakes e testes determinísticos do pipeline e assembler. |

## Testes

O target macOS `QuickPasteTests` faz parte do scheme `QuickPaste`. Os testes OCR usam classifier,
preprocessor, recognizer e formula converter falsos; não dependem da disponibilidade ou da saída do
Vision.

Cobertura principal:

- `.noText` e `.text`;
- reconhecimento e hint de idioma;
- erros de classificação e reconhecimento;
- flag desligada sem chamadas a dependências;
- cancelamento e limpeza da fila;
- FIFO;
- seam de fórmula;
- ordenação, parágrafos, whitespace e confiança ponderada.

Execução:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste \
  -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

## Diagnóstico rápido

### A ação OCR não aparece no clique direito

- Confirme que o OCR está habilitado em **Configurações ▸ Avançado**.
- Clique diretamente sobre a imagem inline, não sobre o texto ao lado.

### A imagem foi inserida, mas nenhum texto apareceu

- No fluxo automático, a imagem pode ter sido classificada como `.noText`.
- Use **Reconhecer texto (OCR)** no menu contextual para ignorar o gate.
- Tente uma imagem maior, com melhor contraste e texto menos inclinado.

### O OCR mostrou erro

- Dispense o erro e tente novamente com outra imagem.
- Se a fila estiver processando várias imagens, os trabalhos seguintes ainda serão executados.
- Use **Cancelar** para interromper o trabalho atual e limpar os pendentes.

## Trabalho futuro

- calibrar gate e preprocessing com corpus real;
- expor métricas de confiança quando forem úteis para decisão do usuário;
- melhorar reconstrução de tabelas e layouts complexos;
- implementar conversão de fórmula para LaTeX em módulo separado, sem adicionar item de menu antes
  de existir uma implementação funcional.
