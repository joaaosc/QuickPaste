# Release Checklist

Use este checklist antes de marcar a versão final.

## Código

- Confirmar que `xcodebuild -list -project QuickPaste.xcodeproj` mostra apenas o target e scheme `QuickPaste`.
- Rodar build Debug:

```sh
xcodebuild -project QuickPaste.xcodeproj \
  -scheme QuickPaste \
  -configuration Debug \
  -derivedDataPath .deriveddata \
  build
```

- Rodar build Release:

```sh
xcodebuild -project QuickPaste.xcodeproj \
  -scheme QuickPaste \
  -configuration Release \
  -derivedDataPath .deriveddata \
  build
```

## Validação manual

- Abrir o app e confirmar que o ícone aparece na barra de menus.
- Confirmar que clique esquerdo mostra/oculta o painel.
- Confirmar que clique direito abre o menu com configurações e sair.
- Confirmar que `Control + Option + Space` mostra/oculta o painel quando habilitado.
- Editar texto, fechar e abrir o painel para validar persistência.
- Copiar a nota inteira para a área de transferência.
- Traduzir uma nota curta para cada idioma crítico da release.
- Alterar tamanho da fonte nas configurações e validar o editor.
- Habilitar/desabilitar início no login e confirmar que não há erro visível.

## Git

- Confirmar que artefatos locais não aparecem no status:

```sh
git status --short --branch
```

- Conferir diff final:

```sh
git diff --stat
git diff --cached --stat
```

- Criar commit de release em um estado revisado:

```sh
git add -A
git commit -m "Prepara versão final do QuickPaste"
```
