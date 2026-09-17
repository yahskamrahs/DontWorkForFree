import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

import 'providers/profile_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shift_provider.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'utils/biometric_guard.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/salary_calculator_screen.dart';
import 'screens/settings_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Timezone
  tz.initializeTimeZones();
  try {
    final localTz = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTz.identifier));
  } catch (_) {
    tz.setLocalLocation(tz.UTC);
  }

  final profileProvider = ProfileProvider();
  final settingsProvider = SettingsProvider();
  final shiftProvider = ShiftProvider();

  // Each of these touches disk/platform channels on startup (DB open,
  // notification plugin init, prefs read). A single failure here (e.g. a
  // corrupted DB file left behind by a killed process) must not hang main()
  // forever with no runApp() ever called — that shows up as an infinite
  // splash screen with no crash dialog. So init is best-effort per step.
  try {
    await NotificationService.instance.initialize();
  } catch (_) {}
  try {
    await DatabaseService.instance.db; // warm-up the DB connection
  } catch (_) {}
  try {
    await profileProvider.initialize();
  } catch (_) {}
  try {
    await settingsProvider.initialize();
  } catch (_) {}

  shiftProvider.updateShiftDuration(
    profileProvider.activeProfile.duration,
    profileProvider.activeProfile.id,
    profileProvider.activeProfile.name,
  );
  shiftProvider.updateNotificationSettings(
    breakReminderEnabled: settingsProvider.breakReminderEnabled,
    breakReminderHour: settingsProvider.breakReminderHour,
    breakReminderMinute: settingsProvider.breakReminderMinute,
    twoHourReminderEnabled: settingsProvider.twoHourReminderEnabled,
    overtimeReminderEnabled: settingsProvider.overtimeReminderEnabled,
    overtimeIntervalMinutes: settingsProvider.overtimeIntervalMinutes,
    entertainmentModeEnabled: settingsProvider.entertainmentModeEnabled,
    entertainmentIntervalMinutes: settingsProvider.entertainmentIntervalMinutes,
  );
  try {
    await shiftProvider.initialize();
  } catch (_) {}

  NotificationService.instance.onCustomAction = (action) {
    if (action == 'ACTION_PAUSE') {
      if (shiftProvider.isOnBreak) {
        shiftProvider.endBreak();
      } else {
        shiftProvider.startBreak();
      }
    } else if (action == 'ACTION_CLOCK_OUT') {
      shiftProvider.punchOut();
    }
  };

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F1625),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: profileProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        // ShiftProvider depends on both ProfileProvider (shift duration) and
        // SettingsProvider (notification preferences). ProxyProvider2 re-runs
        // update() whenever either upstream provider notifies.
        ChangeNotifierProxyProvider2<ProfileProvider, SettingsProvider, ShiftProvider>(
          create: (_) => shiftProvider,
          update: (_, profileProv, settingsProv, shiftProv) {
            shiftProv!.updateShiftDuration(
              profileProv.activeProfile.duration,
              profileProv.activeProfile.id,
              profileProv.activeProfile.name,
            );
            shiftProv.updateNotificationSettings(
              breakReminderEnabled: settingsProv.breakReminderEnabled,
              breakReminderHour: settingsProv.breakReminderHour,
              breakReminderMinute: settingsProv.breakReminderMinute,
              twoHourReminderEnabled: settingsProv.twoHourReminderEnabled,
              overtimeReminderEnabled: settingsProv.overtimeReminderEnabled,
              overtimeIntervalMinutes: settingsProv.overtimeIntervalMinutes,
              entertainmentModeEnabled: settingsProv.entertainmentModeEnabled,
              entertainmentIntervalMinutes: settingsProv.entertainmentIntervalMinutes,
            );
            return shiftProv;
          },
        ),
      ],
      child: const DontWorkForFreeApp(),
    ),
  );
}

class DontWorkForFreeApp extends StatelessWidget {
  const DontWorkForFreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: "Don't Work For Free",
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const _AppShell(),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF080C18),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFB800),
        onPrimary: Color(0xFF080C18),
        secondary: Color(0xFF00E676),
        onSecondary: Color(0xFF080C18),
        surface: Color(0xFF0F1625),
        onSurface: Colors.white,
        error: Color(0xFFFF1744),
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0F1625),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0F1625),
        indicatorColor: const Color(0xFFFFB800).withValues(alpha: 0.15),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: Color(0xFFFFB800),
                fontSize: 11,
                fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: Color(0xFF5A6478), fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFFFB800), size: 22);
          }
          return const IconThemeData(color: Color(0xFF5A6478), size: 22);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF162035),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E2D47)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E2D47)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFB800), width: 1.5),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8A97B0)),
        hintStyle: const TextStyle(color: Color(0xFF3D4A60)),
      ),
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        headlineLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        headlineMedium:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium:
            TextStyle(color: Color(0xFFB0BEC5), fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Color(0xFFB0BEC5)),
        bodyMedium: TextStyle(color: Color(0xFF8A97B0)),
        labelLarge:
            TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── 4-Tab navigation shell ───────────────────────────────────────────────────

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _currentIndex = 0;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.biometricLockEnabled) {
      if (mounted) setState(() => _authenticated = true);
      await NotificationService.instance.requestPermission();
      return;
    }
    final ok = await BiometricGuard.authenticate(context);
    if (ok && mounted) {
      setState(() => _authenticated = true);
      await NotificationService.instance.requestPermission();
    }
  }

  static const _screens = [
    HomeScreen(),
    HistoryScreen(),
    SalaryCalculatorScreen(),
    NotificationsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFF080C18),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: Color(0xFF1E2D47)),
              const SizedBox(height: 16),
              const Text('App Locked',
                  style: TextStyle(color: Color(0xFF5A6478))),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _checkAuth,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF162035),
                  foregroundColor: const Color(0xFF00E676),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = i);
        },
        height: 64,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Salary',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
