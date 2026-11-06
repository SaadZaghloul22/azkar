import 'package:azkarak/main.dart' as app;
import 'package:azkarak/services/native_bridge.dart';
import 'package:azkarak/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen-recorded on CI for the Play "foreground service" declaration video:
/// the user turns on floating azkar, then a zekr appears over the screen.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('floating azkar demo', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('onboarded', true);
    app.main();
    await wait(tester, 5000);
    for (var i = 0; i < 60 && !await NativeBridge.canDrawOverlays(); i++) {
      await wait(tester, 1000);
    }
    await tester.tap(find.text('المزيد').last);
    await wait(tester, 2000);
    await tester.tap(find.text('الأذكار التلقائية').first);
    await wait(tester, 3000);
    await tester.tap(find.byType(Switch).first);
    await wait(tester, 4000);
    await tester.scrollUntilVisible(find.text('معاينة الآن'), 300,
        scrollable: find.byType(Scrollable).last);
    await wait(tester, 1500);
    await tester.tap(find.text('معاينة الآن'));
    await wait(tester, 12000);
    // A second zekr while the recording also shows the notification shade.
    await NativeBridge.previewOverlay(
        const OverlayConfig(categories: ['tasbih', 'sunnah_duas'], displaySeconds: 15), const []);
    await wait(tester, 20000);
  });
}
