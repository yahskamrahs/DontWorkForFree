import 'dart:async';
import 'package:flutter/material.dart';
import '../models/custom_notification_model.dart';
import '../models/shift_record_model.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';

class ShiftProvider extends ChangeNotifier with WidgetsBindingObserver {
  // ── Profile-injected fields ─────────────────────────────────────────────────
  Duration _shiftDuration = const Duration(hours: 8, minutes: 30);
  String _profileId = 'standard';
  String _profileName = 'Standard';

  // ── Shift state ─────────────────────────────────────────────────────────────
  DateTime? _punchInTime;
  Duration _totalBreakDuration = Duration.zero;
  DateTime? _breakStartTime;
  bool _isActive = false;
  bool _isOnBreak = false;
  bool _isShiftComplete = false;

  // ── History tracking ─────────────────────────────────────────────────────────
  int? _openRecordId;

  // ── Custom notifications ─────────────────────────────────────────────────────
  List<CustomNotificationModel> _customNotifications = [];

  // ── Ticker ───────────────────────────────────────────────────────────────────
  Timer? _ticker;
  int _tickCount = 0;

  // ── Public getters ────────────────────────────────────────────────────────────

  DateTime? get punchInTime => _punchInTime;
  bool get isActive => _isActive;
  bool get isOnBreak => _isOnBreak;
  bool get isShiftComplete => _isShiftComplete;
  Duration get totalBreakDuration => _totalBreakDuration;
  Duration get shiftTarget => _shiftDuration;

  List<CustomNotificationModel> get customNotifications =>
      List.unmodifiable(_customNotifications);

  Duration get currentBreakElapsed =>
      (_isOnBreak && _breakStartTime != null)
          ? DateTime.now().difference(_breakStartTime!)
          : Duration.zero;

  Duration get _totalBreaksSoFar => _totalBreakDuration + currentBreakElapsed;

  // Break is included within the shift — exit time never moves
  DateTime get safeExitTime {
    if (_punchInTime == null) return DateTime.now();
    return _punchInTime!.add(_shiftDuration);
  }

