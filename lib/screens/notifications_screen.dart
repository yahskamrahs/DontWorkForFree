import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/custom_notification_model.dart';
import '../providers/settings_provider.dart';
import '../providers/shift_provider.dart';
import '../widgets/notification_dialog.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C18),
      body: SafeArea(
        child: Consumer<ShiftProvider>(
          builder: (context, shift, _) {
            return CustomScrollView(
              slivers: [
                _buildHeader(),
                _buildSystemSection(shift),
                _buildBuiltInSection(context),
                _buildCustomHeader(context, shift),
                _buildCustomList(context, shift),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildHeader() {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOTIFICATION',
              style: TextStyle(
                color: Color(0xFF5A6478),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Master Engine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Fully offline · Scheduled on-device',
              style: TextStyle(color: Color(0xFF3D4A60), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSystemSection(ShiftProvider shift) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('SYSTEM ALERTS'),
            const SizedBox(height: 10),
            _SystemNotifCard(
              icon: Icons.luggage_rounded,
              color: const Color(0xFFFFB800),
              title: '5-Minute Warning',
              description: '"Pack Your Bags" — fires 5 minutes before your safe exit time.',
              isActive: shift.isActive,
              activeLabel: 'Auto-scheduled',
            ),
            const SizedBox(height: 10),
            _SystemNotifCard(
              icon: Icons.alarm_rounded,
              color: const Color(0xFFFF1744),
              title: 'Shift Complete Siren',
              description:
                  'Fullscreen alarm + aggressive vibration the exact second 8.5 hours are done.',
              isActive: shift.isActive,
              activeLabel: 'Auto-scheduled',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Built-in Reminders ────────────────────────────────────────────────────

  SliverToBoxAdapter _buildBuiltInSection(BuildContext context) {
    final s = context.watch<SettingsProvider>();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader('BUILT-IN REMINDERS'),
            const SizedBox(height: 10),

            // ── 1. Break reminder at fixed clock time ───────────────────────
            _BuiltInCard(
              icon: Icons.coffee_rounded,
              color: const Color(0xFF7C83FD),
              title: 'Daily Break Reminder',
              subtitle: 'Fires at a fixed clock time during your shift',
              isEnabled: s.breakReminderEnabled,
              onToggle: s.setBreakReminderEnabled,
              trailing: s.breakReminderEnabled
                  ? GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: s.breakReminderHour,
                            minute: s.breakReminderMinute,
                          ),
                          helpText: 'SET BREAK TIME',
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: Theme.of(ctx).colorScheme.copyWith(
                                    primary: const Color(0xFF7C83FD),
                                    onSurface: Colors.white,
                                    surface: const Color(0xFF162035),
                                  ),
                              dialogTheme: const DialogThemeData(
                                  backgroundColor: Color(0xFF0F1625)),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null && context.mounted) {
                          await context
                              .read<SettingsProvider>()
                              .setBreakReminderTime(picked.hour, picked.minute);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C83FD).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF7C83FD)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${s.breakReminderHour.toString().padLeft(2, '0')}'
                          ':${s.breakReminderMinute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF7C83FD),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),

            // ── 2. Every 2 Hours Update ────────────────────────────────────────
            _BuiltInCard(
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFFFFB800),
              title: 'Every 2 Hours Update',
              subtitle:
                  'Alert every 2 hours showing how much time is left',
              isEnabled: s.twoHourReminderEnabled,
              onToggle: s.setTwoHourReminderEnabled,
            ),
            const SizedBox(height: 10),

            // ── 3. Overtime escalation ──────────────────────────────────────
            _BuiltInCard(
              icon: Icons.alarm_on_rounded,
              color: const Color(0xFFFF6B6B),
              title: 'Overtime Escalation',
              subtitle:
                  'Repeating alerts after shift ends — until you punch out',
              isEnabled: s.overtimeReminderEnabled,
              onToggle: s.setOvertimeReminderEnabled,
              trailing: s.overtimeReminderEnabled
                  ? _IntervalPicker(
                      value: s.overtimeIntervalMinutes,
                      onChanged: s.setOvertimeIntervalMinutes,
                    )
                  : null,
            ),
            const SizedBox(height: 10),

            // ── 4. Entertainment mode ──────────────────────────────────────
            _BuiltInCard(
              icon: Icons.theater_comedy_rounded,
              color: const Color(0xFF00BCD4),
              title: 'Entertainment Mode',
              subtitle: 'Fetches fresh jokes from the web to keep you entertained',
              isEnabled: s.entertainmentModeEnabled,
              onToggle: s.setEntertainmentModeEnabled,
              trailing: s.entertainmentModeEnabled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SimpleIntervalPicker(
                          value: s.entertainmentIntervalMinutes,
                          color: const Color(0xFF00BCD4),
                          suffix: ' mins during shift',
                          onChanged: s.setEntertainmentIntervalMinutes,
                        ),
                        const SizedBox(height: 8),
                        _LanguagePicker(
                          value: s.jokeLanguage,
                          color: const Color(0xFF00BCD4),
                          onChanged: s.setJokeLanguage,
                        ),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildCustomHeader(
      BuildContext context, ShiftProvider shift) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Row(
          children: [
            const _SectionHeader('CUSTOM REMINDERS'),
            const Spacer(),
            GestureDetector(
              onTap: () => _addNotification(context, shift),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFFFB800).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 16, color: Color(0xFFFFB800)),
                    SizedBox(width: 4),
                    Text(
                      'Add',
                      style: TextStyle(
                        color: Color(0xFFFFB800),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomList(BuildContext context, ShiftProvider shift) {
    final notifications = shift.customNotifications;

    if (notifications.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1625),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2D47)),
            ),
            child: Column(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    size: 48, color: Color(0xFF1E2D47)),
                const SizedBox(height: 12),
                const Text(
                  'No custom reminders yet.',
                  style: TextStyle(color: Color(0xFF5A6478), fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tap "Add" to create interval or milestone alerts.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF3D4A60), fontSize: 12),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => _addNotification(context, shift),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Create First Reminder'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB800),
                    side: const BorderSide(color: Color(0xFFFFB800)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CustomNotifCard(
              notification: notifications[i],
              onToggle: () =>
                  shift.toggleCustomNotification(notifications[i].id),
              onEdit: () => _editNotification(context, shift, notifications[i]),
              onDelete: () =>
                  _deleteNotification(context, shift, notifications[i].id),
            ),
          ),
          childCount: notifications.length,
        ),
      ),
    );
  }

  Future<void> _addNotification(
      BuildContext context, ShiftProvider shift) async {
    final result = await showNotificationDialog(context);
    if (result != null) {
      await shift.addCustomNotification(result);
    }
  }

  Future<void> _editNotification(BuildContext context, ShiftProvider shift,
      CustomNotificationModel existing) async {
    final result =
        await showNotificationDialog(context, existing: existing);
    if (result != null) {
      await shift.updateCustomNotification(result);
    }
  }

  void _deleteNotification(
      BuildContext context, ShiftProvider shift, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Reminder?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This reminder will be removed and any pending notification cancelled.',
          style: TextStyle(color: Color(0xFF8A97B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF5A6478))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              shift.deleteCustomNotification(id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF1744))),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

/// Card used for the three built-in notification presets.
class _BuiltInCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final Future<void> Function(bool) onToggle;
  final Widget? trailing; // optional time picker or interval picker

  const _BuiltInCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.onToggle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isEnabled ? 1.0 : 0.55,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? color.withValues(alpha: 0.3)
                : const Color(0xFF1E2D47),
            width: isEnabled ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF5A6478),
                        fontSize: 11,
                        height: 1.4),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Toggle switch
            GestureDetector(
              onTap: () => onToggle(!isEnabled),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 26,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.25)
                      : const Color(0xFF1E2D47),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isEnabled ? color : const Color(0xFF2A3A50),
                  ),
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      left: isEnabled ? 20 : 2,
                      top: 3,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isEnabled ? color : const Color(0xFF3D4A60),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown to pick the overtime escalation interval (15 / 30 / 45 / 60 min).
class _IntervalPicker extends StatelessWidget {
  final int value;
  final Future<void> Function(int) onChanged;

  const _IntervalPicker({required this.value, required this.onChanged});

  static const _options = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Every ',
            style: TextStyle(color: Color(0xFF8A97B0), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _options.contains(value) ? value : 15,
              dropdownColor: const Color(0xFF162035),
              isDense: true,
              style: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              items: _options
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('$m min'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
        const Text(' after shift ends',
            style: TextStyle(color: Color(0xFF8A97B0), fontSize: 12)),
      ],
    );
  }
}

