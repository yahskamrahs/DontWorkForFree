import 'dart:convert';

enum NotificationType { interval, milestone }

enum MilestoneType { hoursRemaining, percentComplete }

class CustomNotificationModel {
  final String id;
  final String title;
  final String message;
  final bool isEnabled;
  final NotificationType type;

  // Interval type
  final Duration? intervalDuration;

  // Milestone type
  final MilestoneType? milestoneType;
  final double? milestoneValue;

  const CustomNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isEnabled,
    required this.type,
    this.intervalDuration,
    this.milestoneType,
    this.milestoneValue,
  });

  CustomNotificationModel copyWith({
    String? title,
    String? message,
    bool? isEnabled,
    Duration? intervalDuration,
    MilestoneType? milestoneType,
    double? milestoneValue,
  }) {
    return CustomNotificationModel(
      id: id,
      title: title ?? this.title,
      message: message ?? this.message,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type,
      intervalDuration: intervalDuration ?? this.intervalDuration,
      milestoneType: milestoneType ?? this.milestoneType,
      milestoneValue: milestoneValue ?? this.milestoneValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'isEnabled': isEnabled,
        'type': type.index,
        'intervalSeconds': intervalDuration?.inSeconds,
        'milestoneType': milestoneType?.index,
        'milestoneValue': milestoneValue,
      };

  factory CustomNotificationModel.fromJson(Map<String, dynamic> json) {
    return CustomNotificationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      isEnabled: json['isEnabled'] as bool,
      type: NotificationType.values[json['type'] as int],
      intervalDuration: json['intervalSeconds'] != null
          ? Duration(seconds: json['intervalSeconds'] as int)
          : null,
      milestoneType: json['milestoneType'] != null
          ? MilestoneType.values[json['milestoneType'] as int]
          : null,
      milestoneValue: (json['milestoneValue'] as num?)?.toDouble(),
    );
  }

  static List<CustomNotificationModel> listFromJsonStrings(
      List<String> strings) {
    return strings
        .map((s) => CustomNotificationModel.fromJson(
            jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  String get shortDescription {
    if (type == NotificationType.interval && intervalDuration != null) {
      final h = intervalDuration!.inHours;
      final m = intervalDuration!.inMinutes % 60;
      if (h > 0 && m > 0) return 'Every ${h}h ${m}m';
      if (h > 0) return 'Every ${h}h';
      return 'Every ${m}m';
    }
    if (type == NotificationType.milestone && milestoneValue != null) {
      final val = milestoneValue!;
      final display = val == val.truncateToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      if (milestoneType == MilestoneType.hoursRemaining) {
        return '${display}h remaining';
      }
      return '$display% complete';
    }
    return '';
  }
}
