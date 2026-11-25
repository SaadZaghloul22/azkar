import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../services/notifications.dart';
import '../services/prayer_service.dart';
import '../state/quran_wird.dart';
import '../state/ramadan.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'quran/quran_screen.dart';
import 'share_screen.dart';

/// Authenticated Ramadan du'as and virtues (text, source).
const ramadanDuas = [
  (
    'دعاء رؤية الهلال',
    'اللهم أهلّه علينا باليُمن والإيمان، والسلامة والإسلام، ربي وربك الله',
    'رواه الترمذي (٣٤٥١) وحسّنه'
  ),
  ('دعاء الإفطار', 'ذهب الظمأ، وابتلّت العروق، وثبت الأجر إن شاء الله', 'رواه أبو داود (٢٣٥٧) وحسّنه الألباني'),
  (
    'إذا أفطر عند قوم',
    'أفطر عندكم الصائمون، وأكل طعامكم الأبرار، وصلّت عليكم الملائكة',
    'رواه أبو داود (٣٨٥٤) وصحّحه الألباني'
  ),
  ('دعاء ليلة القدر', 'اللهم إنك عفوّ تحب العفو فاعفُ عني', 'رواه الترمذي (٣٥١٣) وصحّحه'),
  ('إذا سابّه أحد أو قاتله', 'إني صائم، إني صائم', 'رواه البخاري (١٨٩٤) ومسلم (١١٥١)'),
  ('فضل صيام رمضان', 'من صام رمضان إيمانًا واحتسابًا غُفر له ما تقدّم من ذنبه', 'رواه البخاري (٣٨) ومسلم (٧٦٠)'),
  ('فضل قيام رمضان', 'من قام رمضان إيمانًا واحتسابًا غُفر له ما تقدّم من ذنبه', 'رواه البخاري (٣٧) ومسلم (٧٥٩)'),
  ('فضل ليلة القدر', 'من قام ليلة القدر إيمانًا واحتسابًا غُفر له ما تقدّم من ذنبه', 'رواه البخاري (١٩٠١) ومسلم (٧٦٠)'),
  ('السحور', 'تسحّروا فإن في السحور بركة', 'رواه البخاري (١٩٢٣) ومسلم (١٠٩٥)'),
];

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({super.key, this.debugNow});

  /// Fixed "now" for screenshots/tests (shows the screen as on that day).
  final DateTime? debugNow;
  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  late Timer _tick;
  late DateTime _now = widget.debugNow ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (widget.debugNow == null) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _resync() async {
    final r = context.read<RamadanController>();
    final prayer = context.read<SettingsController>().prayer;
    await NotificationService.instance.scheduleRamadan(r, prayer);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<RamadanController>();
    final prayer = context.watch<SettingsController>().prayer;
    final info = r.info(_now);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('رمضان ${arNum(info.hYear)} هـ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _Hero(info: info, prayer: prayer, now: _now),
          if (!prayer.hasLocation)
            Card(
              color: cs.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('حدّد موقعك من شاشة المواقيت لتظهر الإمساكية ومواعيد السحور والإفطار.'),
              ),
            ),
          if (info.inRamadan) ...[
            const SectionTitle('إنجاز اليوم'),
            _Tracker(info: info),
          ],
          const SectionTitle('ختمة رمضان'),
          _KhatmaCard(info: info),
          if (prayer.hasLocation) ...[
            const SectionTitle('الإمساكية'),
            _Imsakiya(info: info, prayer: prayer),
          ],
          const SectionTitle('زكاة الفطر'),
          Card(
            child: ListTile(
              leading: Icon(Icons.volunteer_activism_rounded, color: cs.primary),
              title: const Text('حاسبة زكاة الفطر', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${arNum(r.zakatPeople)} ${r.zakatPeople == 1 ? 'شخص' : 'أشخاص'} • '
                  '${_kg(r.zakatKg * r.zakatPeople)} كجم'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _ZakatSheet(),
              ),
            ),
          ),
          const SectionTitle('أدعية وفضائل'),
          for (final d in ramadanDuas) _DuaCard(title: d.$1, text: d.$2, source: d.$3),
          const SectionTitle('التذكيرات'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.nights_stay_rounded),
                  title: const Text('تذكير السحور'),
                  subtitle: Text('قبل الفجر بـ ${arNum(r.suhoorMinutes)} دقيقة'),
                  value: r.suhoor,
                  onChanged: (v) async {
                    await r.update(suhoor: v);
                    if (v) await NotificationService.instance.requestPermission();
                    unawaited(_resync());
                  },
                ),
                if (r.suhoor)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final m in const [30, 45, 60, 90])
                          ChoiceChip(
                            label: Text('${arNum(m)} د'),
                            selected: r.suhoorMinutes == m,
                            onSelected: (_) async {
                              await r.update(suhoorMinutes: m);
                              unawaited(_resync());
                            },
                          ),
                      ],
                    ),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.restaurant_rounded),
                  title: const Text('تذكير الإفطار'),
                  subtitle: const Text('عند أذان المغرب مع دعاء الإفطار'),
                  value: r.iftar,
                  onChanged: (v) async {
                    await r.update(iftar: v);
                    if (v) await NotificationService.instance.requestPermission();
                    unawaited(_resync());
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.brightness_3_rounded),
                  title: const Text('تنبيه أول ليلة من رمضان'),
                  subtitle: const Text('مع دعاء رؤية الهلال'),
                  value: r.crescent,
                  onChanged: (v) async {
                    await r.update(crescent: v);
                    unawaited(_resync());
                  },
                ),
              ],
            ),
          ),
          const SectionTitle('بداية الشهر في بلدك'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('المواعيد محسوبة بتقويم أم القرى. إن بدأ الصيام في بلدك قبله أو بعده بيوم فعدّلها هنا.',
                      style: TextStyle(height: 1.6)),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: -1, label: Text('قبله بيوم')),
                      ButtonSegment(value: 0, label: Text('أم القرى')),
                      ButtonSegment(value: 1, label: Text('بعده بيوم')),
                    ],
                    selected: {r.offset},
                    onSelectionChanged: (s) async {
                      await r.update(offset: s.first);
                      unawaited(_resync());
                    },
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

