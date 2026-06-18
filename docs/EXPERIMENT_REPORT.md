# Experimento: reformulação do editor (skills + MCPs)

Branch: `experiment/editor-mvvm` · base: `main` (`6e49562`)

Objetivo: reformular uma parte pequena do QuickPaste exercitando as skills
(`swift-architecture-skill`, `swiftui-pro`, `swift-testing-pro`, `apple-ai-and-models`)
e os MCPs (`apple-docs`, `XcodeBuildMCP`).

## O que foi alterado
Extração de uma camada MVVM no editor, sem mudar o produto:
- `EditorModel` (`@Observable @MainActor`) passa a ser a fonte de verdade do texto,
  da orquestração de tradução (state machine `TranslationOutcome`) e da detecção de idioma.
- Seams por protocolo: `NotePersisting`, `PasteboardWriting`, `LanguageDetecting`
  (impls live + `InMemoryNotePersistence` para previews/testes).
- Persistência **com debounce** (antes: escrita no `UserDefaults` a cada tecla).
- `EditorView` enxuta: liga `$model.text` + `.onChange`, rótulos de acessibilidade
  em todos os botões só-ícone, e preview matrix (vazia / com texto / dark).
- Toque criativo on-device: **detecção de idioma** (NaturalLanguage) exibida na barra
  inferior e usada como `source` da tradução.

## Skills aplicadas
- **swift-architecture-skill** → MVVM + DI por protocolo (fit check: feature única SwiftUI;
  TCA descartado por ser dependência nova).
- **swiftui-pro** → trocou `Binding(get:set:)` por `$model.text`+`.onChange`; a11y labels;
  preview matrix; um-tipo-por-arquivo (`TranslationOutcome` isolado).
- **swift-testing-pro** → testes em `struct` com `#expect`, fakes via DI, `@MainActor`,
  parametrização com `zip`.
- **apple-ai-and-models** → tradução/ID de idioma como stack on-device atrás de adapters;
  privacidade (sandbox sem rede), fallback em `.failed`, sem logar clipboard, sem ação
  destrutiva automática. **Não** apliquei Vision/OCR/Core ML do template (não há esse uso).

## MCPs usados
- **apple-docs** — `get_apple_doc_content`/`get_platform_compatibility` em `TranslationSession`,
  `translationTask(_:action:)` e `NLLanguageRecognizer`. Confirmou: Translation macOS 15+,
  sessão válida só dentro do closure (uso posterior = `fatalError`), NL macOS 10.14+. Isso
  ditou o desenho (estado no model, `translationTask` na View).
- **XcodeBuildMCP** — `session_set_defaults`, `list_schemes`, `show_build_settings`.
  **Limitação:** o workflow **macOS não está habilitado** (só simulador), então o build real
  foi via `xcodebuild` (necessidade legítima, não preguiça). Ver "o que faria diferente".

## Comandos/tools executados
- MCP: `mcp__XcodeBuildMCP__{session_set_defaults,list_schemes,show_build_settings}`,
  `mcp__apple-docs__{search_apple_docs,get_apple_doc_content}`.
- Build (4×, todos `BUILD SUCCEEDED`): `xcodebuild -project QuickPaste.xcodeproj -scheme QuickPaste
  -configuration Debug -derivedDataPath .deriveddata build` (baseline + após cada passo).

## Arquivos
- **Criados:** `QuickPaste/Editor/EditorModel.swift`, `QuickPaste/Editor/EditorServices.swift`,
  `QuickPaste/Editor/TranslationOutcome.swift`, `QuickPasteTests/EditorModelTests.swift`,
  `QuickPasteTests/LanguageDetectorTests.swift`, `docs/EXPERIMENT_REPORT.md`.
- **Modificados:** `QuickPaste/EditorView.swift`, `QuickPaste/QuickPasteSettings.swift`.
- **Removidos:** nenhum arquivo (removido apenas o `static var noteText`, agora via seam).

## Resultado do build/test
- **Build:** `** BUILD SUCCEEDED **` em todos os passos, sem warnings de isolamento após os
  ajustes `nonisolated`.
- **Testes:** escritos (13 casos) mas **não executados** — o `.xcodeproj` não tem test target e
  criá-lo exige editar o `project.pbxproj` (objectVersion 77), risco que evitei para preservar o
  projeto. Os arquivos ficam em `QuickPasteTests/` (fora do grupo sincronizado → não compilam no
  app, confirmado). Para rodar: ver "Plano de testes".

## O que melhorou
- View deixou de ser "fat view": estado/serviços/UI separados e testáveis.
- Persistência com debounce (não escreve a cada tecla).
- Tradução vira state machine explícita (uma só fonte de verdade) com fallback claro.
- Acessibilidade: botões só-ícone agora têm rótulo VoiceOver.
- Feature on-device extra (idioma detectado), 100% local.

## O que piorou / ficou arriscado
- Mais arquivos/indireção num app de ~700 LOC (custo de MVVM; mantido proporcional).
- Detecção de idioma curta é ruidosa (mitigado por `minimumCharacters = 8`); passar `source`
  detectado errado pode, em teoria, piorar a tradução vs. auto-detecção do sistema.
- Golden outputs do NaturalLanguage **não verificados em execução** (testes não rodaram).
- `clear` continua sem confirmação (ação destrutiva) — preservei o comportamento atual.

## O que faria diferente numa implementação real
- Criar o **test target** de verdade (no Xcode) e rodar a suíte; idealmente habilitar o workflow
  **macOS** do XcodeBuildMCP (xcodebuildmcp.com/docs/configuration) para build/test pelo MCP.
- Tornar o debounce injetável por um relógio fake para testar timing de forma determinística.
- Avaliar confirmação para `clear` e talvez `@SceneStorage` para restaurar estado da janela.

## Próximo experimento recomendado
Habilitar o workflow macOS do XcodeBuildMCP + adicionar o test target, e então uma feature de IA
com `apple-ai-and-models` de fato (ex.: resumo on-device via **Foundation Models** atrás de um
adapter, com fallback determinístico e testes via fake client) — medindo se a verificação por
`apple-docs` e os testes mudam a qualidade.

## Plano de testes (para executar)
1. No Xcode: File ▸ New ▸ Target ▸ **Unit Testing Bundle** (`QuickPasteTests`), host = QuickPaste.
2. Adicionar os dois arquivos de `QuickPasteTests/` ao novo target.
3. Rodar `⌘U` (ou, com o workflow macOS do MCP, `test`/`xcodebuild test`).
Cobertura atual: restauração/persistência (`persistNow`), contagens, state machine de tradução
(início, no-op vazio, trim/validação, erro, adoção), efeitos de pasteboard, `clear`, detecção de
idioma (init + `NaturalLanguageDetector` parametrizado + mapeamento BCP-47).
