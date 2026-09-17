import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';
import '../utils/export_util.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/earnings_meter.dart';
import '../widgets/overtime_penalty_widget.dart';
import '../widgets/profile_selector_sheet.dart';
import '../widgets/time_edit_dialog.dart';
import '../widgets/weekly_balance_card.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScreenshotController _screenshotCtrl = ScreenshotController();

  @override
  Widget build(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shift, _) {
        return Stack(
          children: [
            Scaffold(
              backgroundColor: const Color(0xFF080C18),
              body: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(context, shift),
                    Expanded(
                      child: shift.isActive
                          ? _ActiveDashboard(
                              shift: shift,
                              screenshotCtrl: _screenshotCtrl,
                            )
                          : _PunchInView(onPunchIn: shift.punchIn),
                    ),
                  ],
                ),
              ),
            ),
            if (shift.isShiftComplete)
              OvertimePenaltyOverlay(
                shiftEndTime: shift.safeExitTime,
                onLeave: shift.punchOut,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ShiftProvider shift) {
    final profile = context.watch<ProfileProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — title + offline badge
          Row(
            children: [
              const Text("DON'T WORK FOR ",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const Text('FREE',
                  style: TextStyle(
                      color: Color(0xFFFFB800),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF00E676).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 10, color: Color(0xFF00E676)),
                    SizedBox(width: 4),
                    Text('OFFLINE',
                        style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2 — profile badge + share button
          Row(
            children: [
              GestureDetector(
                onTap: shift.isActive
                    ? null
                    : () => showProfileSelectorSheet(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.work_outline_rounded,
                          size: 11, color: Color(0xFFFFB800)),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          profile.activeProfile.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFFFFB800),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (shift.isActive)
                GestureDetector(
                  onTap: () =>
                      ExportUtil.captureAndShare(_screenshotCtrl, context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.ios_share_rounded,
                        color: Color(0xFF5A6478), size: 18),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Punch-in view ────────────────────────────────────────────────────────────

class _PunchInView extends StatelessWidget {
  final Future<void> Function({DateTime? customTime}) onPunchIn;
  const _PunchInView({required this.onPunchIn});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security_rounded,
              size: 56, color: Color(0xFF1E2D47)),
          const SizedBox(height: 20),
          const Text('Your time is yours.',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Track your ${profile.activeProfile.durationLabel} shift.\nNot a second more.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF5A6478), fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          const _MonthlyRecoveryTracker(),
          const SizedBox(height: 52),
          _HoldToPunchButton(
            onPunchIn: () => onPunchIn(),
          ),
          const SizedBox(height: 36),
          TextButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(now),
                helpText: 'WHEN DID YOU ACTUALLY ARRIVE?',
                builder: (ctx, child) => _darkTimePicker(ctx, child),
              );
              if (picked == null || !context.mounted) return;
              final candidate = DateTime(
                  now.year, now.month, now.day, picked.hour, picked.minute);
              final adjusted = candidate.isAfter(now)
                  ? candidate.subtract(const Duration(days: 1))
                  : candidate;
              await onPunchIn(customTime: adjusted);
            },
            icon: const Icon(Icons.edit_calendar_rounded,
                size: 15, color: Color(0xFF5A6478)),
            label: const Text('I forgot — set custom time',
                style: TextStyle(color: Color(0xFF5A6478), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Active dashboard ─────────────────────────────────────────────────────────

class _ActiveDashboard extends StatelessWidget {
  final ShiftProvider shift;
  final ScreenshotController screenshotCtrl;

  const _ActiveDashboard({
    required this.shift,
    required this.screenshotCtrl,
  });

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final exitFmt = DateFormat('h:mm a').format(shift.safeExitTime);
    final remaining = shift.remainingTime;
    final onBreak = shift.isOnBreak;
    final pct = (shift.progress * 100).toStringAsFixed(0);

    // Commute display
    final homeFmt = settings.commuteMode
        ? DateFormat('h:mm a').format(
            shift.safeExitTime
                .add(Duration(minutes: settings.commuteMinutes)))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Screenshot(
        controller: screenshotCtrl,
        child: Column(
          children: [
            // Safe exit card
            _GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.door_front_door_rounded,
                      color: Color(0xFF5A6478), size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SAFE TO LEAVE AT',
                          style: TextStyle(
                              color: Color(0xFF5A6478),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4)),
                      Text(exitFmt,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1)),
                      if (homeFmt != null)
                        Text('Home by $homeFmt',
                            style: const TextStyle(
                                color: Color(0xFF7C83FD),
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => showTimeEditDialog(context),
                    icon: const Icon(Icons.tune_rounded,
                        color: Color(0xFFFFB800), size: 20),
                    tooltip: 'Adjust punch-in time',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFFFB800).withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Countdown ring
            CountdownRing(
              size: 250,
              progress: shift.progress,
              isComplete: false,
              isPaused: false, // Timer always runs — break is inside the shift
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onBreak) ...[
                    const Icon(Icons.pause_circle_filled_rounded,
                        color: Color(0xFF5A6478), size: 24),
                    const SizedBox(height: 2),
                    const Text('ON BREAK',
                        style: TextStyle(
                            color: Color(0xFF5A6478),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2)),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    _fmt(remaining),
                    style: TextStyle(
                      color: onBreak
                          ? const Color(0xFF5A6478)
                          : Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 2,
                    ),
                  ),
                  Text('REMAINING',
                      style: TextStyle(
                          color: onBreak
                              ? const Color(0xFF3D4A60)
                              : const Color(0xFF5A6478),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'PROGRESS',
                    value: '$pct%',
                    icon: Icons.analytics_outlined,
                    color: const Color(0xFFFFB800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'BREAK TIME',
                    value: _fmt(shift.totalBreakDuration +
                        shift.currentBreakElapsed),
                    icon: Icons.free_breakfast_outlined,
                    color: const Color(0xFF7C83FD),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Earnings meter
            const EarningsMeter(),
            if (context.read<SettingsProvider>().hasEarningsData)
              const SizedBox(height: 12),

            // Weekly balance
            const WeeklyBalanceCard(),
            const SizedBox(height: 12),

            // Break toggle
            _BreakButton(
              isOnBreak: onBreak,
              breakElapsed: shift.currentBreakElapsed,
              onToggle: () =>
                  onBreak ? shift.endBreak() : shift.startBreak(),
            ),
            const SizedBox(height: 10),

            // End shift
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmPunchOut(context, shift),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('End Shift Early'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8A97B0),
                  side: const BorderSide(color: Color(0xFF1E2D47)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmPunchOut(BuildContext context, ShiftProvider shift) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Shift Early?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This saves your current shift to history and cancels all reminders.',
          style: TextStyle(color: Color(0xFF8A97B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep Going',
                style: TextStyle(color: Color(0xFF5A6478))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              shift.punchOut();
            },
            child: const Text('End It',
                style: TextStyle(color: Color(0xFFFF1744))),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2D47)),
        ),
        child: child,
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E2D47)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF5A6478),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      );
}

class _BreakButton extends StatelessWidget {
  final bool isOnBreak;
  final Duration breakElapsed;
  final VoidCallback onToggle;
  const _BreakButton({
    required this.isOnBreak,
    required this.breakElapsed,
    required this.onToggle,
  });

  String _fmtBreak() {
    final m = breakElapsed.inMinutes.toString().padLeft(2, '0');
    final s = (breakElapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onToggle,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: isOnBreak
            ? const Color(0xFF7C83FD).withValues(alpha: 0.1)
            : const Color(0xFF0F1625),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnBreak
              ? const Color(0xFF7C83FD).withValues(alpha: 0.5)
              : const Color(0xFF1E2D47),
          width: isOnBreak ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon - fixed size
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isOnBreak
                  ? Icons.play_circle_filled_rounded
                  : Icons.pause_circle_filled_rounded,
              key: ValueKey(isOnBreak),
              color: isOnBreak
                  ? const Color(0xFF7C83FD)
                  : const Color(0xFF5A6478),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          // Text - Expanded with proper constraints
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnBreak ? 'END BREAK' : 'TAKE A BREAK',
                  style: TextStyle(
                    color: isOnBreak ? const Color(0xFF7C83FD) : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isOnBreak
                      ? 'Running: ${_fmtBreak()}  ·  exit time unchanged'
                      : 'Break is inside your shift · exit time stays fixed',
                  style: const TextStyle(
                    color: Color(0xFF3D4A60),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _darkTimePicker(BuildContext ctx, Widget? child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: const Color(0xFFFFB800),
              onSurface: Colors.white,
              surface: const Color(0xFF162035),
            ),
        dialogTheme:
            const DialogThemeData(backgroundColor: Color(0xFF0F1625)),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: const Color(0xFF0F1625),
          dialBackgroundColor: const Color(0xFF162035),
          hourMinuteColor: const Color(0xFF162035),
          hourMinuteTextColor: Colors.white,
          dialHandColor: const Color(0xFFFFB800),
          dialTextColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      child: child!,
    );

class _MonthlyRecoveryTracker extends StatefulWidget {
  const _MonthlyRecoveryTracker();
  @override
  State<_MonthlyRecoveryTracker> createState() => _MonthlyRecoveryTrackerState();
}

class _MonthlyRecoveryTrackerState extends State<_MonthlyRecoveryTracker> {
  Duration _surplus = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await DatabaseService.instance.getRecentRecords(limit: 999);
    final now = DateTime.now();
    final monthRecords = records.where((r) => 
      r.punchInTime.year == now.year && 
      r.punchInTime.month == now.month && 
      r.profileId != 'LEAVE'
    );
    final total = monthRecords.fold(Duration.zero, (acc, r) => acc + r.surplus);
    if (mounted) {
      setState(() {
        _surplus = total;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox();
    final isPos = _surplus >= Duration.zero;
    final mSecs = _surplus.inSeconds.abs();
    final mH = mSecs ~/ 3600;
    final mM = (mSecs % 3600) ~/ 60;
    final str = mSecs < 60 ? 'Perfect Average!' : '${isPos ? '+' : '-'}${mH > 0 ? '${mH}h ' : ''}${mM}m';

    if (mSecs < 60) return const SizedBox();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isPos ? const Color(0xFF00E676) : const Color(0xFFFF1744)).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isPos ? const Color(0xFF00E676) : const Color(0xFFFF1744)).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text('Monthly Recovery Status', style: TextStyle(color: isPos ? const Color(0xFF00E676) : const Color(0xFFFF1744), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(isPos ? 'Surplus: $str' : 'Lost Time: $str', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            isPos ? 'You are ahead of your average.' : 'You need to recover $str to maintain average.',
            style: const TextStyle(color: Color(0xFF8A97B0), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HoldToPunchButton extends StatefulWidget {
  final Future<void> Function() onPunchIn;
  const _HoldToPunchButton({required this.onPunchIn});

  @override
  State<_HoldToPunchButton> createState() => _HoldToPunchButtonState();
}

class _HoldToPunchButtonState extends State<_HoldToPunchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFinished = false;

  // Track last haptic tick to avoid over-vibrating
  double _lastHapticProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Slightly faster for snappier feel
      duration: const Duration(milliseconds: 400),
    );

    // Subtle haptic ticks as progress fills
    _controller.addListener(() {
      if (_isFinished) return;
      final val = _controller.value;
      // Tick at every 25% for a subtle "click-click-click-done" feel
      if (val >= 0.25 && _lastHapticProgress < 0.25) {
        HapticFeedback.selectionClick();
        _lastHapticProgress = 0.25;
      } else if (val >= 0.50 && _lastHapticProgress < 0.50) {
        HapticFeedback.selectionClick();
        _lastHapticProgress = 0.50;
      } else if (val >= 0.75 && _lastHapticProgress < 0.75) {
        HapticFeedback.selectionClick();
        _lastHapticProgress = 0.75;
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (!_isFinished) {
          _isFinished = true;
          // Satisfying completion haptic: medium impact feels polished, not jarring
          HapticFeedback.mediumImpact();
          // Fire punch-in immediately — no delay
          widget.onPunchIn();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (_isFinished) return;
    _lastHapticProgress = 0.0;
    // Gentle initial tap feedback
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (_isFinished) return;
    _lastHapticProgress = 0.0;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (_isFinished) return;
    _lastHapticProgress = 0.0;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Use a curved animation for a natural, smooth feel
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) {
          // Smooth scale: starts at 1.0, gently zooms to 1.06
          final scale = 1.0 + (curved.value * 0.06);
          return Transform.scale(
            scale: scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Base Button
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFFB800)],
                      radius: 0.7,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB800)
                            .withValues(alpha: 0.3 + (curved.value * 0.25)),
                        blurRadius: 40 + (curved.value * 20),
                        spreadRadius: 4 + (curved.value * 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint_rounded,
                          size: 58, color: Color(0xFF080C18)),
                      SizedBox(height: 8),
                      Text('PUNCH IN',
                          style: TextStyle(
                              color: Color(0xFF080C18),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.5)),
                    ],
                  ),
                ),
                // Progress Bar Border — smooth white ring
                if (curved.value > 0.0)
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: curved.value,
                      strokeWidth: 3.5,
                      strokeCap: StrokeCap.round,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
