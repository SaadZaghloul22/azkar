import 'dart:convert';
import 'dart:io';

import 'package:azkarak/data/quran.dart';
import 'package:azkarak/state/quran_wird.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final q = Quran.fromJson(
      jsonDecode(File('assets/data/quran.json').readAsStringSync()) as Map<String, dynamic>);

  test('text and licence notice are intact', () {
    expect(q.surahs.length, 114);
    expect(q.surahs.fold<int>(0, (a, s) => a + s.ayahs), Quran.ayahCount);
    expect(q.notice, contains('Tanzil Quran Text (Uthmani, Version 1.1)'));
    expect(q.notice, contains('CHANGING IT IS NOT ALLOWED'));
  });

  test('pages follow the Madinah mushaf', () {
    // Page 1 is al-Fatiha, page 2 opens al-Baqarah, page 3 starts at al-Baqarah 6.
    expect([for (final a in q.pageAyat(1)) a.id], [1, 2, 3, 4, 5, 6, 7]);
    final p2 = q.pageAyat(2);
    expect(p2.first.surah, 2);
    expect(p2.first.number, 1);
    expect(p2.first.basmala, isNotNull);
    expect(q.pageAyat(3).first.number, 6);
    expect(q.surahOfPage(604).number, 112);
    expect(q.pageLastAyah(604), Quran.ayahCount);
    // Every ayah is on exactly one page, in order.
    var expected = 1;
    for (var p = 1; p <= Quran.pageCount; p++) {
      for (final a in q.pageAyat(p)) {
        expect(a.id, expected);
        expect(q.pageOf(a.id), p);
        expected++;
      }
    }
    expect(expected - 1, Quran.ayahCount);
  });

  test('juz start pages constant matches the data', () {
    expect([for (var j = 1; j <= 30; j++) q.juzStartPage(j)], kJuzStartPages);
    expect(q.juzOfPage(1), 1);
    expect(q.juzOfPage(582), 30);
  });

  test('basmala is split off verse 1 of every surah except al-Fatiha and at-Tawba', () {
    for (final s in q.surahs) {
      final first = q.pageAyat(q.surahStartPage(s.number)).firstWhere((a) => a.surah == s.number);
      expect(first.number, 1);
      if (s.number == 1 || s.number == 9) {
        expect(first.basmala, isNull, reason: 'surah ${s.number}');
      } else {
        expect(first.basmala, isNotNull, reason: 'surah ${s.number}');
        expect(first.text.isNotEmpty, isTrue);
        // Nothing is lost: basmala + rest is the verse exactly as written.
        expect('${first.basmala} ${first.text}', q.ayahText(first.id));
      }
    }
  });

  test('search finds verses typed in ordinary spelling', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await q.search('الحمد لله رب العالمين'), contains(2));
    final kursi = await q.search('الله لا اله الا هو الحي القيوم');
    expect(kursi.first, q.surahs[1].firstAyahId + 254); // al-Baqarah 255
    expect(await q.search('قل هو الله احد'), [6222]);
    expect((await q.search('الصلاة')).length, greaterThan(50)); // Uthmani الصلوٰة
    expect(await q.search('ا'), isEmpty);
    expect(q.reference(6222), contains('١'));
    expect(q.shareText(8).startsWith('الٓمٓ'), isTrue); // al-Baqarah 1 without basmala
  });
}