String _kg(double v) => arNum(v == v.roundToDouble() ? v.round() : double.parse(v.toStringAsFixed(1)));

String _left(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '${arNum(m)} دقيقة';
  return '${arNum(h)} س ${arNum(m)} د';
}

class _Hero extends StatelessWidget {
  const _Hero({required this.info, required this.prayer, required this.now});
  final RamadanInfo info;
  final PrayerConfig prayer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white);
    if (!info.inRamadan) {
      return HeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.daysUntil == 1 ? 'رمضان غدًا' : 'باقي ${arNum(info.daysUntil)} يومًا على رمضان',
                style: white.copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('أول أيام رمضان ${arNum(info.hYear)}: ${gregorianDateText(info.start)}',
                style: white.copyWith(color: Colors.white70)),
            Text('عدد أيامه ${arNum(info.days)} يومًا حسب تقويم أم القرى • العيد ${gregorianDateText(info.eid)}',
                style: white.copyWith(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }
    final today = PrayerService.timesFor(prayer, now);
    DateTime? t(String k) => today?.firstWhere((s) => s.key == k).time;
    final fajr = t('fajr'), maghrib = t('maghrib');
    String? countdown;
    if (fajr != null && maghrib != null) {
      if (now.isBefore(fajr)) {
        countdown = 'باقي على الإمساك ${_left(fajr.difference(now))}';
      } else if (now.isBefore(maghrib)) {
        countdown = 'باقي على الإفطار ${_left(maghrib.difference(now))}';
      } else {
        countdown = info.oddNightTonight ? 'الليلة من ليالي الوتر في العشر الأواخر' : 'تقبّل الله صيامك';
      }
    }
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اليوم ${arNum(info.day!)} من رمضان', style: white.copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
          if (info.lastTen)
            Text('العشر الأواخر', style: white.copyWith(color: AppColors.goldSoft, fontWeight: FontWeight.w700)),
          if (countdown != null) ...[
            const SizedBox(height: 6),
            Text(countdown, style: white.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
          if (fajr != null && maghrib != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _TimeBox('الإمساك', fajr.subtract(const Duration(minutes: 10))),
                _TimeBox('الفجر', fajr),
                _TimeBox('الإفطار', maghrib),
                _TimeBox('العشاء', t('isha')!),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox(this.label, this.time);
  final String label;
  final DateTime time;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(timeText(time), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      );
}

class _Tracker extends StatelessWidget {
  const _Tracker({required this.info});
  final RamadanInfo info;
  @override
  Widget build(BuildContext context) {
    final r = context.watch<RamadanController>();
    final cs = Theme.of(context).colorScheme;
    final day = info.day!;
    final done = r.doneOn(info.hYear, day);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in RamadanController.items.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: done.contains(e.key),
                    onSelected: (_) => r.toggle(info.hYear, day, e.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('صمت ${arNum(r.fastedDays(info.hYear))} من ${arNum(info.days)} يومًا',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var d = 1; d <= info.days; d++)
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: r.doneOn(info.hYear, d).contains('fast')
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      border: d == day ? Border.all(color: AppColors.gold, width: 2) : null,
                    ),
                    child: Text(arNum(d),
                        style: TextStyle(
                            fontSize: 11,
                            color: r.doneOn(info.hYear, d).contains('fast') ? cs.onPrimary : cs.onSurface)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KhatmaCard extends StatelessWidget {
  const _KhatmaCard({required this.info});
  final RamadanInfo info;
  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final cs = Theme.of(context).colorScheme;
    void open() => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuranScreen(initialTab: 0)));
    if (w.active) {
      final t = w.today()!;
      return Card(
        child: ListTile(
          leading: Icon(Icons.auto_stories_rounded, color: cs.primary),
          title: Text(t.done ? 'أتممت ورد اليوم ✓' : 'ورد اليوم: ص ${arNum(t.from)} ← ${arNum(t.to)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('أنجزت ${arNum((t.khatmaRatio * 100).floor())}٪ من الختمة'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: open,
        ),
      );
    }
    final daysLeft = info.inRamadan ? info.days - info.day! + 1 : info.days;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              info.inRamadan
                  ? 'اختم القرآن في ما بقي من رمضان (${arNum(daysLeft)} يومًا)، ونقسّم لك الورد ونذكّرك به.'
                  : 'تبدأ ختمة رمضان مع أول يوم في الشهر: جزء يوميًا تقريبًا، مع تذكير يومي.',
              style: const TextStyle(height: 1.6),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: info.inRamadan
                  ? () async {
                      await w.start(days: daysLeft, startPage: 1);
                      await NotificationService.instance.requestPermission();
                      unawaited(NotificationService.instance.scheduleQuranWird(w));
                      if (context.mounted) open();
                    }
                  : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(info.inRamadan ? 'ابدأ ختمة رمضان' : 'تتاح مع بداية رمضان'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Imsakiya extends StatelessWidget {
  const _Imsakiya({required this.info, required this.prayer});
  final RamadanInfo info;
  final PrayerConfig prayer;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const head = TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5);
    Widget cell(String s, {TextStyle? style, int flex = 2}) =>
        Expanded(flex: flex, child: Text(s, textAlign: TextAlign.center, style: style ?? const TextStyle(fontSize: 13)));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: info.inRamadan,
        leading: Icon(Icons.calendar_month_rounded, color: cs.primary),
        title: Text('إمساكية رمضان ${arNum(info.hYear)}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('الإمساك قبل الفجر بعشر دقائق'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              cell('اليوم', style: head, flex: 1),
              cell('التاريخ', style: head, flex: 3),
              cell('الإمساك', style: head),
              cell('الفجر', style: head),
              cell('المغرب', style: head),
              cell('العشاء', style: head),
            ]),
          ),
          const Divider(height: 1),
          for (var d = 1; d <= info.days; d++)
            Builder(builder: (context) {
              final date = info.dateOf(d);
              final times = PrayerService.timesFor(prayer, date);
              if (times == null) return const SizedBox.shrink();
              DateTime t(String k) => times.firstWhere((s) => s.key == k).time;
              final isToday = info.day == d;
              return Container(
                color: isToday ? AppColors.gold.withValues(alpha: 0.18) : (d.isEven ? cs.surfaceContainerHighest.withValues(alpha: 0.4) : null),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(children: [
                  cell(arNum(d), flex: 1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  cell('${arNum(date.day)}/${arNum(date.month)}', flex: 3),
                  cell(timeText(t('fajr').subtract(const Duration(minutes: 10)))),
                  cell(timeText(t('fajr'))),
                  cell(timeText(t('maghrib')), style: TextStyle(fontSize: 13, color: cs.primary, fontWeight: FontWeight.w700)),
                  cell(timeText(t('isha'))),
                ]),
              );
            }),
        ],
      ),
    );
  }
}

class _ZakatSheet extends StatelessWidget {
  const _ZakatSheet();
  @override
  Widget build(BuildContext context) {
    final r = context.watch<RamadanController>();
    final cs = Theme.of(context).colorScheme;
    final kg = r.zakatKg * r.zakatPeople;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('زكاة الفطر', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'صاع من غالب قوت البلد (أرز أو تمر أو قمح…) عن كل فرد تعوله، يُخرج قبل صلاة العيد، ويجوز قبله بيوم أو يومين.',
                style: TextStyle(height: 1.6, color: cs.onSurface.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(child: Text('عدد الأفراد', style: TextStyle(fontWeight: FontWeight.w700))),
                  IconButton.outlined(
                    onPressed: r.zakatPeople > 1 ? () => r.update(zakatPeople: r.zakatPeople - 1) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(arNum(r.zakatPeople),
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  IconButton.outlined(
                    onPressed: () => r.update(zakatPeople: r.zakatPeople + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('مقدار الصاع', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SegmentedButton<double>(
                segments: const [
                  ButtonSegment(value: 3, label: Text('٣ كجم')),
                  ButtonSegment(value: 2.5, label: Text('٢٫٥ كجم')),
                ],
                selected: {r.zakatKg},
                onSelectionChanged: (s) => r.update(zakatKg: s.first),
              ),
              const SizedBox(height: 4),
              Text('٣ كجم تقريبًا تقدير اللجنة الدائمة للإفتاء بالسعودية، و٢٫٥ كجم تقدير شائع عند جهات فتوى أخرى.',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65))),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: r.zakatPricePerKg > 0 ? r.zakatPricePerKg.toString() : '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'سعر الكيلو (اختياري)',
                  helperText: 'لمعرفة التكلفة التقريبية فقط',
                ),
                onChanged: (v) {
                  final n = double.tryParse(v.trim().replaceAllMapped(
                      RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x660}').replaceAll('٫', '.'));
                  r.update(zakatPricePerKg: n ?? 0);
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('${_kg(kg)} كجم', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    Text('عن ${arNum(r.zakatPeople)} ${r.zakatPeople == 1 ? 'شخص' : 'أشخاص'}'),
                    if (r.zakatPricePerKg > 0)
                      Text('التكلفة التقريبية: ${arNum((kg * r.zakatPricePerKg).round())}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('إخراجها نقدًا محل خلاف بين العلماء؛ ومن أخذ بجوازه فليرجع إلى القيمة التي تعلنها جهة الفتوى في بلده.',
                  style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurface.withValues(alpha: 0.65))),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.title, required this.text, required this.source});
  final String title;
  final String text;
  final String source;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(fontFamily: 'Amiri', fontSize: 20, height: 1.8)),
            Row(
              children: [
                Expanded(
                    child: Text(source, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65)))),
                IconButton(
                  tooltip: 'نسخ',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: '$text\n($source)'));
                    if (context.mounted) showSnack(context, 'تم النسخ');
                  },
                ),
                IconButton(
                  tooltip: 'مشاركة كصورة',
                  icon: const Icon(Icons.image_rounded, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareScreen(
                        zekr: Zekr(id: -9000, categoryId: 0, title: title, content: text, repeatCount: 1, source: source),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
