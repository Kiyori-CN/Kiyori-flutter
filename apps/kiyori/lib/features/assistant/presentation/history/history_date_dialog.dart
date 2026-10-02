part of 'chat_history_page.dart';

/// 对应旧 Compose DatePickerDialog：480px 内日历正文，底部取消/确认。
/// 日期仅为弹层草稿，确认后交还记忆重建草稿，不发起任务。
class _HistoryDateDialog extends StatefulWidget {
  const _HistoryDateDialog({this.initial});
  final DateTimeRange? initial;
  @override
  State<_HistoryDateDialog> createState() => _HistoryDateDialogState();
}

class _HistoryDateDialogState extends State<_HistoryDateDialog> {
  late DateTime? start = widget.initial?.start, end = widget.initial?.end;
  final inputKey = GlobalKey<FormState>();
  String? rangeError;
  late final ScrollController months;
  bool input = false;
  double monthHeight = 336;
  @override
  void initState() {
    super.initState();
    final date = start ?? DateTime.now();
    months = ScrollController(
      initialScrollOffset:
          ((date.year - 1900) * 12 + date.month - 1) * monthHeight,
    );
  }

  @override
  void dispose() {
    months.dispose();
    super.dispose();
  }

  void select(DateTime date) => setState(() {
    if (start == null || end != null || date.isBefore(start!)) {
      start = date;
      end = null;
    } else {
      end = date;
    }
  });

  String label(DateTime? date, String fallback) =>
      date == null ? fallback : '${date.month}月${date.day}日';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final nextHeight = 48.0 + 6 * (48 * scale.clamp(1.0, 2.0));
    if (nextHeight != monthHeight) {
      final month = months.hasClients
          ? months.offset / monthHeight
          : months.initialScrollOffset / monthHeight;
      monthHeight = nextHeight;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && months.hasClients) months.jumpTo(month * monthHeight);
      });
    }
    return Dialog(
      key: const ValueKey('history-date-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: 480,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '记忆重建日期范围',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${label(start, '开始日期')} – ${label(end, '结束日期')}',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                IconButton(
                                  tooltip: input ? '切换到日历输入模式' : '切换到文本输入模式',
                                  onPressed: () =>
                                      setState(() => input = !input),
                                  icon: Icon(
                                    input
                                        ? Icons.calendar_today
                                        : Icons.edit_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (input)
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: inputKey,
                              child: Column(
                                children: [
                                  InputDatePickerFormField(
                                    initialDate: start,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2100, 12, 31),
                                    fieldLabelText: '开始日期',
                                    onDateSaved: (date) => start = date,
                                  ),
                                  const SizedBox(height: 16),
                                  InputDatePickerFormField(
                                    initialDate: end,
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2100, 12, 31),
                                    fieldLabelText: '结束日期',
                                    onDateSaved: (date) => end = date,
                                  ),
                                  if (rangeError != null)
                                    Text(
                                      rangeError!,
                                      style: TextStyle(color: colors.error),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              for (final day in [
                                '日',
                                '一',
                                '二',
                                '三',
                                '四',
                                '五',
                                '六',
                              ])
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: months,
                            itemExtent: monthHeight,
                            itemCount: 201 * 12,
                            itemBuilder: (context, index) {
                              final month = DateTime(
                                1900 + index ~/ 12,
                                index % 12 + 1,
                              );
                              final offset = month.weekday % 7;
                              final count = DateTime(
                                month.year,
                                month.month + 1,
                                0,
                              ).day;
                              return Column(
                                children: [
                                  SizedBox(
                                    height: 48,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                      ),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${month.year}年${month.month}月',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (var week = 0; week < 6; week++)
                                    SizedBox(
                                      height: (monthHeight - 48) / 6,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            for (var day = 0; day < 7; day++)
                                              Expanded(
                                                child: Builder(
                                                  builder: (context) {
                                                    final number =
                                                        week * 7 +
                                                        day -
                                                        offset +
                                                        1;
                                                    if (number < 1 ||
                                                        number > count) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    final date = DateTime(
                                                      month.year,
                                                      month.month,
                                                      number,
                                                    );
                                                    final selected =
                                                        date == start ||
                                                        date == end;
                                                    final between =
                                                        start != null &&
                                                        end != null &&
                                                        date.isAfter(start!) &&
                                                        date.isBefore(end!);
                                                    final today =
                                                        DateUtils.isSameDay(
                                                          date,
                                                          DateTime.now(),
                                                        );
                                                    return Material(
                                                      color: selected
                                                          ? colors.primary
                                                          : between
                                                          ? colors
                                                                .primaryContainer
                                                          : Colors.transparent,
                                                      shape: selected || today
                                                          ? CircleBorder(
                                                              side:
                                                                  today &&
                                                                      !selected
                                                                  ? BorderSide(
                                                                      color: colors
                                                                          .primary,
                                                                    )
                                                                  : BorderSide
                                                                        .none,
                                                            )
                                                          : null,
                                                      child: InkWell(
                                                        key: ValueKey(
                                                          'history-date-${month.year}-${month.month}-$number',
                                                        ),
                                                        customBorder:
                                                            const CircleBorder(),
                                                        onTap: () =>
                                                            select(date),
                                                        child: Center(
                                                          child: Text(
                                                            '$number',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: selected
                                                                  ? colors
                                                                        .onPrimary
                                                                  : colors
                                                                        .onSurface,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: input || (start != null && end != null)
                        ? () {
                            if (input &&
                                !(inputKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            if (input) inputKey.currentState!.save();
                            if (start != null &&
                                end != null &&
                                end!.isBefore(start!)) {
                              setState(() => rangeError = '结束日期不得早于开始日期');
                              return;
                            }
                            if (start != null && end != null) {
                              Navigator.of(context)
                                  .pop(DateTimeRange(start: start!, end: end!));
                            }
                          }
                        : null,
                    child: const Text('确认'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
