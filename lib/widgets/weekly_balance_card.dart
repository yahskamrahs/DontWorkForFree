import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';
import '../services/database_service.dart';

class WeeklyBalanceCard extends StatefulWidget {
  const WeeklyBalanceCard({super.key});

  @override
  State<WeeklyBalanceCard> createState() => _WeeklyBalanceCardState();
}

class _WeeklyBalanceCardState extends State<WeeklyBalanceCard> {
  Duration _balance = Duration.zero;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(WeeklyBalanceCard old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final monday = _getMonday(DateTime.now());
    final records = await DatabaseService.instance.getWeekRecords(monday);
    Duration total = Duration.zero;
    for (final r in records) {
      total += r.surplus;
    }
    if (mounted) {
      setState(() {
        _balance = total;
        _loaded = true;
      });
    }
  }

  DateTime _getMonday(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  @override
  Widget build(BuildContext context) {
    // Re-load when shift state changes (e.g., after punch-out)
    context.watch<ShiftProvider>();

    if (!_loaded) return const SizedBox.shrink();

    final isPositive = _balance >= Duration.zero;
    final absSecs = _balance.inSeconds.abs();
    final h = absSecs ~/ 3600;
    final m = (absSecs % 3600) ~/ 60;

    String label;
    if (absSecs < 60) {
      label = 'Balanced this week';
    } else if (isPositive) {
      final parts = [if (h > 0) '${h}h', if (m > 0) '${m}m'];
      label = '+${parts.join(' ')} banked — leave early today!';
    } else {
      final parts = [if (h > 0) '${h}h', if (m > 0) '${m}m'];
      label = '-${parts.join(' ')} owed this week';
    }

    final color = isPositive ? const Color(0xFF00E676) : const Color(0xFFFF6B6B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEEKLY BALANCE',
                  style: TextStyle(
                    color: Color(0xFF5A6478),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _load,
            child: const Icon(Icons.refresh_rounded,
                size: 16, color: Color(0xFF3D4A60)),
          ),
        ],
      ),
    );
  }
}
