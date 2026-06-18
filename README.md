# QuickPaste

QuickPaste é um app de **barra de menus para macOS**: um bloco de rascunho sempre à mão, em um
painel flutuante estilo Spotlight. Edite texto, **cole imagens do clipboard (⌘V) inline no corpo da
nota**, copie o conteúdo e traduza a nota com o framework on-device **Translation** da Apple.

## Recursos

- Ícone na barra de menus: clique esquerdo mostra/oculta a nota; clique direito abre o menu.
- Painel flutuante (NSPanel) **acima de todos os apps** — exceto a janela de Configurações, que
  abre como janela ativa, acima dele.
- Atalho global **⌃⌥Espaço** + **atalho personalizado** opcional (Configurações ▸ Atalhos).
- **Liquid Glass** (macOS 26) no cartão de tradução e no cabeçalho do Sobre.
- Editor com contagem de palavras/caracteres, tamanho de fonte ajustável e **detecção de idioma
  on-device** (NaturalLanguage).
- **Colar imagem do clipboard com ⌘V**, inline no corpo do texto. Opcionalmente **mais de uma
  imagem** (Configurações ▸ Avançado).
- Tradução on-device para 8 idiomas (pode ser desligada em Configurações).
- **OCR em imagens**: opção presente em Configurações, **ainda não implementada** (será com Vision).
- Botão de engrenagem no editor (canto inferior) que abre as Configurações.
- Configurações em abas: **Geral, Avançado, Telas, Atalhos, Sobre**.
- Persistência local da nota (RTFD, incl. imagens) e preferências em `UserDefaults`.
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

O app é "agent" (sem ícone no Dock). Abra as Configurações de duas formas:

- **Botão de engrenagem** no canto inferior do editor; ou
- **clique direito (ou Control-clique) no ícone** da barra de menus ▸ "Configurações…" (ou ⌘, com a
  janela do app ativa).

Passo a passo em [docs/how-to/open-settings.md](docs/how-to/open-settings.md).

## Documentação

A documentação segue o modelo [Diátaxis](https://diataxis.fr) — comece por **[docs/](docs/README.md)**:
tutorial, how-tos, referência e explicação.

## Estrutura

```text
QuickPaste/
  QuickPasteApp.swift        Entrada SwiftUI (cena Settings + AppDelegate).
  AppDelegate.swift          Status item, painel flutuante, atalho global e camada de janelas.
  FloatingPanel.swift        NSPanel não-ativador + roteamento de ⌘-teclas.
  HotKeyManager.swift        Atalho global via Carbon.
  QuickPasteSettings.swift   Chaves/defaults e idiomas suportados.
  EditorView.swift           UI do editor.
  Editor/
    EditorModel.swift        Estado/orquestração (MVVM, @Observable).
    EditorServices.swift     Seams: persistência (RTFD), pasteboard, detecção de idioma.
    NoteTextEditor.swift     Editor NSTextView rich text (⌘V de imagem inline).
    TranslationOutcome.swift Estado da tradução.
  Settings/
    SettingsContent.swift    TabView host.
    GeneralSettingsView.swift, AdvancedSettingsView.swift, DisplaysSettingsView.swift,
    ShortcutsSettingsView.swift, AboutSettingsView.swift
QuickPasteTests/             Testes (Swift Testing).
docs/                        Documentação (Diátaxis).
```

## Privacidade

Tudo é **on-device**: nota (texto + imagens, em RTFD) e preferências ficam em `UserDefaults`;
tradução e detecção de idioma rodam localmente. O app é sandboxed e **sem entitlement de rede**.
Detalhes em [docs/explanation/architecture.md](docs/explanation/architecture.md).
