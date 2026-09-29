# Naipe

Estúdio **offline-first** em Flutter para criação, gestão e exportação de cartas de jogos personalizadas (estilo TCG).

O app trabalha com **blueprints** (modelos mestres reutilizáveis), edição em lote, importação **CSV** e exportação para **PDF**, metadados **JSON/XML** e **Tabletop Simulator**. A sincronização em nuvem fica atrás de um `SyncRepository` — a implementação atual é local/simulada para não travar as telas.

## Stack

- Flutter + Riverpod + go_router
- Persistência local: drift (SQLite)
- Imagens: image_picker + path_provider
- CSV: csv + file_picker
- PDF: pdf + printing

## Demo pública (GitHub Pages)

Versão web publicada automaticamente a cada push em `master`:

**https://luccoelho.github.io/TCC/**

É a build web (não APK/iOS). Câmera/galeria ficam limitadas no navegador; o restante do fluxo (seed, blueprint, coleção, CSV, export) funciona offline no browser.

## Como rodar

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Na primeira execução o banco é populado com o projeto de demonstração **Círculo de Bruma**.

## Estrutura

- `lib/data/` — schema, repositórios, seed, sync e exportação
- `lib/screens/` — uma pasta por tela, sempre falando com repositórios (nunca com o banco direto)
- `lib/widgets/` — FieldRenderer, CardFace, SyncStatusBadge, ImagePickerHelper, CardCanvasScaler
