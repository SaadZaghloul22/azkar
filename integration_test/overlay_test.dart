import 'package:azkarak/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:azkarak/services/native_bridge.dart';
import 'package:azkarak/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Shows the floating zekr window repeatedly so the device-level screenshots
/// taken by tool/emulator_run.sh capture it over the app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('floating zekr window can be shown', (tester) async {
    (await SharedPreferences.getInstance()).setBool('onboarded', true);
    app.main();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    var granted = false;
    for (var i = 0; i < 60 && !granted; i++) {
      granted = await NativeBridge.canDrawOverlays();
      if (!granted) await tester.pump(const Duration(seconds: 1));
    }
    expect(granted, isTrue, reason: 'overlay permission not granted on emulator');
    const cfg = OverlayConfig(categories: ['tasbih', 'sunnah_duas'], displaySeconds: 30);
    for (var round = 0; round < 6; round++) {
      await NativeBridge.previewOverlay(cfg, const []);
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  });
}
