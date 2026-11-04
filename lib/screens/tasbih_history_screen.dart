import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

class TasbihHistoryScreen extends StatefulWidget {
  const TasbihHistoryScreen({super.key});
  @override
  State<TasbihHistoryScreen> createState() => _TasbihHistoryScreenState();
}

class _TasbihHistoryScreenState extends State<TasbihHistoryScreen> {
  List<TasbeehSession> _sessions = [];
  List<DailyProgress> _week = [];
  bool _loading = true;

  static const _days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppState>().db;
    final now = DateTime.now();
    final from = dayKey(now.subtract(const Duration(days: 6)));
    final sessions = await db.sessions(limit: 100);
    final week = await db.progressRange(from, dayKey(now));
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _week = week;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: const Text('سجل التسبيح')),
          body: const Center(child: CircularProgressIndicator()));
    }
    final now = DateTime.now();
    final byDay = {for (final p in _week) p.date: p.totalTasbeeh};
    final days = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final values = days.map((d) => byDay[dayKey(d)] ?? 0).toList();
    final maxV = values.fold<int>(1, (a, b) => a > b ? a : b);
    final today = values.last;
    final weekTotal = values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التسبيح'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              tooltip: 'مسح الجلسات',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('مسح سجل الجلسات؟'),
                    content: const Text('لن يؤثر ذلك على إحصائيات الأيام.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('إلغاء')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true), child: const Text('مسح')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await context.read<AppState>().db.clearSessions();
                  _load();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _Stat(label: 'اليوم', value: today)),
              const SizedBox(width: 12),
              Expanded(child: _Stat(label: 'آخر ٧ أيام', value: weekTotal)),
            ],
          ),
          const SectionTitle('الأسبوع'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
              child: SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(values[i] == 0 ? '' : arNum(values[i]),
                                style: const TextStyle(fontSize: 10.5)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 110 * values[i] / maxV + 3,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: i == 6 ? cs.secondary : cs.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_days[days[i].weekday - 1],
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SectionTitle('الجلسات السابقة'),
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('لا توجد جلسات محفوظة بعد')),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final s in _sessions)
                    ListTile(
                      leading: Icon(
                          s.completedAt != null
                              ? Icons.check_circle_rounded
                              : Icons.timelapse_rounded,
                          color: s.completedAt != null ? cs.primary : cs.outline),
                      title: Text(s.name, style: const TextStyle(fontFamily: 'Amiri', fontSize: 17)),
                      subtitle: Text(
                          '${gregorianDateText(s.createdAt)} • ${timeText(s.createdAt)}'),
                      trailing: Text(arNum(s.count),
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16, color: cs.primary)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(arNum(value),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.primary)),
            Text(label, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}
