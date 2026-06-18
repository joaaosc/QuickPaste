# Explicação: arquitetura e decisões

## Visão geral
QuickPaste é um app SwiftUI **macOS-first** empacotado como utilitário de barra de menus
(`LSUIElement`). O ciclo de vida e o chrome nativo (status item, painel, atalho global, camada de
janelas) ficam em AppKit; a UI (editor e Settings) é SwiftUI.

```
QuickPasteApp (App, cena Settings)
        │  @NSApplicationDelegateAdaptor
        ▼
AppDelegate ── status item, FloatingPanel (NSPanel), HotKeyManager (Carbon), camada de janelas
        │  hospeda
        ▼
EditorView (SwiftUI) ── NoteTextEditor (NSTextView rich text)
        │  observa
        ▼
EditorModel (@Observable, @MainActor)
        │  depende de protocolos (DI)
        ▼
NotePersisting · PasteboardWriting · LanguageDetecting   (EditorServices)
```

## MVVM com seams por protocolo
O editor segue **MVVM**: `EditorModel` é a fonte de verdade (conteúdo rich, máquina de estados de
tradução, idioma detectado). A View depende de `EditorModel`, que depende de **protocolos**
(`NotePersisting`, `PasteboardWriting`, `LanguageDetecting`) — mantendo a View fina e o estado
testável com fakes (`InMemoryNotePersistence`). A persistência é **debounced**; `persistNow()` faz
flush ao fechar o painel.

## Conteúdo rich text e imagens inline
A nota é um `NSAttributedString`, então imagens coladas ficam **inline no corpo do texto** como
`NSTextAttachment`. O editor é um `NSTextView` (`NoteTextEditor`) — escolhido porque o `TextEditor`
do SwiftUI não permite interceptar o paste nem inserir anexos. No ⌘V, se o clipboard tem **imagem e
nenhum texto**, inserimos a imagem (escalada à largura) na posição do cursor; o toggle "permitir
mais de uma imagem" controla se substituímos a anterior. O `plainText` (sem o caractere de anexo
U+FFFC) alimenta tradução, contagem e detecção. Persistência: **RTFD** (embute as imagens) em
`UserDefaults`.

## Configurações em abas (modular)
`SettingsContent` é um `TabView` nativo (Geral, Avançado, Telas, Atalhos, Sobre), cada aba uma view
modular (`GeneralSettingsView`, `AdvancedSettingsView`, …) usando `Form`/`Section`/`LabeledContent`
e controles nativos. Deixamos o **sistema** aplicar material/estilo (sem imitar "vidro" à mão).
Preferências via `@AppStorage` (sem acoplar UI à lógica).

## Camada de janelas (painel acima de tudo, exceto Settings)
O painel da nota fica em `NSWindow.Level.floating` (acima de todos os apps). Como a janela de
Settings é a única janela **titulada não-painel** do app, o `AppDelegate` observa o foco de janelas:
ao Settings virar key, **ativa o app** (`NSApp.activate()`), eleva a Settings acima do painel e
ordena-a à frente — garantindo que abra como **janela ativa, acima de tudo** — e baixa o painel para
`.normal`. Ao perder o foco, a Settings volta a `.normal`; ao fechar, o painel volta a `.floating`.
Vale para o item de menu e para o `SettingsLink`.

## Atalhos globais
`HotKeyManager.reload()` (chamado pelo `AppDelegate` no launch e a cada `UserDefaults.didChange`)
registra via Carbon (`RegisterEventHotKey`) o atalho **fixo ⌃⌥Espaço** (se `globalHotKeyEnabled`) e o
**personalizado** (se definido). O `ShortcutRecorder` (AppKit) grava keyCode + modificadores Carbon
+ string de exibição em `UserDefaults`. Ambos chamam o mesmo handler (alternar a nota).

## Liquid Glass
macOS 26+: o editor usa estilos de botão `.glass`/`.glassProminent` (engrenagem prominente para
destaque) e `.glassEffect(_:in:)` no cartão de tradução; o Sobre tem um cabeçalho em glass.
Seguindo a HIG, deixamos o **sistema** aplicar material/interação em vez de imitar vidro à mão.

## On-device e privacidade
O app é **sandboxed e sem entitlement de rede**. Tudo roda localmente:
- **Tradução**: framework `Translation` (on-device, macOS 15+). A `TranslationSession` só é válida
  dentro do closure do `translationTask`, então a View mantém o `translationTask` e o model guarda o
  estado. Pode ser desligada em Configurações.
- **Detecção de idioma**: `NLLanguageRecognizer` (NaturalLanguage), sem download de modelo.
- **OCR**: opção presente, ainda não implementada (seria Vision, on-device).
- **Dados**: nota (RTFD) e preferências em `UserDefaults`. Conteúdo do clipboard nunca é logado.

## Testes
Os testes (Swift Testing, em `QuickPasteTests/`) exercitam o `EditorModel` e o detector com fakes via
injeção de dependência — sem chamar modelos reais. Veja o
[EXPERIMENT_REPORT](../EXPERIMENT_REPORT.md) para como conectar o test target.
