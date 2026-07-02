class ShiftProfileModel {
  final String id;
  final String name;
  final int durationMinutes;
  final bool isDefault;

  const ShiftProfileModel({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.isDefault = false,
  });

  Duration get duration => Duration(minutes: durationMinutes);

  static const standard = ShiftProfileModel(
    id: 'standard',
    name: 'Standard',
    durationMinutes: 510,
    isDefault: true,
  );

  static const halfDay = ShiftProfileModel(
    id: 'half_day',
    name: 'Half Day',
    durationMinutes: 255,
    isDefault: true,
  );

  factory ShiftProfileModel.custom({
    required String name,
    required int durationMinutes,
  }) =>
      ShiftProfileModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        durationMinutes: durationMinutes,
      );

  ShiftProfileModel copyWith({String? name, int? durationMinutes}) =>
      ShiftProfileModel(
        id: id,
        name: name ?? this.name,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isDefault: isDefault,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'isDefault': isDefault,
      };

  factory ShiftProfileModel.fromJson(Map<String, dynamic> json) =>
      ShiftProfileModel(
        id: json['id'] as String,
        name: json['name'] as String,
        durationMinutes: json['durationMinutes'] as int,
        isDefault: json['isDefault'] as bool? ?? false,
      );

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  bool operator ==(Object other) =>
      other is ShiftProfileModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
