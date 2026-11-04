import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'tasbih_history_screen.dart';

const defaultTasbihat = [
  'سُبْحَانَ اللَّهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللَّهُ أَكْبَرُ',
  'لَا إِلَٰهَ إِلَّا اللَّهُ',
  'أَسْتَغْفِرُ اللَّهَ',
  'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
];

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});
  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> with WidgetsBindingObserver {
  List<String> _custom = [];
  String _dhikr = defaultTasbihat.first;
  int _target = 33; // 0 = open count (no target)
  int _count = 0;
  int _rounds = 0;
  int _pendingProgress = 0;
  DateTime _startedAt = DateTime.now();
  bool _pressed = false;
  late final AppState _app = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _app;
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flush();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.inactive) _flush();
  }

  Future<void> _restore() async {
    final db = context.read<AppState>().db;
    final prefs = await SharedPreferences.getInstance();
    final custom = await db.customTasbeeh();
    final raw = prefs.getString('tasbih_state');
    if (!mounted) return;
    setState(() {
      _custom = custom;
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _dhikr = j['dhikr'] as String? ?? _dhikr;
        _target = j['target'] as int? ?? 33;
        _count = j['count'] as int? ?? 0;
        _rounds = j['rounds'] as int? ?? 0;
      }
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tasbih_state',
        jsonEncode({'dhikr': _dhikr, 'target': _target, 'count': _count, 'rounds': _rounds}));
  }

  Future<void> _flush() async {
    if (_pendingProgress == 0) return;
    final n = _pendingProgress;
    _pendingProgress = 0;
    await _app.addTasbeeh(n);
  }

  /// Completed rounds are saved as they finish; reset saves only the partial count.
  Future<void> _saveSession({required bool completed}) async {
    final total = completed ? _target : _count;
    if (total == 0) return;
    await context.read<AppState>().db.saveSession(TasbeehSession(
          name: _dhikr,
          count: total,
          target: _target,
          createdAt: _startedAt,
          completedAt: completed ? DateTime.now() : null,
        ));
  }

  void _tap() {
    final s = context.read<SettingsController>();
    setState(() => _count++);
    _pendingProgress++;
    if (s.sound) SystemSound.play(SystemSoundType.click);
    final reached = _target > 0 && _count >= _target;
    if (s.vibration) {
      reached ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    }
    if (reached) {
      _saveSession(completed: true);
      setState(() {
        _rounds++;
        _count = 0;
        _startedAt = DateTime.now();
      });
      _flush();
      showSnack(context, 'أتممت ${arNum(_target)} — بارك الله فيك');
    } else if (_pendingProgress >= 10) {
      _flush();
    }
    _persist();
  }

  Future<void> _reset() async {
    await _saveSession(completed: false);
    await _flush();
    setState(() {
      _count = 0;
      _rounds = 0;
      _startedAt = DateTime.now();
    });
    _persist();
  }

  Future<void> _select(String dhikr) async {
    if (dhikr == _dhikr) return;
    await _reset();
    setState(() => _dhikr = dhikr);
    _persist();
  }

  Future<void> _setTarget(int t) async {
    await _reset();
    setState(() => _target = t);
    _persist();
  }

  Future<void> _customTarget() async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('هدف مخصص'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'مثال: ٧٠'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text.trim());
              if (n != null && n > 0 && n <= 100000) Navigator.pop(ctx, n);
            },
            child: const Text('تم'),
          ),
        ],
      ),
    );
    if (v != null) _setTarget(v);
  }

  Future<void> _addCustom() async {
    final ctrl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسبيحة جديدة'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اكتب التسبيحة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (v == null || !mounted) return;
    final db = context.read<AppState>().db;
    await db.addCustomTasbeeh(v);
    final custom = await db.customTasbeeh();
    setState(() => _custom = custom);
    _select(v);
  }

  Future<void> _removeCustom(String t) async {
    final db = context.read<AppState>().db;
    await db.deleteCustomTasbeeh(t);
    final custom = await db.customTasbeeh();
    setState(() => _custom = custom);
    if (_dhikr == t) _select(defaultTasbihat.first);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = context.watch<SettingsController>();
    final progress = _target == 0 ? 0.0 : _count / _target;
    final all = [...defaultTasbihat, ..._custom];
    return Scaffold(
      appBar: AppBar(
        title: const Text('المسبحة الإلكترونية'),
        actions: [
          IconButton(
            tooltip: s.vibration ? 'إيقاف الاهتزاز' : 'تشغيل الاهتزاز',
            onPressed: () => s.setVibration(!s.vibration),
            icon: Icon(s.vibration ? Icons.vibration_rounded : Icons.phone_android_rounded),
          ),
          IconButton(
            tooltip: s.sound ? 'إيقاف الصوت' : 'تشغيل الصوت',
            onPressed: () => s.setSound(!s.sound),
            icon: Icon(s.sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
          IconButton(
            tooltip: 'السجل',
            onPressed: () async {
              await _flush();
              if (!context.mounted) return;
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TasbihHistoryScreen()));
            },
            icon: const Icon(Icons.insights_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in all)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onLongPress: _custom.contains(t) ? () => _removeCustom(t) : null,
                      child: ChoiceChip(
                        label: Text(t,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface)),
                        selected: t == _dhikr,
                        onSelected: (_) => _select(t),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('تسبيحة'),
                    onPressed: _addCustom,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final t in [33, 100, 500, 1000])
                ChoiceChip(
                  label: Text(arNum(t)),
                  selected: _target == t,
                  onSelected: (_) => _setTarget(t),
                ),
              ChoiceChip(
                label: Text(![0, 33, 100, 500, 1000].contains(_target)
                    ? 'مخصص (${arNum(_target)})'
                    : 'مخصص'),
                selected: ![0, 33, 100, 500, 1000].contains(_target),
                onSelected: (_) => _customTarget(),
              ),
              ChoiceChip(
                label: const Text('مفتوح'),
                selected: _target == 0,
                onSelected: (_) => _setTarget(0),
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final d = (box.biggest.shortestSide * 0.78).clamp(200.0, 320.0);
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(_dhikr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Amiri',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTapDown: (_) => setState(() => _pressed = true),
                        onTapCancel: () => setState(() => _pressed = false),
                        onTapUp: (_) {
                          setState(() => _pressed = false);
                          _tap();
                        },
                        child: AnimatedScale(
                          scale: _pressed ? 0.95 : 1,
                          duration: const Duration(milliseconds: 90),
                          child: ProgressRing(
                            value: progress,
                            size: d,
                            stroke: 12,
                            color: cs.secondary,
                            child: Container(
                              width: d - 34,
                              height: d - 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const RadialGradient(
                                  colors: [AppColors.emeraldLight, AppColors.emerald],
                                  radius: 0.9,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.emerald.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    child: Text(arNum(_count),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 76,
                                            fontWeight: FontWeight.w800,
                                            height: 1.1)),
                                  ),
                                  Text(
                                      _target == 0 ? 'عدّ مفتوح' : 'من ${arNum(_target)}',
                                      style: const TextStyle(
                                          color: AppColors.goldSoft, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_rounds > 0)
                        Text('الجولات المكتملة: ${arNum(_rounds)}',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: cs.secondary)),
                      Text('اضغط على الدائرة للتسبيح',
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: OutlinedButton.icon(
              onPressed: (_count == 0 && _rounds == 0) ? null : _reset,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('تصفير وحفظ الجلسة'),
            ),
          ),
        ],
      ),
    );
  }
}
