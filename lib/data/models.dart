class Category {
  final int id;
  final String key;
  final String name;
  final String icon;
  final int sortOrder;
  final int count;

  const Category({
    required this.id,
    required this.key,
    required this.name,
    required this.icon,
    required this.sortOrder,
    this.count = 0,
  });

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        key: m['key'] as String,
        name: m['name'] as String,
        icon: m['icon'] as String,
        sortOrder: m['sort_order'] as int,
        count: (m['cnt'] as int?) ?? 0,
      );
}

class Zekr {
  final int id;
  final int categoryId;
  final String title;
  final String content;
  final int repeatCount;
  final String? virtue;
  final String? source;
  final String? audioPath;
  final bool isVerified;

  /// true for azkar the user added themselves (custom_azkar table).
  final bool isCustom;

  const Zekr({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.content,
    required this.repeatCount,
    this.virtue,
    this.source,
    this.audioPath,
    this.isVerified = true,
    this.isCustom = false,
  });

  factory Zekr.fromMap(Map<String, Object?> m) => Zekr(
        id: m['id'] as int,
        categoryId: m['category_id'] as int,
        title: m['title'] as String,
        content: m['content'] as String,
        repeatCount: m['repeat_count'] as int,
        virtue: m['virtue'] as String?,
        source: m['source'] as String?,
        audioPath: m['audio_path'] as String?,
        isVerified: (m['is_verified'] as int? ?? 1) == 1,
      );

  factory Zekr.fromCustom(Map<String, Object?> m) => Zekr(
        id: m['id'] as int,
        categoryId: -1,
        title: m['title'] as String,
        content: m['content'] as String,
        repeatCount: m['repeat_count'] as int,
        isVerified: false,
        isCustom: true,
      );
}

class TasbeehSession {
  final int? id;
  final String name;
  final int count;
  final int target;
  final DateTime createdAt;
  final DateTime? completedAt;

  const TasbeehSession({
    this.id,
    required this.name,
    required this.count,
    required this.target,
    required this.createdAt,
    this.completedAt,
  });

  factory TasbeehSession.fromMap(Map<String, Object?> m) => TasbeehSession(
        id: m['id'] as int,
        name: m['tasbeeh_name'] as String,
        count: m['count'] as int,
        target: m['target'] as int,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completed_at'] as int),
      );
}

class DailyProgress {
  final String date;
  final bool morning;
  final bool evening;
  final bool sleep;
  final int totalTasbeeh;

  const DailyProgress({
    required this.date,
    this.morning = false,
    this.evening = false,
    this.sleep = false,
    this.totalTasbeeh = 0,
  });

  /// Daily wird = morning + evening + sleep azkar + 100 tasbeeh.
  static const tasbeehGoal = 100;

  double get ratio {
    var done = 0.0;
    if (morning) done++;
    if (evening) done++;
    if (sleep) done++;
    done += (totalTasbeeh / tasbeehGoal).clamp(0, 1);
    return done / 4;
  }

  factory DailyProgress.fromMap(Map<String, Object?> m) => DailyProgress(
        date: m['date'] as String,
        morning: (m['morning_completed'] as int) == 1,
        evening: (m['evening_completed'] as int) == 1,
        sleep: (m['sleep_completed'] as int) == 1,
        totalTasbeeh: m['total_tasbeeh'] as int,
      );
}
