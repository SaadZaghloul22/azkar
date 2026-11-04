import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class _Bg {
  final String name;
  final List<Color> colors;
  final Color text;
  final Color accent;
  const _Bg(this.name, this.colors, this.text, this.accent);
}

const _backgrounds = [
  _Bg('زمردي', [AppColors.emerald, AppColors.emeraldDark], Colors.white, AppColors.goldSoft),
  _Bg('ليلي', [Color(0xFF1C2E4A), Color(0xFF0D1626)], Colors.white, Color(0xFFE5C76B)),
  _Bg('رملي', [Color(0xFFF6EBD3), Color(0xFFE8D3A8)], Color(0xFF3B2A12), Color(0xFF8A6A00)),
  _Bg('عاجي', [Color(0xFFFFFDF7), Color(0xFFF1ECDF)], AppColors.ink, AppColors.emerald),
  _Bg('عنابي', [Color(0xFF6B1F2E), Color(0xFF3F0F19)], Colors.white, Color(0xFFF0C66E)),
];

/// Turns a zekr into a shareable image (WhatsApp and others) using the system share sheet.
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.zekr});
  final Zekr zekr;
  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _key = GlobalKey();
  int _bg = 0;
  double _size = 24;
  bool _showSource = true;
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zekr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: widget.zekr.isCustom ? null : '${widget.zekr.title} — من تطبيق أذكار المسلم',
      ));
    } catch (e) {
      if (mounted) showSnack(context, 'تعذّرت المشاركة');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgrounds[_bg];
    final z = widget.zekr;
    return Scaffold(
      appBar: AppBar(title: const Text('مشاركة كصورة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RepaintBoundary(
            key: _key,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: bg.colors,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: StarPatternPainter(color: bg.accent.withValues(alpha: 0.1)),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: bg.accent.withValues(alpha: 0.6), width: 1.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        child: Column(
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: bg.accent, size: 22),
                            const SizedBox(height: 4),
                            Text(z.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: bg.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width - 110),
                                    child: Text(
                                      z.content,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Amiri',
                                        fontSize: _size,
                                        height: 1.9,
                                        color: bg.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_showSource && z.source != null)
                              Text(z.source!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: bg.text.withValues(alpha: 0.75), fontSize: 12)),
                            const SizedBox(height: 6),
                            Text('أذكار المسلم',
                                style: TextStyle(
                                    color: bg.accent.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SectionTitle('الخلفية'),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _backgrounds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => setState(() => _bg = i),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: _backgrounds[i].colors),
                        border: Border.all(
                          color: i == _bg
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.black12,
                          width: i == _bg ? 3 : 1,
                        ),
                      ),
                    ),
                    Text(_backgrounds[i].name, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          const SectionTitle('حجم الخط'),
          Slider(
            value: _size,
            min: 16,
            max: 36,
            divisions: 10,
            onChanged: (v) => setState(() => _size = v),
          ),
          if (z.source != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('إظهار المصدر'),
              value: _showSource,
              onChanged: (v) => setState(() => _showSource = v),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share_rounded),
            label: const Text('مشاركة الصورة'),
          ),
        ],
      ),
    );
  }
}
