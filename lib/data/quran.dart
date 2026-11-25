import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';

/// The Quran text (Tanzil Uthmani 1.1, verbatim) laid out on the 604 pages of the
/// Madinah mushaf. Built by tool/build_quran.py; loaded once, off the UI thread,
/// and indexed so every lookup the reader needs is O(1) or a binary search.
class Quran {
  Quran._(this._raw);

  static const pageCount = 604;
  static const ayahCount = 6236;
  static const juzCount = 30;


  final Map<String, dynamic> _raw;
  late final List<String> _ayat = (_raw['ayat'] as List).cast<String>();

  /// The basmala exactly as the text spells it: verse 1:1. In the Tanzil text it also
  /// prefixes verse 1 of every surah except al-Fatiha (where it is verse 1) and
  /// at-Tawba (which has none).
  late final String basmala = _ayat[0];
  late final List<int> _pageStart = (_raw['pages'] as List).cast<int>();
  late final List<int> _juzStart = (_raw['juz'] as List).cast<int>();
  late final List<int> _rubStart = (_raw['rub'] as List).cast<int>();
  late final Set<int> _sajda = (_raw['sajda'] as List).cast<int>().toSet();
  late final List<SurahInfo> surahs = _buildSurahs();
  String get notice => _raw['notice'] as String;

  // ayahId (1-based) -> surah number / ayah number in surah
  late final Uint8List _ayahSurah = Uint8List(ayahCount + 1);
  late final Uint16List _ayahNo = Uint16List(ayahCount + 1);

  static Quran? _instance;
  static Future<Quran>? _loading;

