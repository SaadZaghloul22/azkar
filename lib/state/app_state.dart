import 'package:flutter/foundation.dart';

import '../core/arabic.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../services/native_bridge.dart';
import '../services/notifications.dart';
import 'settings.dart';

/// App-wide data held in memory and backed by [AppDatabase].
class AppState extends ChangeNotifier {
  AppState(this.db, this.settings);
  final AppDatabase db;
  final SettingsController settings;

  List<Category> categories = [];
  List<Zekr> allAzkar = [];
  Set<int> favoriteIds = {};
  DailyProgress today = DailyProgress(date: dayKey(DateTime.now()));
  List<Zekr> customAzkar = [];

  Future<void> load() async {
    categories = await db.categories();
    allAzkar = await db.allAzkar();
    favoriteIds = await db.favoriteIds();
    customAzkar = await db.customAzkar();
    await refreshProgress();
  }

  Category? categoryByKey(String key) {
    for (final c in categories) {
      if (c.key == key) return c;
    }
    return null;
  }

  Category? categoryById(int id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Same zekr for the whole day, rotating daily through short authentic azkar.
  Zekr? get zekrOfDay {
    final pool = allAzkar
        .where((z) => z.content.length < 260 && !z.content.startsWith('يقرأ'))
        .toList();
    if (pool.isEmpty) return null;
    final n = DateTime.now();
    final dayIndex = DateTime(n.year, n.month, n.day)
            .difference(DateTime(2024, 1, 1))
            .inDays;
    return pool[dayIndex % pool.length];
  }

  Future<void> refreshProgress() async {
    today = await db.progress(dayKey(DateTime.now()));
    notifyListeners();
  }

  bool isFavorite(int id) => favoriteIds.contains(id);

  Future<void> toggleFavorite(int id) async {
    if (favoriteIds.contains(id)) {
      await db.removeFavorite(id);
      favoriteIds.remove(id);
    } else {
      await db.addFavorite(id);
      favoriteIds.add(id);
    }
    notifyListeners();
  }

  /// Marks morning/evening/sleep as completed for today when its category is finished.
  Future<void> completeCategory(String key) async {
    if (key != 'morning' && key != 'evening' && key != 'sleep') return;
    await db.markCompleted(dayKey(DateTime.now()), key);
    await refreshProgress();
  }

  Future<void> addTasbeeh(int n) async {
    if (n <= 0) return;
    await db.addTasbeeh(dayKey(DateTime.now()), n);
    await refreshProgress();
  }

  Future<void> reloadCustom() async {
    customAzkar = await db.customAzkar();
    notifyListeners();
    await syncOverlay();
  }

  /// Pushes current floating-azkar settings to the native service.
  Future<void> syncOverlay() async {
    try {
      final o = settings.overlay;
      if (o.enabled) {
        await NativeBridge.startOverlay(o, customAzkar.map((e) => e.content).toList());
      } else {
        await NativeBridge.stopOverlay();
      }
    } catch (e) {
      debugPrint('overlay sync failed: $e');
    }
  }

  Future<void> syncReminders() =>
      NotificationService.instance.scheduleReminders(settings.reminders, allAzkar);

  Future<void> syncPrayerAlerts() =>
      NotificationService.instance.schedulePrayerAlerts(settings.prayer);
}
