import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';

class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen> {
  late final TextEditingController _salaryCtrl;
  static const double _serviceCharge = 200.0;

  // ── Monthly calculator state ──────────────────────────────────────────────
  DateTime _calcMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _leaveDays = 0;

  // ── 6-month cycle simulator — leaves per cycle month (index 0–5) ──────────
  final Map<int, int> _cycleLeaves = {};

  @override
  void initState() {
    super.initState();
    final salary = context.read<SettingsProvider>().monthlySalary;
    _salaryCtrl = TextEditingController(
      text: salary > 0 ? salary.toStringAsFixed(0) : '',
    );
    _salaryCtrl.addListener(() => setState(() {}));
    _loadLeavesForMonth();
  }

  Future<void> _loadLeavesForMonth() async {
    final records = await DatabaseService.instance.getRecentRecords(limit: 999);
    final count = records.where((r) => 
      r.punchInTime.year == _calcMonth.year && 
      r.punchInTime.month == _calcMonth.month && 
      r.profileId == 'LEAVE'
    ).length;
    if (mounted) {
      setState(() => _leaveDays = count);
    }
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTED — MONTHLY
  // ══════════════════════════════════════════════════════════════════════════

  double get _salary =>
      double.tryParse(_salaryCtrl.text.replaceAll(',', '')) ?? 0;

  int get _daysInCalcMonth =>
      DateTime(_calcMonth.year, _calcMonth.month + 1, 0).day;
  double get _dailyRate => _salary > 0 ? _salary / _daysInCalcMonth : 0;
  int get _workingDays =>
      (_daysInCalcMonth - _leaveDays).clamp(0, _daysInCalcMonth);
  double get _grossEarnings => _dailyRate * _workingDays;
  double get _leaveDeduction => _dailyRate * _leaveDays;
  double get _inHand => _grossEarnings - _serviceCharge;

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTED — 6-MONTH CYCLE
  // ══════════════════════════════════════════════════════════════════════════

  // Cycle A: Apr–Sep → payout Oct 5
  // Cycle B: Oct–Mar → payout Apr 5
  DateTime get _cycleStart {
    final now = DateTime.now();
    if (now.month >= 4 && now.month <= 9) return DateTime(now.year, 4);
    if (now.month >= 10) return DateTime(now.year, 10);
    return DateTime(now.year - 1, 10);
  }

  DateTime get _payoutDate {
    final s = _cycleStart;
    return s.month == 4 ? DateTime(s.year, 10, 5) : DateTime(s.year + 1, 4, 5);
  }

  List<DateTime> get _cycleMonths => List.generate(
    6,
    (i) => DateTime(_cycleStart.year, _cycleStart.month + i),
  );

  int _daysIn(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  // Daily rate for a specific cycle month (1 leave's worth)
  double _leaveValueFor(DateTime m) => _salary > 0 ? _salary / _daysIn(m) : 0;

  bool _isPast(DateTime m) =>
      m.isBefore(DateTime(DateTime.now().year, DateTime.now().month));
  bool _isCurrent(DateTime m) {
    final n = DateTime.now();
    return m.year == n.year && m.month == n.month;
  }

  void _setCycleLeave(int i, int val) => setState(() {
    _cycleLeaves[i] = val.clamp(0, _daysIn(_cycleMonths[i]));
  });

  // Guaranteed encashment — ALWAYS 6 × daily rate, never changes
  double get _fullCycleEncashment =>
      _cycleMonths.fold(0.0, (s, m) => s + _leaveValueFor(m));

  // Accumulated encashment for elapsed months only
  double get _accumulatedEncashment => _cycleMonths
      .where((m) => _isPast(m) || _isCurrent(m))
      .fold(0.0, (s, m) => s + _leaveValueFor(m));

  int get _elapsedMonths =>
      _cycleMonths.where((m) => _isPast(m) || _isCurrent(m)).length;

  // Total leave deductions simulated across ALL 6 cycle months
  double get _totalSimLeaveDeductions {
    double total = 0;
    for (int i = 0; i < _cycleMonths.length; i++) {
      final days = _leavesForMonth(i);
      total += _leaveValueFor(_cycleMonths[i]) * days;
    }
    return total;
  }

  int _leavesForMonth(int i) => _cycleLeaves[i] ?? 0;

  // Net financial impact of the leave policy:
  //   +ve = you gain money (encashment > deductions)
  //   -ve = you lose money (deductions > encashment)
  double get _netPolicyBenefit =>
      _fullCycleEncashment - _totalSimLeaveDeductions;

  int get _daysUntilPayout =>
      _payoutDate.difference(DateTime.now()).inDays.clamp(0, 999);

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  NumberFormat get _fmt => NumberFormat.currency(
    locale: 'en_IN',
    symbol: context.read<SettingsProvider>().currencySymbol,
    decimalDigits: 2,
  );

  String _f(double v) => _fmt.format(v);

  void _prevMonth() {
    setState(() => _calcMonth = DateTime(_calcMonth.year, _calcMonth.month - 1));
    _loadLeavesForMonth();
  }
  void _nextMonth() {
    setState(() => _calcMonth = DateTime(_calcMonth.year, _calcMonth.month + 1));
    _loadLeavesForMonth();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C18),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(5, 17, 5, 45),
          children: [
            _header(),
            const SizedBox(height: 24),
            _configCard(),
            const SizedBox(height: 14),
            _monthLeaveCard(),
            const SizedBox(height: 14),
            _breakdownCard(),
            const SizedBox(height: 22),
            _sectionDivider('6-MONTH LEAVE ENCASHMENT SIMULATOR'),
            const SizedBox(height: 4),
            // Key rule callout
            _guaranteeCallout(),
            const SizedBox(height: 12),
            _cycleInfoCard(),
            const SizedBox(height: 12),
            _cycleSimulatorCard(),
            const SizedBox(height: 12),
            _netImpactCard(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SALARY',
        style: TextStyle(
          color: Color(0xFF5A6478),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      SizedBox(height: 2),
      Text(
        'Calculator',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
      SizedBox(height: 4),
      Text(
        'Daily rate · Leave deductions · Guaranteed encashment',
        style: TextStyle(color: Color(0xFF3D4A60), fontSize: 12),
      ),
    ],
  );

  // ── Config card ───────────────────────────────────────────────────────────

  Widget _configCard() {
    final sym = context.read<SettingsProvider>().currencySymbol;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('SALARY INPUTS'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Field(
                  controller: _salaryCtrl,
                  label: 'Monthly Salary',
                  prefix: sym,
                  hint: '20000',
                  isLarge: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Tax',
                      style: TextStyle(color: Color(0xFF5A6478), fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          sym,
                          style: const TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '200',
                          style: TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 1, color: const Color(0xFF1E2D47)),
                    const SizedBox(height: 2),
                    const Text(
                      'Fixed for all',
                      style: TextStyle(color: Color(0xFF3D4A60), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_salary > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                'Full month in-hand (0 leaves): ${_f(_salary - _serviceCharge)}',
                style: const TextStyle(
                  color: Color(0xFFFFB800),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Month & leave picker ──────────────────────────────────────────────────

  Widget _monthLeaveCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('MONTH & LEAVE CALCULATOR'),
        const SizedBox(height: 12),
        Row(
          children: [
            _NavBtn(icon: Icons.chevron_left_rounded, onTap: _prevMonth),
            Expanded(
              child: Center(
                child: Text(
                  DateFormat('MMMM yyyy').format(_calcMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _NavBtn(icon: Icons.chevron_right_rounded, onTap: _nextMonth),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            '$_daysInCalcMonth days in this month   •   Daily rate: ${_f(_dailyRate)}',
            style: const TextStyle(color: Color(0xFF5A6478), fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFF1E2D47), height: 1),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave Days Taken',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Each day deducted at the daily rate above',
                    style: TextStyle(color: Color(0xFF3D4A60), fontSize: 11),
                  ),
                ],
              ),
            ),
            _Counter(
              value: _leaveDays,
              max: _daysInCalcMonth,
              onDecrement: _leaveDays > 0
                  ? () => setState(() => _leaveDays--)
                  : null,
              onIncrement: _leaveDays < _daysInCalcMonth
                  ? () => setState(() => _leaveDays++)
                  : null,
            ),
          ],
        ),
      ],
    ),
  );

  // ── Monthly breakdown card ────────────────────────────────────────────────

  Widget _breakdownCard() {
    final neg = _inHand < 0;
    return _Card(
      accentColor: neg ? const Color(0xFFFF1744) : const Color(0xFF00E676),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('THIS MONTH\'S SALARY BREAKDOWN'),
          const SizedBox(height: 14),
          _CalcRow(
            label:
                '${DateFormat('MMMM yyyy').format(_calcMonth)} ($_daysInCalcMonth days)',
            value: _f(_salary),
            isHeader: true,
          ),
          if (_leaveDays > 0) ...[
            const SizedBox(height: 8),
            _CalcRow(
              label: 'Daily rate',
              value: '${_f(_salary)} ÷ $_daysInCalcMonth = ${_f(_dailyRate)}',
              dimValue: true,
            ),
            const SizedBox(height: 8),
            _CalcRow(
              label: 'Working days',
              value: '$_daysInCalcMonth − $_leaveDays = $_workingDays',
              dimValue: true,
            ),
            const SizedBox(height: 8),
            _CalcRow(
              label: 'Gross (after leaves)',
              value:
                  '${_f(_dailyRate)} × $_workingDays = ${_f(_grossEarnings)}',
              dimValue: true,
            ),
            const SizedBox(height: 8),
            _CalcRow(
              label: 'Leave deduction',
              value: '− ${_f(_leaveDeduction)}',
              valueColor: const Color(0xFFFF6B6B),
            ),
          ],
          const SizedBox(height: 8),
          _CalcRow(
            label: 'Service tax',
            value: '− ${_f(_serviceCharge)}',
            valueColor: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E2D47), height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'IN-HAND SALARY',
                style: TextStyle(
                  color: Color(0xFF8A97B0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                _f(_inHand),
                style: TextStyle(
                  color: neg
                      ? const Color(0xFFFF1744)
                      : const Color(0xFF00E676),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (neg)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '⚠ Leave deductions exceed salary.',
                style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  // ── Section divider ───────────────────────────────────────────────────────

  Widget _sectionDivider(String label) => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFF1E2D47))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5A6478),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFF1E2D47))),
    ],
  );

  // ── GUARANTEE CALLOUT ─────────────────────────────────────────────────────
  // This is the key rule the user asked about

  Widget _guaranteeCallout() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF00E676).withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: Color(0xFF00E676),
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'GUARANTEED RULE — READ THIS',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Your company gives you 1 paid leave per month = '
          '6 paid leaves per 6-month cycle.',
          style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        const Text(
          '✅  Took 0 leaves all 6 months?  →  Still receive 6 days salary.\n'
          '✅  Took 3+3 leaves in last 2 months?  →  Still receive 6 days salary.\n'
          '✅  Took 1 leave every month (6 total)?  →  Still receive 6 days salary.',
          style: TextStyle(color: Color(0xFF00E676), fontSize: 12, height: 1.7),
        ),
        const SizedBox(height: 8),
        const Text(
          'The 6-day encashment is SEPARATE from monthly leave deductions. '
          'Leaves reduce your monthly pay, but the encashment is always paid '
          'in full on the payout date.',
          style: TextStyle(color: Color(0xFF8A97B0), fontSize: 11, height: 1.6),
        ),
      ],
    ),
  );

  // ── Cycle info card ───────────────────────────────────────────────────────

  Widget _cycleInfoCard() {
    final periodLabel =
        '${DateFormat('MMM yyyy').format(_cycleMonths.first)} '
        '– ${DateFormat('MMM yyyy').format(_cycleMonths.last)}';
    final payoutFmt = DateFormat('d MMMM yyyy').format(_payoutDate);
    final isPaid = _payoutDate.isBefore(DateTime.now());

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Label('CURRENT CYCLE'),
                    const SizedBox(height: 4),
                    Text(
                      periodLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'PAYOUT DATE',
                      style: TextStyle(
                        color: Color(0xFF5A6478),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      payoutFmt,
                      style: const TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isPaid ? '✓ Paid out' : 'In $_daysUntilPayout days',
                      style: TextStyle(
                        color: isPaid
                            ? const Color(0xFF00E676)
                            : const Color(0xFF5A6478),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _CycleStat(
                label: 'Elapsed',
                value: '$_elapsedMonths / 6',
                color: const Color(0xFFFFB800),
              ),
              _CycleStat(
                label: 'Accumulated',
                value: _f(_accumulatedEncashment),
                color: const Color(0xFF7C83FD),
              ),
              _CycleStat(
                label: 'Full Payout',
                value: _f(_fullCycleEncashment),
                color: const Color(0xFF00E676),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Cycle simulator card ──────────────────────────────────────────────────
  // User sets leaves for EACH cycle month independently.
  // The encashment column stays the same no matter what they enter.
Widget _cycleSimulatorCard() => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('LEAVE SIMULATOR'),
                  SizedBox(height: 2),
                  Text(
                    'Set leaves per month. Watch encashment stay fixed.',
                    style: TextStyle(color: Color(0xFF3D4A60), fontSize: 11),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _cycleLeaves.clear()),
              child: const Text(
                'Reset',
                style: TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF5A6478),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Column headers - FIXED flex ratios
        const Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                'Month',
                style: TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Leaves',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF5A6478),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Monthly Pay',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Encashment',
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(color: Color(0xFF1E2D47), height: 1),
        const SizedBox(height: 4),
        // One row per cycle month
        ...List.generate(_cycleMonths.length, (i) => _simulatorRow(i)),
        const SizedBox(height: 8),
        const Divider(color: Color(0xFF1E2D47), height: 1),
        const SizedBox(height: 10),
        // Totals row - FIXED flex ratios
        Row(
          children: [
            const Expanded(
              flex: 2,
              child: Text(
                'TOTALS',
                style: TextStyle(
                  color: Color(0xFF8A97B0),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox()),
            Expanded(
              flex: 2,
              child: Text(
                '−${_f(_totalSimLeaveDeductions)}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '+${_f(_fullCycleEncashment)}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
 Widget _simulatorRow(int i) {
    final m = _cycleMonths[i];
    final past = _isPast(m);
    final current = _isCurrent(m);
    final upcoming = !past && !current;
    final leaves = _leavesForMonth(i);
    final days = _daysIn(m);
    final leaveVal = _leaveValueFor(m);
    final monthlyPay = _salary > 0
        ? (_salary / days) * (days - leaves) - _serviceCharge
        : 0.0;
    final deduction = leaveVal * leaves;

    Color monthColor = upcoming
        ? const Color(0xFF3D4A60)
        : current
        ? const Color(0xFFFFB800)
        : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Month name - FIXED flex
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM yy').format(m),
                  style: TextStyle(
                    color: monthColor,
                    fontSize: 11,
                    fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$days days',
                  style: const TextStyle(color: Color(0xFF3D4A60), fontSize: 8),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Leave counter - FIXED flex
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniBtn(
                  icon: Icons.remove_rounded,
                  enabled: leaves > 0,
                  onTap: () => _setCycleLeave(i, leaves - 1),
                ),
                SizedBox(
                  width: 20,
                  child: Text(
                    '$leaves',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: leaves > 0
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFF3D4A60),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _MiniBtn(
                  icon: Icons.add_rounded,
                  enabled: leaves < days,
                  onTap: () => _setCycleLeave(i, leaves + 1),
                ),
              ],
            ),
          ),
          // Monthly pay - FIXED flex
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  upcoming ? '—' : _f(monthlyPay),
                  style: TextStyle(
                    color: upcoming
                        ? const Color(0xFF1E2D47)
                        : deduction > 0
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF8A97B0),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (deduction > 0 && !upcoming)
                  Text(
                    '−${_f(deduction)}',
                    style: const TextStyle(
                      color: Color(0xFFFF1744),
                      fontSize: 8,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Encashment - FIXED flex
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _f(leaveVal),
                  style: TextStyle(
                    color: upcoming
                        ? const Color(0xFF2A4040)
                        : const Color(0xFF00E676),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (deduction > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'UNCHANGED',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 6,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ── Net impact card ───────────────────────────────────────────────────────

  Widget _netImpactCard() {
    final net = _netPolicyBenefit;
    final isPositive = net >= 0;
    final color = isPositive
        ? const Color(0xFF00E676)
        : const Color(0xFFFF6B6B);
    final totalLeaves = _cycleLeaves.values.fold(0, (a, b) => a + b);

    return _Card(
      accentColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('6-MONTH NET IMPACT ANALYSIS'),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Total leave deductions',
            value: '−${_f(_totalSimLeaveDeductions)}',
            valueColor: const Color(0xFFFF6B6B),
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Guaranteed encashment (6 days)',
            value: '+${_f(_fullCycleEncashment)}',
            valueColor: const Color(0xFF00E676),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E2D47), height: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPositive
                          ? 'YOU GAIN from leave policy'
                          : 'YOU LOSE from leave policy',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalLeaves == 0
                          ? 'No leaves taken → full encashment is pure bonus'
                          : totalLeaves <= 6
                          ? '$totalLeaves leaves taken, still get all 6 days encashed'
                          : '$totalLeaves leaves taken — deductions exceed encashment',
                      style: const TextStyle(
                        color: Color(0xFF5A6478),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                _f(net.abs()),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Payout month total
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB800).withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFB800).withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'On ${DateFormat('d MMMM yyyy').format(_payoutDate)}, '
                  'your salary slip will include:',
                  style: const TextStyle(
                    color: Color(0xFFFFB800),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  label:
                      '${DateFormat('MMMM').format(_cycleMonths.last)} '
                      'in-hand (${_leavesForMonth(5)} leaves)',
                  value: _salary > 0
                      ? _f(
                          (_salary / _daysIn(_cycleMonths.last)) *
                                  (_daysIn(_cycleMonths.last) -
                                      _leavesForMonth(5)) -
                              _serviceCharge,
                        )
                      : '—',
                  valueColor: const Color(0xFF8A97B0),
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: '+ Leave encashment (6 days GUARANTEED)',
                  value: '+${_f(_fullCycleEncashment)}',
                  valueColor: const Color(0xFF00E676),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFFFFB800), height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'TOTAL RECEIVED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _salary > 0
                          ? _f(
                              ((_salary / _daysIn(_cycleMonths.last)) *
                                          (_daysIn(_cycleMonths.last) -
                                              _leavesForMonth(5)) -
                                      _serviceCharge) +
                                  _fullCycleEncashment,
                            )
                          : '—',
                      style: const TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  const _Card({required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF0F1625),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: accentColor?.withValues(alpha: 0.35) ?? const Color(0xFF1E2D47),
        width: accentColor != null ? 1.5 : 1,
      ),
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF5A6478),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final String hint;
  final bool isLarge;
  const _Field({
    required this.controller,
    required this.label,
    required this.prefix,
    required this.hint,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF5A6478), fontSize: 10),
      ),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            prefix,
            style: TextStyle(
              color: const Color(0xFFFFB800),
              fontSize: isLarge ? 20 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                color: Colors.white,
                fontSize: isLarge ? 22 : 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      Container(height: 1, color: const Color(0xFF1E2D47)),
    ],
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF162035),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF8A97B0), size: 20),
    ),
  );
}

class _Counter extends StatelessWidget {
  final int value;
  final int max;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  const _Counter({
    required this.value,
    required this.max,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _MiniBtn(
        icon: Icons.remove_rounded,
        enabled: onDecrement != null,
        large: true,
        onTap: onDecrement ?? () {},
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'days',
              style: TextStyle(color: Color(0xFF5A6478), fontSize: 10),
            ),
          ],
        ),
      ),
      _MiniBtn(
        icon: Icons.add_rounded,
        enabled: onIncrement != null,
        large: true,
        onTap: onIncrement ?? () {},
      ),
    ],
  );
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool large;
  final VoidCallback onTap;
  const _MiniBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      padding: EdgeInsets.all(large ? 8 : 4),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF162035) : const Color(0xFF0F1625),
        borderRadius: BorderRadius.circular(large ? 10 : 6),
        border: Border.all(
          color: enabled ? const Color(0xFF1E2D47) : const Color(0xFF0F1625),
        ),
      ),
      child: Icon(
        icon,
        size: large ? 18 : 14,
        color: enabled ? const Color(0xFF8A97B0) : const Color(0xFF1E2D47),
      ),
    ),
  );
}

class _CalcRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHeader;
  final bool dimValue;
  final Color? valueColor;
  const _CalcRow({
    required this.label,
    required this.value,
    this.isHeader = false,
    this.dimValue = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: isHeader ? Colors.white : const Color(0xFF8A97B0),
            fontSize: isHeader ? 13 : 12,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        value,
        style: TextStyle(
          color:
              valueColor ??
              (isHeader
                  ? Colors.white
                  : dimValue
                  ? const Color(0xFF5A6478)
                  : Colors.white),
          fontSize: isHeader ? 13 : 12,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF8A97B0), fontSize: 12),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );
}

class _CycleStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CycleStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5A6478),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}
