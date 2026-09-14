# Plano de Implementação das Telas — App de Cartas Personalizadas

Documento de acompanhamento. A stack adotada é Flutter + Riverpod + drift + go_router.

## 2. Ordem de implementação (fases)

- [x] **Fase 0 — Fundação de dados**: schema drift para as 8 entidades + tabela `change_logs` (ajuste necessário à tela 3.12), repositórios (CRUD + soft delete + `updated_at`), seed de dados de teste.
- [x] **Fase 1 — Núcleo do fluxo criativo**: Home/Dashboard → Criação/Edição de Blueprint → Lista de Cartas da Coleção → Editor Individual de Carta.
- [x] **Fase 2 — Produtividade em lote**: edição em lote na Lista de Cartas, Importação de CSV.
- [x] **Fase 3 — Saída**: Preview da Carta, Exportação (PDF, Tabletop Simulator, JSON/XML).
- [x] **Fase 4 — Telas de menor prioridade**: Gerenciamento de Coleções/Pastas, Configurações de Conta/Sincronização, Onboarding, Galeria de Blueprints, Histórico e Controle de Versão.

## 3. Especificação das telas

### 3.1 Home / Dashboard *(Fase 1)*
- [x] Concluído — `lib/screens/home/`

### 3.2 Criação/Edição de Blueprint *(Fase 1)*
- [x] Concluído — `lib/screens/blueprint_editor/`

### 3.3 Lista de Cartas da Coleção *(Fase 1 / Fase 2)*
- [x] Concluído — `lib/screens/collection_cards/`

### 3.4 Editor Individual de Carta *(Fase 1)*
- [x] Concluído — `lib/screens/card_editor/`

### 3.5 Importação de CSV *(Fase 2)*
- [x] Concluído — `lib/screens/csv_import/`

### 3.6 Preview da Carta *(Fase 3)*
- [x] Concluído — `lib/screens/card_preview/`

### 3.7 Exportação *(Fase 3)*
- [x] Concluído — `lib/screens/export/`

### 3.8 Gerenciamento de Coleções/Pastas *(Fase 4)*
- [x] Concluído — `lib/screens/collections/`

### 3.9 Configurações de Conta / Sincronização *(Fase 4)*
- [x] Concluído — `lib/screens/settings/` (`SyncRepository` abstrato; implementação local simulada)

### 3.10 Onboarding / Tutorial *(Fase 4)*
- [x] Concluído — `lib/screens/onboarding/`

### 3.11 Galeria de Blueprints *(Fase 4)*
- [x] Concluído — `lib/screens/blueprint_gallery/`

### 3.12 Histórico e Controle de Versão *(Fase 4)*
- [x] Concluído — `lib/screens/history/` (schema extra: tabela `change_logs`)

## 4. Componentes compartilhados

- [x] **FieldRenderer** — `lib/widgets/field_renderer.dart` (+ `CardFace`)
- [x] **SyncStatusBadge** — `lib/widgets/sync_status_badge.dart`
- [x] **ImagePickerHelper** — `lib/widgets/image_picker_helper.dart`
- [x] **CardCanvasScaler** — `lib/widgets/card_canvas_scaler.dart`
