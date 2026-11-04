import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/database.dart';
import '../state/settings.dart';
import 'notifications.dart';

const dailyTask = 'azkar.daily_reschedule';

/// Runs once a day in the background (WorkManager) to roll prayer alerts forward
/// and rotate the daily random-zekr reminder, even if the app is not opened.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsController(prefs);
      await NotificationService.instance.init();
      await NotificationService.instance.schedulePrayerAlerts(settings.prayer);
      final db = await AppDatabase.open(singleInstance: false);
      await NotificationService.instance
          .scheduleReminders(settings.reminders, await db.allAzkar());
      await db.close();
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> registerBackgroundWork() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    dailyTask,
    dailyTask,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
