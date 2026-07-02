import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shift_record_model.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../widgets/multi_date_picker_sheet.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ShiftRecordModel> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await DatabaseService.instance.getRecentRecords();
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  Future<void> _delete(int id) async {
    await DatabaseService.instance.deleteRecord(id);
    await _load();
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All History?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'All shift records will be permanently deleted.',
          style: TextStyle(color: Color(0xFF8A97B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF5A6478))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear All',
                style: TextStyle(color: Color(0xFFFF1744))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DatabaseService.instance.clearAll();
      await _load();
    }
  }

  // Group records by week label
  Map<String, List<ShiftRecordModel>> _grouped() {
    final result = <String, List<ShiftRecordModel>>{};
    for (final r in _records) {
      final dt = r.punchInTime;
      final monday = dt.subtract(Duration(days: dt.weekday - 1));
      final label =
          'Week of ${DateFormat('MMM d').format(monday)}';
      result.putIfAbsent(label, () => []).add(r);
    }
    return result;
  }

  Duration _weekSurplus(List<ShiftRecordModel> week) =>
      week.where((r) => r.profileId != 'LEAVE').fold(Duration.zero, (acc, r) => acc + r.surplus);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final groups = _grouped();
    final fmt = NumberFormat.currency(
        symbol: settings.currencySymbol, decimalDigits: 0);

    final monthRecords = _records.where((r) {
      final now = DateTime.now();
      return r.punchInTime.year == now.year && r.punchInTime.month == now.month && r.profileId != 'LEAVE';
    }).toList();
    final monthSurplus = monthRecords.fold(Duration.zero, (acc, r) => acc + r.surplus);
    final isMonthPos = monthSurplus >= Duration.zero;
    final mSecs = monthSurplus.inSeconds.abs();
    final mH = mSecs ~/ 3600;
    final mM = (mSecs % 3600) ~/ 60;
    final monthSurplusStr = mSecs < 60 ? 'Perfect Average' : '${isMonthPos ? '+' : '-'}${mH > 0 ? '${mH}h ' : ''}${mM}m';

    return Scaffold(
      backgroundColor: const Color(0xFF080C18),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final dates = await showMultiDatePickerSheet(context);
          if (dates != null && dates.isNotEmpty && mounted) {
            for (final date in dates) {
              final leaveRecord = ShiftRecordModel(
                date: ShiftRecordModel.dateKey(date),
                punchIn: date.toIso8601String(),
                punchOut: date.toIso8601String(),
                totalBreakSeconds: 0,
                scheduledDurationMinutes: 0,
                profileId: 'LEAVE',
                profileName: 'Leave Day',
              );
              await DatabaseService.instance.insertRecord(leaveRecord);
            }
            _load();
          }
        },
        backgroundColor: const Color(0xFFFFB800),
        icon: const Icon(Icons.event_busy_rounded, color: Color(0xFF080C18)),
        label: const Text('Add Leave', style: TextStyle(color: Color(0xFF080C18), fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SHIFT', style: TextStyle(color: Color(0xFF5A6478), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2)),
                      Text('History', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const Spacer(),
                  if (_records.isNotEmpty)
                    IconButton(
                      onPressed: () => _clearAll(context),
                      icon: const Icon(Icons.delete_sweep_outlined,
                          color: Color(0xFF3D4A60)),
                      tooltip: 'Clear all history',
                    ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF5A6478)),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_records.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isMonthPos ? const Color(0xFF00E676) : const Color(0xFFFF1744)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (isMonthPos ? const Color(0xFF00E676) : const Color(0xFFFF1744)).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(isMonthPos ? Icons.trending_up_rounded : Icons.trending_down_rounded, 
                           color: isMonthPos ? const Color(0xFF00E676) : const Color(0xFFFF1744), size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Monthly Average Status', style: TextStyle(color: isMonthPos ? const Color(0xFF00E676) : const Color(0xFFFF1744), fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(isMonthPos ? 'Surplus: $monthSurplusStr' : 'Lost Time: $monthSurplusStr', 
                                 style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFFFB800), strokeWidth: 2))
                  : _records.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: const Color(0xFFFFB800),
                          backgroundColor: const Color(0xFF0F1625),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: groups.length,
                            itemBuilder: (context, i) {
                              final weekLabel = groups.keys.elementAt(i);
                              final weekRecords = groups[weekLabel]!;
                              final surplus = _weekSurplus(weekRecords);
                              return _WeekGroup(
                                label: weekLabel,
                                surplus: surplus,
                                records: weekRecords,
                                currencyFmt: fmt,
                                settings: settings,
                                onDelete: _delete,
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history_rounded, size: 64, color: Color(0xFF1E2D47)),
          const SizedBox(height: 16),
          const Text('No shifts recorded yet.',
              style: TextStyle(color: Color(0xFF5A6478), fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Complete your first shift to see history here.',
            style: TextStyle(color: Color(0xFF3D4A60), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Week group ───────────────────────────────────────────────────────────────

class _WeekGroup extends StatelessWidget {
  final String label;
  final Duration surplus;
  final List<ShiftRecordModel> records;
  final NumberFormat currencyFmt;
  final SettingsProvider settings;
  final Future<void> Function(int id) onDelete;

  const _WeekGroup({
    required this.label,
    required this.surplus,
    required this.records,
    required this.currencyFmt,
    required this.settings,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPos = surplus >= Duration.zero;
    final absSecs = surplus.inSeconds.abs();
    final h = absSecs ~/ 3600;
    final m = (absSecs % 3600) ~/ 60;
    final surplusLabel = absSecs < 60
        ? 'Balanced'
        : '${isPos ? '+' : '-'}${h > 0 ? '${h}h ' : ''}${m}m';

    // Total worked this week
    final totalWorked = records.fold<Duration>(
        Duration.zero, (acc, r) => acc + r.workedDuration);
    final twH = totalWorked.inHours;
    final twM = totalWorked.inMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF5A6478),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isPos ? const Color(0xFF00E676) : const Color(0xFFFF6B6B))
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                surplusLabel,
                style: TextStyle(
                  color: isPos ? const Color(0xFF00E676) : const Color(0xFFFF6B6B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${twH}h ${twM}m total',
              style: const TextStyle(color: Color(0xFF3D4A60), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...records.map((r) => _RecordTile(
              record: r,
              settings: settings,
              currencyFmt: currencyFmt,
              onDelete: () => onDelete(r.id!),
            )),
      ],
    );
  }
}

// ─── Individual record tile ───────────────────────────────────────────────────

class _RecordTile extends StatelessWidget {
  final ShiftRecordModel record;
  final SettingsProvider settings;
  final NumberFormat currencyFmt;
  final VoidCallback onDelete;

  const _RecordTile({
    required this.record,
    required this.settings,
    required this.currencyFmt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inFmt = DateFormat('h:mm a').format(record.punchInTime);
    final outFmt = record.punchOutTime != null
        ? DateFormat('h:mm a').format(record.punchOutTime!)
        : '--';
    final dayFmt = DateFormat('EEE, MMM d').format(record.punchInTime);
    final wh = record.workedDuration.inHours;
    final wm = record.workedDuration.inMinutes % 60;
    final surplus = record.surplus;
    final isPos = surplus >= Duration.zero;
    final surplusSecs = surplus.inSeconds.abs();
    final sh = surplusSecs ~/ 3600;
    final sm = (surplusSecs % 3600) ~/ 60;
    final surplusStr = surplusSecs < 60
        ? null
        : '${isPos ? '+' : '-'}${sh > 0 ? '${sh}h ' : ''}${sm}m';

    // Earnings (if salary configured)
    double? earned;
    if (settings.hasEarningsData) {
      final rate = settings.perSecondRate(record.scheduledDurationMinutes);
      earned = rate * record.workedDuration.inSeconds;
    }

    return GestureDetector(
      onLongPress: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0F1625),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Record?', style: TextStyle(color: Colors.white)),
            content: const Text('Are you sure you want to delete this record?', style: TextStyle(color: Color(0xFF8A97B0))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A6478)))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFFF1744)))),
            ],
          ),
        );
        if (ok == true) onDelete();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2D47)),
        ),
        child: Row(
          children: [
            // Date column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayFmt,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(record.profileName,
                    style: const TextStyle(
                        color: Color(0xFF3D4A60), fontSize: 11)),
              ],
            ),
            const Spacer(),
            // Times + duration
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (record.profileId == 'LEAVE')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('LEAVE', style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  )
                else ...[
                  Text('$inFmt → $outFmt',
                      style: const TextStyle(
                          color: Color(0xFF8A97B0), fontSize: 12)),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${wh}h ${wm}m',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    if (surplusStr != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isPos
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF6B6B))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          surplusStr,
                          style: TextStyle(
                            color: isPos
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF6B6B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ],
                if (earned != null && record.profileId != 'LEAVE')
                  Text(
                    currencyFmt.format(earned),
                    style: const TextStyle(
                        color: Color(0xFF5A6478), fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
