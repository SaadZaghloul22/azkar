import 'package:azkarak/state/ramadan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ramadan 1448 per Umm al-Qura', () {
    final i = RamadanCalendar.info(DateTime(2026, 11, 25, 10));
    expect(i.hYear, 1448);
    expect(i.start, DateTime(2027, 2, 8));
    expect(i.days, 29);
    expect(i.eid, DateTime(2027, 3, 9));
    expect(i.inRamadan, isFalse);
    expect(i.daysUntil, 75);
  });

  test('inside Ramadan: day number, last ten, odd nights', () {
    expect(RamadanCalendar.info(DateTime(2027, 2, 8, 3)).day, 1);
    final d20 = RamadanCalendar.info(DateTime(2027, 2, 27, 20));
    expect(d20.day, 20);
    expect(d20.lastTen, isFalse);
    expect(d20.oddNightTonight, isTrue); // night of the 21st
    final d21 = RamadanCalendar.info(DateTime(2027, 2, 28, 20));
    expect(d21.lastTen, isTrue);
    expect(d21.oddNightTonight, isFalse);
    final last = RamadanCalendar.info(DateTime(2027, 3, 8, 12));
    expect(last.day, 29);
  });

  test('after Eid it points to the next Ramadan', () {
    final i = RamadanCalendar.info(DateTime(2027, 3, 9, 8));
    expect(i.hYear, 1449);
    expect(i.start, DateTime(2028, 1, 28));
    expect(i.inRamadan, isFalse);
  });

  test('country offset shifts the start by a day', () {
    expect(RamadanCalendar.info(DateTime(2026, 11, 25), offset: 1).start, DateTime(2027, 2, 9));
    expect(RamadanCalendar.info(DateTime(2027, 2, 8, 12), offset: 1).inRamadan, isFalse);
    expect(RamadanCalendar.info(DateTime(2027, 2, 7, 12), offset: -1).day, 1);
  });
}
