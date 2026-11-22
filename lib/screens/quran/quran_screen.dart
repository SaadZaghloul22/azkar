import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../data/quran.dart';
import '../../services/notifications.dart';
import '../../state/quran_wird.dart';
import '../../widgets/common.dart';
import 'mushaf_reader.dart';

/// المصحف: three tabs — ورد القرآن (the khatma), الفهرس (surahs / juz), العلامات.
class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  late final Future<Quran> _quran = Quran.load();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصحف'),
          bottom: const TabBar(tabs: [
            Tab(text: 'ورد القرآن'),
            Tab(text: 'الفهرس'),
            Tab(text: 'العلامات'),
          ]),
        ),
        body: FutureBuilder<Quran>(
          future: _quran,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(icon: Icons.error_outline_rounded, text: 'تعذّر تحميل المصحف');
            }
            final q = snap.data;
            if (q == null) return const _Skeleton();
            return TabBarView(children: [
              WirdTab(quran: q),
              _IndexTab(quran: q),
              _BookmarksTab(quran: q),
            ]);
          },
        ),
      ),
    );
  }
}

/// Opens the reader at [page]; loads the Quran first if needed.
Future<void> openMushaf(BuildContext context, int page, {bool wird = false}) async {
  final q = await Quran.load();
  if (!context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MushafReader(quran: q, initialPage: page, wirdMode: wird)),
  );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double h) => Container(
          height: h,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(16)),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [bar(170), bar(90), bar(64), bar(64), bar(64)],
    );
  }
}

// ======================================================================= wird

class WirdTab extends StatelessWidget {
  const WirdTab({super.key, required this.quran});
  final Quran quran;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    return w.active ? _ActiveWird(quran: quran) : _WirdSetup(quran: quran);
  }
}

class _WirdSetup extends StatefulWidget {
  const _WirdSetup({required this.quran});
  final Quran quran;
  @override
  State<_WirdSetup> createState() => _WirdSetupState();
}

class _WirdSetupState extends State<_WirdSetup> {
  static const _choices = [7, 10, 15, 20, 30, 40, 60, 90];
  int _days = 30;
  bool _fromCurrent = false;

  String _perDay(int days, int startPage) {
    final pages = (KhatmaPlan.lastPage - startPage + 1) / days;
    if (startPage == 1 && 30 % days == 0) {
      final juz = 30 ~/ days;
      return juz == 1 ? 'جزء واحد يوميًا' : '${arNum(juz)} أجزاء يوميًا';
    }
    return 'حوالي ${arNum(pages.ceil())} صفحة يوميًا';
  }

  Future<void> _customDays() async {
    final ctrl = TextEditingController(text: '$_days');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عدد أيام الختمة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'من ١ إلى ٣٦٥ يومًا'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim().replaceAllMapped(
                  RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}'));
              Navigator.pop(ctx, n);
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (v != null && v >= 1 && v <= 365) setState(() => _days = v);
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final cs = Theme.of(context).colorScheme;
    final startPage = _fromCurrent ? w.lastPage : 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        HeroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ابدأ ختمة جديدة',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                w.khatmas > 0
                    ? 'أتممت ${arNum(w.khatmas)} ${w.khatmas == 1 ? 'ختمة' : 'ختمات'} بفضل الله. اختر مدة ختمتك القادمة.'
                    : 'اختر في كم يومًا تريد أن تختم القرآن، ونقسّم لك وردًا يوميًا ونذكّرك به.',
                style: const TextStyle(color: Colors.white70, height: 1.6),
              ),
            ],
          ),
        ),
        const SectionTitle('مدة الختمة'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _choices)
              ChoiceChip(
                label: Text('${arNum(d)} يومًا'),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
            ChoiceChip(
              label: Text(_choices.contains(_days) ? 'مدة أخرى' : '${arNum(_days)} يومًا'),
              selected: !_choices.contains(_days),
              onSelected: (_) => _customDays(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: Icon(Icons.menu_book_rounded, color: cs.primary),
            title: Text(_perDay(_days, startPage), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('تنتهي الختمة يوم ${gregorianDateText(DateTime.now().add(Duration(days: _days - 1)))}'),
          ),
        ),
        if (w.lastPage > 1) ...[
          const SectionTitle('من أين تبدأ؟'),
          Card(
            child: RadioGroup<bool>(
              groupValue: _fromCurrent,
              onChanged: (v) => setState(() => _fromCurrent = v ?? false),
              child: Column(
                children: [
                  const RadioListTile<bool>(
                    value: false,
                    title: Text('من أول المصحف (الفاتحة)'),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    title: Text('من حيث توقفت: صفحة ${arNum(w.lastPage)}'),
                    subtitle: Text('سورة ${widget.quran.surahOfPage(w.lastPage).name}'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SectionTitle('التذكير اليومي'),
        _ReminderCard(),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            await w.start(days: _days, startPage: startPage);
            await NotificationService.instance.requestPermission();
            unawaited(NotificationService.instance.scheduleQuranWird(w));
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('ابدأ الختمة', style: TextStyle(fontSize: 17)),
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final t = DateTime(2000, 1, 1, w.remindHour, w.remindMinute);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('ذكّرني بورد القرآن'),
            value: w.remind,
            onChanged: (v) async {
              await w.setReminder(on: v);
              if (v) await NotificationService.instance.requestPermission();
              unawaited(NotificationService.instance.scheduleQuranWird(w));
            },
          ),
          if (w.remind)
            ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('وقت التذكير'),
              trailing: Text(timeText(t), style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: w.remindHour, minute: w.remindMinute),
                );
                if (picked == null) return;
                await w.setReminder(on: true, hour: picked.hour, minute: picked.minute);
                unawaited(NotificationService.instance.scheduleQuranWird(w));
              },
            ),
        ],
      ),
    );
  }
}

