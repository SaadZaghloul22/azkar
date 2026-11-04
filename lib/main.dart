import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database.dart';
import 'services/background.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(prefs);
  final db = await AppDatabase.open();
  final state = AppState(db, settings);
  await state.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: state),
      ],
      child: const AzkarApp(),
    ),
  );

  // Non-blocking startup work: keep schedules and services in sync.
  Future(() async {
    try {
      await NotificationService.instance.init();
      await state.syncPrayerAlerts();
      await state.syncReminders();
      await registerBackgroundWork();
      await state.syncOverlay();
    } catch (e) {
      debugPrint('startup sync failed: $e');
    }
  });
}
