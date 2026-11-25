import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/arabic.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/quran.dart';
import '../../services/notifications.dart';
import '../../state/quran_wird.dart';
import '../../widgets/common.dart';
import '../share_screen.dart';

const _quranFont = 'AmiriQuran';

/// The 604-page mushaf. Swipe like a printed mushaf (next page is to the left),
/// tap to show the controls. In [wirdMode] it tracks today's wird and offers
/// "أتممت ورد اليوم" once the last page of the portion is reached.
class MushafReader extends StatefulWidget {
  const MushafReader({
    super.key,
    required this.quran,
    required this.initialPage,
    this.wirdMode = false,
    this.highlightAyah,
  });
  final Quran quran;
  final int initialPage;
  final bool wirdMode;

  /// Ayah to highlight on open (from search or a verse bookmark).
  final int? highlightAyah;

  @override
  State<MushafReader> createState() => _MushafReaderState();
}

class _MushafReaderState extends State<MushafReader> {
  late final PageController _pc = PageController(initialPage: widget.initialPage - 1);
  late int _page = widget.initialPage;
  bool _chrome = false;
  late int? _selected = widget.highlightAyah;
  Timer? _saveDebounce;
  late final QuranWirdController _wird;

  @override
  void initState() {
    super.initState();
    _wird = context.read<QuranWirdController>();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _wird.setLastPage(_page);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pc.dispose();
    super.dispose();
  }

