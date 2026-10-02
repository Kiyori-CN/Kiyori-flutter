enum AvatarModelType {
  dragonbones('DRAGONBONES'),
  webp('WEBP'),
  mp4('MP4'),
  mmd('MMD'),
  gltf('GLTF'),
  fbx('FBX');

  const AvatarModelType(this.label);
  final String label;
}

class AvatarPresentation {
  const AvatarPresentation({
    this.models = const [],
    this.currentId,
    this.enabled = false,
    this.loading = false,
    this.importing = false,
  });
  final List<AvatarModelPresentation> models;
  final String? currentId;
  final bool enabled, loading, importing;
}

class AvatarModelPresentation {
  const AvatarModelPresentation({
    required this.id,
    required this.name,
    required this.type,
    this.animations = const [],
    this.mappings = const {},
    this.customMoods = const [],
    this.settings = const {},
  });
  final String id, name;
  final AvatarModelType type;
  final List<String> animations;
  final Map<String, String> mappings;
  final List<AvatarMoodPresentation> customMoods;
  final Map<String, double> settings;
}

class AvatarMoodPresentation {
  const AvatarMoodPresentation(
    this.key,
    this.title,
    this.hint, [
    this.fallback,
  ]);
  final String key, title, hint;
  final String? fallback;
}

const avatarBuiltInMoods = [
  AvatarMoodPresentation('angry', '生气', '用户表达侮辱、不公、责备、生气或强烈不满时使用。', '难过'),
  AvatarMoodPresentation('happy', '开心', '用户表达明确表扬、达成目标、收到礼物或明显开心时使用。', '开心'),
  AvatarMoodPresentation('shy', '害羞', '用户夸奖、暧昧、戳中可爱点，角色表现害羞时使用。', '困惑'),
  AvatarMoodPresentation('aojiao', '傲娇', '用户调侃、轻微争执、角色嘴硬又软化时使用。', '困惑'),
  AvatarMoodPresentation('cry', '难过', '用户失落、难过、受挫、哭诉或道歉后低落时使用。', '难过'),
];

/// 参数仅随这个目录实体的本次存在而存活，不写配置或驱动原生渲染。
class AvatarDraft {
  AvatarDraft(AvatarModelPresentation model)
    : values = {
        'scale': model.type == AvatarModelType.dragonbones ? .5 : 1.0,
        'x': 0,
        'y': 0,
        ...model.settings,
      },
      mappings = Map.of(model.mappings);
  final Map<String, double> values;
  final Map<String, String> mappings;
}
