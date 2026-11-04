import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'auto_azkar_screen.dart';
import 'favorites_screen.dart';
import 'reader_screen.dart';
import 'share_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final zod = state.zekrOfDay;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _Header(),
          if (zod != null) ...[
            const SectionTitle('ذكر اليوم'),
            _ZekrOfDayCard(zekr: zod),
          ],
          const SectionTitle('وردك اليومي'),
          _ProgressCard(progress: state.today),
          const SectionTitle('وصول سريع'),
          const _QuickGrid(),
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header();
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final h = _now.hour;
    if (h >= 4 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'طاب يومك';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    final prayer = context.watch<SettingsController>().prayer;
    final next = PrayerService.next(prayer, _now);
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('السلام عليكم ورحمة الله',
                        style: TextStyle(color: AppColors.goldSoft, fontSize: 13)),
                    Text(_greeting,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.3)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _now.hour >= 5 && _now.hour < 18
                      ? Icons.wb_sunny_rounded
                      : Icons.nights_stay_rounded,
                  color: AppColors.goldSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(hijriDateText(_now),
              style: const TextStyle(
                  color: AppColors.goldSoft, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(gregorianDateText(_now),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => HomeShell.tab.value = 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: next == null
                  ? const Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppColors.goldSoft),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text('حدّد موقعك لعرض مواقيت الصلاة',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        Icon(Icons.chevron_left_rounded, color: Colors.white70),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded,
                            color: AppColors.goldSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('الصلاة القادمة: ${next.name}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text(timeText(next.time),
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('متبقٍ',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11)),
                            Text(durationText(next.time.difference(_now)),
                                style: const TextStyle(
                                    color: AppColors.goldSoft,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZekrOfDayCard extends StatelessWidget {
  const _ZekrOfDayCard({required this.zekr});
  final Zekr zekr;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final fav = state.isFavorite(zekr.id);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ReaderScreen.single(zekr: zekr))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.format_quote_rounded, color: cs.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(zekr.title,
                        style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(zekr.content,
                  textAlign: TextAlign.center,
                  style: azkarTextStyle(context, size: 22)),
              if (zekr.source != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(zekr.source!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                    onPressed: () => state.toggleFavorite(zekr.id),
                    icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: fav ? Colors.redAccent : cs.primary),
                  ),
                  IconButton(
                    tooltip: 'مشاركة كصورة',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ShareScreen(zekr: zekr))),
                    icon: Icon(Icons.ios_share_rounded, color: cs.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});
  final DailyProgress progress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (progress.ratio * 100).round();
    Widget item(String label, bool done) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18, color: done ? cs.primary : cs.outline),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                    color: done ? cs.primary : cs.onSurface.withValues(alpha: 0.7))),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              value: progress.ratio,
              size: 76,
              stroke: 8,
              child: Text('${arNum(pct)}٪',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: cs.primary)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  item('الصباح', progress.morning),
                  item('المساء', progress.evening),
                  item('النوم', progress.sleep),
                  item(
                      'تسبيح ${arNum(progress.totalTasbeeh.clamp(0, DailyProgress.tasbeehGoal))}/${arNum(DailyProgress.tasbeehGoal)}',
                      progress.totalTasbeeh >= DailyProgress.tasbeehGoal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickGrid extends StatelessWidget {
  const _QuickGrid();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    void openCat(String key) {
      final c = state.categoryByKey(key);
      if (c != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(category: c)));
      }
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BigTile(
                title: 'أذكار الصباح',
                subtitle: state.today.morning ? 'تمّت اليوم ✓' : 'بعد الفجر حتى الشروق',
                icon: Icons.wb_sunny_rounded,
                colors: const [Color(0xFFE9B949), Color(0xFFC98A1B)],
                onTap: () => openCat('morning'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BigTile(
                title: 'أذكار المساء',
                subtitle: state.today.evening ? 'تمّت اليوم ✓' : 'بعد العصر حتى المغرب',
                icon: Icons.nights_stay_rounded,
                colors: const [Color(0xFF2F5E8C), Color(0xFF1C3A5E)],
                onTap: () => openCat('evening'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SmallTile(
                  label: 'المسبحة',
                  icon: Icons.radio_button_checked_rounded,
                  onTap: () => HomeShell.tab.value = 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallTile(
                  label: 'المفضلة',
                  icon: Icons.favorite_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FavoritesScreen()))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallTile(
                  label: 'الأذكار التلقائية',
                  icon: Icons.picture_in_picture_alt_rounded,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AutoAzkarScreen()))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SmallTile(
                  label: 'أذكار النوم',
                  icon: Icons.bedtime_rounded,
                  onTap: () => openCat('sleep')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallTile(
                  label: 'بعد الصلاة',
                  icon: Icons.mosque_rounded,
                  onTap: () => openCat('after_prayer')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallTile(
                  label: 'جميع الأذكار',
                  icon: Icons.menu_book_rounded,
                  onTap: () => HomeShell.tab.value = 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 30),
                const SizedBox(height: 18),
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
