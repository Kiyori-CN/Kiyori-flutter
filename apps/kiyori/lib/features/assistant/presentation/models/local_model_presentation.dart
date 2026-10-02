/// 共享下载服务提供的只读事实；页面不扫描模型目录或创建下载任务。
class LocalModelsPresentation {
  const LocalModelsPresentation({
    this.models = const [],
    this.loading = false,
    this.error = false,
  });
  final List<LocalModelPresentation> models;
  final bool loading, error;
}

enum LocalModelPhase {
  idle,
  connecting,
  downloading,
  paused,
  completed,
  failed,
}

class LocalModelPresentation {
  const LocalModelPresentation({
    required this.id,
    required this.name,
    required this.sizeGb,
    this.description = '',
    this.tags = const [],
    this.hasSource = false,
    this.downloaded = false,
    this.phase = LocalModelPhase.idle,
    this.progress = 0,
    this.transferred = '',
    this.speed = '',
    this.currentFile = '',
    this.currentFileIndex = 0,
    this.totalFiles = 0,
    this.error = '',
  });
  final String id, name, description, transferred, speed, currentFile, error;
  final List<String> tags;
  final double sizeGb, progress;
  final bool hasSource, downloaded;
  final LocalModelPhase phase;
  final int currentFileIndex, totalFiles;
  double get boundedProgress =>
      progress.isFinite ? progress.clamp(0.0, 1.0) : 0;
  bool get canDelete =>
      phase == LocalModelPhase.paused ||
      phase == LocalModelPhase.completed ||
      phase == LocalModelPhase.failed ||
      (phase == LocalModelPhase.idle && downloaded);
}
