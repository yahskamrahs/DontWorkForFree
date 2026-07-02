class ShiftRecordModel {
  final int? id;
  final String date; // yyyy-MM-dd
  final String punchIn; // ISO8601
  final String? punchOut; // ISO8601, null if shift is still open
  final int totalBreakSeconds;
  final int scheduledDurationMinutes;
  final String profileId;
  final String profileName;

  const ShiftRecordModel({
    this.id,
    required this.date,
    required this.punchIn,
    this.punchOut,
    required this.totalBreakSeconds,
    required this.scheduledDurationMinutes,
    required this.profileId,
    required this.profileName,
  });

  DateTime get punchInTime => DateTime.parse(punchIn);
  DateTime? get punchOutTime =>
      punchOut != null ? DateTime.parse(punchOut!) : null;

  Duration get scheduledDuration =>
      Duration(minutes: scheduledDurationMinutes);

  Duration get totalBreak => Duration(seconds: totalBreakSeconds);

  Duration get workedDuration {
    final end = punchOutTime ?? DateTime.now();
    final raw = end.difference(punchInTime) - totalBreak;
    return raw.isNegative ? Duration.zero : raw;
  }

  /// Positive = overtime, Negative = undertime
  Duration get surplus => workedDuration - scheduledDuration;

  bool get wasOnTime => surplus <= const Duration(minutes: 2);
  bool get isOpen => punchOut == null;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'date': date,
        'punch_in': punchIn,
        'punch_out': punchOut,
        'total_break_seconds': totalBreakSeconds,
        'scheduled_duration_minutes': scheduledDurationMinutes,
        'profile_id': profileId,
        'profile_name': profileName,
      };

  factory ShiftRecordModel.fromMap(Map<String, dynamic> m) =>
      ShiftRecordModel(
        id: m['id'] as int?,
        date: m['date'] as String,
        punchIn: m['punch_in'] as String,
        punchOut: m['punch_out'] as String?,
        totalBreakSeconds: m['total_break_seconds'] as int,
        scheduledDurationMinutes: m['scheduled_duration_minutes'] as int,
        profileId: m['profile_id'] as String,
        profileName: m['profile_name'] as String,
      );

  ShiftRecordModel copyWith({String? punchOut, int? totalBreakSeconds}) =>
      ShiftRecordModel(
        id: id,
        date: date,
        punchIn: punchIn,
        punchOut: punchOut ?? this.punchOut,
        totalBreakSeconds: totalBreakSeconds ?? this.totalBreakSeconds,
        scheduledDurationMinutes: scheduledDurationMinutes,
        profileId: profileId,
        profileName: profileName,
      );

  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
