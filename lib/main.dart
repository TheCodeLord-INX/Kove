import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/settings_provider.dart';
import 'core/services/notification_service.dart';
import 'core/services/background_worker.dart';
import 'features/tenants/presentation/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ── Initialize SharedPreferences ──────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── Initialize local notifications ────────────────
  await NotificationService.initialize();

  // ── Initialize Workmanager ────────────────────────
  await Workmanager().initialize(callbackDispatcher);

  // Register a periodic task that runs roughly every 4 hours.
  // The OS will throttle/batch execution to save battery.
  // When it fires on the 25th, the worker checks for missing readings.
  await Workmanager().registerPeriodicTask(
    kAuditCheckTask,
    kAuditCheckTask,
    frequency: const Duration(hours: 4),
    constraints: Constraints(
      networkType: NetworkType.notRequired,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TenantManagerApp(),
    ),
  );
}

class TenantManagerApp extends ConsumerWidget {
  const TenantManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(settingsProvider.select((s) => s.isDarkMode));

    return MaterialApp(
      title: 'Tenant Manager',
      debugShowCheckedModeBanner: false,
      theme: KoveTheme.light,
      darkTheme: KoveTheme.dark,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const DashboardScreen(),
    );
  }
}
