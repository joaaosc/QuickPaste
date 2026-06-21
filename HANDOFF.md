# HANDOFF — log de raciocínio e mudanças

Log cronológico a partir da etapa do OCR (branch `feature/ocr-vision`). Registra **todo** raciocínio
e mudança, para continuar o desenvolvimento fora do Claude. Mais recente no topo de cada data.

---

## 2026-06-20 — investigação do crash `swift_retain` em "Converter fórmula para LaTeX"

**Escopo (CLAUDE.md):** corrigir só o crash `EXC_BAD_ACCESS`/`swift_retain` ao converter fórmula.

**Estado sujo confirmado (`git status --short`):** modificados AGENTS.md, HANDOFF.md, project.pbxproj,
scheme, EditorModel.swift, NoteTextEditor.swift, EditorView.swift, entitlements, QuickPasteSettings.swift,
AdvancedSettingsView.swift; novos não rastreados: CLAUDE.md, `Editor/FormulaRecognition/`, Info.plist,
`QuickPasteTests/FormulaRecognition/`, `QuickPaste Application Support/`. Nada revertido.

**Inspeção do caminho (menu → EditorView → EditorModel → CoreAIFormulaConverter → runtime Core AI):**
- O limite de imagem é **idêntico** ao do OCR de texto: ambos fazem `NSImage→CGImage` no MainActor e
  enfileiram só o `CGImage` (Sendable). Nenhum objeto AppKit cruza para a `Task`. ⇒ se o OCR de texto
  funciona, o limite de imagem não é a causa; o crash é específico do runtime Core AI da fórmula.
- Docs Apple (apple-docs MCP) confirmam: `InferenceFunction` **é dono dos próprios recursos** (pesos/
  buffers) e é `Sendable`; `AIModel` é `struct`/`Sendable`. ⇒ soltar o `AIModel` em `CoreAIModelLoader.load()`
  após `loadFunction` é seguro — **não** é a causa.
- Construção de entrada `NDArray(scalars:shape:)` e tokenizer/tensor são valores puros — sem hazard.
- Suspeita principal restante: tratamento de saída em `CoreAIModel.copyFloats` (consumir `InferenceValue`
  / ler `NDArray.View` via ponteiro) — combina com `swift_retain` e com "0 eventos" (evento de inferência
  só é gravado ao concluir a run; crash ao consumir a saída ocorreria antes disso).

**Backtrace (fornecido pelo usuário):** crash em `Task` na pool cooperativa, `EXC_BAD_ACCESS` em
`swift_retain` (ponteiro corrompido `0xa8000000000008`), pilha 100% em frameworks Apple:
`CoreAIRuntime → BNNSCoreAIDelegate → BNNSGraphContextExecute_v2 → swift_retain`. Nenhum frame do
QuickPaste. OCR de texto (Vision) **funciona**. ⇒ crash é exclusivamente na execução do grafo Core AI.

**Causa raiz (confirmada):** a especialização do Core AI "produz código executável" (doc Apple,
*Managing model specialization and caching*); o backend **CPU (BNNS Graph)** executa esse código
**in-process via MAP_JIT**. O QuickPaste roda com **Hardened Runtime + App Sandbox** e o
`QuickPaste.entitlements` só tinha `com.apple.security.app-sandbox` — **sem entitlement de JIT**. Sob o
Hardened Runtime, a memória JIT do BNNS não mapeia/executa corretamente e o executor lê ponteiros lixo
→ `swift_retain` em endereço inválido. O LatexOCRlab funciona por ser projeto separado (sem hardened/
sandbox). O `FormulaConverterFactory` força `.cpu` (caminho exato que faz JIT in-process).

**Correção:** adicionado `com.apple.security.cs.allow-jit` ao `QuickPaste.entitlements` (mantém o app
sandboxed; só permite o JIT que o backend CPU do Core AI exige). Sem mudança de código, de semântica do
modelo, do compute unit `.cpu` ou da estratégia de assets.

**Verificação:** precisa de build **assinada** (Run no Xcode, ⌘R) — entitlements não são aplicados com
`CODE_SIGNING_ALLOWED=NO`. Repetir: clique direito na imagem ▸ Converter fórmula para LaTeX.
**Fallback** se persistir: somar `com.apple.security.cs.allow-unsigned-executable-memory` (caminho JIT
legado), ou deixar o compute unit no `.automatic` (evita JIT in-process da CPU usando ANE/GPU).

### CORREÇÃO DO DIAGNÓSTICO (mesma data) — a causa raiz é o MODELO subtreinado, não o QuickPaste

A teoria do JIT/entitlement acima foi **descartada por evidência**. Depuração dirigida por XcodeBuildMCP
(teste de paridade temporário rodando o `.aimodel` real no ambiente de build do QuickPaste, já removido):