  Duration get remainingTime {
    if (!_isActive) return Duration.zero;
    final diff = safeExitTime.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  double get progress {
    if (!_isActive) return 0.0;
    final worked = _shiftDuration - remainingTime;
    return (worked.inMilliseconds / _shiftDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  // ── Notification preferences (injected from SettingsProvider) ───────────────
  bool _breakReminderEnabled = false;
  int _breakReminderHour = 13;
  int _breakReminderMinute = 30;
  bool _twoHourReminderEnabled = false;
  bool _overtimeReminderEnabled = true;
  int _overtimeIntervalMinutes = 15;
  bool _entertainmentModeEnabled = true;
  int _entertainmentIntervalMinutes = 15;

  // ── Called by ProxyProvider whenever ProfileProvider changes ─────────────────

  void updateShiftDuration(Duration duration, String profileId, String profileName) {
    _shiftDuration = duration;
    _profileId = profileId;
    _profileName = profileName;
    if (_isActive) {
      _rescheduleNotifications();
      _syncWidget();
    }
    notifyListeners();
  }

  // ── Called by ProxyProvider2 whenever SettingsProvider changes ───────────────

  void updateNotificationSettings({
    required bool breakReminderEnabled,
    required int breakReminderHour,
    required int breakReminderMinute,
    required bool twoHourReminderEnabled,
    required bool overtimeReminderEnabled,
    required int overtimeIntervalMinutes,
    required bool entertainmentModeEnabled,
    required int entertainmentIntervalMinutes,
  }) {
    _breakReminderEnabled = breakReminderEnabled;
    _breakReminderHour = breakReminderHour;
    _breakReminderMinute = breakReminderMinute;
    _twoHourReminderEnabled = twoHourReminderEnabled;
    _overtimeReminderEnabled = overtimeReminderEnabled;
    _overtimeIntervalMinutes = overtimeIntervalMinutes;
    _entertainmentModeEnabled = entertainmentModeEnabled;
    _entertainmentIntervalMinutes = entertainmentIntervalMinutes;
    if (_isActive) _rescheduleNotifications();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    _customNotifications = await StorageService.loadCustomNotifications();
    final wasActive = await StorageService.loadIsActive();

    if (wasActive) {
      _punchInTime = await StorageService.loadPunchIn();
      _totalBreakDuration = await StorageService.loadTotalBreakDuration();
      _isOnBreak = await StorageService.loadIsOnBreak();
      _breakStartTime = await StorageService.loadBreakStart();
      _isActive = _punchInTime != null;

      if (_isActive) {
        // Restore open DB record id
        final openRecord = await DatabaseService.instance.getOpenRecord();
        _openRecordId = openRecord?.id;

        if (remainingTime == Duration.zero) {
          _isShiftComplete = true;
        } else {
          _startTicker();
        }
        await _rescheduleNotifications();
        await _syncWidget();
        await NotificationService.instance
            .showPersistentTimer(safeExitTime: safeExitTime, shiftDuration: _shiftDuration, isOnBreak: _isOnBreak, breakStartTime: _breakStartTime);
      }
    }

    notifyListeners();
  }

  // ── Shift actions ────────────────────────────────────────────────────────────

  Future<void> punchIn({DateTime? customTime}) async {
    _punchInTime = customTime ?? DateTime.now();
    _totalBreakDuration = Duration.zero;
    _breakStartTime = null;
    _isActive = true;
    _isOnBreak = false;
    _isShiftComplete = false;
    _tickCount = 0;

    await StorageService.savePunchIn(_punchInTime!);
    await StorageService.saveTotalBreakDuration(Duration.zero);
    await StorageService.saveBreakStart(null);

    // Open a DB record for this shift
    final record = ShiftRecordModel(
      date: ShiftRecordModel.dateKey(_punchInTime!),
      punchIn: _punchInTime!.toIso8601String(),
      totalBreakSeconds: 0,
      scheduledDurationMinutes: _shiftDuration.inMinutes,
      profileId: _profileId,
      profileName: _profileName,
    );
    _openRecordId = await DatabaseService.instance.insertRecord(record);

    _startTicker();
    await _rescheduleNotifications();
    await _syncWidget();
    await NotificationService.instance
        .showPersistentTimer(safeExitTime: safeExitTime, shiftDuration: _shiftDuration, isOnBreak: _isOnBreak, breakStartTime: _breakStartTime);
    notifyListeners();
  }

  Future<void> punchOut() async {
    // Close the DB record
    if (_openRecordId != null) {
      final closed = ShiftRecordModel(
        id: _openRecordId,
        date: ShiftRecordModel.dateKey(_punchInTime!),
        punchIn: _punchInTime!.toIso8601String(),
        punchOut: DateTime.now().toIso8601String(),
        totalBreakSeconds: _totalBreaksSoFar.inSeconds,
        scheduledDurationMinutes: _shiftDuration.inMinutes,
        profileId: _profileId,
        profileName: _profileName,
      );
      await DatabaseService.instance.updateRecord(closed);
    }

    _ticker?.cancel();
    _ticker = null;
    _isActive = false;
    _isOnBreak = false;
    _isShiftComplete = false;
    _punchInTime = null;
    _totalBreakDuration = Duration.zero;
    _breakStartTime = null;
    _openRecordId = null;
    _tickCount = 0;

    await StorageService.clearShift();
    await NotificationService.instance.cancelAll();
    await NotificationService.instance.dismissAlarm();
    await NotificationService.instance.cancelPersistentTimer();
    await WidgetService.clear();
    notifyListeners();
  }

  Future<void> adjustPunchInTime(DateTime newTime) async {
    if (!_isActive) return;
    _punchInTime = newTime;
    await StorageService.savePunchIn(newTime);

    // Update open DB record
    if (_openRecordId != null) {
      final updated = ShiftRecordModel(
        id: _openRecordId,
        date: ShiftRecordModel.dateKey(newTime),
        punchIn: newTime.toIso8601String(),
        totalBreakSeconds: _totalBreakDuration.inSeconds,
        scheduledDurationMinutes: _shiftDuration.inMinutes,
        profileId: _profileId,
        profileName: _profileName,
      );
      await DatabaseService.instance.updateRecord(updated);
    }

    await _rescheduleNotifications();
    await _syncWidget();
    await NotificationService.instance
        .showPersistentTimer(safeExitTime: safeExitTime, shiftDuration: _shiftDuration, isOnBreak: _isOnBreak, breakStartTime: _breakStartTime);
    notifyListeners();
  }

  Future<void> startBreak() async {
    if (!_isActive || _isOnBreak) return;
    _isOnBreak = true;
    _breakStartTime = DateTime.now();
    await StorageService.saveBreakStart(_breakStartTime);
    await NotificationService.instance.showPersistentTimer(
      safeExitTime: safeExitTime,
      shiftDuration: _shiftDuration,
      isOnBreak: _isOnBreak,
      breakStartTime: _breakStartTime,
    );
    notifyListeners();
  }

  Future<void> endBreak() async {
    if (!_isActive || !_isOnBreak || _breakStartTime == null) return;
    _totalBreakDuration += DateTime.now().difference(_breakStartTime!);
    _isOnBreak = false;
    _breakStartTime = null;
    await StorageService.saveTotalBreakDuration(_totalBreakDuration);
    await StorageService.saveBreakStart(null);
    // No rescheduling — exit time is fixed, breaks don't affect it
    await NotificationService.instance.showPersistentTimer(
      safeExitTime: safeExitTime,
      shiftDuration: _shiftDuration,
      isOnBreak: _isOnBreak,
      breakStartTime: _breakStartTime,
    );
    notifyListeners();
  }

  // ── Custom notifications ──────────────────────────────────────────────────────

  Future<void> addCustomNotification(CustomNotificationModel n) async {
    _customNotifications.add(n);
    await _persistAndReschedule();
  }

  Future<void> updateCustomNotification(CustomNotificationModel n) async {
    final idx = _customNotifications.indexWhere((x) => x.id == n.id);
    if (idx >= 0) {
      _customNotifications[idx] = n;
      await _persistAndReschedule();
    }
  }

  Future<void> deleteCustomNotification(String id) async {
    _customNotifications.removeWhere((x) => x.id == id);
    await _persistAndReschedule();
  }

  Future<void> toggleCustomNotification(String id) async {
    final idx = _customNotifications.indexWhere((x) => x.id == id);
    if (idx >= 0) {
      final n = _customNotifications[idx];
      _customNotifications[idx] = n.copyWith(isEnabled: !n.isEnabled);
      await _persistAndReschedule();
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _tickCount++;

      if (!_isShiftComplete && remainingTime == Duration.zero) {
        _isShiftComplete = true;
        _ticker?.cancel();
        _ticker = null;
        WidgetService.clear();
        NotificationService.instance
            .switchPersistentTimerToOvertime(safeExitTime: safeExitTime);
      }

      // Update home widget and notification progress once per minute
      if (_tickCount % 60 == 0) {
        _syncWidget();
        if (!_isShiftComplete) {
          NotificationService.instance.showPersistentTimer(safeExitTime: safeExitTime, shiftDuration: _shiftDuration, isOnBreak: _isOnBreak, breakStartTime: _breakStartTime);
        }
      }

      notifyListeners();
    });
  }

  Future<void> _rescheduleNotifications() async {
    if (!_isActive || _punchInTime == null) return;
    await NotificationService.instance.scheduleAllNotifications(
      punchInTime: _punchInTime!,
      safeExitTime: safeExitTime,
      shiftDuration: _shiftDuration,
      customNotifications: _customNotifications,
      breakReminderEnabled: _breakReminderEnabled,
      breakReminderHour: _breakReminderHour,
      breakReminderMinute: _breakReminderMinute,
      twoHourReminderEnabled: _twoHourReminderEnabled,
      overtimeReminderEnabled: _overtimeReminderEnabled,
      overtimeIntervalMinutes: _overtimeIntervalMinutes,
      entertainmentModeEnabled: _entertainmentModeEnabled,
      entertainmentIntervalMinutes: _entertainmentIntervalMinutes,
    );
  }

  Future<void> _syncWidget() async {
    final r = remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');
    final exitFmt = _isActive
        ? '${safeExitTime.hour % 12 == 0 ? 12 : safeExitTime.hour % 12}'
            ':${safeExitTime.minute.toString().padLeft(2, '0')}'
            ' ${safeExitTime.hour >= 12 ? 'PM' : 'AM'}'
        : '--';
    await WidgetService.update(
      isActive: _isActive,
      remaining: '$h:$m:$s',
      exitTime: exitFmt,
    );
  }

  Future<void> _persistAndReschedule() async {
    await StorageService.saveCustomNotifications(_customNotifications);
    if (_isActive) await _rescheduleNotifications();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || state == AppLifecycleState.paused) {
      if (_isActive && !_isShiftComplete) {
        NotificationService.instance.showPersistentTimer(safeExitTime: safeExitTime, shiftDuration: _shiftDuration, isOnBreak: _isOnBreak, breakStartTime: _breakStartTime);
      } else if (_isActive && _isShiftComplete) {
        NotificationService.instance.switchPersistentTimerToOvertime(safeExitTime: safeExitTime);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
}
