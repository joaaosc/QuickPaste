# Changelog

## Não lançado

- Reformula o editor em MVVM (`EditorModel` `@Observable`) com seams por protocolo (persistência,
  pasteboard, detecção de idioma) e persistência da nota com debounce.
- Adiciona detecção de idioma on-device (NaturalLanguage) e rótulos de acessibilidade no editor.
- Adiciona **colar imagem do clipboard com ⌘V** (anexo na nota, persistido como PNG; tradução de
  imagem fora de escopo).
- Adiciona documentação no modelo Diátaxis em `docs/` e atualiza o `README`.
- Adiciona suíte de testes (Swift Testing) em `QuickPasteTests/` (test target a conectar).

## 1.0.0

- Consolida o app em um único target macOS `QuickPaste`.
- Adiciona painel flutuante AppKit com autosave de posição e tamanho.
- Adiciona atalho global `Control + Option + Space`.
- Adiciona editor persistente com contagem de palavras/caracteres.
- Adiciona tradução pelo framework `Translation`.
- Adiciona configurações para inicialização, login, atalho global, fonte e idioma.
- Remove o target auxiliar `QuickPasteConfig` e arquivos compartilhados antigos.
- Adiciona scheme compartilhado para build via Xcode e linha de comando.
