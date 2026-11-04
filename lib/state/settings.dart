import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderConfig {
  final String key;
  final String label;
  final bool enabled;
  final int hour;
  final int minute;

  const ReminderConfig(this.key, this.label, this.enabled, this.hour, this.minute);

  ReminderConfig copyWith({bool? enabled, int? hour, int? minute}) => ReminderConfig(
      key, label, enabled ?? this.enabled, hour ?? this.hour, minute ?? this.minute);

  Map<String, Object> toJson() =>
      {'key': key, 'label': label, 'enabled': enabled, 'hour': hour, 'minute': minute};

  factory ReminderConfig.fromJson(Map<String, dynamic> j) => ReminderConfig(
      j['key'] as String,
      j['label'] as String,
      j['enabled'] as bool,
      j['hour'] as int,
      j['minute'] as int);
}

class OverlayConfig {
  final bool enabled;
  final int intervalMinutes;
  final int startHour;
  final int endHour;
  final bool random;
  final List<String> categories;
  final int displaySeconds;
  final bool includeCustom;

  const OverlayConfig({
    this.enabled = false,
    this.intervalMinutes = 15,
    this.startHour = 7,
    this.endHour = 23,
    this.random = true,
    this.categories = const ['tasbih', 'sunnah_duas', 'quran_duas'],
    this.displaySeconds = 10,
    this.includeCustom = true,
  });

  OverlayConfig copyWith({
    bool? enabled,
    int? intervalMinutes,
    int? startHour,
    int? endHour,
    bool? random,
    List<String>? categories,
    int? displaySeconds,
    bool? includeCustom,
  }) =>
      OverlayConfig(
        enabled: enabled ?? this.enabled,
        intervalMinutes: intervalMinutes ?? this.intervalMinutes,
        startHour: startHour ?? this.startHour,
        endHour: endHour ?? this.endHour,
        random: random ?? this.random,
        categories: categories ?? this.categories,
        displaySeconds: displaySeconds ?? this.displaySeconds,
        includeCustom: includeCustom ?? this.includeCustom,
      );

  Map<String, Object> toJson() => {
        'enabled': enabled,
        'intervalMinutes': intervalMinutes,
        'startHour': startHour,
        'endHour': endHour,
        'random': random,
        'categories': categories,
        'displaySeconds': displaySeconds,
        'includeCustom': includeCustom,
      };

  factory OverlayConfig.fromJson(Map<String, dynamic> j) => OverlayConfig(
        enabled: j['enabled'] as bool? ?? false,
        intervalMinutes: j['intervalMinutes'] as int? ?? 15,
        startHour: j['startHour'] as int? ?? 7,
        endHour: j['endHour'] as int? ?? 23,
        random: j['random'] as bool? ?? true,
        categories: (j['categories'] as List?)?.cast<String>() ??
            const ['tasbih', 'sunnah_duas', 'quran_duas'],
        displaySeconds: j['displaySeconds'] as int? ?? 10,
        includeCustom: j['includeCustom'] as bool? ?? true,
      );
}

class PrayerConfig {
  final String method;
  final bool hanafi;
  final Map<String, int> offsets;
  final Map<String, bool> alerts;
  final double? lat;
  final double? lng;

  static const prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

  const PrayerConfig({
    this.method = 'umm_al_qura',
    this.hanafi = false,
    this.offsets = const {},
    this.alerts = const {
      'fajr': true,
      'dhuhr': true,
      'asr': true,
      'maghrib': true,
      'isha': true,
    },
    this.lat,
    this.lng,
  });

  bool get hasLocation => lat != null && lng != null;

  PrayerConfig copyWith({
    String? method,
    bool? hanafi,
    Map<String, int>? offsets,
    Map<String, bool>? alerts,
    double? lat,
    double? lng,
  }) =>
      PrayerConfig(
        method: method ?? this.method,
        hanafi: hanafi ?? this.hanafi,
        offsets: offsets ?? this.offsets,
        alerts: alerts ?? this.alerts,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );

  Map<String, Object?> toJson() => {
        'method': method,
        'hanafi': hanafi,
        'offsets': offsets,
        'alerts': alerts,
        'lat': lat,
        'lng': lng,
      };

