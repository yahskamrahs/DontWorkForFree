import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../services/database_service.dart';
import '../utils/biometric_guard.dart';
import '../widgets/profile_selector_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _salaryCtrl;
  late TextEditingController _commuteCtrl;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _salaryCtrl = TextEditingController(
        text: settings.monthlySalary > 0
            ? settings.monthlySalary.toStringAsFixed(0)
            : '');
    _commuteCtrl =
        TextEditingController(text: settings.commuteMinutes.toString());
  }

  @override
  void dispose() {
    _salaryCtrl.dispose();
    _commuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final profile = context.watch<ProfileProvider>();
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF080C18),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          children: [
            // Header
            const Text('SETTINGS',
                style: TextStyle(
                    color: Color(0xFF5A6478),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
            const SizedBox(height: 2),
            const Text('Configuration',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 28),

            // ── Shift Profile ──────────────────────────────────────────────
            _SectionHeader('SHIFT PROFILE'),
            const SizedBox(height: 10),
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.work_outline_rounded,
                      color: Color(0xFFFFB800), size: 20),
                ),
                title: Text(profile.activeProfile.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  profile.activeProfile.durationLabel,
                  style: const TextStyle(color: Color(0xFF5A6478)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF3D4A60)),
                onTap: () => showProfileSelectorSheet(context),
              ),
            ),
            const SizedBox(height: 24),

            // ── Earnings Tracker ──────────────────────────────────────────
            _SectionHeader('EARNINGS TRACKER'),
            const SizedBox(height: 4),
            const Text(
              'Set your monthly salary to see a live earnings counter and overtime costs.',
              style: TextStyle(color: Color(0xFF3D4A60), fontSize: 12),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _salaryCtrl,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Monthly Salary',
                            prefixText: '  ',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (v) {
                            final val = double.tryParse(v) ?? 0;
                            settings.setMonthlySalary(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CurrencyPicker(
                        value: settings.currencySymbol,
                        onChanged: settings.setCurrencySymbol,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Commute Mode ──────────────────────────────────────────────
            _SectionHeader('COMMUTE MODE'),
            const SizedBox(height: 4),
            const Text(
              'Shows a "Home by" time that adds your commute to the safe exit time.',
              style: TextStyle(color: Color(0xFF3D4A60), fontSize: 12),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_transit_rounded,
                          color: Color(0xFF7C83FD), size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('Enable commute display',
                              style: TextStyle(color: Colors.white))),
                      Switch(
                        value: settings.commuteMode,
                        onChanged: settings.setCommuteMode,
                        activeThumbColor: const Color(0xFF7C83FD),
                      ),
                    ],
                  ),
                  if (settings.commuteMode) ...[
                    const Divider(color: Color(0xFF1E2D47), height: 24),
                    Row(
                      children: [
                        const Text('One-way commute:',
                            style: TextStyle(
                                color: Color(0xFF8A97B0), fontSize: 13)),
                        const Spacer(),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _commuteCtrl,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            onChanged: (v) {
                              final val = int.tryParse(v) ?? 30;
                              settings.setCommuteMinutes(val);
                            },
                          ),
                        ),
                        const Text(' min',
                            style: TextStyle(color: Color(0xFF5A6478))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Security ──────────────────────────────────────────────────
            _SectionHeader('SECURITY'),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded,
                      color: Color(0xFF00E676), size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Biometric Lock',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        Text('Locks the app behind fingerprint',
                            style: TextStyle(
                                color: Color(0xFF5A6478), fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: settings.biometricLockEnabled,
                    onChanged: (val) async {
                      if (val) {
                        final available = await BiometricGuard.isAvailable();
                        if (!available && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('No biometrics available on this device.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                      }
                      await settings.setBiometricLock(val);
                    },
                    activeThumbColor: const Color(0xFF00E676),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Data Management ───────────────────────────────────────────
            _SectionHeader('DATA'),
            const SizedBox(height: 10),
            _SettingsCard(
              child: Column(
                children: [
                  _DataTile(
                    icon: Icons.delete_forever_rounded,
                    label: 'Clear All History',
                    color: const Color(0xFFFF1744),
                    onTap: () => _confirmClearHistory(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                "Don't Work For Free  •  100% Offline",
                style: TextStyle(color: Color(0xFF1E2D47), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All History?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'All shift records will be permanently deleted. This cannot be undone.',
          style: TextStyle(color: Color(0xFF8A97B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5A6478))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await DatabaseService.instance.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('History cleared.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFFF1744))),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF5A6478),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2D47)),
        ),
        child: child,
      );
}

class _DataTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DataTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _CurrencyPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CurrencyPicker({required this.value, required this.onChanged});

  static const _options = ['₹', '\$', '€', '£', '¥'];

  @override
  Widget build(BuildContext context) => DropdownButton<String>(
        value: _options.contains(value) ? value : '₹',
        dropdownColor: const Color(0xFF162035),
        underline: const SizedBox.shrink(),
        style: const TextStyle(
            color: Color(0xFFFFB800),
            fontSize: 18,
            fontWeight: FontWeight.w700),
        items: _options
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      );
}
