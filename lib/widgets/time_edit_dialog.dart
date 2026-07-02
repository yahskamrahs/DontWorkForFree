import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shift_provider.dart';

Future<void> showTimeEditDialog(BuildContext context) async {
  final provider = context.read<ShiftProvider>();
  final current = provider.punchInTime ?? DateTime.now();

  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(current),
    helpText: 'SET ACTUAL PUNCH-IN TIME',
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: const Color(0xFFFFB800),
              onSurface: Colors.white,
              surface: const Color(0xFF162035),
            ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF0F1625),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF0F1625),
          dialBackgroundColor: const Color(0xFF162035),
          hourMinuteColor: const Color(0xFF162035),
          hourMinuteTextColor: Colors.white,
          dayPeriodColor: const Color(0xFF162035),
          dayPeriodTextColor: Colors.white,
          entryModeIconColor: const Color(0xFFFFB800),
          dialHandColor: const Color(0xFFFFB800),
          dialTextColor: Colors.white,
          helpTextStyle: const TextStyle(
            color: Color(0xFF8A97B0),
            fontSize: 12,
            letterSpacing: 1.5,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      child: child!,
    ),
  );

  if (picked == null || !context.mounted) return;

  final now = DateTime.now();
  final candidate = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);

  // If time is "in the future" they probably meant yesterday — shift it back
  final adjusted =
      candidate.isAfter(now) ? candidate.subtract(const Duration(days: 1)) : candidate;

  if (adjusted.isAfter(now)) {
    // Still in the future — not valid
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Punch-in time must be in the past.'),
        backgroundColor: Color(0xFFFF1744),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  await provider.adjustPunchInTime(adjusted);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Punch-in adjusted to ${picked.format(context)}. Exit time recalculated.',
        ),
        backgroundColor: const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