- Runtime do QuickPaste é **byte-idêntico** ao LatexOCRlab (mesmo `CoreAIModel`/`copyFloats`/loader/
  decoder/preprocessing; só `public`→`nonisolated`). Settings de concorrência idênticos.
- Teste headless: `DETERMINISTIC=true`, `PARITY(run==golden do lab)=true`, `CGImage==arquivo`,
  e **sem crash** em ~10+ inferências. `.cpu`/`.gpu`/`.neuralEngine` e full/crop dão a **mesma** saída.
- A saída é sempre o lixo fixo `{ 2 } ^ { 2 } ...` (`eos=false`, 256 passos) **independente da imagem**.
- O **benchmark do próprio lab** (`results/predictions/benchmark-greedy.jsonl`, gerado em **PyTorch**
  `best.pt`) tem **64/64** predições com esse mesmo lixo. `benchmark-greedy-summary.json`:
  `exact_match=0.0`, `token_accuracy=0.10`, `eos_stop_rate=0.0`, `invalid_latex_rate=1.0`.
- `results/training/run_summary.json`: **3 épocas, 120 passos**, `val_loss=3.25`. `configs/training.yaml`
  é um **"BOUNDED prototype... Infrastructure, not accuracy"** (`max_train_batches: 40`, `batch_size: 16`)
  → ~640 imagens/época de um dataset de 234k. Modelo essencialmente **não treinado**.

**Conclusão:** modelo colapsou nos tokens mais frequentes e **ignora a imagem**. Core AI converte fiel;
QuickPaste roda fiel. **A integração do QuickPaste está correta.** Correção = **retreinar** o modelo no
LatexOCRlab (não basta reconverter). O crash provavelmente é efeito do decode desenfreado (256 passos,
nunca EOS) sob hardened runtime — reavaliar após o modelo emitir EOS. Entitlements voltaram a só
`app-sandbox` (allow-jit não comprovado). Artefatos temporários de debug removidos.

## 2026-06-19 — correção de glitches visuais do editor (cor no dark mode + imagem colada)

**Passo OCR atual:** inalterado (pipeline de texto concluído; `.formula`/`FormulaConverting` seam
preservado). Esta etapa é só polimento visual do editor, sem mexer no pipeline OCR.

**Sintomas relatados:** (1) cor da fonte ilegível no dark mode; (2) imagem colada "quase não ocupa
espaço" e com aparência desorganizada.

**Causa raiz:**
- Cor: `NoteTextEditor` normalizava só a fonte (`.font`), nunca a cor. O round-trip RTFD grava uma
  cor estática (preto), que fica ilegível no fundo escuro.
- Imagem: `scaledBounds` exibia qualquer imagem mais estreita que a coluna no tamanho nativo em
  pontos (minúscula em telas Retina) e nunca preenchia a largura; o attachment ficava inline,
  colado ao texto, sem layout de bloco.

**Implementado (somente `NoteTextEditor.swift`):**
- Cor dinâmica `NSColor.textColor` (adapta a light/dark em runtime) fixada via novo helper
  `normalizeAppearance(of:font:)`, chamado no `makeNSView` e nos dois caminhos de push externo do
  `updateNSView`; `typingAttributes`/`textColor`/`insertionPointColor` também passam a usar
  `.textColor`. Estilos de parágrafo são preservados (a imagem centralizada não é desfeita).
- `displayBounds(for:)` (substitui `scaledBounds`): imagem preenche a coluna do editor preservando
  proporção — reduz imagens grandes e amplia as pequenas no máximo 2× (mantém nitidez).
- Imagem colada vira bloco centralizado, em linha própria, com espaçamento de parágrafo; quebra de
  linha à frente só quando necessário e o caret cai numa linha esquerda/limpa abaixo. Re-colagem em
  modo imagem-única agora colapsa linhas em branco residuais (sem acúmulo).

**Arquivos modificados:** `QuickPaste/Editor/NoteTextEditor.swift`, `HANDOFF.md`.
**Arquivos criados/removidos:** nenhum.

**Validação:** `xcodebuild build test` (Xcode 27 beta, `platform=macOS`, scheme `QuickPaste`):
`BUILD SUCCEEDED` + `TEST SUCCEEDED`, sem novos warnings do código do projeto (apenas o aviso pré-
existente de AppIntents metadata). Suíte de 30 casos permanece verde. Inspeção visual (dark mode +
imagem real) continua pendente — é a mesma verificação GUI já listada.

**Bloqueadores conhecidos:** nenhum de compilação/teste.

