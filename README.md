# QuickPaste

QuickPaste é um app de **barra de menus para macOS**: um bloco de rascunho sempre à mão, em um
painel flutuante estilo Spotlight. Edite texto, **cole imagens do clipboard (⌘V)**, copie o
conteúdo e traduza a nota com o framework on-device **Translation** da Apple.

## Recursos

- Ícone na barra de menus: clique esquerdo mostra/oculta a nota; clique direito abre o menu.
- Painel flutuante (NSPanel) redimensionável e não-ativador, com autosave de posição/tamanho.
- Atalho global **⌃⌥Espaço** para mostrar/ocultar.
- Editor com contagem de palavras/caracteres, tamanho de fonte ajustável e **detecção de idioma
  on-device** (NaturalLanguage).
- **Colar imagem do clipboard com ⌘V** — a imagem vira um anexo na nota (tradução de imagem está
  fora de escopo por enquanto).
- Tradução on-device para 8 idiomas.
- Persistência local da nota e da imagem em `UserDefaults`.
- Abrir a nota ao iniciar o app e iniciar o app no login.

## Requisitos

- macOS 26.5+ (deployment target do projeto), com o framework `Translation`.
- Xcode 26.5+/27 (compila no SDK macOS 27). Conta de desenvolvedor para assinatura automática.

## Como rodar

Abra `QuickPaste.xcodeproj` no Xcode e rode o scheme `QuickPaste`, ou pela linha de comando:

```sh
xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste -configuration Debug \
  -derivedDataPath .deriveddata build
```

`.deriveddata/` é ignorado pelo Git.

## Como abrir as configurações

O app é "agent" (sem ícone no Dock), então o config abre pelo menu da barra de menus:
**clique direito (ou Control-clique) no ícone do QuickPaste ▸ "Configurações…"** (ou ⌘, com uma
janela do app ativa). Passo a passo em [docs/how-to/open-settings.md](docs/how-to/open-settings.md).

## Documentação

A documentação segue o modelo [Diátaxis](https://diataxis.fr) — comece por **[docs/](docs/README.md)**:
tutorial, how-tos, referência e explicação.

## Estrutura

```text
QuickPaste/
  QuickPasteApp.swift        Entrada SwiftUI (cena Settings + AppDelegate).
  AppDelegate.swift          Status item, painel flutuante e atalho global.
  FloatingPanel.swift        NSPanel não-ativador + roteamento de ⌘-teclas.
  HotKeyManager.swift        Atalho global via Carbon.
  SettingsContent.swift      Tela de configurações.
  QuickPasteSettings.swift   Chaves/defaults e idiomas suportados.
  EditorView.swift           UI do editor.
  Editor/
    EditorModel.swift        Estado/orquestração (MVVM, @Observable).
    EditorServices.swift     Seams: persistência, pasteboard, detecção de idioma.
    NoteTextEditor.swift     Editor NSTextView (intercepta ⌘V de imagem).
    TranslationOutcome.swift Estado da tradução.
QuickPasteTests/             Testes (Swift Testing).
docs/                        Documentação (Diátaxis).
```

## Privacidade

Tudo é **on-device**: nota, imagem e preferências ficam em `UserDefaults`; tradução e detecção de
idioma rodam localmente. O app é sandboxed e **sem entitlement de rede**. Detalhes em
[docs/explanation/architecture.md](docs/explanation/architecture.md).
