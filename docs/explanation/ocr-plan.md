# Plano de OCR em imagens (e futuro LaTeX → .tex)

> **Status: PLANO. Nada implementado ainda.** Branch `feature/ocr-vision`.
> Objetivo: (1) identificar de forma robusta o que é "imagem com texto" (viável p/ OCR) vs. o que
> não é; (2) um OCR **extremamente competente**; (3) converter a arquitetura existente **sem
> quebrar nada** (swift-architecture-skill); (4) preparar o caminho futuro: imagens de fórmulas
> matemáticas → `.tex` via modelo próprio em **Core AI**, acionado por clique direito na imagem.

## Frameworks (verificados no apple-docs)
- **Vision** — `RecognizeTextRequest` (macOS 15+) → `RecognizedTextObservation`; apoio:
  `DetectTextRectanglesRequest` (gate rápido), `DetectDocumentSegmentationRequest` (recortar/
  endireitar documento), `RecognizeDocumentsRequest` (layout/tabelas). Tudo **on-device**.
- **NaturalLanguage** — já usado; reaproveitar para escolher `recognitionLanguages` do OCR.
- **Core AI** — `CoreAI` (macOS 27, **beta**): rodar o modelo próprio de LaTeX offline no Neural
  Engine (`AIModel`/`AIModelAsset`; converter com `coreai-torch`). Atrás de `@available(macOS 27)`.
- **Tradução (contexto)**: o app usa o framework **`Translation`** (on-device), **não** Foundation
  Models nem Core AI — OCR e tradução são pipelines separados.

## Fit de arquitetura
**fit** — extensão do **MVVM** atual via novos seams (protocolos) + DI. Não troca arquitetura, não
adiciona dependências externas, isola Vision/Core AI (beta) atrás de adapters. Mantém `EditorModel`
testável com fakes (mesmo padrão de `LanguageDetecting`).

---

## Parte 1 — Identificar "imagem com texto" (gate de viabilidade)

Objetivo: evitar rodar (e oferecer) OCR em fotos/decorações sem texto, e não falhar em capturas de
tela/documentos. Pipeline em estágios, do mais barato ao mais caro:

1. **Pré-filtro barato** — ignorar imagens minúsculas (ex.: < 32×32) ou com baixa variância (provável
   cor sólida/ícone).
2. **Detecção de regiões de texto** — `DetectTextRectanglesRequest` (rápido, só localiza, não
   reconhece). Sem regiões plausíveis ⇒ classifica como **sem texto**.
3. **Reconhecimento de sondagem** — `RecognizeTextRequest` com `recognitionLevel = .fast` na imagem
   (ou nas regiões). Coletar sinais:
   - nº de observações de texto;
   - **confiança** média (`RecognizedTextObservation`/candidatos);
   - **cobertura** (fração da área da imagem coberta por texto);
   - contagem de caracteres reconhecidos.
4. **Classificação** (`ImageTextClass`): combinar os sinais por limiares calibráveis, ex.:
   - `.noText` — sem regiões ou confiança/charcount abaixo do mínimo;
   - `.text(confidence)` — ≥1 região com confiança ≥ ~0.5 e ≥ N caracteres;
   - `.formula` — (futuro) heurística/classificador: bloco único centralizado, muitos símbolos
     matemáticos, poucas palavras (refinado depois pelo modelo Core AI).
5. **Anti-falsos-positivos**: exigir confiança + charcount mínimos; permitir "OCR mesmo assim"
   manual quando o gate disser `.noText` (override do usuário).

Saída do gate: `ImageTextClass` + (opcional) regiões/recorte para a Parte 2.

---

## Parte 2 — OCR "extremamente competente"

1. **Pré-processamento** (Core Image, on-device): recorte/deskew via
   `DetectDocumentSegmentationRequest`; upscale de imagens pequenas; aumento de contraste; opcional
   binarização. Isso é o que mais eleva a acurácia em prints e fotos.
2. **Reconhecimento preciso** — `RecognizeTextRequest` com:
   - `recognitionLevel = .accurate`;
   - `usesLanguageCorrection = true`;
   - `recognitionLanguages` derivado da nota (NaturalLanguage) ou multilíngue;
   - `RecognizeDocumentsRequest` quando for documento (preserva parágrafos/tabelas/layout).
3. **Duas passagens**: gate `.fast` (Parte 1) → reconhecimento `.accurate` só quando vale a pena.
4. **Pós-processamento**: juntar linhas, normalizar espaços, preservar quebras significativas,
   aparar; opcionalmente manter ordem por bounding boxes (top-down, left-right).
5. **Resultado** (`RecognizedText`): texto + confiança + (opcional) blocos com posição, para a UI
   decidir layout.

---

## Parte 3 — Arquitetura (sem quebrar nada)

### Novos seams (protocolos) — em `Editor/OCR/`
```text
ImageTextClassifying   func classify(_ image: NSImage) async -> ImageTextClass
TextRecognizing        func recognize(in image: NSImage) async throws -> RecognizedText
FormulaConverting      func latex(from image: NSImage) async throws -> String   // futuro (Core AI)
```
Tipos de domínio: `ImageTextClass { noText, text(confidence: Double), formula }`, `RecognizedText`.