class _ActiveWird extends StatelessWidget {
  const _ActiveWird({required this.quran});
  final Quran quran;

  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final plan = w.plan!;
    final t = w.today()!;
    final cs = Theme.of(context).colorScheme;
    final fromSurah = quran.surahOfPage(t.from).name;
    final toSurah = quran.surahs[quran.surahOf(quran.pageLastAyah(t.to)) - 1].name;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        HeroCard(
          child: Row(
            children: [
              ProgressRing(
                value: t.khatmaRatio,
                size: 92,
                color: AppColors.goldSoft,
                track: Colors.white24,
                child: Text('${arNum((t.khatmaRatio * 100).floor())}٪',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('اليوم ${arNum(t.day)} من ${arNum(t.days)}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('قرأت ${arNum(t.progress)} من ${arNum(KhatmaPlan.lastPage)} صفحة',
                        style: const TextStyle(color: Colors.white70)),
                    Text('تنتهي ${gregorianDateText(plan.endDate)}',
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionTitle('ورد اليوم'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: t.done
                ? Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: cs.primary, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('أتممت ورد اليوم',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            Text('تقبّل الله منك. وردك القادم يبدأ من صفحة ${arNum(t.progress + 1)}'),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('من صفحة ${arNum(t.from)} إلى صفحة ${arNum(t.to)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        fromSurah == toSurah
                            ? 'سورة $fromSurah • ${arNum(t.pages)} صفحة'
                            : 'من سورة $fromSurah إلى سورة $toSurah • ${arNum(t.pages)} صفحة',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () {
                          final resume = w.lastPage >= t.from && w.lastPage <= t.to ? w.lastPage : t.from;
                          openMushaf(context, resume, wird: true);
                        },
                        icon: const Icon(Icons.auto_stories_rounded),
                        label: Text(w.lastPage > t.from && w.lastPage <= t.to ? 'تابع ورد اليوم' : 'ابدأ ورد اليوم'),
                      ),
                    ],
                  ),
          ),
        ),
        if (t.behind > 0) ...[
          const SizedBox(height: 8),
          Card(
            color: cs.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('عليك ${arNum(t.behind)} صفحة من الأيام الماضية',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('يمكنك قراءتها مع ورد اليوم، أو توزيع الباقي على الأيام المتبقية مع الحفاظ على موعد الختم.'),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await w.reschedule();
                        unawaited(NotificationService.instance.scheduleQuranWird(w));
                        if (context.mounted) showSnack(context, 'تم توزيع الباقي على الأيام المتبقية');
                      },
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: const Text('إعادة توزيع الباقي'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _Stat(icon: Icons.local_fire_department_rounded, value: arNum(w.streak), label: 'أيام متتالية')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.menu_book_rounded, value: arNum(w.pagesToday), label: 'صفحة اليوم')),
            const SizedBox(width: 10),
            Expanded(child: _Stat(icon: Icons.workspace_premium_rounded, value: arNum(w.khatmas), label: 'ختمات')),
          ],
        ),
        const SectionTitle('التذكير اليومي'),
        _ReminderCard(),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('إنهاء الختمة الحالية؟'),
                content: const Text('سيتم إيقاف الورد والتذكير. يبقى مكان قراءتك وعلاماتك كما هي.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنهاء')),
                ],
              ),
            );
            if (ok != true) return;
            await w.stop();
            unawaited(NotificationService.instance.scheduleQuranWird(w));
          },
          icon: const Icon(Icons.stop_circle_outlined),
          label: const Text('إنهاء الختمة'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ====================================================================== index

class _IndexTab extends StatefulWidget {
  const _IndexTab({required this.quran});
  final Quran quran;
  @override
  State<_IndexTab> createState() => _IndexTabState();
}

class _IndexTabState extends State<_IndexTab> {
  bool _juz = false;
  String _query = '';
  late final List<String> _normNames =
      widget.quran.surahs.map((s) => normalizeArabic(s.name)).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final q = widget.quran;
    final w = context.watch<QuranWirdController>();
    final cs = Theme.of(context).colorScheme;
    final nq = normalizeArabic(_query);
    final surahs = [
      for (var i = 0; i < q.surahs.length; i++)
        if (nq.isEmpty || _normNames[i].contains(nq) || '${i + 1}' == _query.trim()) q.surahs[i],
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverList.list(children: [
            Card(
              color: cs.primaryContainer,
              child: ListTile(
                leading: Icon(Icons.auto_stories_rounded, color: cs.onPrimaryContainer),
                title: const Text('متابعة القراءة', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('صفحة ${arNum(w.lastPage)} • سورة ${q.surahOfPage(w.lastPage).name}'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => openMushaf(context, w.lastPage),
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('السور'), icon: Icon(Icons.list_rounded)),
                ButtonSegment(value: true, label: Text('الأجزاء'), icon: Icon(Icons.layers_rounded)),
              ],
              selected: {_juz},
              onSelectionChanged: (s) => setState(() => _juz = s.first),
            ),
            if (!_juz) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'ابحث باسم السورة أو رقمها',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
            const SizedBox(height: 4),
          ]),
        ),
        if (_juz)
          SliverList.builder(
            itemCount: Quran.juzCount,
            itemBuilder: (context, i) {
              final page = q.juzStartPage(i + 1);
              final s = q.surahOfPage(page);
              return ListTile(
                leading: _Num(i + 1),
                title: Text('الجزء ${arNum(i + 1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('يبدأ من سورة ${s.name}'),
                trailing: Text('ص ${arNum(page)}'),
                onTap: () => openMushaf(context, page),
              );
            },
          )
        else if (surahs.isEmpty)
          const SliverToBoxAdapter(
              child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('لا توجد سورة بهذا الاسم')),
          ))
        else
          SliverList.builder(
            itemCount: surahs.length,
            itemBuilder: (context, i) {
              final s = surahs[i];
              final page = q.surahStartPage(s.number);
              return ListTile(
                leading: _Num(s.number),
                title: Text('سورة ${s.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.meccan ? 'مكية' : 'مدنية'} • آياتها ${arNum(s.ayahs)}'),
                trailing: Text('ص ${arNum(page)}'),
                onTap: () => openMushaf(context, page),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.n);
  final int n;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1.5),
        color: cs.primary.withValues(alpha: 0.06),
      ),
      child: Text(arNum(n), style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ================================================================== bookmarks

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab({required this.quran});
  final Quran quran;
  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final pages = w.bookmarks.toList()..sort();
    if (pages.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmark_border_rounded,
        text: 'لا توجد علامات بعد.\nأثناء القراءة اضغط على الصفحة ثم على أيقونة العلامة.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: pages.length,
      itemBuilder: (context, i) {
        final p = pages[i];
        return ListTile(
          leading: const Icon(Icons.bookmark_rounded, color: AppColors.gold),
          title: Text('صفحة ${arNum(p)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('سورة ${quran.surahOfPage(p).name} • الجزء ${arNum(quran.juzOfPage(p))}'),
          trailing: IconButton(
            tooltip: 'حذف العلامة',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => w.toggleBookmark(p),
          ),
          onTap: () => openMushaf(context, p),
        );
      },
    );
  }
}
