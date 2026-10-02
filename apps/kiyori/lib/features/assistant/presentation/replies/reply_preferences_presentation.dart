/// 回复配置的展示快照，不拥有角色存储或消息发送策略。
class ReplyPreferencesPresentation {
  const ReplyPreferencesPresentation({
    this.targetName = '',
    this.enabled = false,
    this.mergeSend = false,
    this.mergeDelay = 5000,
    this.charDelay = 250,
    this.removePunctuation = false,
    this.emoticons = false,
    this.selfie = false,
    this.customPrompt = '你必须遵守：禁止使用动作表情，禁止描述动作表情，只允许使用纯文本进行对话。',
    this.selfiePrompt = 'kipfel vrchat, long hair, Matcha color hair, purple eyes, sweater vest, black skirt, black necktie, collared shirt, long sleeves, black headwear, beanie, pleated skirt, hair bun, white shirt, hair ribbon, hairclip, hair between eyes, black footwear, blush, hair ornament, cat hat, very long hair, sweater, animal ear headwear, bag, bandaid on leg, socks',
  });
  final String targetName, customPrompt, selfiePrompt;
  final bool enabled, mergeSend, removePunctuation, emoticons, selfie;
  final int mergeDelay, charDelay;
}
