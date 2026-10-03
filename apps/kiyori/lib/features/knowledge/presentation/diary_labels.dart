const diaryPhases = {
  'note': '记录',
  'plan': '计划',
  'progress': '进展',
  'decision': '决策',
  'evidence': '证据',
  'risk': '风险',
  'validation': '验证',
};

String diaryPhaseLabel(String phase, String? raw) =>
    phase == 'note' && raw != null && raw.toLowerCase() != 'note'
    ? raw
    : phase == 'closed'
    ? '收尾'
    : diaryPhases[phase] ?? raw ?? '记录';
