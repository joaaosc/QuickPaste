# QuickPaste

QuickPaste é um app de barra de menus para macOS que mantém uma nota rápida sempre acessível. Ele abre um painel flutuante estilo Spotlight, permite editar texto, copiar o conteúdo para a área de transferência e traduzir a nota pelo framework Translation da Apple.

## Recursos

- Ícone na barra de menus com clique esquerdo para mostrar/ocultar a nota.
- Menu contextual com acesso às configurações e saída do app.
- Painel flutuante redimensionável com autosave de posição e tamanho.
- Atalho global `Control + Option + Space`.
- Editor com contagem de palavras/caracteres e tamanho de fonte configurável.
- Persistência local da nota em `UserDefaults`.
- Tradução para português, inglês, espanhol, francês, alemão, italiano, japonês e chinês simplificado.
- Opção para abrir a nota ao iniciar o app e iniciar o app no login.

## Requisitos

- macOS com suporte ao framework `Translation`.
- Xcode 26.5 ou superior, conforme configuração atual do projeto.
- Conta de desenvolvimento Apple configurada no Xcode para assinatura automática.

## Como rodar

Abra `QuickPaste.xcodeproj` no Xcode e execute o scheme `QuickPaste`.

Pela linha de comando:

```sh
xcodebuild -project QuickPaste.xcodeproj \
  -scheme QuickPaste \
  -configuration Debug \
  -derivedDataPath .deriveddata \
  build
```

O build local usa `.deriveddata/`, que é ignorado pelo Git.

## Estrutura

```text
QuickPaste/
  AppDelegate.swift          Ciclo de vida, status item, painel e atalho global.
  EditorView.swift           Editor principal, ações de copiar/limpar e tradução.
  FloatingPanel.swift        NSPanel customizado para comportamento flutuante.
  HotKeyManager.swift        Registro do atalho global via Carbon.
  QuickPasteApp.swift        Entrada SwiftUI do app.
  QuickPasteSettings.swift   Chaves, defaults e idiomas suportados.
  SettingsContent.swift      Tela de configurações.
docs/
  RELEASE_CHECKLIST.md       Checklist para preparar uma release.
```

## Git

O branch de trabalho atual é `AppKit-version`. A versão final esperada consolida o app em um único target `QuickPaste`, remove o target auxiliar `QuickPasteConfig` e mantém o scheme `QuickPaste` compartilhado em `QuickPaste.xcodeproj/xcshareddata/xcschemes/`.

Antes de fechar uma release:

```sh
git status --short --branch
xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste -configuration Release -derivedDataPath .deriveddata build
```

## Privacidade

A nota e preferências ficam em `UserDefaults` no dispositivo. O app não adiciona backend próprio nem grava arquivos de usuário diretamente.
