import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/custom_notification_model.dart';

/// Shows the add/edit dialog. Returns the saved model, or null if cancelled.
Future<CustomNotificationModel?> showNotificationDialog(
  BuildContext context, {
  CustomNotificationModel? existing,
}) {
  return showDialog<CustomNotificationModel>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _NotificationDialog(existing: existing),
  );
}

class _NotificationDialog extends StatefulWidget {
  final CustomNotificationModel? existing;
  const _NotificationDialog({this.existing});

  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> {
  final _formKey = GlobalKey<FormState>();

  late NotificationType _type;
  late TextEditingController _titleCtrl;
  late TextEditingController _messageCtrl;

  // Interval fields
  late TextEditingController _hoursCtrl;
  late TextEditingController _minsCtrl;

  // Milestone fields
  MilestoneType _milestoneType = MilestoneType.hoursRemaining;
  late TextEditingController _milestoneValueCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? NotificationType.interval;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _messageCtrl = TextEditingController(text: e?.message ?? '');
    _milestoneType = e?.milestoneType ?? MilestoneType.hoursRemaining;
    _milestoneValueCtrl = TextEditingController(
      text: e?.milestoneValue?.toString() ?? '',
    );

    final interval = e?.intervalDuration ?? const Duration(hours: 1);
    _hoursCtrl =
        TextEditingController(text: interval.inHours.toString());
    _minsCtrl =
        TextEditingController(text: (interval.inMinutes % 60).toString());
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _messageCtrl,
      _hoursCtrl,
      _minsCtrl,
      _milestoneValueCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Duration? interval;
    MilestoneType? msType;
    double? msValue;

    if (_type == NotificationType.interval) {
      final h = int.tryParse(_hoursCtrl.text) ?? 0;
      final m = int.tryParse(_minsCtrl.text) ?? 0;
      interval = Duration(hours: h, minutes: m);
      if (interval.inMinutes < 1) {
        _showError('Interval must be at least 1 minute.');
        return;
      }
    } else {
      msType = _milestoneType;
      msValue = double.tryParse(_milestoneValueCtrl.text);
      if (msValue == null || msValue <= 0) {
        _showError('Enter a valid positive number.');
        return;
      }
      if (msType == MilestoneType.hoursRemaining && msValue > 8.5) {
        _showError('Hours remaining must be ≤ 8.5.');
        return;
      }
      if (msType == MilestoneType.percentComplete &&
          (msValue <= 0 || msValue >= 100)) {
        _showError('Percent must be between 1 and 99.');
        return;
      }
    }

    final result = CustomNotificationModel(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      isEnabled: widget.existing?.isEnabled ?? true,
      type: _type,
      intervalDuration: interval,
      milestoneType: msType,
      milestoneValue: msValue,
    );

    Navigator.of(context).pop(result);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFFF1744),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F1625),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing == null
                      ? 'New Reminder'
                      : 'Edit Reminder',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                // Type toggle
                _SectionLabel('REMINDER TYPE'),
                const SizedBox(height: 8),
                _TypeToggle(
                  selected: _type,
                  onChanged: widget.existing == null
                      ? (t) => setState(() => _type = t)
                      : null,
                ),
                const SizedBox(height: 20),

                // Title
                _SectionLabel('TITLE'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Hydration Nudge',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Message
                _SectionLabel('MESSAGE'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _messageCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Stretch your legs and grab water!',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),

                // Type-specific fields
                if (_type == NotificationType.interval) ...[
                  _SectionLabel('REPEAT EVERY'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberField(
                          controller: _hoursCtrl,
                          label: 'Hours',
                          max: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberField(
                          controller: _minsCtrl,
                          label: 'Minutes',
                          max: 59,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _SectionLabel('TRIGGER WHEN'),
                  const SizedBox(height: 8),
                  _MilestoneTypeToggle(
                    selected: _milestoneType,
                    onChanged: (t) => setState(() => _milestoneType = t),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _milestoneValueCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: InputDecoration(
                      hintText: _milestoneType ==
                              MilestoneType.hoursRemaining
                          ? 'e.g. 1.5  (hours remaining)'
                          : 'e.g. 75  (percent complete)',
                      suffixText: _milestoneType ==
                              MilestoneType.hoursRemaining
                          ? 'h'
                          : '%',
                      suffixStyle:
                          const TextStyle(color: Color(0xFFFFB800)),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],

                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1E2D47)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF8A97B0))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB800),
                          foregroundColor: const Color(0xFF080C18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          widget.existing == null ? 'Add' : 'Save',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF5A6478),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      );
}

class _TypeToggle extends StatelessWidget {
  final NotificationType selected;
  final ValueChanged<NotificationType>? onChanged;
  const _TypeToggle({required this.selected, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Interval',
          icon: Icons.repeat_rounded,
          active: selected == NotificationType.interval,
          onTap: onChanged != null
              ? () => onChanged!(NotificationType.interval)
              : null,
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: 'Milestone',
          icon: Icons.flag_rounded,
          active: selected == NotificationType.milestone,
          onTap: onChanged != null
              ? () => onChanged!(NotificationType.milestone)
              : null,
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFFFB800).withValues(alpha: 0.15)
              : const Color(0xFF162035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? const Color(0xFFFFB800) : const Color(0xFF1E2D47),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: active
                    ? const Color(0xFFFFB800)
                    : const Color(0xFF5A6478)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFFFFB800) : const Color(0xFF5A6478),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneTypeToggle extends StatelessWidget {
  final MilestoneType selected;
  final ValueChanged<MilestoneType> onChanged;
  const _MilestoneTypeToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TypeChip(
          label: 'Hours left',
          icon: Icons.hourglass_bottom_rounded,
          active: selected == MilestoneType.hoursRemaining,
          onTap: () => onChanged(MilestoneType.hoursRemaining),
        ),
        const SizedBox(width: 10),
        _TypeChip(
          label: '% done',
          icon: Icons.percent_rounded,
          active: selected == MilestoneType.percentComplete,
          onTap: () => onChanged(MilestoneType.percentComplete),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int max;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
      ),
      maxLength: 2,
      validator: (v) {
        final n = int.tryParse(v ?? '');
        if (n == null || n < 0 || n > max) return '0–$max';
        return null;
      },
    );
  }
}
