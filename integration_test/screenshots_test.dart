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

    // Quran: start a 30-day khatma, read today's wird, check the index.
    await tapText(tester, 'ابدأ ختمة القرآن');
    await settle(tester, 2500);
    expect(find.text('ابدأ ختمة جديدة'), findsOneWidget);
    await binding.takeScreenshot('01a_quran_wird_setup');
    await tapText(tester, 'ابدأ الختمة');
    await settle(tester, 2000);
    expect(find.text('اليوم ١ من ٣٠'), findsOneWidget);
    expect(find.text('من صفحة ١ إلى صفحة ٢١'), findsOneWidget);
    await binding.takeScreenshot('01b_quran_wird_active');
    await tapText(tester, 'ابدأ ورد اليوم');
    await settle(tester, 2500);
    expect(find.text('سورة الفَاتِحة'), findsWidgets);
    await binding.takeScreenshot('01c_mushaf_p1');
    // Next page: in the RTL mushaf the next page lies to the left, so the finger moves
    // left-to-right.
    final pv = find.byType(PageView);
    debugPrint('MUSHAF_SWIPE: pageviews=${pv.evaluate().length}');
    double? pageOf() => tester.widget<PageView>(pv.first).controller?.page;
    Future<void> swipe(double dx) async {
      final c = tester.getCenter(pv.first);
      final g = await tester.startGesture(c);
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(c + Offset(dx * i / 12, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settle(tester, 2500);
    }

    debugPrint('MUSHAF_SWIPE: before=${pageOf()}');
    await swipe(420);
    debugPrint('MUSHAF_SWIPE: after L->R =${pageOf()}');
    await binding.takeScreenshot('01d1_after_ltr');
    if (find.text('٢').evaluate().isEmpty) {
      await swipe(-420);
      debugPrint('MUSHAF_SWIPE: after R->L =${pageOf()}');
      await binding.takeScreenshot('01d2_after_rtl');
    }
    expect(find.text('٢'), findsWidgets);
    await binding.takeScreenshot('01d_mushaf_p2');
    expect(find.text('سورة البَقَرَة'), findsWidgets);
    await swipe(420);
    await binding.takeScreenshot('01e_mushaf_p3');
    expect(find.text('٣'), findsWidgets);
    // Long-press a verse: share / copy / bookmark sheet.
    await tester.longPressAt(tester.getCenter(find.byType(PageView)));
    await settle(tester, 1500);
    expect(find.text('نسخ'), findsOneWidget);
    await binding.takeScreenshot('01g_ayah_sheet');
    await tapText(tester, 'علامة على الآية');
    await settle(tester);
    navigatorKey.currentState!.pop();
    await settle(tester);
    await tapText(tester, 'الفهرس');
    await settle(tester);
    expect(find.text('سورة البَقَرَة'), findsWidgets);
    await binding.takeScreenshot('01f_quran_index');
    await tester.tap(find.byTooltip('البحث في القرآن'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'الحي القيوم');
    await settle(tester, 3000);
    expect(find.textContaining('عدد النتائج'), findsOneWidget);
    await binding.takeScreenshot('01h_quran_search');
    navigatorKey.currentState!.pop();
    await settle(tester);
    await tapText(tester, 'العلامات');
    await settle(tester);
    expect(find.text('الآيات'), findsOneWidget);
    await binding.takeScreenshot('01i_quran_bookmarks');
    navigatorKey.currentState!.pop();
    await settle(tester);

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
    await tapText(tester, 'الأذان');
    await settle(tester);
    expect(find.text('صوت أذان الفجر'), findsOneWidget);
    await binding.takeScreenshot('06b_adhan');
    navigatorKey.currentState!.pop();
    await settle(tester);

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
