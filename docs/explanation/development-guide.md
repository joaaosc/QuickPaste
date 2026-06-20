# Guia de desenvolvimento

Documento para continuar o desenvolvimento do QuickPaste **sem o Claude**. Resume a estrutura, os
subsistemas, como estender e o roadmap (incl. o plano do OCR).

## Pré-requisitos
- **Xcode 26.5+/27** (o projeto compila no SDK macOS 27); deployment target **macOS 26.5**.
- Conta de desenvolvedor para assinatura automática.
- **Sem dependências externas** — só frameworks Apple.

## Build & run
- Xcode: abra `QuickPaste.xcodeproj`, rode o scheme `QuickPaste` (⌘R).
- Terminal:
  ```sh
  xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste -configuration Debug \
    -derivedDataPath .deriveddata build
  ```
  O app é `LSUIElement` (sem Dock) — procure o ícone na barra de menus.

## Mapa do projeto
```
QuickPaste/
  QuickPasteApp.swift        @main; cena Settings + @NSApplicationDelegateAdaptor.
  AppDelegate.swift          Status item, FloatingPanel, atalhos, camada de janelas.
  FloatingPanel.swift        NSPanel não-ativador; roteia ⌘-teclas (copy/paste/undo…).
  HotKeyManager.swift        Atalhos globais Carbon (fixo + personalizado).
  QuickPasteSettings.swift   Chaves/defaults; enum TranslationLanguage.
  EditorView.swift           UI do editor (SwiftUI).
  Editor/
    EditorModel.swift        @Observable @MainActor; estado/orquestração (MVVM).
    EditorServices.swift     Protocolos (seams) + impls: persistência, pasteboard, detecção.
    NoteTextEditor.swift     NSTextView rich text; ⌘V de imagem inline.
    TranslationOutcome.swift Máquina de estados da tradução.
    OCR/
      OCRTypes.swift         Tipos de domínio e estado OCR.
      OCRServices.swift      Protocolos, classificador e recognizer Vision.
      OCRImagePreprocessor.swift  Documento/perspectiva/upscale.
      OCRTextAssembler.swift Ordenação e pós-processamento puros.
  Settings/
    SettingsContent.swift    TabView host (Geral/Avançado/Telas/Atalhos/Sobre).
    *SettingsView.swift       Uma view por aba.
    ShortcutRecorder.swift   Gravador de atalho (AppKit) usado na aba Atalhos.
QuickPasteTests/             Testes (Swift Testing) — ver "Testes".
```

## Subsistemas

### Editor (MVVM + seams)
`EditorModel` é a fonte de verdade. Depende de protocolos (`NotePersisting`, `PasteboardWriting`,
`LanguageDetecting`, `ImageTextClassifying`, `ImagePreprocessing`, `TextRecognizing`) injetados —
troque por fakes em testes/previews (`InMemoryNotePersistence` e doubles em `QuickPasteTests/OCR`).
Conteúdo é `NSAttributedString` (texto + imagens inline) persistido como **RTFD**; `plainText`
(sem o caractere de anexo U+FFFC) alimenta tradução, contagem e detecção. Persistência é debounced
(`persistNow()` faz flush ao fechar o painel).

### Imagens inline
`NoteTextEditor` é um `NSTextView` (rich text, `importsGraphics = false`). `ClipboardTextView.paste`
insere a imagem do clipboard inline (escala à largura) quando há imagem e **nenhum** texto; respeita
`allowMultipleImages` (modo single substitui a anterior).

Com `ocrEnabled`, `EditorModel` classifica e reconhece novas imagens em fila FIFO. O clique direito
sobre uma imagem oferece OCR manual. Veja [Referência: OCR em imagens](../reference/ocr.md).

### Tradução e detecção de idioma
On-device: framework `Translation` (a `TranslationSession` só vale dentro do closure do
`translationTask`, que fica na View) e `NLLanguageRecognizer` (NaturalLanguage). A tradução é
gated por `translationEnabled`.

### Atalhos globais
`HotKeyManager.reload()` (chamado por `AppDelegate` no launch e a cada mudança de defaults) registra
via Carbon o atalho fixo **⌃⌥Espaço** (se `globalHotKeyEnabled`) e o **personalizado** (se definido).
O gravador `ShortcutRecorder` salva keyCode + modificadores Carbon + string de exibição em
`UserDefaults`.

### Camada de janelas
O painel fica em `.floating` (acima de todos os apps). Quando a janela de Settings (única titulada
não-painel) ganha foco, o `AppDelegate` ativa o app, eleva a Settings e baixa o painel para
`.normal`; restaura ao perder foco / fechar.

### Settings (abas)
`SettingsContent` é um `TabView` nativo; cada aba é uma view modular usando `Form`/`Section`/
`LabeledContent`. Preferências via `@AppStorage` lendo chaves de `QuickPasteSettings.Key`.

### Liquid Glass
macOS 26+: `.glassEffect(_:in:)` (cartão de tradução, cabeçalho do Sobre) e estilos de botão
`.glass` / `.glassProminent` (toolbar do editor; engrenagem prominente).

## Como estender

### Adicionar uma preferência
1. Adicione a chave em `QuickPasteSettings.Key`.
2. Registre o default em `registerDefaults()`.
3. Use `@AppStorage(QuickPasteSettings.Key.x)` na aba de Settings adequada.
4. Se afeta runtime imediato (ex.: atalho), reaja em `AppDelegate.defaultsDidChange`.

### Adicionar uma aba de Settings
Crie `XSettingsView` em `Settings/` e adicione um `.tabItem` em `SettingsContent`.

## Testes
`QuickPasteTests/` é um target macOS incluído no scheme `QuickPaste`. Ele cobre `EditorModel`,
detecção de idioma e OCR com fakes determinísticos. Rode com `⌘U` ou:

```sh
xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste \
  -configuration Debug -destination 'platform=macOS,arch=arm64' test
```

## Convenções
- **macOS-first**, frameworks Apple antes de terceiros.
- Default actor isolation = **MainActor**; tipos de infraestrutura sem UI são `nonisolated`.
- **Verifique APIs beta/novas na doc** antes de usar (foi assim que se confirmou Translation,
  NaturalLanguage, `SettingsLink` e Liquid Glass).

## OCR atual e próximos passos

O OCR Vision está implementado, opt-in e testado com fakes. A referência completa está em
[docs/reference/ocr.md](../reference/ocr.md). Próximos passos técnicos:

1. smoke test com screenshots, fotos de documentos e imagens sem texto;
2. corpus versionado para calibrar limiares;
3. reconstrução mais rica de tabelas/layouts;
4. módulo futuro e separado para fórmula → LaTeX; não há implementação Core AI hoje.
