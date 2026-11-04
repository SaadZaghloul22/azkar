import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'share_screen.dart';

/// Shows azkar one per page with a large counter. Swipe or auto-advance.
class ReaderScreen extends StatefulWidget {
  ReaderScreen({super.key, required Category this.category})
      : title = category.name,
        initialAzkar = null,
        counterKey = category.key;

  ReaderScreen.single({super.key, required Zekr zekr})
      : category = null,
        title = zekr.title,
        initialAzkar = [zekr],
        counterKey = zekr.isCustom ? 'custom_${zekr.id}' : 'z_${zekr.id}';

  const ReaderScreen.list({
    super.key,
    required this.title,
    required List<Zekr> azkar,
    required this.counterKey,
  })  : category = null,
        initialAzkar = azkar;

  final Category? category;
  final String title;
  final List<Zekr>? initialAzkar;
  final String counterKey;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _page = PageController();
  List<Zekr> _azkar = [];
  List<int> _counts = [];
  int _index = 0;
  bool _loading = true;
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final list = widget.initialAzkar ?? await state.db.azkarOf(widget.category!.id);
    final saved = settings.countersFor(dayKey(DateTime.now()))[widget.counterKey];
    final counts = (saved != null && saved.length == list.length)
        ? List<int>.from(saved)
        : List<int>.filled(list.length, 0);
    var start = counts.indexWhere((c) => c == 0);
    if (start < 0) start = 0;
    if (!mounted) return;
    setState(() {
      _azkar = list;
      _counts = counts;
      _index = start;
      _loading = false;
    });
    if (start > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _page.jumpToPage(start));
    }
    _markRecent(start);
  }

  void _markRecent(int i) {
    if (i < _azkar.length && !_azkar[i].isCustom) {
      context.read<AppState>().db.markRecent(_azkar[i].id);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  bool get _allDone =>
      _azkar.isNotEmpty &&
      List.generate(_azkar.length, (i) => _counts[i] >= _azkar[i].repeatCount)
          .every((e) => e);

  int get _doneCount =>
      List.generate(_azkar.length, (i) => _counts[i] >= _azkar[i].repeatCount)
          .where((e) => e)
          .length;

  Future<void> _save() async {
    final settings = context.read<SettingsController>();
    final day = dayKey(DateTime.now());
    final all = settings.countersFor(day);
    all[widget.counterKey] = _counts;
    await settings.saveCounters(day, all);
  }

  void _tap() {
    if (_azkar.isEmpty) return;
    final settings = context.read<SettingsController>();
    final z = _azkar[_index];
    if (_counts[_index] >= z.repeatCount) {
      _goNext();
      return;
    }
    setState(() => _counts[_index]++);
    if (settings.sound) SystemSound.play(SystemSoundType.click);
    final finished = _counts[_index] >= z.repeatCount;
    if (settings.vibration) {
      finished ? HapticFeedback.heavyImpact() : HapticFeedback.selectionClick();
    }
    _save();
    if (finished) {
      if (_allDone) {
        _onAllDone();
      } else if (settings.autoAdvance) {
        Future.delayed(const Duration(milliseconds: 450), () {
          if (mounted && _index == _azkar.indexOf(z)) _goNext();
        });
      }
    }
  }

  void _goNext() {
    if (_index < _azkar.length - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    } else if (_allDone) {
      _onAllDone();
    }
  }

  void _goPrev() {
    if (_index > 0) {
      _page.previousPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
    }
  }

  void _resetCurrent() {
    setState(() => _counts[_index] = 0);
    _save();
  }

  void _resetAll() {
    setState(() {
      _counts = List<int>.filled(_azkar.length, 0);
      _celebrated = false;
    });
    _save();
    _page.jumpToPage(0);
  }

  Future<void> _onAllDone() async {
    if (_celebrated) return;
    _celebrated = true;
    final key = widget.category?.key;
    if (key != null) await context.read<AppState>().completeCategory(key);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 64, color: cs.secondary),
              const SizedBox(height: 12),
              Text('أتممت ${widget.title}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('تقبّل الله منك وجعلها في ميزان حسناتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetAll();
                      },
                      child: const Text('البدء من جديد'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('رجوع'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_azkar.isEmpty) {
      return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const EmptyState(icon: Icons.menu_book_rounded, text: 'لا توجد أذكار هنا'));
    }
    final total = _azkar.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'reset' ? _resetAll() : _resetCurrent(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'one', child: Text('تصفير هذا الذكر')),
              PopupMenuItem(value: 'reset', child: Text('البدء من جديد')),
            ],
          ),
        ],
        bottom: total > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Text('${arNum(_index + 1)} من ${arNum(total)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: cs.primary)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _doneCount / total,
                            minHeight: 6,
                            color: cs.secondary,
                            backgroundColor: cs.outlineVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: total,
              onPageChanged: (i) {
                setState(() => _index = i);
                _markRecent(i);
              },
              itemBuilder: (_, i) => _ZekrPage(
                zekr: _azkar[i],
                count: _counts[i],
                onTap: _tap,
              ),
            ),
          ),
          _CounterBar(
            zekr: _azkar[_index],
            count: _counts[_index],
            canPrev: _index > 0,
            canNext: _index < total - 1,
            onTap: _tap,
            onPrev: _goPrev,
            onNext: _goNext,
          ),
        ],
      ),
    );
  }
}

