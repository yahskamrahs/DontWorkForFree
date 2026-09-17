import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/shift_record_model.dart';
import '../providers/profile_provider.dart';
import '../services/database_service.dart';

class AddPastShiftDialog extends StatefulWidget {
  const AddPastShiftDialog({super.key});

  @override
  State<AddPastShiftDialog> createState() => _AddPastShiftDialogState();
}

class _AddPastShiftDialogState extends State<AddPastShiftDialog> {
  DateTime _date = DateTime.now();
  TimeOfDay _punchIn = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _punchOut = const TimeOfDay(hour: 17, minute: 30);
  int _breakMinutes = 30;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1625),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Past Shift', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow('Date', fmt.format(_date), () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            }),
            const SizedBox(height: 16),
            _buildRow('Punch In', _punchIn.format(context), () async {
              final t = await showTimePicker(context: context, initialTime: _punchIn);
              if (t != null) setState(() => _punchIn = t);
            }),
            const SizedBox(height: 16),
            _buildRow('Punch Out', _punchOut.format(context), () async {
              final t = await showTimePicker(context: context, initialTime: _punchOut);
              if (t != null) setState(() => _punchOut = t);
            }),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Break (Mins)', style: TextStyle(color: Color(0xFF8A97B0))),
                SizedBox(
                  width: 80,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF3D4A60)),
                      ),
                    ),
                    controller: TextEditingController(text: _breakMinutes.toString())
                      ..selection = TextSelection.collapsed(offset: _breakMinutes.toString().length),
                    onChanged: (v) {
                      _breakMinutes = int.tryParse(v) ?? 0;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF5A6478))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            foregroundColor: const Color(0xFF080C18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _save,
          child: const Text('Save Shift', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8A97B0))),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF162035),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.activeProfile;

    final inTime = DateTime(_date.year, _date.month, _date.day, _punchIn.hour, _punchIn.minute);
    var outTime = DateTime(_date.year, _date.month, _date.day, _punchOut.hour, _punchOut.minute);

    if (outTime.isBefore(inTime)) {
      // Assume overnight shift
      outTime = outTime.add(const Duration(days: 1));
    }

    final record = ShiftRecordModel(
      date: ShiftRecordModel.dateKey(_date),
      punchIn: inTime.toIso8601String(),
      punchOut: outTime.toIso8601String(),
      totalBreakSeconds: _breakMinutes * 60,
      scheduledDurationMinutes: profile.duration.inMinutes,
      profileId: profile.id,
      profileName: profile.name,
    );

    await DatabaseService.instance.insertRecord(record);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