class _SimpleIntervalPicker extends StatelessWidget {
  final int value;
  final Color color;
  final String suffix;
  final Future<void> Function(int) onChanged;

  const _SimpleIntervalPicker({
    required this.value,
    required this.color,
    required this.suffix,
    required this.onChanged,
  });

  static const _options = [1, 5, 15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Every ',
            style: TextStyle(color: Color(0xFF8A97B0), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _options.contains(value) ? value : 30,
              dropdownColor: const Color(0xFF162035),
              isDense: true,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              items: _options
                  .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
        Text(suffix,
            style: const TextStyle(color: Color(0xFF8A97B0), fontSize: 12)),
      ],
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  final String value;
  final Color color;
  final Future<void> Function(String) onChanged;

  const _LanguagePicker({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  static const _options = ['English', 'Hindi', 'Mixed'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Language ',
            style: TextStyle(color: Color(0xFF8A97B0), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _options.contains(value) ? value : 'Mixed',
              dropdownColor: const Color(0xFF162035),
              isDense: true,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              items: _options
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
            ),
          ),
        ),
      ],
    );
  }
}

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

class _SystemNotifCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool isActive;
  final String activeLabel;

  const _SystemNotifCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.isActive,
    required this.activeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1625),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2D47)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00E676).withValues(alpha: 0.1)
                            : const Color(0xFF1E2D47),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isActive ? activeLabel : 'Pending shift',
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF00E676)
                              : const Color(0xFF3D4A60),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF5A6478),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomNotifCard extends StatelessWidget {
  final CustomNotificationModel notification;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomNotifCard({
    required this.notification,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _typeColor => notification.type == NotificationType.interval
      ? const Color(0xFF7C83FD)
      : const Color(0xFF00BCD4);

  IconData get _typeIcon => notification.type == NotificationType.interval
      ? Icons.repeat_rounded
      : Icons.flag_rounded;

  @override
  Widget build(BuildContext context) {
    final enabled = notification.isEnabled;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? _typeColor.withValues(alpha: 0.25)
                : const Color(0xFF1E2D47),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          notification.shortDescription,
                          style: TextStyle(
                            color: _typeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          notification.message,
                          style: const TextStyle(
                            color: Color(0xFF5A6478),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onEdit,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: Color(0xFF3D4A60)),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18, color: Color(0xFF3D4A60)),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 26,
                    decoration: BoxDecoration(
                      color: enabled
                          ? _typeColor.withValues(alpha: 0.25)
                          : const Color(0xFF1E2D47),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: enabled ? _typeColor : const Color(0xFF2A3A50),
                      ),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          left: enabled ? 20 : 2,
                          top: 3,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: enabled ? _typeColor : const Color(0xFF3D4A60),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
