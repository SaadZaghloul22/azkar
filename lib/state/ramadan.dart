import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where we are relative to Ramadan. Dates follow the Umm al-Qura calendar,
/// shifted by the user's [offset] (-1/0/+1 day) for countries that start by sighting.
@immutable
class RamadanInfo {
  const RamadanInfo({required this.hYear, required this.start, required this.days, required this.now});

  final int hYear; // Hijri year of this (or the next) Ramadan
  final DateTime start; // 1 Ramadan (date only)
  final int days; // 29 or 30
  final DateTime now;

  DateTime get eid => start.add(Duration(days: days));
  DateTime get _today => DateTime(now.year, now.month, now.day);

  /// 1-based day of Ramadan, or null outside it.
  int? get day {
    final d = _today.difference(start).inDays;
    return d >= 0 && d < days ? d + 1 : null;
  }

  bool get inRamadan => day != null;
  int get daysUntil => start.difference(_today).inDays; // > 0 before Ramadan
  bool get lastTen => (day ?? 0) > 20;

  /// Odd nights of the last ten: the night *before* day 21, 23, 25, 27, 29.
  bool get oddNightTonight {
    final d = day;
    return d != null && d >= 20 && d < days && (d + 1).isOdd;
  }

  /// Date of Ramadan day [n] (1-based).
  DateTime dateOf(int n) => start.add(Duration(days: n - 1));
}

class RamadanCalendar {
  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);

  static (DateTime, int) ramadanOf(int hYear, int offset) {
    final h = HijriCalendar();
    final start = _date(h.hijriToGregorian(hYear, 9, 1)).add(Duration(days: offset));
    return (start, h.getDaysInMonth(hYear, 9));
  }

  /// The current Ramadan, or the next one once this year's has ended.
  static RamadanInfo info(DateTime now, {int offset = 0}) {
    final today = _date(now);
    var y = HijriCalendar.fromDate(today.subtract(Duration(days: offset))).hYear;
    var (start, days) = ramadanOf(y, offset);
    if (!today.isBefore(start.add(Duration(days: days)))) {
      y++;
      (start, days) = ramadanOf(y, offset);
    }
    return RamadanInfo(hYear: y, start: start, days: days, now: now);
  }
}

/// Ramadan settings and the daily tracker (fasting, tarawih, quran, sadaqa).
class RamadanController extends ChangeNotifier {
  RamadanController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _k = 'ramadan_v1';
  static const items = {
    'fast': 'الصيام',
    'tarawih': 'التراويح / القيام',
    'quran': 'ورد القرآن',
    'sadaqa': 'صدقة',
  };

  int offset = 0; // start-of-month adjustment for the user's country
  bool suhoor = true;
  int suhoorMinutes = 45; // before Fajr
  bool iftar = true;
  bool crescent = true; // first-night reminder with the crescent du'a
  int zakatPeople = 1;
  double zakatKg = 3; // per person (one sa')
  double zakatPricePerKg = 0;
  final Map<String, Set<String>> _done = {}; // "1448-5" -> {"fast", ...}

  RamadanInfo info([DateTime? now]) => RamadanCalendar.info(now ?? DateTime.now(), offset: offset);

  void _load() {
    try {
      final raw = _prefs.getString(_k);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      offset = ((j['offset'] as int?) ?? 0).clamp(-1, 1);
      suhoor = (j['suhoor'] as bool?) ?? true;
      suhoorMinutes = ((j['suhoorMinutes'] as int?) ?? 45).clamp(10, 120);
      iftar = (j['iftar'] as bool?) ?? true;
      crescent = (j['crescent'] as bool?) ?? true;
      zakatPeople = ((j['zakatPeople'] as int?) ?? 1).clamp(1, 99);
      zakatKg = ((j['zakatKg'] as num?) ?? 3).toDouble();
      zakatPricePerKg = ((j['zakatPrice'] as num?) ?? 0).toDouble();
      final done = j['done'];
      if (done is Map) {
        done.forEach((k, v) {
          if (k is String && v is List) _done[k] = v.whereType<String>().toSet();
        });
      }
    } catch (e) {
      debugPrint('ramadan: bad saved state ($e), starting fresh');
    }
  }

  Future<void> _save() async {
    // Keep two Ramadans of history at most.
    final years = _done.keys.map((k) => k.split('-').first).toSet().toList()..sort();
    if (years.length > 2) {
      for (final y in years.take(years.length - 2)) {
        _done.removeWhere((k, _) => k.startsWith('$y-'));
      }
    }
    await _prefs.setString(
      _k,
      jsonEncode({
        'offset': offset,
        'suhoor': suhoor,
        'suhoorMinutes': suhoorMinutes,
        'iftar': iftar,
        'crescent': crescent,
        'zakatPeople': zakatPeople,
        'zakatKg': zakatKg,
        'zakatPrice': zakatPricePerKg,
        'done': _done.map((k, v) => MapEntry(k, v.toList()..sort())),
      }),
    );
  }

  Set<String> doneOn(int hYear, int day) => _done['$hYear-$day'] ?? const {};

  Future<void> toggle(int hYear, int day, String item) async {
    final s = _done.putIfAbsent('$hYear-$day', () => <String>{});
    if (!s.remove(item)) s.add(item);
    await _save();
    notifyListeners();
  }

  /// Days of this Ramadan on which the fast was marked.
  int fastedDays(int hYear) => _done.entries.where((e) => e.key.startsWith('$hYear-') && e.value.contains('fast')).length;

  Future<void> update({
    int? offset,
    bool? suhoor,
    int? suhoorMinutes,
    bool? iftar,
    bool? crescent,
    int? zakatPeople,
    double? zakatKg,
    double? zakatPricePerKg,
  }) async {
    if (offset != null) this.offset = offset.clamp(-1, 1);
    if (suhoor != null) this.suhoor = suhoor;
    if (suhoorMinutes != null) this.suhoorMinutes = suhoorMinutes;
    if (iftar != null) this.iftar = iftar;
    if (crescent != null) this.crescent = crescent;
    if (zakatPeople != null) this.zakatPeople = zakatPeople.clamp(1, 99);
    if (zakatKg != null) this.zakatKg = zakatKg;
    if (zakatPricePerKg != null) this.zakatPricePerKg = zakatPricePerKg;
    await _save();
    notifyListeners();
  }
}
