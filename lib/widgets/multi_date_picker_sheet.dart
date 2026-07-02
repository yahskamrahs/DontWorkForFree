import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Bottom sheet calendar that lets the user tap any combination of
/// individual (not necessarily consecutive) past/present dates.
/// Returns the selected dates (date-only, no time component), or null if
/// the user cancelled without confirming.
Future<Set<DateTime>?> showMultiDatePickerSheet(BuildContext context) {
  return showModalBottomSheet<Set<DateTime>>(
    context: context,
    backgroundColor: const Color(0xFF0F1625),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => const _MultiDatePickerSheet(),
  );
}

class _MultiDatePickerSheet extends StatefulWidget {
  const _MultiDatePickerSheet();

  @override
  State<_MultiDatePickerSheet> createState() => _MultiDatePickerSheetState();
}

class _MultiDatePickerSheetState extends State<_MultiDatePickerSheet> {
  late DateTime _visibleMonth;
  final Set<DateTime> _selected = {};

  static const _firstYear = 2000;

  DateTime get _today => DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  bool get _canGoNext =>
      _visibleMonth.isBefore(DateTime(_today.year, _today.month));
  bool get _canGoPrev => _visibleMonth.isAfter(DateTime(_firstYear, 1));

  void _toggle(DateTime day) {
    setState(() {
      if (_selected.contains(day)) {
        _selected.remove(day);
      } else {
        _selected.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday % 7;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D47),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Leave',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap any dates to mark them as leave.',
              style: TextStyle(color: Color(0xFF5A6478), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _canGoPrev ? () => _changeMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: _canGoPrev ? Colors.white : const Color(0xFF3D4A60),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_visibleMonth),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: _canGoNext ? () => _changeMonth(1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _canGoNext ? Colors.white : const Color(0xFF3D4A60),
                ),
              ],
            ),
            Row(
              children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: Color(0xFF5A6478),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                final day = DateTime(
                    _visibleMonth.year, _visibleMonth.month, index - firstWeekday + 1);
                final isFuture = day.isAfter(_today);
                final isSelected = _selected.contains(day);
                final isToday = day == _today;

                return Padding(
                  padding: const EdgeInsets.all(2),
                  child: Material(
                    color: isSelected
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF162035),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isFuture ? null : () => _toggle(day),
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: isFuture
                                ? const Color(0xFF3D4A60)
                                : isSelected
                                    ? const Color(0xFF080C18)
                                    : Colors.white,
                            fontWeight: isToday || isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _selected.isEmpty
                        ? 'No dates selected'
                        : '${_selected.length} date${_selected.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: Color(0xFF8A97B0), fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF5A6478))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB800),
                    disabledBackgroundColor: const Color(0xFF1E2D47),
                    foregroundColor: const Color(0xFF080C18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Leave',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
