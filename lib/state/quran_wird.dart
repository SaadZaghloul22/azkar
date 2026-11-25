import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Page where each of the 30 juz starts in the Madinah mushaf (checked against the
/// Quran data by test/quran_test.dart).
const kJuzStartPages = [
  1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282, //
  302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582,
];

/// A khatma plan: read pages [startPage]..604 in [days] days starting on [startDate].
/// Pure arithmetic, no I/O, so it is unit-tested directly.
@immutable
class KhatmaPlan {
  const KhatmaPlan({
    required this.days,
    required this.startDate,
    this.startPage = 1,
  });

  static const lastPage = 604;

  final int days;
  final DateTime startDate; // date only
  final int startPage;

  int get totalPages => lastPage - startPage + 1;

  /// Last page of day [day] (0-based). Pages are spread evenly; a 30-day khatma from
  /// page 1 follows the juz exactly (one juz a day).
  int dayEnd(int day) {
    if (day >= days - 1) return lastPage;
    if (day < 0) return startPage - 1;
    // Whole juz per day from the start of the mushaf: end each day on a juz boundary.
    if (startPage == 1 && 30 % days == 0) {
      return kJuzStartPages[(day + 1) * (30 ~/ days)] - 1;
    }
    return startPage - 1 + ((totalPages * (day + 1)) / days).round();
  }

  int dayStart(int day) => dayEnd(day - 1) + 1;
  int dayPages(int day) => dayEnd(day) - dayStart(day) + 1;

  /// 0-based day of the plan for [today] (may be < 0 before start, >= days after).
  int dayIndex(DateTime today) => _date(today).difference(_date(startDate)).inDays;

  DateTime get endDate => _date(startDate).add(Duration(days: days - 1));

  /// Where the reader should be by the end of [today].
  int targetFor(DateTime today) => dayEnd(dayIndex(today).clamp(0, days - 1));

  /// Pages still owed from previous days, given reading reached [progress].
  int pagesBehind(DateTime today, int progress) {
    final d = dayIndex(today);
    if (d <= 0) return 0;
    final shouldHave = dayEnd((d - 1).clamp(0, days - 1));
    return (shouldHave - progress).clamp(0, lastPage);
  }

  /// Spreads what is left (after [progress]) over the days left, keeping the end date.
  KhatmaPlan rescheduled(DateTime today, int progress) {
    final left = (endDate.difference(_date(today)).inDays + 1).clamp(1, 10000);
    return KhatmaPlan(
      days: left,
      startDate: _date(today),
      startPage: (progress + 1).clamp(1, lastPage),
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days,
        'start': startDate.toIso8601String(),
        'startPage': startPage,
      };

  static KhatmaPlan? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final days = j['days'];
    final start = DateTime.tryParse(j['start']?.toString() ?? '');
    if (days is! int || days < 1 || start == null) return null;
    return KhatmaPlan(
      days: days,
      startDate: _date(start),
      startPage: ((j['startPage'] as int?) ?? 1).clamp(1, lastPage),
    );
  }

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// Today's portion of the wird, as shown on the home card and the wird tab.
@immutable
class WirdToday {
  const WirdToday({
    required this.from,
    required this.to,
    required this.day,
    required this.days,
    required this.behind,
    required this.done,
    required this.progress,
  });
  final int from;
  final int to;
  final int day; // 1-based
  final int days;
  final int behind;
  final bool done;
  final int progress; // last page completed in the khatma

  int get pages => (to - from + 1).clamp(0, KhatmaPlan.lastPage);
  double get khatmaRatio => progress / KhatmaPlan.lastPage;
}

/// Mushaf reading state: last page, bookmarks, and the khatma (ورد القرآن).
class QuranWirdController extends ChangeNotifier {
  QuranWirdController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _k = 'quran_wird_v1';

  KhatmaPlan? _plan;
  int _progress = 0; // last page completed in the current khatma
  int lastPage = 1; // last page open in the reader
  final Set<int> bookmarks = {}; // pages
  final Set<int> ayahMarks = {}; // ayah ids
  bool kahf = true; // Friday reminder for Surat al-Kahf
  int kahfHour = 10;
  int kahfMinute = 0;
  int khatmas = 0;
  bool remind = true;

  /// Reader font size; 0 = fit each page to the screen.
  double fontSize = 0;
  int remindHour = 20;
  int remindMinute = 0;
  final Map<String, int> _log = {}; // yyyy-mm-dd -> pages completed that day

  KhatmaPlan? get plan => _plan;
  int get progress => _progress;
  bool get active => _plan != null;

  void _load() {
    try {
      final raw = _prefs.getString(_k);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _plan = KhatmaPlan.fromJson(j['plan'] as Map<String, dynamic>?);
      _progress = ((j['progress'] as int?) ?? 0).clamp(0, KhatmaPlan.lastPage);
      lastPage = ((j['lastPage'] as int?) ?? 1).clamp(1, KhatmaPlan.lastPage);
      bookmarks.addAll(((j['bookmarks'] as List?) ?? const []).whereType<int>());
      ayahMarks.addAll(((j['ayahMarks'] as List?) ?? const [])
          .whereType<int>()
          .where((id) => id >= 1 && id <= 6236));
      kahf = (j['kahf'] as bool?) ?? true;
      kahfHour = ((j['kahfHour'] as int?) ?? 10).clamp(0, 23);
      kahfMinute = ((j['kahfMinute'] as int?) ?? 0).clamp(0, 59);
      khatmas = (j['khatmas'] as int?) ?? 0;
      remind = (j['remind'] as bool?) ?? true;
      remindHour = ((j['remindHour'] as int?) ?? 20).clamp(0, 23);
      remindMinute = ((j['remindMinute'] as int?) ?? 0).clamp(0, 59);
      fontSize = ((j['fontSize'] as num?) ?? 0).toDouble().clamp(0, 60);
      final log = j['log'];
      if (log is Map) {
        log.forEach((k, v) {
          if (k is String && v is int) _log[k] = v;
        });
      }
    } catch (e) {
      debugPrint('quran wird: bad saved state ($e), starting fresh');
    }
  }

  Future<void> _save() async {
    // Keep the log small: the last 120 days are enough for streaks and history.
    if (_log.length > 120) {
      final keys = _log.keys.toList()..sort();
      for (final k in keys.take(_log.length - 120)) {
        _log.remove(k);
      }
    }
    await _prefs.setString(
      _k,
      jsonEncode({
        'plan': _plan?.toJson(),
        'progress': _progress,
        'lastPage': lastPage,
        'bookmarks': bookmarks.toList()..sort(),
        'ayahMarks': ayahMarks.toList()..sort(),
        'kahf': kahf,
        'kahfHour': kahfHour,
        'kahfMinute': kahfMinute,
        'khatmas': khatmas,
        'remind': remind,
        'remindHour': remindHour,
        'remindMinute': remindMinute,
        'fontSize': fontSize,
        'log': _log,
      }),
    );
  }

  WirdToday? today([DateTime? now]) {
    final p = plan;
    if (p == null) return null;
    final t = now ?? DateTime.now();
    final d = p.dayIndex(t).clamp(0, p.days - 1);
    final target = p.dayEnd(d);
    final done = _progress >= target;
    return WirdToday(
      from: (_progress + 1).clamp(1, KhatmaPlan.lastPage),
      to: target,
      day: d + 1,
      days: p.days,
      behind: p.pagesBehind(t, _progress),
      done: done,
      progress: _progress,
    );
  }

  /// Consecutive days (ending today or yesterday) on which some wird was read.
  int get streak {
    var n = 0;
    var d = DateTime.now();
    if (!_log.containsKey(_key(d))) d = d.subtract(const Duration(days: 1));
    while (_log.containsKey(_key(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  int get pagesToday => _log[_key(DateTime.now())] ?? 0;

  Future<void> start({required int days, int startPage = 1}) async {
    _plan = KhatmaPlan(days: days, startDate: DateTime.now(), startPage: startPage);
    _progress = startPage - 1;
    await _save();
    notifyListeners();
  }

  Future<void> stop() async {
    _plan = null;
    await _save();
    notifyListeners();
  }

  /// Reading reached the end of [page] in the khatma. Returns true when this
  /// completed the whole mushaf.
  Future<bool> completeThrough(int page) async {
    if (_plan == null || page <= _progress) return false;
    final added = page - _progress;
    _progress = page.clamp(0, KhatmaPlan.lastPage);
    final k = _key(DateTime.now());
    _log[k] = (_log[k] ?? 0) + added;
    final finished = _progress >= KhatmaPlan.lastPage;
    if (finished) {
      khatmas++;
      _plan = null;
      _progress = 0;
    }
    await _save();
    notifyListeners();
    return finished;
  }

  Future<void> reschedule() async {
    final p = plan;
    if (p == null) return;
    _plan = p.rescheduled(DateTime.now(), _progress);
    await _save();
    notifyListeners();
  }

  Future<void> setLastPage(int page) async {
    if (page == lastPage) return;
    lastPage = page.clamp(1, KhatmaPlan.lastPage);
    await _save();
    notifyListeners();
  }

  Future<void> toggleBookmark(int page) async {
    if (!bookmarks.remove(page)) bookmarks.add(page);
    await _save();
    notifyListeners();
  }

  Future<void> toggleAyahMark(int ayahId) async {
    if (!ayahMarks.remove(ayahId)) ayahMarks.add(ayahId);
    await _save();
    notifyListeners();
  }

  Future<void> setKahf({required bool on, int? hour, int? minute}) async {
    kahf = on;
    if (hour != null) kahfHour = hour;
    if (minute != null) kahfMinute = minute;
    await _save();
    notifyListeners();
  }

  Future<void> setReminder({required bool on, int? hour, int? minute}) async {
    remind = on;
    if (hour != null) remindHour = hour;
    if (minute != null) remindMinute = minute;
    await _save();
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _save();
    notifyListeners();
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
