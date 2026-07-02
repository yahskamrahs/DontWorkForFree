import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/shift_profile_model.dart';
import '../providers/profile_provider.dart';

Future<void> showProfileSelectorSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0F1625),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    isScrollControlled: true,
    builder: (_) => const _ProfileSheet(),
  );
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final profiles = provider.allProfiles;
    final activeId = provider.activeProfile.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D47),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Shift Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select your shift duration for today.',
            style: TextStyle(color: Color(0xFF5A6478), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...profiles.map((p) => _ProfileTile(
                profile: p,
                isActive: p.id == activeId,
                onSelect: () async {
                  await provider.setActiveProfile(p.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
                onDelete: p.isDefault
                    ? null
                    : () async {
                        await provider.deleteProfile(p.id);
                      },
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddProfileDialog(context, provider),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Custom Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFFFB800),
              side: const BorderSide(color: Color(0xFFFFB800)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddProfileDialog(
      BuildContext context, ProfileProvider provider) async {
    final nameCtrl = TextEditingController();
    final hCtrl = TextEditingController(text: '8');
    final mCtrl = TextEditingController(text: '30');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Profile',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Profile name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: hCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Hours'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: mCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(color: Color(0xFF5A6478))),
          ),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final h = int.tryParse(hCtrl.text) ?? 0;
              final m = int.tryParse(mCtrl.text) ?? 0;
              final total = h * 60 + m;
              if (name.isNotEmpty && total > 0) {
                await provider.addProfile(
                    ShiftProfileModel.custom(name: name, durationMinutes: total));
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add',
                style: TextStyle(color: Color(0xFFFFB800))),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    hCtrl.dispose();
    mCtrl.dispose();
  }
}

class _ProfileTile extends StatelessWidget {
  final ShiftProfileModel profile;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onSelect,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFB800).withValues(alpha: 0.1)
              : const Color(0xFF162035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFFFFB800)
                : const Color(0xFF1E2D47),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isActive ? const Color(0xFFFFB800) : const Color(0xFF3D4A60),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      color: isActive ? const Color(0xFFFFB800) : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    profile.durationLabel,
                    style: const TextStyle(
                        color: Color(0xFF5A6478), fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18, color: Color(0xFF3D4A60)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
