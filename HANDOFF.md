# HANDOFF — log de raciocínio e mudanças

Log cronológico a partir da etapa do OCR (branch `feature/ocr-vision`). Registra **todo** raciocínio
e mudança, para continuar o desenvolvimento fora do Claude. Mais recente no topo de cada data.

---

## 2026-06-18 — branch `feature/ocr-vision` (planejamento do OCR)

**Antes de ramificar (na `main`):** revertidas as caixas (Liquid Glass) nos ícones da toolbar do
editor — voltaram a `.borderless` (commit `09f4f80`). Glass mantido só no cartão de tradução e no
cabeçalho do Sobre (não-ícones). Docs alinhadas.

**Branch criada** a partir da `main` (que já contém o revert).

**Decisão de escopo:** esta etapa é **somente planejamento** (instrução explícita: não implementar
OCR agora). Entregável: `docs/explanation/ocr-plan.md`.

**Docs Apple consultadas (apple-docs MCP):**
- **Translation** — framework `Translation`, macOS 14.4+. `TranslationSession`/`translationTask`,
  `LanguageAvailability`, `TranslationError`. Modelos de tradução **on-device** (baixados por idioma).
  ⇒ É o que o QuickPaste usa hoje para traduzir. NÃO é Foundation Models / Core ML / Core AI.
- **Vision `RecognizeTextRequest`** — struct, macOS 15+. Gera `RecognizedTextObservation`;
  `recognitionLanguages` para restringir idiomas. Há também `RecognizeDocumentsRequest`,
  `DetectDocumentSegmentationRequest`, `DetectTextRectanglesRequest`, `DetectBarcodesRequest`.
  ⇒ Base do OCR.
- **Core AI** — framework `CoreAI`, **macOS 27 (beta)**. Rodar modelos próprios no Apple silicon
  (CPU/GPU/Neural Engine). `AIModel`, `AIModelAsset`, `InferenceFunction`, `NDArray`; ferramentas
  `coreai-optimization`, `coreai-torch` (converter PyTorch), compilação AOT.
  ⇒ Caminho para o modelo futuro de LaTeX (treinar → converter → inferência offline).

**Decisão de arquitetura (swift-architecture-skill, Deep Refactor Mode):** OCR como **módulo aditivo
e isolado atrás de protocolos** (seams), injetado por DI; **sem trocar a arquitetura** (segue MVVM) e
**sem quebrar nada** (gated por `ocrEnabled`, default off). APIs beta (Core AI) ficam atrás de
`@available` + adapter. Detalhes em `docs/explanation/ocr-plan.md`.

**Sem código implementado.** Próximo passo (quando aprovado): Passo 1 do plano (protocolos + no-op).

### Mudanças neste branch
- `HANDOFF.md` (este arquivo) — criado.
- `docs/explanation/ocr-plan.md` — plano de OCR.
- `docs/README.md` — link para o plano.

### Implementação — Passo 1: módulo OCR (sem fiação)
Raciocínio: começar pelo módulo isolado, sem tocar no editor, para garantir a API Vision e manter
o LaTeX como módulo à parte (só o seam).
Decisões:
- Seams usam `CGImage` (Sendable; entrada nativa do Vision) → chamadas async cruzam atores limpas.
- Confirmado no apple-docs: `RecognizeTextRequest` (macOS 15+), `perform(on:)` async,
  `recognitionLevel`/`usesLanguageCorrection`/`recognitionLanguages: [Locale.Language]`,
  `RecognizedTextObservation.topCandidates(_:)` → `RecognizedText.string/.confidence`.
- `FormulaConverting` **declarado, sem impl** (módulo LaTeX/Core AI será separado).
Arquivos:
- `Editor/OCR/OCRTypes.swift` — `ImageTextClass` (.noText/.text/.formula), `RecognizedText`.
- `Editor/OCR/OCRServices.swift` — protocolos `ImageTextClassifying`/`TextRecognizing`/
  `FormulaConverting` (Sendable) + impls Vision `VisionImageTextClassifier` (gate `.fast`),
  `VisionTextRecognizer` (`.accurate` + correção).
Build: `BUILD SUCCEEDED`. Sem fiação ainda (tipos não usados).

### Implementação — Passo 2: auto-OCR ao colar (gated por `ocrEnabled`)
Raciocínio: o `EditorModel` orquestra (MVVM); a View só converte a imagem e dispara. Texto
reconhecido é **anexado** (não-destrutivo, mantém a imagem). LaTeX continua fora (case `.formula`
reservado, sem ação).
Decisões:
- `EditorModel` recebe `classifier`/`recognizer` por DI (defaults Vision); `handlePastedImage`
  (classifica → reconhece se `.text`), `recognizeText` (explícito, sem gate de classificação),
  `appendRecognizedText` (anexa com `\n`, persiste, redetecta idioma). Tudo gated por `ocrEnabled`.
- `QuickPasteSettings.ocrEnabled` accessor adicionado.
- `ClipboardTextView.onImagePasted` chama de volta após inserir a imagem; `EditorView` converte
  `NSImage`→`CGImage` e chama `model.handlePastedImage` num `Task`.
- **Correção de fonte**: `NoteTextEditor.updateNSView` agora normaliza a fonte em todo push externo
  (clear/adopt/texto do OCR) e sincroniza de volta (sem loop) — assim o texto anexado herda a fonte.
Arquivos: `EditorModel.swift`, `QuickPasteSettings.swift`, `NoteTextEditor.swift`, `EditorView.swift`.
Build: `BUILD SUCCEEDED`, sem warnings de Sendable/isolamento.
Pendente de runtime: não testado na GUI (colar imagem com texto → ver o texto anexado).

### Implementação — Passo 3: clique direito na imagem (OCR + integração LaTeX preparada)
Raciocínio: ponto de integração do módulo LaTeX é o menu de contexto; deixo o item presente porém
desabilitado ("em breve") até o módulo existir.
Decisões:
- `ClipboardTextView.menu(for:)` detecta o `NSTextAttachment` sob o clique (via
  `characterIndexForInsertion(at:)`), extrai a `NSImage` (de `.image` ou do `fileWrapper`, p/ cobrir
  imagens restauradas de RTFD) e monta o menu:
  - "Reconhecer texto (OCR)" — só quando `ocrEnabled`; chama `onRecognizeImage`.
  - "Converter fórmula para LaTeX (.tex) — em breve" — **desabilitado** enquanto
    `onConvertImageToLaTeX == nil` (seam do módulo separado).
- `NoteTextEditor` ganhou `ocrEnabled`/`onRecognizeImage`/`onConvertToLaTeX (=nil)`; `EditorView`
  liga o clique direito a `model.recognizeText(in:)`.
- Rótulo do toggle de OCR em Avançado atualizado (não é mais "em breve" para texto).
- Testes (Swift Testing, não-wired): `StubClassifier`/`StubRecognizer`; cobrem append quando
  habilitado+`.text`, no-op quando desabilitado, e skip quando `.noText`.
Arquivos: `NoteTextEditor.swift`, `EditorView.swift`, `Settings/AdvancedSettingsView.swift`,
`QuickPasteTests/EditorModelTests.swift`.
Build: `BUILD SUCCEEDED`.

**Estado do OCR:** Passos 1–3 feitos (texto). Falta: verificação em runtime; pré-processamento
avançado (deskew/upscale) e `RecognizeDocumentsRequest` (opcional, ver ocr-plan); módulo LaTeX/Core
AI (branch futura, seam pronto).
