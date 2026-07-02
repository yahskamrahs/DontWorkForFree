import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';

class EarningsMeter extends StatelessWidget {
  const EarningsMeter({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final shift = context.watch<ShiftProvider>();

    if (!settings.hasEarningsData || !shift.isActive) return const SizedBox.shrink();

    final rate = settings.perSecondRate(shift.shiftTarget.inMinutes);
    final workedSec = (shift.shiftTarget.inSeconds * shift.progress).round();
    final earned = rate * workedSec;
    final daily = settings.monthlySalary / settings.currentMonthDays;
    final progressVal = (earned / daily).clamp(0.0, 1.0);

    final fmt = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 14, color: Color(0xFF00E676)),
              const SizedBox(width: 6),
              const Text(
                'EARNED TODAY',
                style: TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Text(
                'of ${fmt.format(daily)}',
                style: const TextStyle(
                  color: Color(0xFF3D4A60),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmt.format(earned),
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressVal,
              backgroundColor: const Color(0xFF1E2D47),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