  /// Loaded and cached for the life of the app.
  static Future<Quran> load() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= () async {
      final text = await rootBundle.loadString('assets/data/quran.json');
      final q = Quran.fromJson(await compute(_decode, text));
      _instance = q;
      return q;
    }();
  }

  /// The instance, if already loaded (null before the first [load]).
  static Quran? get cached => _instance;

  static Map<String, dynamic> _decode(String s) => jsonDecode(s) as Map<String, dynamic>;

  factory Quran.fromJson(Map<String, dynamic> raw) => Quran._(raw).._index();

  void _index() {
    var id = 1;
    for (var s = 0; s < surahs.length; s++) {
      for (var a = 1; a <= surahs[s].ayahs; a++) {
        _ayahSurah[id] = s + 1;
        _ayahNo[id] = a;
        id++;
      }
    }
  }

  List<SurahInfo> _buildSurahs() {
    final list = (_raw['surahs'] as List);
    var start = 1;
    final out = <SurahInfo>[];
    for (var i = 0; i < list.length; i++) {
      final e = list[i] as List;
      final ayahs = e[1] as int;
      out.add(SurahInfo(
        number: i + 1,
        name: e[0] as String,
        ayahs: ayahs,
        meccan: e[2] == 1,
        firstAyahId: start,
      ));
      start += ayahs;
    }
    return out;
  }

  // ---------------------------------------------------------------- lookups

  String ayahText(int ayahId) => _ayat[ayahId - 1];
  int surahOf(int ayahId) => _ayahSurah[ayahId];
  int ayahNumber(int ayahId) => _ayahNo[ayahId];
  bool isSajda(int ayahId) => _sajda.contains(ayahId);

  /// First ayah id on [page] (1-based page).
  int pageFirstAyah(int page) => _pageStart[page - 1];

  /// Last ayah id on [page].
  int pageLastAyah(int page) => page == pageCount ? ayahCount : _pageStart[page] - 1;

  /// Page (1..604) that contains [ayahId].
  int pageOf(int ayahId) => _floorIndex(_pageStart, ayahId) + 1;

  /// Juz (1..30) that contains [ayahId].
  int juzOfAyah(int ayahId) => _floorIndex(_juzStart, ayahId) + 1;

  /// Juz shown in the header of [page]: the juz of the page's first ayah.
  int juzOfPage(int page) => juzOfAyah(pageFirstAyah(page));

  /// Hizb quarter (1..240) of [ayahId].
  int rubOf(int ayahId) => _floorIndex(_rubStart, ayahId) + 1;

  /// True when [ayahId] opens a new hizb quarter (shown with ۞ in the margin).
  bool startsRub(int ayahId) => ayahId > 1 && _rubStart.contains(ayahId);

  /// Page where juz [juz] (1..30) starts.
  int juzStartPage(int juz) => pageOf(_juzStart[juz - 1]);

  int surahStartPage(int surah) => pageOf(surahs[surah - 1].firstAyahId);

  /// Surah name for the page header: the surah of the page's first ayah.
  SurahInfo surahOfPage(int page) => surahs[surahOf(pageFirstAyah(page)) - 1];

  /// The ayat on [page], in order, with the basmala split off verse 1 so the reader
  /// can draw it as its own line under the surah banner, as the printed mushaf does.
  List<PageAyah> pageAyat(int page) {
    final out = <PageAyah>[];
    for (var id = pageFirstAyah(page); id <= pageLastAyah(page); id++) {
      final s = surahOf(id);
      final n = ayahNumber(id);
      var text = ayahText(id);
      String? basmalaText;
      if (n == 1 && s != 1 && s != 9) {
        final split = splitBasmala(text);
        if (split != null) {
          basmalaText = split.$1;
          text = split.$2;
        }
      }
      out.add(PageAyah(
        id: id,
        surah: s,
        number: n,
        text: text,
        startsSurah: n == 1,
        basmala: basmalaText,
        sajda: isSajda(id),
        rub: startsRub(id),
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------- search

  List<String>? _searchIndex;
  Future<List<String>>? _indexing;

  /// Letters only, tuned for searching Uthmani text with ordinary spelling: the
  /// Uthmani wāw-for-alef (الصلوٰة) becomes alef, then diacritics are dropped and
  /// letter forms unified (normalizeArabic), then every alef is dropped so that
  /// «العالمين» finds «ٱلْعَـٰلَمِينَ» (written without the alef).
  static String searchKey(String s) =>
      normalizeArabic(s.replaceAll('و\u0670', 'ا')).replaceAll('ا', '');

  static List<String> _buildIndex(List<String> ayat) => [for (final a in ayat) searchKey(a)];

  /// Ayah ids whose text contains [query] (at least 2 letters), in mushaf order,
  /// with exact-spelling matches first. The index is built once, off the UI thread.
  Future<List<int>> search(String query) async {
    final key = searchKey(query);
    if (key.replaceAll(' ', '').length < 2) return const [];
    final index = _searchIndex ??= await (_indexing ??= compute(_buildIndex, _ayat));
    final exactKey = normalizeArabic(query);
    final exact = <int>[], loose = <int>[];
    for (var i = 0; i < index.length; i++) {
      if (!index[i].contains(key)) continue;
      (normalizeArabic(_ayat[i]).contains(exactKey) ? exact : loose).add(i + 1);
    }
    return [...exact, ...loose];
  }

  /// "سورة البقرة: ٢٥٥" style reference for an ayah.
  String reference(int ayahId) => '${surahs[surahOf(ayahId) - 1].name}: ${arNum(ayahNumber(ayahId))}';

  /// Verse text for copying/sharing: verse 1 without the basmala prefix.
  String shareText(int ayahId) {
    final t = ayahText(ayahId);
    final s = surahOf(ayahId);
    if (ayahNumber(ayahId) == 1 && s != 1 && s != 9) return splitBasmala(t)?.$2 ?? t;
    return t;
  }

  static final _marks = RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');
  static String _skeleton(String w) => w.replaceAll(_marks, '').replaceAll('\u0671', 'ا');
  static const _basmalaSkeleton = ['بسم', 'الله', 'الرحمن', 'الرحيم'];

  /// Splits a leading basmala off verse 1. Matched on the bare letters of the first
  /// four words, because the Tanzil text marks it slightly differently in a few
  /// surahs (e.g. a shadda on the ب in at-Tin and al-Qadr). Returns (basmala, rest)
  /// with both parts exactly as written, or null if the verse has none.
  static (String, String)? splitBasmala(String text) {
    final words = text.split(' ');
    if (words.length < 5) return null;
    for (var i = 0; i < 4; i++) {
      if (_skeleton(words[i]) != _basmalaSkeleton[i]) return null;
    }
    return (words.take(4).join(' '), words.skip(4).join(' '));
  }

  static int _floorIndex(List<int> starts, int value) {
    var lo = 0, hi = starts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (starts[mid] <= value) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }
}

@immutable
class SurahInfo {
  const SurahInfo({
    required this.number,
    required this.name,
    required this.ayahs,
    required this.meccan,
    required this.firstAyahId,
  });
  final int number;
  final String name;
  final int ayahs;
  final bool meccan;
  final int firstAyahId;
}

@immutable
class PageAyah {
  const PageAyah({
    required this.id,
    required this.surah,
    required this.number,
    required this.text,
    required this.startsSurah,
    required this.basmala,
    required this.sajda,
    required this.rub,
  });
  final int id;
  final int surah;
  final int number;
  final String text;
  final bool startsSurah;
  /// The basmala to draw above this verse (verse 1 of a surah), exactly as written.
  final String? basmala;
  final bool sajda;
  final bool rub;
}
