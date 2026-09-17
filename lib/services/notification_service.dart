import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/custom_notification_model.dart';
import 'joke_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  if (response.actionId == 'snooze_5') {
    tz_data.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    // Cancel the currently blaring alarm
    if (response.id != null) {
      await plugin.cancel(response.id!);
    } else {
      await plugin.cancel(2); // _alarmId is 2
    }

    final now = tz.TZDateTime.now(tz.local);
    final snoozeTime = now.add(const Duration(minutes: 5));

    await plugin.zonedSchedule(
      9999,
      '🚨 SIREN SNOOZED',
      'You have 5 minutes before the siren blares again. Go home.',
      snoozeTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shift_critical_siren_2',
          'Siren Alerts',
          sound: const RawResourceAndroidNotificationSound('siren'),
          playSound: true,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('snooze_5', 'Snooze 5 mins', showsUserInterface: true),
            AndroidNotificationAction('stop_alarm', 'Stop Siren', showsUserInterface: true),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } else if (response.actionId == 'stop_alarm') {
    final plugin = FlutterLocalNotificationsPlugin();
    if (response.id != null) {
      await plugin.cancel(response.id!);
    } else {
      await plugin.cancel(2); // _alarmId is 2
    }
    // You could also cancel the snooze alarm (id 9999) if they spam it
    await plugin.cancel(9999);
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // ── Notification IDs ────────────────────────────────────────────────────────
  static const _warningId = 1;       // 5-min warning
  static const _alarmId = 2;         // shift-complete siren
  static const _breakReminderId = 3; // fixed-time break reminder
  static const _twoHourId = 4;       // 2 hours remaining
  static const _overtimeBase = 10;   // 10–17: overtime escalation (8 slots)
  static const _overtimeSlots = 8;
  static const _entertainmentBase = 30; // 30+ for jokes
  static const _customBase = 100;
  static const _idsPerCustom = 15;
  static const _persistentTimerId = 50; // live lock-screen shift countdown

  // ── Channel IDs ─────────────────────────────────────────────────────────────
  static const _shiftChannel = 'shift_critical_v2';
  static const _reminderChannel = 'shift_reminders_v2';
  static const _sirenChannel = 'shift_critical_siren_2';
  static const _persistentChannel = 'shift_timer_v2';

  // App icon shown as large icon on every notification
  static const _appIcon =
      DrawableResourceAndroidBitmap('@mipmap/launcher_icon');

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    await _createChannels();
    _setupMethodChannel();
  }

  static const _batteryChannel = MethodChannel('com.example.dontworkforfree/battery');
  static const _customChannel = MethodChannel('com.example.dontworkforfree/notifications');

  Function(String)? onCustomAction;

  void _setupMethodChannel() {
    _customChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationAction') {
        final action = call.arguments as String;
        onCustomAction?.call(action);
      }
    });
  }
  Future<void> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await _requestBatteryOptimizationExemption();
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final isIgnoring = await _batteryChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (!isIgnoring) {
        await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (_) {
      // Non-fatal: device may not support this API
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(AndroidNotificationChannel(
      _shiftChannel,
      'Shift Alerts',
      description: 'Critical shift alerts — 5-min warning & overtime siren',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFFFF1744),
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _reminderChannel,
      'Shift Reminders',
      description: 'Break reminders, milestones & interval nudges',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _sirenChannel,
      'Siren Alerts',
      description: 'Used for extremely aggressive looping alarms.',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('siren'),
      enableVibration: true,
    ));

    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _persistentChannel,
      'Live Shift Timer',
      description: 'Silent, persistent notification showing your live shift countdown — visible on the lock screen, like a screen-recording timer.',
      importance: Importance.defaultImportance,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERSISTENT LIVE TIMER — lock-screen chronometer, same mechanism screen
  // recorders use (Notification.Builder#setUsesChronometer). The OS ticks
  // this natively from `when`, so it keeps counting even if the app process
  // is backgrounded or killed — no periodic updates needed from Dart.
  // ══════════════════════════════════════════════════════════════════════════

  /// Shows/refreshes the live shift-timer notification. Counts down to
  /// [safeExitTime] while on the clock, or counts up from it once overtime
  /// has started.
  Future<void> showPersistentTimer({
    required DateTime safeExitTime,
    Duration? shiftDuration,
    bool isOnBreak = false,
    DateTime? breakStartTime,
  }) async {
    final isOvertime = DateTime.now().isAfter(safeExitTime);
    await _postPersistentTimer(
      anchor: safeExitTime,
      countDown: !isOvertime,
      title: isOvertime ? '🔴 Working overtime' : '🟢 Shift in progress',
      body: isOvertime ? 'Unpaid time elapsed' : 'Time left until safe exit',
      shiftDuration: shiftDuration,
      isOnBreak: isOnBreak,
      breakStartTime: breakStartTime,
    );
  }

  /// Flips an already-showing timer from countdown to counting up, once the
  /// shift completes. Cheap to call — it's just a notification content swap.
  Future<void> switchPersistentTimerToOvertime(
          {required DateTime safeExitTime}) =>
      _postPersistentTimer(
        anchor: safeExitTime,
        countDown: false,
        title: '🔴 Working overtime',
        body: 'Unpaid time elapsed',
        shiftDuration: null,
      );

  Future<void> _postPersistentTimer({
    required DateTime anchor,
    required bool countDown,
    required String title,
    required String body,
    Duration? shiftDuration,
    bool isOnBreak = false,
    DateTime? breakStartTime,
  }) async {
    int progressPercent = countDown ? 100 : 100;
    if (countDown && shiftDuration != null && shiftDuration.inSeconds > 0) {
      final now = DateTime.now();
      final remaining = anchor.difference(now).inSeconds;
      progressPercent = ((remaining / shiftDuration.inSeconds) * 100).clamp(0, 100).toInt();
    }

    if (Platform.isAndroid) {
      try {
        await _customChannel.invokeMethod('showActiveShiftNotification', {
          'isOvertime': !countDown,
          'anchorEpochMillis': anchor.millisecondsSinceEpoch,
          'progressPercent': progressPercent,
          'isOnBreak': isOnBreak,
          'breakStartEpochMillis': breakStartTime?.millisecondsSinceEpoch ?? 0,
        });
        return; // Custom notification shown — don't show standard
      } catch (e) {
        debugPrint('Custom notification failed, falling back to standard: $e');
      }
    }
    // Fallback: standard notification (non-Android, or custom failed)
    await _postStandardTimer(anchor, countDown, title, body);
  }

  Future<void> _postStandardTimer(
    DateTime anchor,
    bool countDown,
    String title,
    String body,
  ) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _persistentChannel,
        'Live Shift Timer',
        importance: Importance.defaultImportance,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        when: anchor.millisecondsSinceEpoch,
        usesChronometer: true,
        chronometerCountDown: countDown,
        visibility: NotificationVisibility.public,
        largeIcon: _appIcon,
        category: AndroidNotificationCategory.status,
      ),
    );
    await _plugin.show(_persistentTimerId, title, body, details);
  }

  Future<void> cancelPersistentTimer() async {
    if (Platform.isAndroid) {
      try {
        await _customChannel.invokeMethod('cancelActiveShiftNotification');
      } catch (e) {
        // Ignore
      }
    }
    await _plugin.cancel(_persistentTimerId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MASTER SCHEDULER
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> scheduleAllNotifications({
    required DateTime punchInTime,
    required DateTime safeExitTime,
    required Duration shiftDuration,
    required List<CustomNotificationModel> customNotifications,
    bool breakReminderEnabled = false,
    int breakReminderHour = 13,
    int breakReminderMinute = 30,
    bool twoHourReminderEnabled = false,
    bool overtimeReminderEnabled = true,
    int overtimeIntervalMinutes = 15,
    bool entertainmentModeEnabled = true,
    int entertainmentIntervalMinutes = 15,
  }) async {
    await cancelAll();
    final now = DateTime.now();

    // ── 5-min warning ───────────────────────────────────────────────────────
    final warnAt = safeExitTime.subtract(const Duration(minutes: 5));
    if (warnAt.isAfter(now)) {
      await _fire(
        id: _warningId,
        title: '⚡ 5 MINUTES TO FREEDOM',
        body: 'Start shutting down. You\'ve earned this.',
        bigText:
            'Your shift wraps up in 5 minutes. Close those tabs, save your work '
            'and get ready to walk out. You\'ve put in the hours — now claim your freedom.',
        at: warnAt,
        channelId: _shiftChannel,
        importance: Importance.high,
        priority: Priority.high,
        accentColor: const Color(0xFFFFB800),
        mode: AndroidScheduleMode.exactAllowWhileIdle,
        ticker: '5 minutes left in your shift!',
      );
    }

    // ── Shift-complete alarm (SIREN) ─────────────────────────────────────────
    if (safeExitTime.isAfter(now)) {
      await _scheduleAlarm(at: safeExitTime);
    }

    // ── Built-in: break reminder ─────────────────────────────────────────────
    if (breakReminderEnabled) {
      await _scheduleBreakReminder(
        hour: breakReminderHour,
        minute: breakReminderMinute,
        shiftStart: punchInTime,
        shiftEnd: safeExitTime,
      );
    }

    // ── Built-in: Every 2 hours update ───────────────────────────────────────
    if (twoHourReminderEnabled) {
      for (int i = 1; i <= 6; i++) {
        final at = punchInTime.add(Duration(hours: 2 * i));
        if (at.isAfter(now) && at.isBefore(safeExitTime)) {
          final remaining = safeExitTime.difference(at);
          final hoursLeft = remaining.inHours;
          final minsLeft = remaining.inMinutes % 60;
          final timeStr = hoursLeft > 0 ? '$hoursLeft hr $minsLeft min' : '$minsLeft min';
          
          await _fire(
            id: _twoHourId + i,
            title: '⏳ SHIFT UPDATE: $timeStr LEFT',
            body: 'You have been working for ${2 * i} hours.',
            bigText: 'You are ${2 * i} hours into your shift. '
                     'There is exactly $timeStr left until you can go home. Keep it up!',
            at: at,
            channelId: _reminderChannel,
            importance: Importance.high,
            priority: Priority.high,
            accentColor: const Color(0xFFFFB800),
            mode: AndroidScheduleMode.exactAllowWhileIdle,
            ticker: '$timeStr left on your shift.',
          );
        }
      }
    }

    // ── Hardcoded Idle Alerts (Every 1 hour) ─────────────────────────────────
    for (int i = 1; i <= 8; i++) {
      final at = punchInTime.add(Duration(hours: i));
      if (at.isAfter(now) && at.isBefore(safeExitTime)) {
        await _fire(
          id: 5000 + i, // idle base id
          title: '🚶 Time to Move!',
          body: 'You have been working for $i hour(s). Stretch a bit!',
          bigText: 'Sitting for too long is bad for your health. '
                   'Get up, stretch your legs, drink some water, and rest your eyes for a few minutes.',
          at: at,
          channelId: _reminderChannel,
          importance: Importance.high,
          priority: Priority.high,
          accentColor: const Color(0xFF00E676),
          mode: AndroidScheduleMode.exactAllowWhileIdle,
          ticker: 'Take a quick break!',
        );
      }
    }

    // ── Built-in: overtime escalation ───────────────────────────────────────
    if (overtimeReminderEnabled) {
      await _scheduleOvertimeEscalation(
        safeExitTime: safeExitTime,
        intervalMinutes: overtimeIntervalMinutes,
      );
    }

    // ── Built-in: entertainment mode ────────────────────────────────────────
    if (entertainmentModeEnabled && entertainmentIntervalMinutes > 0) {
      final jokes = await JokeService.fetchJokes(count: 10);
      int jokeIndex = 0;
      int i = 1;
      while (true) {
        final at = punchInTime.add(Duration(minutes: entertainmentIntervalMinutes * i));
        if (at.isAfter(safeExitTime)) break;
        if (at.isAfter(now)) {
          final joke = jokes[jokeIndex % jokes.length];
          await _fire(
            id: _entertainmentBase + i,
            title: '🎭 Joke Break!',
            body: joke,
            bigText: joke,
            at: at,
            channelId: _reminderChannel,
            importance: Importance.high,
            priority: Priority.high,
            accentColor: const Color(0xFF00BCD4),
            mode: AndroidScheduleMode.exactAllowWhileIdle,
            ticker: 'Time for a quick laugh',
          );
          jokeIndex++;
        }
        i++;
      }
    }

    // ── User custom notifications ────────────────────────────────────────────
    for (int i = 0; i < customNotifications.length; i++) {
      final cn = customNotifications[i];
      if (!cn.isEnabled) continue;
      await _scheduleCustom(
        notification: cn,
        punchInTime: punchInTime,
        safeExitTime: safeExitTime,
        shiftDuration: shiftDuration,
        baseId: _customBase + i * _idsPerCustom,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILT-IN NOTIFICATION METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _scheduleBreakReminder({
    required int hour,
    required int minute,
    required DateTime shiftStart,
    required DateTime shiftEnd,
  }) async {
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, hour, minute);
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');

    if (at.isAfter(now) && at.isAfter(shiftStart) && at.isBefore(shiftEnd)) {
      await _fire(
        id: _breakReminderId,
        title: '☕ BREAK O\'CLOCK — $hh:$mm',
        body: 'Step away. Hydrate. Breathe. You\'ve earned this.',
        bigText:
            'It\'s $hh:$mm — your designated break time. '
            'Close the screen, refill your water and give your brain a reset. '
            'A sharp mind after a break is worth more than 30 more tired minutes.',
        at: at,
        channelId: _reminderChannel,
        importance: Importance.high,
        priority: Priority.high,
        accentColor: const Color(0xFF7C83FD),
        mode: AndroidScheduleMode.exactAllowWhileIdle,
        ticker: 'Break time! Step away for a bit.',
      );
    }
  }

  Future<void> _scheduleOvertimeEscalation({
    required DateTime safeExitTime,
    required int intervalMinutes,
  }) async {
    const titles = [
      '🔴 OVERTIME — YOU\'RE WORKING FOR FREE',
      '💸 STILL HERE? THAT\'S FREE MONEY GONE.',
      '🚨 YOUR EMPLOYER IS LOVING THIS. LEAVE.',
      '⛔ 1 HOUR FREE. THIS STOPS NOW.',
      '🔥 YOUR CLOCK. YOUR MONEY. YOUR LOSS.',
      '💀 STILL GIFTING YOUR TIME AWAY?',
      '🚨 SERIOUSLY — THE DOOR IS RIGHT THERE.',
      '☠️ FINAL OVERTIME ALERT. WE TRIED.',
    ];

    const bodies = [
      'Pack your bag and walk out. Every minute is unpaid.',
      'Close that laptop. You\'re not getting paid for this.',
      'They\'re not paying. You\'re not leaving. Fix one of those.',
      'An entire hour free. This is not okay. GO HOME.',
      'Your time has a price. Stop discounting it. Leave now.',
      'The exit is 10 steps away. Take them. Right now.',
      'Last chance before we stop trying. Please just go.',
      'Two hours free. We\'re done sending alerts. You\'re on your own.',
    ];

    const expanded = [
      'Your shift ended and you\'re still at your desk. '
          'Every single minute from here is FREE labor — no pay, no compensation, nothing. '
          'Pack your bag. Close your laptop. Walk out the door.',

      'You\'ve now given away free time to your employer. '
          'That\'s money you\'ll never see. Shut down your screen right now and leave. '
          'Your employer is not going to thank you for this.',

      'Nearly an hour of unpaid work. Your employer is absolutely thrilled. '
          'Are you? Because you should be furious. '
          'Close the laptop. Grab your bag. Don\'t look back.',

      'ONE FULL HOUR worked for zero pay. '
          'Think about what that means. An hour of your life — your time, your energy — '
          'handed over for free. This ends now. Get up and go home.',

      'Your boss clocked out. Your colleagues left. The building is emptying. '
          'And you\'re still here, working for free. '
          'Your time has value. Stop giving it away. LEAVE.',

      '90 minutes of unpaid overtime. If this were a salary deduction you\'d be furious. '
          'This is worse — it\'s invisible. You\'re not getting this time back. '
          'Please get up and walk out right now.',

      'This app has tried 7 times to get you to leave. '
          'Your shift ended a long time ago. This is the second-to-last alert. '
          'Walk out that door before the final one arrives.',

      'Two full hours of FREE work. This is the last notification we\'ll send. '
          'We\'ve done everything we can. The rest is up to you. '
          'You deserve to go home. Please go home.',
    ];

    final now = DateTime.now();
    for (int i = 0; i < _overtimeSlots; i++) {
      final at = safeExitTime.add(Duration(minutes: intervalMinutes * (i + 1)));
      if (at.isAfter(now)) {
        await _fire(
          id: _overtimeBase + i,
          title: titles[i],
          body: bodies[i],
          bigText: expanded[i],
          at: at,
          channelId: _shiftChannel,
          importance: Importance.max,
          priority: Priority.max,
          accentColor: const Color(0xFFFF1744),
          mode: AndroidScheduleMode.exactAllowWhileIdle,
          ticker: bodies[i],
          vibrationPattern: Int64List.fromList([0, 600, 200, 600]),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CORE FIRE METHOD
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _fire({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String channelId,
    required Importance importance,
    required Priority priority,
    required AndroidScheduleMode mode,
    required Color accentColor,
    String? bigText,
    String? ticker,
    bool fullScreen = false,
    Int64List? vibrationPattern,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == _shiftChannel ? 'Shift Alerts' : (channelId == _sirenChannel ? 'Siren Alerts' : 'Shift Reminders'),
        importance: importance,
        priority: priority,
        color: accentColor,
        playSound: true,
        largeIcon: _appIcon,
        vibrationPattern:
            vibrationPattern ?? Int64List.fromList([0, 400, 200, 400]),
        fullScreenIntent: fullScreen,
        ticker: ticker,
        styleInformation: bigText != null
            ? BigTextStyleInformation(
                bigText,
                htmlFormatBigText: false,
                contentTitle: title,
                summaryText: "Don't Work For Free",
              )
            : const DefaultStyleInformation(false, false),
      ),
    );

    final tzAt = tz.TZDateTime.from(at, tz.local);
    final tzNow = tz.TZDateTime.now(tz.local);

    if (tzAt.isBefore(tzNow)) {
      await _plugin.show(
        id,
        title,
        body,
        details,
      );
    } else {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzAt,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── Shift-complete alarm (highest priority — bypasses DND) ──────────────────
  Future<void> _scheduleAlarm({required DateTime at}) async {
    final aggVibration = Int64List.fromList(
        [0, 1000, 300, 1000, 300, 1000, 300, 1000, 300, 1000]);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _sirenChannel,
        'Siren Alerts',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        autoCancel: false,
        ongoing: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('siren'),
        vibrationPattern: aggVibration,
        enableLights: true,
        color: const Color(0xFFFF1744),
        ledColor: const Color(0xFFFF1744),
        ledOnMs: 300,
        ledOffMs: 300,
        largeIcon: _appIcon,
        additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT loops the siren
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction('snooze_5', 'Snooze 5 mins', showsUserInterface: true),
          AndroidNotificationAction('stop_alarm', 'Stop Siren', showsUserInterface: true),
        ],
        ticker: 'SHIFT COMPLETE — YOU\'RE WORKING FOR FREE. GO HOME.',
        styleInformation: const BigTextStyleInformation(
          'Your 8.5 hours are DONE. Every second after this is unpaid labor — '
          'no compensation, no overtime, nothing. Close the laptop. '
          'Grab your bag. Walk out that door right now. '
          'You earned your freedom. Take it.',
          htmlFormatBigText: false,
          contentTitle: '🚨  SHIFT DONE. DROP EVERYTHING.',
          summaryText: "Don't Work For Free",
        ),
      ),
    );

    if (at.isBefore(DateTime.now().add(const Duration(seconds: 1)))) {
      await _plugin.show(
        _alarmId,
        '🚨  SHIFT DONE. DROP EVERYTHING.',
        'Your 8.5 hours are up. You\'re working for FREE right now.',
        details,
      );
    } else {
      await _plugin.zonedSchedule(
        _alarmId,
        '🚨  SHIFT DONE. DROP EVERYTHING.',
        'Your 8.5 hours are up. You\'re working for FREE right now.',
        tz.TZDateTime.from(at, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // ── User-created custom notifications ────────────────────────────────────────
  Future<void> _scheduleCustom({
    required CustomNotificationModel notification,
    required DateTime punchInTime,
    required DateTime safeExitTime,
    required Duration shiftDuration,
    required int baseId,
  }) async {
    final now = DateTime.now();
    int localId = baseId;

    if (notification.type == NotificationType.interval) {
      if (notification.intervalDuration == null) return;
      var trigger = punchInTime.add(notification.intervalDuration!);
      while (
          trigger.isBefore(safeExitTime) && localId < baseId + _idsPerCustom) {
        if (trigger.isAfter(now)) {
          await _fire(
            id: localId,
            title: notification.title,
            body: notification.message,
            at: trigger,
            channelId: _reminderChannel,
            importance: Importance.high,
            priority: Priority.high,
            accentColor: const Color(0xFF7C83FD),
            mode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
        trigger = trigger.add(notification.intervalDuration!);
        localId++;
      }
    } else {
      if (notification.milestoneValue == null) return;
      DateTime triggerTime;

      if (notification.milestoneType == MilestoneType.hoursRemaining) {
        triggerTime = safeExitTime.subtract(
          Duration(minutes: (notification.milestoneValue! * 60).round()),
        );
      } else {
        final pct = notification.milestoneValue! / 100.0;
        triggerTime = punchInTime
            .add(Duration(seconds: (shiftDuration.inSeconds * pct).round()));
      }

      if (triggerTime.isAfter(now) && triggerTime.isBefore(safeExitTime)) {
        await _fire(
          id: localId,
          title: notification.title,
          body: notification.message,
          at: triggerTime,
          channelId: _reminderChannel,
          importance: Importance.high,
          priority: Priority.high,
          accentColor: const Color(0xFF7C83FD),
          mode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
  Future<void> dismissAlarm() => _plugin.cancel(_alarmId);
}