class _ZekrPage extends StatelessWidget {
  const _ZekrPage({required this.zekr, required this.count, required this.onTap});
  final Zekr zekr;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final state = context.watch<AppState>();
    final done = count >= zekr.repeatCount;
    final fav = !zekr.isCustom && state.isFavorite(zekr.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: done ? cs.secondary : cs.outlineVariant, width: done ? 2 : 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(zekr.title,
                            style: TextStyle(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.secondary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(timesText(zekr.repeatCount),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? cs.secondary
                                    : const Color(0xFF8A6A00))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    zekr.content,
                    textAlign: TextAlign.center,
                    style: azkarTextStyle(context),
                  ),
                  if (zekr.isCustom) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: Chip(
                        avatar: Icon(Icons.edit_note_rounded, size: 18, color: cs.primary),
                        label: const Text('ذكر أضفته بنفسك'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (settings.showVirtue && zekr.virtue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.secondary.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.stars_rounded, color: cs.secondary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('فضل الذكر',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(zekr.virtue!, style: const TextStyle(fontSize: 14, height: 1.7)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (zekr.source != null && zekr.source!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(zekr.source!,
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!zekr.isCustom)
                IconButton(
                  tooltip: fav ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
                  onPressed: () => state.toggleFavorite(zekr.id),
                  icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: fav ? Colors.redAccent : cs.primary),
                ),
              IconButton(
                tooltip: 'نسخ',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: zekr.content));
                  if (context.mounted) showSnack(context, 'تم نسخ الذكر');
                },
                icon: Icon(Icons.copy_rounded, color: cs.primary),
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
    );
  }
}

class _CounterBar extends StatelessWidget {
  const _CounterBar({
    required this.zekr,
    required this.count,
    required this.canPrev,
    required this.canNext,
    required this.onTap,
    required this.onPrev,
    required this.onNext,
  });
  final Zekr zekr;
  final int count;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = count >= zekr.repeatCount;
    final remaining = (zekr.repeatCount - count).clamp(0, zekr.repeatCount);
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'السابق',
            onPressed: canPrev ? onPrev : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: onTap,
                child: ProgressRing(
                  value: count / zekr.repeatCount,
                  size: 96,
                  stroke: 7,
                  color: done ? cs.secondary : cs.primary,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: done
                            ? [AppColors.gold, const Color(0xFFA9841A)]
                            : [AppColors.emeraldLight, AppColors.emerald],
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 38)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(arNum(remaining),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1)),
                                const Text('اضغط',
                                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'التالي',
            onPressed: canNext ? onNext : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ],
      ),
    );
  }
}
