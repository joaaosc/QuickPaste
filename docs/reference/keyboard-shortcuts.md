# Referência: atalhos e configurações

## Atalhos de teclado

| Atalho | Ação | Onde |
|---|---|---|
| **⌃⌥Espaço** | Mostrar/ocultar a nota | Global (configurável) |
| **⌘V** | Colar texto, ou **imagem** do clipboard (se não houver texto) | Editor em foco |
| **⌘C / ⌘X / ⌘A** | Copiar / recortar / selecionar tudo | Editor em foco |
| **⌘Z / ⇧⌘Z** | Desfazer / refazer | Editor em foco |
| **⌘W** | Ocultar o painel | Painel |
| **⌘,** | Abrir configurações | Janela do app em foco |
| **⌘Q** | Sair do QuickPaste | App |
| **Esc** | Ocultar o painel | Painel |

Ações da barra inferior: traduzir (🌐), copiar nota (⧉), limpar (🗑) e o seletor de idioma de destino.

## Configurações (`Settings`)

| Seção | Opção | Padrão |
|---|---|---|
| Geral | Abrir a nota ao iniciar o app | desligado |
| Geral | Iniciar no login (`SMAppService`) | desligado |
| Geral | Atalho global ⌃⌥Espaço | ligado |
| Editor | Tamanho da fonte | 14 (10–28) |
| Tradução | Idioma de destino | Inglês |

Idiomas suportados na tradução: Português, Inglês, Espanhol, Francês, Alemão, Italiano, Japonês,
Chinês (simplificado).

## Persistência (`UserDefaults`)

| Chave | Conteúdo |
|---|---|
| `noteText` | Texto da nota |
| `noteImageData` | Imagem anexada (PNG) |
| `editorFontSize` | Tamanho da fonte |
| `targetLanguage` | Idioma de destino |
| `openEditorAtLaunch`, `globalHotKeyEnabled` | Preferências gerais |
