# Explicação: arquitetura e decisões

## Visão geral
QuickPaste é um app SwiftUI **macOS-first** empacotado como utilitário de barra de menus
(`LSUIElement`). O ciclo de vida e o chrome nativo (status item, painel, atalho global) ficam em
AppKit; a UI do editor é SwiftUI.

```
QuickPasteApp (App, cena Settings)
        │  @NSApplicationDelegateAdaptor
        ▼
AppDelegate ── status item, FloatingPanel (NSPanel), HotKeyManager (Carbon)
        │  hospeda
        ▼
EditorView (SwiftUI)
        │  observa
        ▼
EditorModel (@Observable, @MainActor)
        │  depende de protocolos (DI)
        ▼
NotePersisting · PasteboardWriting · LanguageDetecting   (EditorServices)
```

## MVVM com seams por protocolo
O editor segue **MVVM**: `EditorModel` é a fonte de verdade (texto, imagem anexada, máquina de
estados de tradução, idioma detectado). A View não fala com frameworks diretamente — ela depende de
`EditorModel`, que por sua vez depende de **protocolos** (`NotePersisting`, `PasteboardWriting`,
`LanguageDetecting`). Isso mantém a View fina e torna o estado testável com fakes (ex.:
`InMemoryNotePersistence`).

A persistência do texto é **debounced** (não grava a cada tecla); `persistNow()` faz flush ao fechar
o painel.

## Por que NSTextView para o ⌘V de imagem
O `TextEditor` do SwiftUI não expõe a interceptação de paste. Para colar **imagem** do clipboard,
o editor é um `NSTextView` (`NoteTextEditor`) cujo `paste(_:)` desvia uma imagem (quando não há
texto) para `EditorModel.pasteImage`. O texto continua sendo `String`, então tradução, contagem e
detecção de idioma não mudaram. Tradução de imagem está fora de escopo.

## On-device e privacidade
O app é **sandboxed e sem entitlement de rede**. Tudo roda localmente:
- **Tradução**: framework `Translation` (on-device, macOS 15+). A `TranslationSession` só é válida
  dentro do closure do `translationTask` (verificado na doc da Apple), então a View mantém o
  `translationTask` e o model guarda o estado.
- **Detecção de idioma**: `NLLanguageRecognizer` (NaturalLanguage), sem download de modelo.
- **Dados**: nota, imagem e preferências em `UserDefaults`. Conteúdo do clipboard nunca é logado.

## Testes
Os testes (Swift Testing, em `QuickPasteTests/`) exercitam o `EditorModel` e o detector com fakes
via injeção de dependência — sem chamar modelos reais. Veja o
[EXPERIMENT_REPORT](../EXPERIMENT_REPORT.md) para o estado atual (incl. como conectar o test target).
