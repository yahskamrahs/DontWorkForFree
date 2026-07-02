import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_notification_model.dart';

class StorageService {
  static const _punchInKey = 'punch_in_time';
  static const _totalBreakKey = 'total_break_seconds';
  static const _breakStartKey = 'break_start_time';
  static const _isActiveKey = 'is_active';
  static const _isOnBreakKey = 'is_on_break';
  static const _customNotificationsKey = 'custom_notifications';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<void> savePunchIn(DateTime time) async {
    final p = await _prefs;
    await p.setString(_punchInKey, time.toIso8601String());
    await p.setBool(_isActiveKey, true);
  }

  static Future<DateTime?> loadPunchIn() async {
    final p = await _prefs;
    final s = p.getString(_punchInKey);
    return s != null ? DateTime.parse(s) : null;
  }

  static Future<bool> loadIsActive() async {
    final p = await _prefs;
    return p.getBool(_isActiveKey) ?? false;
  }

  static Future<void> saveTotalBreakDuration(Duration d) async {
    final p = await _prefs;
    await p.setInt(_totalBreakKey, d.inSeconds);
  }

  static Future<Duration> loadTotalBreakDuration() async {
    final p = await _prefs;
    return Duration(seconds: p.getInt(_totalBreakKey) ?? 0);
  }

  static Future<void> saveBreakStart(DateTime? time) async {
    final p = await _prefs;
    if (time == null) {
      await p.remove(_breakStartKey);
      await p.setBool(_isOnBreakKey, false);
    } else {
      await p.setString(_breakStartKey, time.toIso8601String());
      await p.setBool(_isOnBreakKey, true);
    }
  }

  static Future<DateTime?> loadBreakStart() async {
    final p = await _prefs;
    final s = p.getString(_breakStartKey);
    return s != null ? DateTime.parse(s) : null;
  }

  static Future<bool> loadIsOnBreak() async {
    final p = await _prefs;
    return p.getBool(_isOnBreakKey) ?? false;
  }

  static Future<void> clearShift() async {
    final p = await _prefs;
    await p.remove(_punchInKey);
    await p.remove(_totalBreakKey);
    await p.remove(_breakStartKey);
    await p.setBool(_isActiveKey, false);
    await p.setBool(_isOnBreakKey, false);
  }

  static Future<void> saveCustomNotifications(
      List<CustomNotificationModel> list) async {
    final p = await _prefs;
    final encoded = list.map((n) => jsonEncode(n.toJson())).toList();
    await p.setStringList(_customNotificationsKey, encoded);
  }

  static Future<List<CustomNotificationModel>> loadCustomNotifications() async {
    final p = await _prefs;
    final raw = p.getStringList(_customNotificationsKey) ?? [];
    return CustomNotificationModel.listFromJsonStrings(raw);
  }
}
