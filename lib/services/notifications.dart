import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';
import '../state/settings.dart';
import 'prayer_service.dart';

/// Local notifications: daily reminders and prayer alerts. Works fully offline.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Payload of the notification that was tapped (e.g. "cat:morning").
  final ValueNotifier<String?> tappedPayload = ValueNotifier(null);

  static const _reminderChannel = AndroidNotificationDetails(
    'reminders',
    'تذكيرات الأذكار',
    channelDescription: 'تذكير بأذكار الصباح والمساء والنوم والورد اليومي',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF0E6B4E),
  );

  static const _prayerChannel = AndroidNotificationDetails(
    'prayer_times',
    'تنبيهات الصلاة',
    channelDescription: 'تنبيه عند دخول وقت الصلاة',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF0E6B4E),
    category: AndroidNotificationCategory.reminder,
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    }
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_azkar'),
      ),
      onDidReceiveNotificationResponse: (r) => tappedPayload.value = r.payload,
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tappedPayload.value = launch!.notificationResponse?.payload;
    }
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermission() async =>
      await _android?.requestNotificationsPermission() ?? true;

  Future<bool> canExact() async => await _android?.canScheduleExactNotifications() ?? false;

  Future<void> requestExact() async => _android?.requestExactAlarmsPermission();

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  static const _reminderIds = {
    'morning': 11,
    'evening': 12,
    'sleep': 13,
    'random': 14,
    'istighfar': 15,
    'wird': 16,
  };

  /// (Re)schedules every daily reminder from [reminders].
  /// [randomPool] supplies the text of the daily random zekr.
  Future<void> scheduleReminders(List<ReminderConfig> reminders, List<Zekr> randomPool) async {
    await init();
    // Exact alarms are delivered far more reliably on phones with aggressive battery
    // managers (realme, Oppo, Xiaomi…). Fall back to inexact when not permitted.
    final exact = await canExact();
    for (final r in reminders) {
      final id = _reminderIds[r.key]!;
      await plugin.cancel(id: id);
      if (!r.enabled) continue;
      String body;
      String payload;
      switch (r.key) {
        case 'morning':
          body = 'حان وقت أذكار الصباح، حصّن يومك بذكر الله';
          payload = 'cat:morning';
        case 'evening':
          body = 'حان وقت أذكار المساء';
          payload = 'cat:evening';
        case 'sleep':
          body = 'لا تنسَ أذكار النوم قبل أن تنام';
          payload = 'cat:sleep';
        case 'istighfar':
          body = 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ';
          payload = 'tasbih';
        case 'wird':
          body = 'أكمل وردك اليومي من الأذكار';
          payload = 'home';
        default:
          final pool = randomPool.where((z) => z.content.length < 220).toList();
          final z = pool.isEmpty ? null : pool[Random().nextInt(pool.length)];
          body = z?.content ?? 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ';
          payload = z == null ? 'home' : 'zekr:${z.id}';
      }
      await plugin.zonedSchedule(
        id: id,
        title: r.label,
        body: body,
        scheduledDate: _nextInstance(r.hour, r.minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _reminderChannel.channelId,
            _reminderChannel.channelName,
            channelDescription: _reminderChannel.channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFF0E6B4E),
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    }
  }

  /// Schedules prayer alerts for the next [days] days. Called on every app start and
  /// daily from the background worker, so alerts keep rolling forward.
  Future<void> schedulePrayerAlerts(PrayerConfig c, {int days = 7}) async {
    await init();
    for (var d = 0; d < 10; d++) {
      for (var p = 0; p < 6; p++) {
        await plugin.cancel(id: 1000 + d * 10 + p);
      }
    }
    if (!c.hasLocation || !c.alerts.values.any((v) => v)) return;
    final exact = await canExact();
    final now = DateTime.now();
    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final slots = PrayerService.timesFor(c, day) ?? const [];
      for (var p = 0; p < slots.length; p++) {
        final s = slots[p];
        if (!(c.alerts[s.key] ?? false) || !s.time.isAfter(now)) continue;
        await plugin.zonedSchedule(
          id: 1000 + d * 10 + p,
          title: s.key == 'sunrise' ? 'وقت الشروق' : 'حان الآن وقت صلاة ${s.name}',
          body: s.key == 'sunrise'
              ? 'انتهى وقت صلاة الفجر'
              : 'قال ﷺ: «أحب الأعمال إلى الله الصلاة على وقتها»',
          scheduledDate: tz.TZDateTime.from(s.time, tz.local),
          notificationDetails: const NotificationDetails(android: _prayerChannel),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'prayer',
        );
      }
    }
  }

  /// Schedules one test reminder [after] from now, so the user can close the app
  /// and check that scheduled notifications really arrive on their phone.
  Future<void> scheduleTest(Duration after) async {
    await init();
    final exact = await canExact();
    await plugin.zonedSchedule(
      id: 98,
      title: 'تذكير تجريبي',
      body: 'وصلك هذا التذكير، إذن التذكيرات تعمل على هاتفك بإذن الله',
      scheduledDate: tz.TZDateTime.now(tz.local).add(after),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
      androidScheduleMode:
          exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'home',
    );
  }

  Future<void> showNow(String title, String body, {String? payload}) async {
    await init();
    await plugin.show(
      id: 99,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel.channelId,
          _reminderChannel.channelName,
          styleInformation: BigTextStyleInformation(body),
          color: const Color(0xFF0E6B4E),
        ),
      ),
      payload: payload,
    );
  }
}
