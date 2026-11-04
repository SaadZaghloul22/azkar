import 'package:adhan/adhan.dart';

import '../state/settings.dart';

const prayerNames = {
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

const calcMethods = {
  'umm_al_qura': 'أم القرى (مكة المكرمة)',
  'egyptian': 'الهيئة المصرية العامة للمساحة',
  'muslim_world_league': 'رابطة العالم الإسلامي',
  'karachi': 'جامعة العلوم الإسلامية بكراتشي',
  'dubai': 'دبي',
  'kuwait': 'الكويت',
  'qatar': 'قطر',
  'moon_sighting_committee': 'لجنة رؤية الهلال',
  'north_america': 'أمريكا الشمالية (ISNA)',
  'singapore': 'سنغافورة',
  'turkey': 'تركيا',
  'tehran': 'طهران',
};

class PrayerSlot {
  final String key;
  final DateTime time;
  const PrayerSlot(this.key, this.time);
  String get name => prayerNames[key]!;
}

/// Prayer times via the `adhan` library (astronomical calculation, no fixed tables).
class PrayerService {
  static CalculationParameters _params(PrayerConfig c) {
    final method = CalculationMethod.values.firstWhere(
      (m) => m.name == c.method,
      orElse: () => CalculationMethod.umm_al_qura,
    );
    final p = method.getParameters();
    p.madhab = c.hanafi ? Madhab.hanafi : Madhab.shafi;
    p.adjustments = PrayerAdjustments(
      fajr: c.offsets['fajr'] ?? 0,
      sunrise: c.offsets['sunrise'] ?? 0,
      dhuhr: c.offsets['dhuhr'] ?? 0,
      asr: c.offsets['asr'] ?? 0,
      maghrib: c.offsets['maghrib'] ?? 0,
      isha: c.offsets['isha'] ?? 0,
    );
    return p;
  }

  /// Returns the six times for [day] (local time) or null if no location yet.
  static List<PrayerSlot>? timesFor(PrayerConfig c, DateTime day) {
    if (!c.hasLocation) return null;
    final pt = PrayerTimes(
      Coordinates(c.lat!, c.lng!),
      DateComponents(day.year, day.month, day.day),
      _params(c),
    );
    return [
      PrayerSlot('fajr', pt.fajr.toLocal()),
      PrayerSlot('sunrise', pt.sunrise.toLocal()),
      PrayerSlot('dhuhr', pt.dhuhr.toLocal()),
      PrayerSlot('asr', pt.asr.toLocal()),
      PrayerSlot('maghrib', pt.maghrib.toLocal()),
      PrayerSlot('isha', pt.isha.toLocal()),
    ];
  }

  /// Next prayer (skipping sunrise) from [now], looking into tomorrow if needed.
  static PrayerSlot? next(PrayerConfig c, DateTime now) {
    for (var d = 0; d < 2; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final slots = timesFor(c, day);
      if (slots == null) return null;
      for (final s in slots) {
        if (s.key != 'sunrise' && s.time.isAfter(now)) return s;
      }
    }
    return null;
  }

  static double qibla(double lat, double lng) => Qibla(Coordinates(lat, lng)).direction;
}
