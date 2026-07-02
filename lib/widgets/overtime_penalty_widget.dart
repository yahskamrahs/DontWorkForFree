import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class OvertimePenaltyOverlay extends StatefulWidget {
  final DateTime shiftEndTime;
  final VoidCallback onLeave;

  const OvertimePenaltyOverlay({
    super.key,
    required this.shiftEndTime,
    required this.onLeave,
  });

  @override
  State<OvertimePenaltyOverlay> createState() => _OvertimePenaltyOverlayState();
}

class _OvertimePenaltyOverlayState extends State<OvertimePenaltyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  Timer? _timer;
  int _overtimeSecs = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _overtimeSecs =
        DateTime.now().difference(widget.shiftEndTime).inSeconds.clamp(0, 9999999);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _overtimeSecs++);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _overtimeLabel {
    final m = (_overtimeSecs ~/ 60).toString().padLeft(2, '0');
    final s = (_overtimeSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final rate = settings.perSecondRate(510); // use 8.5h as reference
    final gifted = rate * _overtimeSecs;
    final fmt = NumberFormat.currency(
      symbol: settings.currencySymbol,
      decimalDigits: 2,
    );

    return Material(
      color: const Color(0xFF07020F),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: const Icon(
                Icons.alarm_on_rounded,
                size: 90,
                color: Color(0xFFFF1744),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'SHIFT COMPLETE',
              style: TextStyle(
                color: Color(0xFFFF1744),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 24),
            // Overtime ticking counter
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFF1744).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Text(
                    'FREE LABOR GIVEN',
                    style: TextStyle(
                      color: Color(0xFF5A6478),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _overtimeLabel,
                    style: const TextStyle(
                      color: Color(0xFFFF1744),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (settings.hasEarningsData) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${fmt.format(gifted)} gifted FREE',
                      style: const TextStyle(
                        color: Color(0xFF8A97B0),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Every second you stay is money out of your pocket.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: widget.onLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF1744),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.exit_to_app_rounded, size: 22),
                      SizedBox(width: 10),
                      Text(
                        "I'M LEAVING NOW",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
