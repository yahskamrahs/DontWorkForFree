import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _salaryKey = 'monthly_salary';
  static const _currencyKey = 'currency_symbol';
  static const _commuteModeKey = 'commute_mode';
  static const _commuteMinKey = 'commute_minutes';
  static const _biometricKey = 'biometric_lock';
  // Built-in notification preferences
  static const _breakReminderEnabledKey = 'break_reminder_enabled';
  static const _breakReminderHourKey = 'break_reminder_hour';
  static const _breakReminderMinuteKey = 'break_reminder_minute';
  static const _twoHourReminderEnabledKey = 'two_hour_reminder_enabled';
  static const _overtimeReminderEnabledKey = 'overtime_reminder_enabled';
  static const _overtimeIntervalKey = 'overtime_interval_minutes';
  static const _entertainmentModeEnabledKey = 'entertainment_mode_enabled';
  static const _entertainmentIntervalKey = 'entertainment_interval_minutes';

  double _monthlySalary = 0;
  String _currencySymbol = '₹';
  bool _commuteMode = false;
  int _commuteMinutes = 30;
  bool _biometricLockEnabled = false;
  // Built-in notifications
  bool _breakReminderEnabled = true;
  int _breakReminderHour = 13;
  int _breakReminderMinute = 30;
  bool _twoHourReminderEnabled = true;
  bool _overtimeReminderEnabled = true;
  int _overtimeIntervalMinutes = 15;
  bool _entertainmentModeEnabled = true;
  int _entertainmentIntervalMinutes = 15;

  double get monthlySalary => _monthlySalary;
  String get currencySymbol => _currencySymbol;
  bool get commuteMode => _commuteMode;
  int get commuteMinutes => _commuteMinutes;
  bool get biometricLockEnabled => _biometricLockEnabled;
  bool get hasEarningsData => _monthlySalary > 0;
  bool get breakReminderEnabled => _breakReminderEnabled;
  int get breakReminderHour => _breakReminderHour;
  int get breakReminderMinute => _breakReminderMinute;
  bool get twoHourReminderEnabled => _twoHourReminderEnabled;
  bool get overtimeReminderEnabled => _overtimeReminderEnabled;
  int get overtimeIntervalMinutes => _overtimeIntervalMinutes;
  bool get entertainmentModeEnabled => _entertainmentModeEnabled;
  int get entertainmentIntervalMinutes => _entertainmentIntervalMinutes;

  int get currentMonthDays {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0).day;
  }

  double perSecondRate(int shiftMinutes) {
    if (_monthlySalary <= 0 || shiftMinutes <= 0) return 0;
    return (_monthlySalary / currentMonthDays) / (shiftMinutes * 60);
  }

  Future<void> initialize() async {
    final p = await SharedPreferences.getInstance();
    _monthlySalary = p.getDouble(_salaryKey) ?? 0;
    _currencySymbol = p.getString(_currencyKey) ?? '₹';
    _commuteMode = p.getBool(_commuteModeKey) ?? false;
    _commuteMinutes = p.getInt(_commuteMinKey) ?? 30;
    _biometricLockEnabled = p.getBool(_biometricKey) ?? false;
    _breakReminderEnabled = p.getBool(_breakReminderEnabledKey) ?? true;
    _breakReminderHour = p.getInt(_breakReminderHourKey) ?? 13;
    _breakReminderMinute = p.getInt(_breakReminderMinuteKey) ?? 30;
    _twoHourReminderEnabled = p.getBool(_twoHourReminderEnabledKey) ?? true;
    _overtimeReminderEnabled = p.getBool(_overtimeReminderEnabledKey) ?? true;
    _overtimeIntervalMinutes = p.getInt(_overtimeIntervalKey) ?? 15;
    _entertainmentModeEnabled = p.getBool(_entertainmentModeEnabledKey) ?? true;
    _entertainmentIntervalMinutes = p.getInt(_entertainmentIntervalKey) ?? 15;
    notifyListeners();
  }

  Future<void> setMonthlySalary(double value) async {
    _monthlySalary = value;
    await (await SharedPreferences.getInstance()).setDouble(_salaryKey, value);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    await (await SharedPreferences.getInstance()).setString(_currencyKey, symbol);
    notifyListeners();
  }

  Future<void> setCommuteMode(bool enabled) async {
    _commuteMode = enabled;
    await (await SharedPreferences.getInstance()).setBool(_commuteModeKey, enabled);
    notifyListeners();
  }

  Future<void> setCommuteMinutes(int minutes) async {
    _commuteMinutes = minutes;
    await (await SharedPreferences.getInstance()).setInt(_commuteMinKey, minutes);
    notifyListeners();
  }

  Future<void> setBiometricLock(bool enabled) async {
    _biometricLockEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_biometricKey, enabled);
    notifyListeners();
  }

  Future<void> setBreakReminderEnabled(bool enabled) async {
    _breakReminderEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_breakReminderEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setBreakReminderTime(int hour, int minute) async {
    _breakReminderHour = hour;
    _breakReminderMinute = minute;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_breakReminderHourKey, hour);
    await p.setInt(_breakReminderMinuteKey, minute);
    notifyListeners();
  }

  Future<void> setTwoHourReminderEnabled(bool enabled) async {
    _twoHourReminderEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_twoHourReminderEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setOvertimeReminderEnabled(bool enabled) async {
    _overtimeReminderEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_overtimeReminderEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setOvertimeIntervalMinutes(int minutes) async {
    _overtimeIntervalMinutes = minutes;
    await (await SharedPreferences.getInstance()).setInt(_overtimeIntervalKey, minutes);
    notifyListeners();
  }

  Future<void> setEntertainmentModeEnabled(bool enabled) async {
    _entertainmentModeEnabled = enabled;
    await (await SharedPreferences.getInstance()).setBool(_entertainmentModeEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setEntertainmentIntervalMinutes(int minutes) async {
    _entertainmentIntervalMinutes = minutes;
    await (await SharedPreferences.getInstance()).setInt(_entertainmentIntervalKey, minutes);
    notifyListeners();
  }
}
