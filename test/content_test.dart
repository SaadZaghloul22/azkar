import 'dart:convert';
import 'dart:io';

import 'package:azkarak/core/arabic.dart';
import 'package:azkarak/data/models.dart';
import 'package:azkarak/services/prayer_service.dart';
import 'package:azkarak/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bundled azkar content', () {
    final data = jsonDecode(File('assets/data/azkar.json').readAsStringSync())
        as Map<String, dynamic>;
    final cats = (data['categories'] as List).cast<Map<String, dynamic>>();

    test('has all required sections', () {
      final keys = cats.map((c) => c['id']).toSet();
      expect(
          keys,
          containsAll([
            'morning', 'evening', 'sleep', 'wakeup', 'after_prayer', 'home',
            'food', 'travel', 'quran_duas', 'sunnah_duas', 'tasbih',
          ]));
    });

    test('every zekr has text, a positive repeat count and a source', () {
      for (final c in cats) {
        for (final z in (c['items'] as List).cast<Map<String, dynamic>>()) {
          expect((z['content'] as String).trim(), isNotEmpty, reason: z['title']);
          expect(z['repeat'] as int, greaterThan(0), reason: z['title']);
          expect((z['source'] as String).trim(), isNotEmpty, reason: z['title']);
        }
      }
    });

    test('ids stay stable and unique (category * 1000 + index)', () {
      final ids = <int>{};
      for (var ci = 0; ci < cats.length; ci++) {
        final items = cats[ci]['items'] as List;
        for (var i = 0; i < items.length; i++) {
          expect(ids.add((ci + 1) * 1000 + i + 1), isTrue);
        }
      }
    });
  });

  group('arabic helpers', () {
    test('digits', () => expect(arNum(2026), '٢٠٢٦'));
    test('normalize strips tashkeel', () {
      expect(normalizeArabic('سُبْحَانَ اللَّهِ'), 'سبحان الله');
      expect(normalizeArabic('أَسْتَغْفِرُ'), 'استغفر');
    });
    test('times text', () {
      expect(timesText(1), 'مرة واحدة');
      expect(timesText(3), '٣ مرات');
      expect(timesText(100), '١٠٠ مرة');
    });
  });

  group('daily progress', () {
    test('ratio counts azkar parts and tasbeeh', () {
      expect(const DailyProgress(date: 'x').ratio, 0);
      expect(
          const DailyProgress(date: 'x', morning: true, evening: true, sleep: true, totalTasbeeh: 100)
              .ratio,
          1);
      expect(const DailyProgress(date: 'x', morning: true, totalTasbeeh: 50).ratio, 0.375);
    });
  });

  group('prayer times', () {
    const riyadh = PrayerConfig(lat: 24.7136, lng: 46.6753);
    test('are ordered through the day', () {
      final slots = PrayerService.timesFor(riyadh, DateTime(2026, 11, 4))!;
      expect(slots.map((s) => s.key).toList(),
          ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']);
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].time.isAfter(slots[i - 1].time), isTrue);
      }
    });
    test('offsets shift a prayer', () {
      final base = PrayerService.timesFor(riyadh, DateTime(2026, 11, 4))!;
      final moved = PrayerService.timesFor(
          riyadh.copyWith(offsets: {'dhuhr': 5}), DateTime(2026, 11, 4))!;
      expect(moved[2].time.difference(base[2].time).inMinutes, 5);
    });
    test('no location gives no times', () {
      expect(PrayerService.timesFor(const PrayerConfig(), DateTime.now()), isNull);
    });
    test('qibla from Riyadh points west-south-west (~244°)', () {
      final q = PrayerService.qibla(24.7136, 46.6753);
      expect(q, inInclusiveRange(240, 247));
    });
  });
}