### Implementações concretas (isolam frameworks/beta)
- `VisionImageTextClassifier: ImageTextClassifying` — Vision (detect + sonda `.fast`).
- `VisionTextRecognizer: TextRecognizing` — Vision (`RecognizeTextRequest`/`RecognizeDocumentsRequest`).
- `CoreAIFormulaConverter: FormulaConverting` — **futuro**, `@available(macOS 27, *)`, Core AI.
- Fakes p/ testes: `FakeTextRecognizer`, `FakeImageTextClassifier`, `FakeFormulaConverter`.

### Integração (DI, aditiva)
- `EditorModel` ganha dependências **opcionais** injetadas:
  `classifier: ImageTextClassifying? = nil`, `recognizer: TextRecognizing? = nil`
  (default nil/live; nil ⇒ comportamento atual inalterado).
- Coordenação fina pode ficar em `EditorModel` ou num `ImageOCRService` dedicado (preferível para
  manter o model enxuto): orquestra gate → OCR → inserção.
- **Gate de feature**: tudo só roda se `QuickPasteSettings.ocrEnabled` (já existe, default off).
- **Concorrência**: OCR é `async` fora do main; mostrar progresso; suportar cancelamento; resultado
  aplicado no `@MainActor` (inserir no `attributedText`). Sem bloquear a UI.

### UX (HIG macOS)
- **Ao colar imagem** com `ocrEnabled`: classificar; se `.text`, rodar OCR e **inserir o texto
  reconhecido abaixo da imagem** (não-destrutivo: mantém a imagem). Estado de progresso + erro.
- **Clique direito numa imagem inline**: menu de contexto (override de `menu(for:)` em
  `NoteTextEditor`/`ClipboardTextView`, detectando o `NSTextAttachment` sob o cursor) com:
  - "Reconhecer texto (OCR)";
  - (futuro) "Converter fórmula para LaTeX (.tex)…".
- Saída do OCR e do LaTeX: ações **copiar / inserir / exportar `.tex`**; nunca sobrescrever sem ação
  explícita do usuário.

### Persistência
- Sem mudança de formato: texto reconhecido vira parte do `attributedText` (RTFD, como hoje).
- (Futuro) guardar o `.tex` associado como **atributo custom** no `NSTextAttachment`, para o clique
  direito reoferecer/reaproveitar a conversão.

### Privacidade
- 100% **on-device** (Vision e Core AI). Sem rede (app já é sandboxed sem entitlement de rede).
  Conteúdo do clipboard/imagens nunca logado.

---

## Parte 4 — Futuro: fórmula renderizada → `.tex` via Core AI

1. Usuário **treina** o modelo (imagem de fórmula renderizada → tokens LaTeX), converte para Core AI
   (`coreai-torch`) e empacota como `AIModelAsset` (`.aimodel`) no bundle.
2. `CoreAIFormulaConverter` carrega o asset e roda inferência (imagem → LaTeX), **offline**, no
   Neural Engine, atrás de `@available(macOS 27, *)`; indisponível ⇒ feature oculta (fallback).
3. **Fluxo**: clique direito na imagem → diálogo → "Converter para LaTeX" → mostra `.tex`
   (copiar/inserir/salvar `.tex`).
4. **Qualidade**: avaliar com o framework **Evaluations** (golden LaTeX); testes com
   `FakeFormulaConverter` (nunca rodar o modelo real em unit test).

---

## Parte 5 — Caminho incremental (cada passo compila e é testável)

1. Adicionar protocolos + tipos de domínio + fakes. Nenhum comportamento muda (sem impl. viva ligada).
2. `VisionTextRecognizer` + `VisionImageTextClassifier` (Vision, macOS 15+). Ligar no fluxo de colar,
   **gated por `ocrEnabled`** (default off) ⇒ opt-in, usuários atuais intactos.
3. Clique direito → OCR em imagens inline (override de menu no `NoteTextEditor`).
4. (Branch futura) `FormulaConverting` + `CoreAIFormulaConverter` + diálogo de LaTeX (macOS 27 beta).
5. Testes (Swift Testing) com fakes a cada passo; build via XcodeBuildMCP/xcodebuild.

## Riscos / tradeoffs
- Acurácia em imagens pequenas/baixo contraste → mitigar com pré-processamento + `.accurate`.
- Falsos positivos/negativos no gate → limiares calibráveis + override manual.
- **Core AI é beta (macOS 27)** → atrás de `@available` + adapter; feature opcional.
- Custo/latência do OCR → assíncrono, com progresso e cancelamento; gate barato antes do caro.
- Decisão de UX (inserir abaixo vs. substituir) → default não-destrutivo (inserir, manter imagem).

## Checklist de PR (quando implementar)
1. OCR atrás de protocolo; Vision/Core AI isolados; `EditorModel` testável com fakes.
2. Gated por `ocrEnabled`; sem mudança de comportamento quando off.
3. APIs beta atrás de `@available`; nada inventado (confirmado no apple-docs).
4. Async fora do main, com cancelamento e tratamento de erro/fallback.
5. On-device; nada logado; ações destrutivas só com confirmação do usuário.
6. Testes com golden outputs; build verde.