  void _onPage(int i) {
    setState(() => _page = i + 1);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () => _wird.setLastPage(_page));
  }

  void _jump(int page) => _pc.jumpToPage(page.clamp(1, Quran.pageCount) - 1);

  Future<void> _completeThrough(int page) async {
    final w = context.read<QuranWirdController>();
    final finished = await w.completeThrough(page);
    unawaited(NotificationService.instance.scheduleQuranWird(w));
    if (!mounted) return;
    if (finished) {
      await showKhatmaDoneDialog(context);
      if (mounted) Navigator.pop(context);
    } else {
      final t = w.today();
      showSnack(
          context,
          t != null && t.done
              ? 'أتممت ورد اليوم، تقبّل الله منك'
              : 'تم تسجيل وصولك إلى صفحة ${arNum(page)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<QuranWirdController>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? AppColors.nightBg : const Color(0xFFFBF7EC);
    final today = w.today();
    final inWird = widget.wirdMode && today != null;
    final atWirdEnd = inWird && !today.done && _page >= today.to;
    final q = widget.quran;
    final surah = q.surahOfPage(_page);

    return Scaffold(
      backgroundColor: paper,
      // The wird bar takes its own space under the page so it never covers text.
      bottomNavigationBar: inWird
          ? Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 3,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: _WirdBar(
                    today: today,
                    page: _page,
                    atEnd: atWirdEnd,
                    onComplete: () => _completeThrough(today.to),
                  ),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _chrome = !_chrome;
              _selected = null;
            }),
            child: PageView.builder(
              controller: _pc,
              itemCount: Quran.pageCount,
              onPageChanged: _onPage,
              itemBuilder: (context, i) => MushafPage(
                quran: q,
                page: i + 1,
                fontSize: w.fontSize,
                bookmarked: w.bookmarks.contains(i + 1),
                marked: w.ayahMarks,
                selected: _selected,
                onAyahLongPress: _ayahSheet,
              ),
            ),
          ),
          // ---- top controls
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _chrome ? 0 : -120,
            left: 0,
            right: 0,
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
              elevation: 2,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                        tooltip: 'رجوع',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: () => Navigator.pop(context)),
                    Expanded(
                      child: Text('سورة ${surah.name} • ص ${arNum(_page)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      tooltip: 'حجم الخط',
                      icon: const Icon(Icons.format_size_rounded),
                      onPressed: () => _fontSheet(context),
                    ),
                    IconButton(
                      tooltip: w.bookmarks.contains(_page) ? 'إزالة العلامة' : 'وضع علامة',
                      icon: Icon(w.bookmarks.contains(_page)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined),
                      onPressed: () => w.toggleBookmark(_page),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ---- bottom: page slider (and "record progress" outside a wird session)
          if (_chrome)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
                elevation: 2,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                            children: [
                              Text(arNum(1)),
                              Expanded(
                                child: Slider(
                                  value: _page.toDouble(),
                                  min: 1,
                                  max: Quran.pageCount.toDouble(),
                                  divisions: Quran.pageCount - 1,
                                  label: arNum(_page),
                                  onChanged: (v) => _jump(v.round()),
                                ),
                              ),
                              Text(arNum(Quran.pageCount)),
                            ],
                          ),
                        if (!inWird && w.active && _page > w.progress)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => _completeThrough(_page),
                              icon: const Icon(Icons.flag_rounded),
                              label: Text('سجّل في الختمة أني قرأت حتى صفحة ${arNum(_page)}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _ayahSheet(PageAyah a) async {
    HapticFeedback.selectionClick();
    setState(() => _selected = a.id);
    final q = widget.quran;
    final surah = q.surahs[a.surah - 1];
    final text = q.shareText(a.id);
    final copyText = '﴿$text﴾ [${q.reference(a.id)}]';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer<QuranWirdController>(
        builder: (ctx, w, _) {
          final marked = w.ayahMarks.contains(a.id);
          Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        Icon(icon, color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(height: 4),
                        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('سورة ${surah.name} • الآية ${arNum(a.number)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.35),
                    child: SingleChildScrollView(
                      child: Text(text,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontFamily: _quranFont, fontSize: 22, height: 1.9)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      action(Icons.copy_rounded, 'نسخ', () async {
                        await Clipboard.setData(ClipboardData(text: copyText));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) showSnack(context, 'تم نسخ الآية');
                      }),
                      action(Icons.image_rounded, 'مشاركة كصورة', () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShareScreen(
                              zekr: Zekr(
                                id: -a.id,
                                categoryId: 0,
                                title: 'سورة ${surah.name}',
                                content: '﴿$text﴾',
                                repeatCount: 1,
                                source: '[${q.reference(a.id)}]',
                              ),
                              fontFamily: _quranFont,
                              lineHeight: 2.0,
                            ),
                          ),
                        );
                      }),
                      action(Icons.share_rounded, 'مشاركة نص', () {
                        Navigator.pop(ctx);
                        SharePlus.instance.share(ShareParams(text: '$copyText\n\nمن تطبيق أذكار المسلم'));
                      }),
                      action(marked ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                          marked ? 'إزالة العلامة' : 'علامة على الآية', () {
                        w.toggleAyahMark(a.id);
                        Navigator.pop(ctx);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() => _selected = null);
  }

  void _fontSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer<QuranWirdController>(
        builder: (ctx, w, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('حجم خط المصحف',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ملء الصفحة تلقائيًا'),
                subtitle: const Text('يُضبط الخط لتظهر الصفحة كاملة بلا تمرير'),
                value: w.fontSize == 0,
                onChanged: (v) => w.setFontSize(v ? 0 : 26),
              ),
              if (w.fontSize > 0)
                Row(
                  children: [
                    const Icon(Icons.text_decrease_rounded),
                    Expanded(
                      child: Slider(
                        value: w.fontSize.clamp(18, 44),
                        min: 18,
                        max: 44,
                        divisions: 13,
                        label: arNum(w.fontSize.round()),
                        onChanged: w.setFontSize,
                      ),
                    ),
                    const Icon(Icons.text_increase_rounded),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WirdBar extends StatelessWidget {
  const _WirdBar({required this.today, required this.page, required this.atEnd, required this.onComplete});
  final WirdToday today;
  final int page;
  final bool atEnd;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (today.done) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(child: Text('أتممت ورد اليوم، تقبّل الله منك')),
        ],
      );
    }
    final left = (today.to - page).clamp(0, Quran.pageCount);
    final ratio = ((page - today.from + 1) / today.pages).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'ورد اليوم: ص ${arNum(today.from)} ← ${arNum(today.to)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(left == 0 ? 'آخر صفحة' : 'تبقّى ${arNum(left)} ص',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: ratio, minHeight: 6),
        ),
        if (atEnd) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_rounded),
              label: const Text('أتممت ورد اليوم'),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showKhatmaDoneDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_rounded, size: 40, color: AppColors.gold),
        title: const Text('ختمت القرآن الكريم'),
        content: const Text('مبارك عليك الختمة، تقبّل الله منك وجعل القرآن ربيع قلبك.\n'
            'يمكنك بدء ختمة جديدة من تبويب «ورد القرآن».'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('الحمد لله'))],
      ),
    );

