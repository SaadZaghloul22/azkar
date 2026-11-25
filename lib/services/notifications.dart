import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/arabic.dart';
import '../data/models.dart';
import '../state/quran_wird.dart';
import '../state/ramadan.dart';
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

  /// One channel per voice: on Android the sound belongs to the channel and cannot be
  /// changed later, so switching voice switches channel. The notification plays the
  /// whole recording; swiping it away or "إيقاف الأذان" stops it.
  static AndroidNotificationDetails adhanDetails(String voice) => AndroidNotificationDetails(
        'adhan_${voice}_v1',
        'الأذان - ${adhanVoices[voice]?.name ?? voice}',
        channelDescription: 'رفع الأذان بصوت كامل عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.max,
        color: const Color(0xFF0E6B4E),
        category: AndroidNotificationCategory.alarm,
        sound: RawResourceAndroidNotificationSound(voice),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        timeoutAfter: 4 * 60 * 1000,
        actions: const [
          AndroidNotificationAction('stop_adhan', 'إيقاف الأذان', cancelNotification: true),
        ],
      );

  /// Daily "ورد القرآن" reminders for the next week, each naming that day's pages.
  /// Re-run whenever the plan or progress changes and on every app start.
  Future<void> scheduleQuranWird(QuranWirdController w) async {
    await init();
    for (var i = 0; i < 7; i++) {
      await plugin.cancel(id: 4000 + i);
    }
    await _scheduleKahf(w);
    final plan = w.plan;
    if (plan == null || !w.remind) return;
    final exact = await canExact();
    final now = tz.TZDateTime.now(tz.local);
    final today = w.today();
    for (var i = 0; i < 7; i++) {
      final day = plan.dayIndex(now) + i;
      if (day >= plan.days) break;
      if (day < 0) continue;
      final at = tz.TZDateTime(tz.local, now.year, now.month, now.day, w.remindHour, w.remindMinute)
          .add(Duration(days: i));
      if (!at.isAfter(now)) continue;
      String body;
      if (i == 0 && today != null) {
        if (today.done) continue;
        body = 'وردك اليوم: من صفحة ${arNum(today.from)} إلى ${arNum(today.to)}';
      } else {
        body = 'وردك اليوم: من صفحة ${arNum(plan.dayStart(day))} إلى ${arNum(plan.dayEnd(day))}';
      }
      await plugin.zonedSchedule(
        id: 4000 + i,
        title: 'ورد القرآن • اليوم ${arNum(day + 1)} من ${arNum(plan.days)}',
        body: body,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'quran_wird',
            'ورد القرآن',
            channelDescription: 'تذكير يومي بورد القرآن',
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFF0E6B4E),
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'quran_wird',
      );
    }
  }

  /// Weekly Friday reminder to read Surat al-Kahf (opens it directly).
  Future<void> _scheduleKahf(QuranWirdController w) async {
    await plugin.cancel(id: 4100);
    if (!w.kahf) return;
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, w.kahfHour, w.kahfMinute);
    while (at.weekday != DateTime.friday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    await plugin.zonedSchedule(
      id: 4100,
      title: 'يوم الجمعة: سورة الكهف',
      body: '«من قرأ سورة الكهف يوم الجمعة أضاء له من النور ما بين الجمعتين». وأكثروا من الصلاة على النبي ﷺ',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'quran_kahf',
          'سورة الكهف يوم الجمعة',
          channelDescription: 'تذكير أسبوعي بقراءة سورة الكهف يوم الجمعة',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF0E6B4E),
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      androidScheduleMode: (await canExact())
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'kahf',
    );
  }

  /// Ramadan: suhoor reminder before Fajr and iftar at Maghrib for the coming days,
  /// plus the first night (crescent du'a). Re-run on start and on any change.
  Future<void> scheduleRamadan(RamadanController r, PrayerConfig prayer) async {
    await init();
    for (var i = 0; i < 16; i++) {
      await plugin.cancel(id: 4200 + i);
    }
    await plugin.cancel(id: 4220);
    if (!prayer.hasLocation) return;
    final now = DateTime.now();
    final info = r.info(now);
    final exact = await canExact();
    final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ramadan',
        'رمضان',
        channelDescription: 'تذكير السحور والإفطار في رمضان',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFF0E6B4E),
        styleInformation: BigTextStyleInformation(''),
      ),
    );
    Future<void> at(int id, DateTime when, String title, String body) async {
      if (!when.isAfter(now)) return;
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: 'ramadan',
      );
    }

    // The night before 1 Ramadan, at Maghrib.
    if (r.crescent && !info.inRamadan && info.daysUntil >= 1 && info.daysUntil <= 30) {
      final eve = info.start.subtract(const Duration(days: 1));
      final maghrib = PrayerService.timesFor(prayer, eve)?.firstWhere((s) => s.key == 'maghrib').time;
      if (maghrib != null) {
        await at(4220, maghrib, 'الليلة أول ليالي رمضان',
            'اللهم أهلّه علينا باليُمن والإيمان، والسلامة والإسلام، ربي وربك الله. مبارك عليكم الشهر');
      }
    }
    // Next 8 days of Ramadan (re-scheduled each time the app starts).
    for (var i = 0; i < 8; i++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final n = date.difference(info.start).inDays + 1;
      if (n < 1 || n > info.days) continue;
      final times = PrayerService.timesFor(prayer, date);
      if (times == null) continue;
      final fajr = times.firstWhere((s) => s.key == 'fajr').time;
      final maghrib = times.firstWhere((s) => s.key == 'maghrib').time;
      if (r.suhoor) {
        await at(4200 + i * 2, fajr.subtract(Duration(minutes: r.suhoorMinutes)),
            'السحور • ${arNum(n)} رمضان',
            'باقي ${arNum(r.suhoorMinutes)} دقيقة على أذان الفجر (${timeText(fajr)}). «تسحّروا فإن في السحور بركة»');
      }
      if (r.iftar) {
        await at(4201 + i * 2, maghrib, 'حان موعد الإفطار • ${arNum(n)} رمضان',
            'ذهب الظمأ، وابتلّت العروق، وثبت الأجر إن شاء الله');
      }
    }
  }

  /// Shows an adhan notification now, so the user can hear exactly what will play.
  Future<void> testAdhan(String voice) async {
    await init();
    await plugin.show(
      id: 97,
      title: 'تجربة الأذان',
      body: 'هكذا سيُرفع الأذان عند دخول وقت الصلاة',
      notificationDetails: NotificationDetails(android: adhanDetails(voice)),
      payload: 'prayer',
    );
  }

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
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == 'stop_adhan') return; // only silences the adhan
        tappedPayload.value = r.payload;
      },
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
        final useAdhan = c.adhanFor(s.key);
        await plugin.zonedSchedule(
          id: 1000 + d * 10 + p,
          title: s.key == 'sunrise' ? 'وقت الشروق' : 'حان الآن وقت صلاة ${s.name}',
          body: s.key == 'sunrise'
              ? 'انتهى وقت صلاة الفجر'
              : 'قال ﷺ: «أحب الأعمال إلى الله الصلاة على وقتها»',
          scheduledDate: tz.TZDateTime.from(s.time, tz.local),
          notificationDetails: NotificationDetails(
            android: useAdhan ? adhanDetails(c.voiceFor(s.key)) : _prayerChannel,
          ),
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
