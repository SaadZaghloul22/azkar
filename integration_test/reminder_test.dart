import 'package:azkarak/main.dart' as app;
import 'package:azkarak/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Schedules a reminder 20 s ahead. tool/emulator_run.sh then checks with
/// `dumpsys notification` that Android actually delivered it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scheduled reminder is delivered', (tester) async {
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
    app.main();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await NotificationService.instance.scheduleTest(const Duration(seconds: 20));
    final pending = await NotificationService.instance.plugin.pendingNotificationRequests();
    expect(pending.any((p) => p.id == 98), isTrue);
    // Keep the app alive (flutter drive force-stops it on exit, which clears alarms)
    // while tool/emulator_run.sh watches for the delivered notification.
    for (var i = 0; i < 900; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