/// One page of the mushaf: header (surah • juz), the text fitted to the screen, page
/// number. Each surah that starts on the page gets a banner and its basmala.
class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.quran,
    required this.page,
    this.fontSize = 0,
    this.bookmarked = false,
    this.marked = const {},
    this.selected,
    this.onAyahLongPress,
  });
  final Quran quran;
  final int page;
  final double fontSize; // 0 = fit
  final bool bookmarked;

  /// Ayat with a verse bookmark (tinted) and the one currently selected (highlighted).
  final Set<int> marked;
  final int? selected;
  final ValueChanged<PageAyah>? onAyahLongPress;

  static final _fitCache = <String, double>{};

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  final _recognizers = <int, LongPressGestureRecognizer>{};

  GestureRecognizer? _recognizerFor(PageAyah a) {
    final cb = widget.onAyahLongPress;
    if (cb == null) return null;
    return _recognizers.putIfAbsent(a.id, () => LongPressGestureRecognizer())..onLongPress = () => cb(a);
  }

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  Quran get quran => widget.quran;
  int get page => widget.page;
  double get fontSize => widget.fontSize;
  bool get bookmarked => widget.bookmarked;
  static Map<String, double> get _fitCache => MushafPage._fitCache;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? AppColors.nightInk : AppColors.ink;
    final accent = dark ? AppColors.goldSoft : AppColors.emerald;
    final ayat = quran.pageAyat(page);
    final surah = quran.surahOfPage(page);
    final juz = quran.juzOfPage(page);
    final mq = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        child: Column(
          children: [
            // header
            Row(
              children: [
                Text('سورة ${surah.name}',
                    style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (bookmarked) Icon(Icons.bookmark_rounded, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('الجزء ${arNum(juz)}',
                    style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w700)),
              ],
            ),
            Divider(height: 10, color: AppColors.gold.withValues(alpha: 0.5)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = fontSize > 0
                      ? fontSize
                      : _fit(ayat, box.maxWidth, box.maxHeight, mq.textScaler);
                  final body = _PageBody(
                    ayat: ayat,
                    quran: quran,
                    size: size,
                    ink: ink,
                    accent: accent,
                    marked: widget.marked,
                    selected: widget.selected,
                    recognizer: _recognizerFor,
                  );
                  return fontSize > 0
                      ? SingleChildScrollView(child: body)
                      // Fitted: the text fills the page; scrolling is only a safety net
                      // for unusually tall pages on very small screens.
                      : SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: box.maxHeight),
                            child: Center(child: body),
                          ),
                        );
                },
              ),
            ),
            Divider(height: 8, color: AppColors.gold.withValues(alpha: 0.5)),
            Text(arNum(page), style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  /// Largest font size (12..34) at which the page fits [h], found by binary search
  /// on real text layout; cached per page and box size.
  double _fit(List<PageAyah> ayat, double w, double h, TextScaler scaler) {
    final key = '$page:${w.round()}:${h.round()}:${scaler.scale(10)}';
    final hit = _fitCache[key];
    if (hit != null) return hit;
    double lo = 12, hi = 34;
    for (var i = 0; i < 9; i++) {
      final mid = (lo + hi) / 2;
      if (_PageBody.measure(ayat, mid, w, scaler) <= h) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final size = (lo * 4).floorToDouble() / 4;
    if (_fitCache.length > 400) _fitCache.clear();
    return _fitCache[key] = size;
  }
}

class _Block {
  const _Block.banner(this.surah)
      : basmala = null,
        ayat = const [];
  const _Block.basmala(this.basmala)
      : surah = null,
        ayat = const [];
  const _Block.text(this.ayat)
      : surah = null,
        basmala = null;
  final SurahInfo? surah;
  final String? basmala;
  final List<PageAyah> ayat;
}

class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.ayat,
    required this.quran,
    required this.size,
    required this.ink,
    required this.accent,
    this.marked = const {},
    this.selected,
    this.recognizer,
  });
  final List<PageAyah> ayat;
  final Quran quran;
  final double size;
  final Color ink;
  final Color accent;
  final Set<int> marked;
  final int? selected;
  final GestureRecognizer? Function(PageAyah)? recognizer;

  static const _lineHeight = 1.95;

  static List<_Block> blocks(List<PageAyah> ayat, Quran? quran) {
    final out = <_Block>[];
    var run = <PageAyah>[];
    for (final a in ayat) {
      if (a.startsSurah) {
        if (run.isNotEmpty) out.add(_Block.text(run));
        run = [];
        out.add(_Block.banner(quran?.surahs[a.surah - 1]));
        if (a.basmala != null) out.add(_Block.basmala(a.basmala));
      }
      run.add(a);
    }
    if (run.isNotEmpty) out.add(_Block.text(run));
    return out;
  }

  static TextSpan span(
    List<PageAyah> ayat,
    double size,
    Color ink,
    Color accent, {
    Set<int> marked = const {},
    int? selected,
    GestureRecognizer? Function(PageAyah)? recognizer,
  }) =>
      TextSpan(
        style: TextStyle(fontFamily: _quranFont, fontSize: size, height: _lineHeight, color: ink),
        children: [
          for (final a in ayat) ...[
            TextSpan(
              text: '${a.text} ',
              recognizer: recognizer?.call(a),
              // Background only: layout (and so the fitted size) does not change.
              style: a.id == selected
                  ? TextStyle(backgroundColor: AppColors.gold.withValues(alpha: 0.30))
                  : marked.contains(a.id)
                      ? TextStyle(backgroundColor: AppColors.emerald.withValues(alpha: 0.10))
                      : null,
            ),
            // End-of-ayah sign (U+06DD) followed by its number: Amiri Quran draws the
            // number inside the ornament.
            TextSpan(text: '\u06DD${arNum(a.number)} ', style: TextStyle(color: accent)),
          ],
        ],
      );

  static double _bannerHeight(double size) => size * 2.1 + 8;

  /// Height of the page body at [size] for width [w] (used by the fitter).
  static double measure(List<PageAyah> ayat, double size, double w, TextScaler scaler) {
    var total = 0.0;
    for (final b in blocks(ayat, null)) {
      if (b.ayat.isEmpty && b.basmala == null) {
        total += _bannerHeight(size);
        continue;
      }
      final tp = TextPainter(
        text: b.basmala != null
            ? TextSpan(text: b.basmala, style: TextStyle(fontFamily: _quranFont, fontSize: size, height: _lineHeight))
            : span(b.ayat, size, const Color(0xFF000000), const Color(0xFF000000)),
        textDirection: TextDirection.rtl,
        textAlign: b.basmala != null ? TextAlign.center : TextAlign.justify,
        textScaler: scaler,
      )..layout(maxWidth: w);
      total += tp.height;
      tp.dispose();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks(ayat, quran))
          if (b.surah != null)
            _SurahBanner(surah: b.surah!, size: size, height: _bannerHeight(size))
          else if (b.basmala != null)
            Text(b.basmala!,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontFamily: _quranFont, fontSize: size, height: _lineHeight, color: ink))
          else
            Text.rich(
                span(b.ayat, size, ink, accent, marked: marked, selected: selected, recognizer: recognizer),
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl),
      ],
    );
  }
}

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.surah, required this.size, required this.height});
  final SurahInfo surah;
  final double size;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? AppColors.goldSoft : AppColors.emeraldDark;
    return Container(
      height: height - 8,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold, width: 1.4),
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: dark ? 0.18 : 0.14),
          AppColors.emerald.withValues(alpha: dark ? 0.25 : 0.08),
          AppColors.gold.withValues(alpha: dark ? 0.18 : 0.14),
        ]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(surah.meccan ? 'مكية' : 'مدنية', style: TextStyle(fontSize: math.max(11, size * 0.45), color: fg)),
          Expanded(
            child: Text('سورة ${surah.name}',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: _quranFont, fontSize: size * 0.95, height: 1.2, color: fg)),
          ),
          Text('آياتها ${arNum(surah.ayahs)}',
              style: TextStyle(fontSize: math.max(11, size * 0.45), color: fg)),
        ],
      ),
    );
  }
}
