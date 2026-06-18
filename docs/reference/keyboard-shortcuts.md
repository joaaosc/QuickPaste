# Referência: atalhos e configurações

## Atalhos de teclado

| Atalho | Ação | Onde |
|---|---|---|
| **⌃⌥Espaço** | Mostrar/ocultar a nota (atalho fixo) | Global (configurável) |
| **(personalizado)** | Mostrar/ocultar a nota | Global (definido em Configurações ▸ Atalhos) |
| **⌘V** | Colar texto, ou **imagem inline** do clipboard (se não houver texto) | Editor em foco |
| **⌘C / ⌘X / ⌘A** | Copiar / recortar / selecionar tudo | Editor em foco |
| **⌘Z / ⇧⌘Z** | Desfazer / refazer | Editor em foco |
| **⌘W** | Ocultar o painel | Painel |
| **⌘,** | Abrir configurações | Janela do app em foco |
| **⌘Q** | Sair do QuickPaste | App |
| **Esc** | Ocultar o painel | Painel |

Ações da barra inferior: abrir configurações (⚙︎), traduzir (🌐), copiar nota (⧉), limpar (🗑) e o
seletor de idioma de destino.

## Configurações (abas)

| Aba | Opções |
|---|---|
| **Geral** | Abrir a nota ao iniciar · Iniciar no login (`SMAppService`) · Atalho global ⌃⌥Espaço |
| **Avançado** | Habilitar tradução · Idioma de destino · Permitir colar mais de uma imagem · OCR em imagens *(em breve)* |
| **Telas** | Tamanho da fonte (10–28) · Comportamento da janela |
| **Atalhos** | **Atalho personalizado** (gravador) + referência dos atalhos |
| **Sobre** | Versão e informações do app |

Idiomas suportados na tradução: Português, Inglês, Espanhol, Francês, Alemão, Italiano, Japonês,
Chinês (simplificado).

## Persistência (`UserDefaults`)

| Chave | Conteúdo |
|---|---|
| `noteRTFD` | Nota como RTFD (texto + imagens inline) |
| `noteText` | Texto da nota (espelho em texto puro / migração) |
| `editorFontSize` | Tamanho da fonte |
| `targetLanguage` | Idioma de destino |
| `translationEnabled` | Tradução habilitada (padrão: sim) |
| `ocrEnabled` | OCR em imagens (sem efeito ainda) |
| `allowMultipleImages` | Permitir mais de uma imagem (padrão: não) |
| `customHotKeyKeyCode` / `customHotKeyModifiers` / `customHotKeyDisplay` | Atalho personalizado (padrão: vazio, keyCode −1) |
| `openEditorAtLaunch`, `globalHotKeyEnabled` | Preferências gerais |
