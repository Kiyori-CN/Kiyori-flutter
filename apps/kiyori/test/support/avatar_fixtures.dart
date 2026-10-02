import 'package:kiyori/features/assistant/presentation/avatar_settings_page.dart';

const avatarA = AvatarModelPresentation(
  id: 'a',
  name: '模型甲',
  type: AvatarModelType.gltf,
  animations: ['idle', 'wave'],
  mappings: {'happy': 'wave'},
  customMoods: [AvatarMoodPresentation('hello', 'hello', '测试问候场景')],
);
const avatarB = AvatarModelPresentation(
  id: 'b',
  name: '模型乙',
  type: AvatarModelType.mmd,
);
const avatarSnapshot = AvatarPresentation(
  models: [avatarA, avatarB],
  currentId: 'a',
);