**Próximo passo recomendado:** smoke test GUI no editor — colar imagem (screenshot grande, imagem
pequena, sem texto) e alternar light/dark — confirmando legibilidade e o bloco centralizado.

## 2026-06-19 — documentação funcional e de configuração do OCR

**Documentado:** referência completa em `docs/reference/ocr.md`, cobrindo ativação, OCR automático e
manual, estados, fila/cancelamento, parâmetros internos, pipeline, idioma, fallback, persistência,
privacidade, limitações, arquitetura, testes e diagnóstico.

**Alinhado:** `README.md`, índice `docs/README.md`, how-to de colar imagem, arquitetura e guia de
desenvolvimento deixaram de afirmar que OCR/test target não existem.

**Arquivos criados:** `docs/reference/ocr.md`.

**Arquivos modificados:** `README.md`, `docs/README.md`, `docs/how-to/paste-an-image.md`,
`docs/explanation/architecture.md`, `docs/explanation/development-guide.md`, `HANDOFF.md`.

**Validação:** documentação confrontada com os defaults e fluxos do código. Apple Docs MCP
reconfirmou `DetectTextRectanglesRequest`, `DetectDocumentSegmentationRequest` e
`RecognizeTextRequest` no macOS 15+, e `RecognizeDocumentsRequest` no macOS 26+.

**Bloqueadores:** nenhum. Nenhum código foi alterado; build/test não foram repetidos nesta etapa
exclusivamente documental.

**Próximo passo recomendado:** executar o smoke test GUI já pendente e registrar os resultados na
seção de limitações/validação da referência OCR.

## 2026-06-19 — OCR robusto, fila e testes executáveis

**Passo OCR atual:** pipeline de texto robusto concluído sobre os Steps 1–3. O seam `.formula` /
`FormulaConverting` foi preservado para uma branch futura; nenhuma API Core AI ou ação LaTeX foi
implementada.

**Implementado:**
- Tipos OCR imutáveis/`Sendable`, blocos com confiança e retângulos normalizados.
- Gate Vision com pré-filtro dimensional, `DetectTextRectanglesRequest`, cobertura, caracteres e
  confiança ponderada; falhas do classificador chegam ao estado da UI.
- Adapters Vision/Core Image isolados em actors próprios; preprocessor com segmentação/correção de
  documento e upscale Lanczos limitado, sem trabalho pesado no `MainActor`.
- `RecognizeDocumentsRequest` para documentos; OCR `.accurate` geral/fallback; idioma automático ou
  hint derivado de `detectedLanguage`; assembler top-down/left-right com parágrafos.
- `EditorModel` com fila FIFO, `OCRState`, cancelamento, erro e DI para classifier/preprocessor/
  recognizer/formula converter. Desligar OCR cancela e limpa a fila.
- `EditorView` sem conversão de imagem nem criação de `Task` quando OCR está off; faixa compacta de
  progresso/erro/cancelamento separada da tradução.
- Menu de contexto de imagem mesclado ao menu nativo do `NSTextView`; item LaTeX desabilitado removido.
- Target macOS `QuickPasteTests` adicionado ao projeto e ao scheme, com fakes determinísticos e
  cobertura de no-text, text, reconhecimento, erros, formula seam, flag off, cancelamento, FIFO,
  ordenação e pós-processamento.

**Arquivos modificados:** `QuickPaste.xcodeproj/project.pbxproj`, scheme `QuickPaste`,
`EditorModel.swift`, `NoteTextEditor.swift`, `OCRServices.swift`, `OCRTypes.swift`, `EditorView.swift`,
`QuickPasteTests/EditorModelTests.swift`, `docs/explanation/ocr-plan.md`, `HANDOFF.md`.

**Arquivos criados:** `OCRImagePreprocessor.swift`, `OCRTextAssembler.swift` e
`QuickPasteTests/OCR/{OCRTestDoubles,OCRPipelineTests,OCRTextAssemblerTests}.swift`.

**Arquivos removidos:** nenhum. Somente a ação LaTeX prematura foi removida do menu.

**Validação:** Apple Docs MCP confirmou disponibilidade e contratos de `DetectTextRectanglesRequest`
(macOS 15+), `DetectDocumentSegmentationRequest` (macOS 15+), `RecognizeTextRequest` (macOS 15+) e
`RecognizeDocumentsRequest` (macOS 26+). XcodeBuildMCP reconheceu o scheme; como suas ações macOS não
estão expostas, build/test foram executados por `xcodebuild` com Xcode 27 beta. Build e 30 casos de
teste verdes, sem warnings do código do projeto na execução final com `-quiet`.

**Bloqueadores conhecidos:** nenhum de compilação/teste. Smoke test GUI manual (colar imagem real,
clique direito e inspeção visual do cancelamento) ainda não foi executado nesta sessão.

