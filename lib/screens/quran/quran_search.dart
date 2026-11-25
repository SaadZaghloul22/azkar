import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/arabic.dart';
import '../../data/quran.dart';
import 'quran_screen.dart';

/// Search the Quran by words, typed in ordinary spelling and without diacritics.
class QuranSearchScreen extends StatefulWidget {
  const QuranSearchScreen({super.key, required this.quran});
  final Quran quran;
  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  static const _maxShown = 300;
  Timer? _debounce;
  String _query = '';
  List<int>? _results;
  bool _busy = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(v));
  }

  Future<void> _run(String v) async {
    final seq = ++_seq;
    setState(() {
      _query = v.trim();
      _busy = true;
    });
    final r = await widget.quran.search(_query);
    if (!mounted || seq != _seq) return; // a newer search started
    setState(() {
      _results = r;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quran;
    final cs = Theme.of(context).colorScheme;
    final r = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'ابحث في القرآن… مثل: الصبر',
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (r != null && _query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  r.isEmpty
                      ? 'لا توجد نتائج'
                      : r.length > _maxShown
                          ? 'عدد النتائج ${arNum(r.length)} • يظهر أول ${arNum(_maxShown)}'
                          : 'عدد النتائج ${arNum(r.length)}',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
                ),
              ),
            ),
          Expanded(
            child: r == null || _query.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'اكتب كلمة أو جزءًا من آية بدون تشكيل، ويمكنك الكتابة بالإملاء المعتاد (مثل: العالمين، الصلاة).',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), height: 1.7),
                    ),
                  )
                : ListView.separated(
                    itemCount: r.length.clamp(0, _maxShown),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final id = r[i];
                      return ListTile(
                        title: Text(
                          q.shareText(id),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, height: 1.8),
                        ),
                        subtitle: Text('سورة ${q.reference(id)} • ص ${arNum(q.pageOf(id))}'),
                        onTap: () => openMushaf(context, q.pageOf(id), highlightAyah: id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
