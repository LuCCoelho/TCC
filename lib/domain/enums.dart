enum FieldType {
  texto,
  imagem,
  icone;

  String get label => switch (this) {
        FieldType.texto => 'Texto',
        FieldType.imagem => 'Imagem',
        FieldType.icone => 'Ícone',
      };

  static FieldType parse(String value) {
    return FieldType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => FieldType.texto,
    );
  }
}

enum ExportFormat {
  pdf,
  tabletopSimulator,
  json,
  xml;

  String get label => switch (this) {
        ExportFormat.pdf => 'PDF para impressão',
        ExportFormat.tabletopSimulator => 'Tabletop Simulator',
        ExportFormat.json => 'Metadados JSON',
        ExportFormat.xml => 'Metadados XML',
      };

  String get fileExtension => switch (this) {
        ExportFormat.pdf => 'pdf',
        ExportFormat.tabletopSimulator => 'json',
        ExportFormat.json => 'json',
        ExportFormat.xml => 'xml',
      };

  static ExportFormat parse(String value) {
    return ExportFormat.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ExportFormat.pdf,
    );
  }
}

enum ExportJobStatus {
  pending,
  processing,
  completed,
  failed;

  String get label => switch (this) {
        ExportJobStatus.pending => 'Pendente',
        ExportJobStatus.processing => 'Processando',
        ExportJobStatus.completed => 'Concluído',
        ExportJobStatus.failed => 'Falhou',
      };

  static ExportJobStatus parse(String value) {
    return ExportJobStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ExportJobStatus.pending,
    );
  }
}

enum SyncPhase {
  synced,
  pending,
  syncing,
  offline,
  error;

  String get label => switch (this) {
        SyncPhase.synced => 'Sincronizado',
        SyncPhase.pending => 'Pendente',
        SyncPhase.syncing => 'Sincronizando',
        SyncPhase.offline => 'Offline',
        SyncPhase.error => 'Falha na sincronização',
      };
}