**Próximo passo recomendado:** executar o smoke test GUI com fixtures reais de screenshot, foto de
documento e imagem sem texto; depois calibrar limiares do gate com um corpus versionado.

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

### Implementação — Passo 4: fórmula → LaTeX via Core AI (runtime do LatexOCRlab portado) — 2026-06-20

Objetivo: integrar o runtime validado do LatexOCRlab (imagem de fórmula → LaTeX, Core AI on-device)
ao QuickPaste, atrás do seam `FormulaConverting` já existente, acionado pelo clique direito na imagem.

Arquitetura:
- Módulo aditivo `QuickPaste/Editor/FormulaRecognition/` (irmão de `Editor/OCR/`, que segue só Vision).
  Runtime portado quase verbatim, marcado `nonisolated` (o alvo usa `SWIFT_DEFAULT_ACTOR_ISOLATION =
  MainActor`). Preserva int32, loop greedy fixo de 257, especialização CPU e os shapes
  ([1,3,160,640]→[1,100,192]→[1,257,580], vocab 580). `.aimodel`/contrato intactos.
- Adapter `CoreAIFormulaConverter: FormulaConverting` (`@available(macOS 27, *)`): CGImage → tensor →
  encoder/decoder → greedy → tokenizer → normalizer → **validação** → LaTeX, ou lança
  `RecognitionError.noFormula`. `FormulaConverterFactory.make()` devolve `nil` em macOS < 27 / sem
  Core AI, escondendo a ação.
- `EditorModel`: nova `OCRJob.Kind.formula` + `enqueueFormula(_:)` reusam fila FIFO/cancelamento/
  estado do OCR (gating por `ocrEnabled`). `dispatchLatex` roteia para o destino de Settings
  (inserir / copiar / ambos) via seam `latexDestination` injetável; erros de fórmula aparecem sem o
  prefixo "OCR falhou:".
- Menu de contexto (AppKit) reescrito e agrupado, com SF Symbols: Reconhecer texto (text.viewfinder),
  Converter fórmula para LaTeX (function, gated por Core AI), Copiar imagem (doc.on.doc), Abrir no
  Preview (eye, só ícone + accessibilityDescription/tooltip). Copiar/Preview são ações puras de AppKit
  (NSPasteboard / NSWorkspace com PNG temporário no container).
- Settings ▸ Avançado: `Picker` "Saída do LaTeX" (enum `LatexOutputDestination`), gated por OCR.

Assets (sandbox, runtime-path): `ResourceLocator` resolve o `.aimodel` no container **Application
Support** primeiro; o vocab (`latexocr-v1-vocab.json`, 20 KB) é embarcado no bundle. O `.aimodel`
(12 MB) **não** é versionado nem embarcado; ausência → mensagem de instalação (sem crash). Core AI fica
**weak-linked** automaticamente (deploy 26.5 < disponibilidade 27 + `@available`) — confirmado por
`otool` (`LC_LOAD_WEAK_DYLIB`).

Arquivos criados: `Editor/FormulaRecognition/` (17 `.swift`: 15 portados/adaptados +
`CoreAIFormulaConverter.swift` + `FormulaConverterFactory.swift`) e `latexocr-v1-vocab.json`;
`QuickPasteTests/FormulaRecognition/FormulaRuntimeTests.swift` e `FormulaConversionTests.swift`.
Arquivos modificados: `Editor/EditorModel.swift`, `Editor/NoteTextEditor.swift`, `EditorView.swift`,
`QuickPasteSettings.swift`, `Settings/AdvancedSettingsView.swift`.

Validação: `BUILD SUCCEEDED` (SDK macOS 27, deploy 26.5) e `TEST SUCCEEDED` — 0 falhas; suíte OCR
existente + 16 testes novos (runtime puro com fake `TokenModel` + fluxo do `EditorModel` com fakes;
nenhum Core AI real nos testes).

Blockers / pendências:
- Smoke test em runtime (macOS 27): instalar o `.aimodel` no container, validar fórmula real,
  no-formula, copiar imagem, abrir no Preview, e launch limpo em macOS 26.5 (ação ausente).
- Acessibilidade: "Abrir no Preview" é só ícone (por pedido); VoiceOver depende da
  accessibilityDescription/tooltip — avaliar rótulo visível se necessário.
- Docs (`docs/reference/ocr.md`, `ocr-plan.md`, `architecture.md`, `development-guide.md`) ainda
  descrevem LaTeX como trabalho futuro — atualizar.

Próximo passo: smoke test GUI da conversão em macOS 27 e atualizar a referência de OCR/LaTeX.
