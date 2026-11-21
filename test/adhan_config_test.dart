import 'dart:io';

import 'package:azkarak/state/settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults: adhan on for the five prayers, never for sunrise', () {
    const c = PrayerConfig();
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      expect(c.adhanFor(p), isTrue, reason: p);
    }
    expect(c.adhanFor('sunrise'), isFalse);
    expect(c.voiceFor('fajr'), c.fajrMuezzin);
    expect(c.voiceFor('dhuhr'), c.muezzin);
  });

  test('json round trip keeps voices and per-prayer mode', () {
    final c = const PrayerConfig(lat: 24.7, lng: 46.7)
        .copyWith(muezzin: 'adhan_3', fajrMuezzin: 'adhan_1', adhan: {'asr': false});
    final r = PrayerConfig.fromJson(c.toJson());
    expect(r.muezzin, 'adhan_3');
    expect(r.fajrMuezzin, 'adhan_1');
    expect(r.adhanFor('asr'), isFalse);
    expect(r.adhanFor('isha'), isTrue);
  });

  test('old saved settings (no adhan fields) load with valid defaults', () {
    final r = PrayerConfig.fromJson({'method': 'umm_al_qura', 'muezzin': 'deleted_voice'});
    expect(adhanVoices.containsKey(r.muezzin), isTrue);
    expect(adhanVoices.containsKey(r.fajrMuezzin), isTrue);
  });

  test('every voice has a bundled sound file', () {
    for (final v in adhanVoices.keys) {
      expect(File('android/app/src/main/res/raw/$v.ogg').existsSync(), isTrue, reason: v);
    }
  });
}
