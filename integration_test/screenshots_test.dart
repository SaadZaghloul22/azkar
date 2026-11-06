import 'dart:convert';

import 'package:azkarak/app.dart' show navigatorKey;
import 'package:azkarak/main.dart' as app;
import 'package:azkarak/state/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Walks through the main screens on a real emulator, checks they render and
/// captures screenshots (used for review and for the store listing).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 100; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text).hitTestable().evaluate().isNotEmpty
        ? find.text(text).hitTestable().first
        : find.text(text).first;
    await t.ensureVisible(f);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(f, warnIfMissed: false);
  }

  testWidgets('main flows render and work', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString(
        'prayer', jsonEncode(const PrayerConfig(lat: 24.7136, lng: 46.6753).toJson()));
    await prefs.setInt('themeMode', ThemeMode.light.index);

    app.main();
    await settle(tester, 900);
    await binding.convertFlutterSurfaceToImage();
    await settle(tester, 200);
    expect(find.text('حصّن يومك بذكر الله'), findsOneWidget);
    await binding.takeScreenshot('00_splash');

    // First run: onboarding (skip every permission so no system dialog blocks the test).
    await settle(tester, 2500);
    expect(find.text('أهلًا بك في أذكار المسلم'), findsOneWidget);
    await binding.takeScreenshot('00a_onboarding_welcome');
    await tester.tap(find.text('ابدأ').hitTestable());
    await settle(tester);
    expect(find.text('تفعيل التذكيرات'), findsOneWidget);
    await binding.takeScreenshot('00b_onboarding_reminders');
    await tester.tap(find.text('لاحقًا').hitTestable());
    await settle(tester);
    expect(find.text('تحديد موقعي'), findsOneWidget);
    await binding.takeScreenshot('00c_onboarding_location');
    await tester.tap(find.text('لاحقًا').hitTestable());
    await settle(tester);
    expect(find.text('تفعيل الأذكار التلقائية'), findsOneWidget);
    await binding.takeScreenshot('00d_onboarding_overlay');
    await tester.tap(find.text('لاحقًا').hitTestable());
    await settle(tester);
    expect(find.text('كل شيء جاهز'), findsOneWidget);
    await binding.takeScreenshot('00e_onboarding_done');
    await tester.tap(find.text('ابدأ الآن').hitTestable());
    await settle(tester, 2000);

    expect(find.text('ذكر اليوم'), findsWidgets);
    await binding.takeScreenshot('01_home');

    // Morning azkar reader: count the first zekr (Ayat al-Kursi, 1 time).
    await tapText(tester, 'أذكار الصباح');
    await settle(tester, 2500);
    expect(find.text('آية الكرسي'), findsWidgets);
    await binding.takeScreenshot('02_reader_morning');
    await tester.tap(find.text('اضغط').first);
    await settle(tester, 1500);
    await binding.takeScreenshot('03_reader_next');
    navigatorKey.currentState!.pop();
    await settle(tester);

    // Categories tab.
    await tester.tap(find.text('الأذكار').last);
    await settle(tester);
    expect(find.text('الأقسام'), findsOneWidget);
    await binding.takeScreenshot('04_categories');

    // Tasbih: tap the counter five times.
    await tester.tap(find.text('المسبحة').last);
    await settle(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tapAt(tester.getCenter(find.text('من ٣٣')));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await settle(tester);
    expect(find.text('٥'), findsWidgets);
    await binding.takeScreenshot('05_tasbih');

    // Prayer times (location preset to Riyadh).
    await tester.tap(find.text('المواقيت').last);
    await settle(tester);
    expect(find.text('الصلاة القادمة'), findsOneWidget);
    await binding.takeScreenshot('06_prayer');

    // More + floating azkar settings.
    await tester.tap(find.text('المزيد').last);
    await settle(tester);
    await binding.takeScreenshot('07_more');
    await tapText(tester, 'الأذكار التلقائية');
    await settle(tester);
    await binding.takeScreenshot('08_auto_azkar');
    navigatorKey.currentState!.pop();
    await settle(tester);

    // Dark mode reader.
    await tapText(tester, 'الإعدادات');
    await settle(tester);
    await binding.takeScreenshot('09_settings');
    await tester.tap(find.text('داكن'));
    await settle(tester);
    navigatorKey.currentState!.pop();
    await settle(tester);
    await tester.tap(find.text('الرئيسية').last);
    await settle(tester);
    await binding.takeScreenshot('10_home_dark');
    await tapText(tester, 'أذكار المساء');
    await settle(tester, 2500);
    await binding.takeScreenshot('11_reader_dark');
  });
}
