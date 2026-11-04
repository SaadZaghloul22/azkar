import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

const _western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
const _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts Western digits in [input] to Arabic-Indic digits.
String arNum(Object input) {
  var s = input.toString();
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(_western[i], _eastern[i]);
  }
  return s;
}

final _tashkeel = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

/// Normalises Arabic text for search: strips diacritics/tatweel and unifies letters.
String normalizeArabic(String s) {
  return s
      .replaceAll(_tashkeel, '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'[﴿﴾۝ۚۖۗ،,.:؛]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
  'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];

String hijriDateText(DateTime d) {
  final h = HijriCalendar.fromDate(d);
  return '${arNum(h.hDay)} ${hijriMonths[h.hMonth - 1]} ${arNum(h.hYear)} هـ';
}

String gregorianDateText(DateTime d) =>
    arNum(DateFormat('EEEE، d MMMM y', 'ar').format(d));

String timeText(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return arNum('$h:$m ${d.hour < 12 ? 'ص' : 'م'}');
}

String durationText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return arNum('${two(h)}:${two(m)}:${two(s)}');
}

String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String timesText(int n) {
  if (n == 1) return 'مرة واحدة';
  if (n == 2) return 'مرتان';
  if (n >= 3 && n <= 10) return '${arNum(n)} مرات';
  return '${arNum(n)} مرة';
}