  factory PrayerConfig.fromJson(Map<String, dynamic> j) => PrayerConfig(
        method: j['method'] as String? ?? 'umm_al_qura',
        hanafi: j['hanafi'] as bool? ?? false,
        offsets: (j['offsets'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ??
            const {},
        alerts: (j['alerts'] as Map?)?.map((k, v) => MapEntry(k as String, v as bool)) ??
            const {},
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );
}

const defaultReminders = [
  ReminderConfig('morning', 'أذكار الصباح', false, 6, 30),
  ReminderConfig('evening', 'أذكار المساء', false, 17, 0),
  ReminderConfig('sleep', 'أذكار النوم', false, 22, 30),
  ReminderConfig('random', 'ذكر عشوائي', false, 13, 0),
  ReminderConfig('istighfar', 'تذكير بالاستغفار', false, 15, 30),
  ReminderConfig('wird', 'تذكير بالورد اليومي', false, 20, 0),
];

/// User preferences, persisted with SharedPreferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _load();
  }
  final SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  double fontSize = 24;
  String azkarFont = 'Amiri';
  bool vibration = true;
  bool sound = false;
  bool autoAdvance = true;
  bool showVirtue = true;
  bool onboarded = false;
  PrayerConfig prayer = const PrayerConfig();
  OverlayConfig overlay = const OverlayConfig();
  List<ReminderConfig> reminders = defaultReminders;

  void _load() {
    themeMode = ThemeMode.values[_prefs.getInt('themeMode') ?? 0];
    fontSize = _prefs.getDouble('fontSize') ?? 24;
    azkarFont = _prefs.getString('azkarFont') ?? 'Amiri';
    vibration = _prefs.getBool('vibration') ?? true;
    sound = _prefs.getBool('sound') ?? false;
    autoAdvance = _prefs.getBool('autoAdvance') ?? true;
    showVirtue = _prefs.getBool('showVirtue') ?? true;
    onboarded = _prefs.getBool('onboarded') ?? false;
    final p = _prefs.getString('prayer');
    if (p != null) prayer = PrayerConfig.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final o = _prefs.getString('overlay');
    if (o != null) overlay = OverlayConfig.fromJson(jsonDecode(o) as Map<String, dynamic>);
    final r = _prefs.getString('reminders');
    if (r != null) {
      final saved = {
        for (final e in (jsonDecode(r) as List).cast<Map<String, dynamic>>())
          e['key'] as String: ReminderConfig.fromJson(e)
      };
      reminders = [for (final d in defaultReminders) saved[d.key] ?? d];
    }
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _prefs.setInt('themeMode', m.index);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    fontSize = v;
    await _prefs.setDouble('fontSize', v);
    notifyListeners();
  }

  Future<void> setAzkarFont(String v) async {
    azkarFont = v;
    await _prefs.setString('azkarFont', v);
    notifyListeners();
  }

  Future<void> setVibration(bool v) async {
    vibration = v;
    await _prefs.setBool('vibration', v);
    notifyListeners();
  }

  Future<void> setSound(bool v) async {
    sound = v;
    await _prefs.setBool('sound', v);
    notifyListeners();
  }

  Future<void> setAutoAdvance(bool v) async {
    autoAdvance = v;
    await _prefs.setBool('autoAdvance', v);
    notifyListeners();
  }

  Future<void> setShowVirtue(bool v) async {
    showVirtue = v;
    await _prefs.setBool('showVirtue', v);
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }

  Future<void> setPrayer(PrayerConfig c) async {
    prayer = c;
    await _prefs.setString('prayer', jsonEncode(c.toJson()));
    notifyListeners();
  }

  Future<void> setOverlay(OverlayConfig c) async {
    overlay = c;
    await _prefs.setString('overlay', jsonEncode(c.toJson()));
    notifyListeners();
  }

  Future<void> setReminder(ReminderConfig c) async {
    reminders = [for (final r in reminders) r.key == c.key ? c : r];
    await _prefs.setString(
        'reminders', jsonEncode(reminders.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  /// Reader counters for today, keyed by category key, so progress survives leaving
  /// the screen or closing the app. Reset automatically on a new day.
  Map<String, List<int>> countersFor(String day) {
    final raw = _prefs.getString('counters');
    if (raw == null) return {};
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['day'] != day) return {};
    return (j['data'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as List).cast<int>()));
  }

  Future<void> saveCounters(String day, Map<String, List<int>> data) =>
      _prefs.setString('counters', jsonEncode({'day': day, 'data': data}));
}
