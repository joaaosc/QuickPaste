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
  Settings/
    SettingsContent.swift    TabView host (Geral/Avançado/Telas/Atalhos/Sobre).
    *SettingsView.swift       Uma view por aba.
    ShortcutRecorder.swift   Gravador de atalho (AppKit) usado na aba Atalhos.
QuickPasteTests/             Testes (Swift Testing) — ver "Testes".
```

## Subsistemas

### Editor (MVVM + seams)
`EditorModel` é a fonte de verdade. Depende de protocolos (`NotePersisting`, `PasteboardWriting`,
`LanguageDetecting`) injetados — troque por fakes em testes/previews (`InMemoryNotePersistence`).
Conteúdo é `NSAttributedString` (texto + imagens inline) persistido como **RTFD**; `plainText`
(sem o caractere de anexo U+FFFC) alimenta tradução, contagem e detecção. Persistência é debounced
(`persistNow()` faz flush ao fechar o painel).

### Imagens inline
`NoteTextEditor` é um `NSTextView` (rich text, `importsGraphics = false`). `ClipboardTextView.paste`
insere a imagem do clipboard inline (escala à largura) quando há imagem e **nenhum** texto; respeita
`allowMultipleImages` (modo single substitui a anterior).

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
`QuickPasteTests/` tem testes Swift Testing do `EditorModel` e do detector (fakes via DI). **Ainda
não há test target** no `.xcodeproj` (evitou-se cirurgia no `project.pbxproj`). Para rodar:
1. Xcode ▸ File ▸ New ▸ Target ▸ **Unit Testing Bundle** (`QuickPasteTests`, host = QuickPaste).
2. Adicione os arquivos de `QuickPasteTests/` ao target.
3. `⌘U`.

## Convenções
- **macOS-first**, frameworks Apple antes de terceiros.
- Default actor isolation = **MainActor**; tipos de infraestrutura sem UI são `nonisolated`.
- **Verifique APIs beta/novas na doc** antes de usar (foi assim que se confirmou Translation,
  NaturalLanguage, `SettingsLink` e Liquid Glass).

## Roadmap — OCR em imagens (próxima branch)
A opção **"Reconhecer texto em imagens (OCR)"** (`ocrEnabled`) já existe, **sem implementação**.
Plano sugerido (a fazer em uma branch nova, ex. `feature/ocr-vision`):
1. Criar um seam `TextRecognizing` (protocolo) + impl `VisionTextRecognizer` usando **Vision**
   (`VNRecognizeTextRequest`/`RecognizeTextRequest`, on-device) — confirmar a API atual no apple-docs.
2. Ao colar uma imagem (em `ClipboardTextView`/`EditorModel`), se `ocrEnabled`, rodar OCR async e
   inserir/anexar o texto reconhecido (decisão de UX: abaixo da imagem ou substituindo).
3. Injetar um `FakeTextRecognizer` nos testes (golden outputs); nunca chamar Vision real em unit test.
4. Manter on-device e macOS-first; tratar falhas com fallback (sem texto reconhecido → no-op).
