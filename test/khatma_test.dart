import 'package:azkarak/state/quran_wird.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 1);

  void coversAllPages(KhatmaPlan p) {
    expect(p.dayStart(0), p.startPage);
    for (var d = 0; d < p.days; d++) {
      expect(p.dayPages(d), greaterThan(0), reason: 'day $d of ${p.days}');
      if (d > 0) expect(p.dayStart(d), p.dayEnd(d - 1) + 1);
    }
    expect(p.dayEnd(p.days - 1), KhatmaPlan.lastPage);
  }

  test('30 days = one juz a day', () {
    final p = KhatmaPlan(days: 30, startDate: start);
    coversAllPages(p);
    for (var d = 0; d < 29; d++) {
      expect(p.dayEnd(d), kJuzStartPages[d + 1] - 1);
    }
  });

  test('15 and 10 days = 2 and 3 juz a day', () {
    final p15 = KhatmaPlan(days: 15, startDate: start);
    coversAllPages(p15);
    expect(p15.dayEnd(0), kJuzStartPages[2] - 1);
    final p10 = KhatmaPlan(days: 10, startDate: start);
    coversAllPages(p10);
    expect(p10.dayEnd(0), kJuzStartPages[3] - 1);
  });

  test('any length covers the mushaf with no gaps', () {
    for (final days in [1, 7, 20, 40, 60, 90, 365, 604]) {
      coversAllPages(KhatmaPlan(days: days, startDate: start));
    }
    coversAllPages(KhatmaPlan(days: 20, startDate: start, startPage: 300));
  });

  test('targets, behind and reschedule keep the end date', () {
    final p = KhatmaPlan(days: 30, startDate: start);
    expect(p.dayIndex(DateTime(2026, 11, 1, 23, 59)), 0);
    expect(p.targetFor(DateTime(2026, 11, 3)), kJuzStartPages[3] - 1);
    // On day 3 having read only 10 pages: owes the rest of days 1-2.
    expect(p.pagesBehind(DateTime(2026, 11, 3), 10), kJuzStartPages[2] - 1 - 10);
    expect(p.pagesBehind(DateTime(2026, 11, 1), 0), 0);
    final r = p.rescheduled(DateTime(2026, 11, 3), 10);
    expect(r.startPage, 11);
    expect(r.endDate, p.endDate);
    expect(r.days, 28);
    expect(r.dayEnd(r.days - 1), KhatmaPlan.lastPage);
  });

  test('json round trip and bad input', () {
    final p = KhatmaPlan(days: 40, startDate: start, startPage: 5);
    final r = KhatmaPlan.fromJson(p.toJson())!;
    expect([r.days, r.startPage, r.startDate], [40, 5, start]);
    expect(KhatmaPlan.fromJson({'days': 0, 'start': 'x'}), isNull);
    expect(KhatmaPlan.fromJson(null), isNull);
  });
}
