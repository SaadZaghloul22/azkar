import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../services/prayer_service.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SettingsController>().prayer;
    return Scaffold(
      appBar: AppBar(title: const Text('اتجاه القبلة')),
      body: !c.hasLocation
          ? const EmptyState(
              icon: Icons.location_searching_rounded,
              text: 'حدّد موقعك أولًا من شاشة المواقيت لحساب اتجاه القبلة')
          : _Compass(qibla: PrayerService.qibla(c.lat!, c.lng!)),
    );
  }
}

class _Compass extends StatelessWidget {
  const _Compass({required this.qibla});
  final double qibla;

  @override
  Widget build(BuildContext context) {
    final stream = FlutterCompass.events;
    if (stream == null) return _noSensor(context);
    return StreamBuilder<CompassEvent>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) return _noSensor(context);
        final heading = snap.data?.heading;
        if (heading == null) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return _noSensor(context);
        }
        final accuracy = snap.data?.accuracy;
        var diff = (qibla - heading) % 360;
        if (diff > 180) diff -= 360;
        final aligned = diff.abs() <= 3;
        final cs = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -heading * math.pi / 180,
                      child: CustomPaint(
                        size: const Size(300, 300),
                        painter: _DialPainter(cs.onSurface, cs.outlineVariant),
                      ),
                    ),
                    Transform.rotate(
                      angle: diff * math.pi / 180,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mosque_rounded,
                              size: 34, color: aligned ? AppColors.gold : cs.primary),
                          Container(
                            width: 6,
                            height: 104,
                            decoration: BoxDecoration(
                              color: aligned ? AppColors.gold : cs.primary,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              aligned ? 'أنت متّجه نحو القبلة' : (diff > 0 ? 'استدر نحو اليمين' : 'استدر نحو اليسار'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: aligned ? AppColors.gold : cs.onSurface),
            ),
            const SizedBox(height: 6),
            Text('زاوية القبلة: ${arNum(qibla.toStringAsFixed(1))}° من الشمال',
                textAlign: TextAlign.center),
            Text('اتجاه الهاتف الحالي: ${arNum(((heading + 360) % 360).toStringAsFixed(0))}°',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (accuracy != null && accuracy > 30)
                    ? Colors.orange.withValues(alpha: 0.12)
                    : cs.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.screen_rotation_rounded,
                      color: (accuracy != null && accuracy > 30) ? Colors.orange : cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (accuracy != null && accuracy > 30)
                          ? 'دقة البوصلة منخفضة. حرّك الهاتف في الهواء على شكل رقم ٨ عدة مرات لمعايرتها.'
                          : 'ضع الهاتف أفقيًا وبعيدًا عن المعادن والأجهزة. إذا كان الاتجاه غير مستقر، حرّك الهاتف على شكل رقم ٨ للمعايرة.',
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _noSensor(BuildContext context) => EmptyState(
        icon: Icons.explore_off_rounded,
        text:
            'هاتفك لا يحتوي على مستشعر بوصلة مناسب.\nزاوية القبلة من موقعك: ${arNum(qibla.toStringAsFixed(1))}° من اتجاه الشمال',
      );
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.ink, this.line);
  final Color ink;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = line.withValues(alpha: 0.35));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = line);
    final tick = Paint()..color = ink.withValues(alpha: 0.5);
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180 - math.pi / 2;
      final len = i % 18 == 0 ? 14.0 : (i % 2 == 0 ? 8.0 : 4.0);
      tick.strokeWidth = i % 18 == 0 ? 3 : 1.2;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r - len),
          c + Offset(math.cos(a), math.sin(a)) * r, tick);
    }
    const labels = ['ش', 'شر', 'ج', 'غ'];
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(
            text: labels[i],
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: i == 0 ? Colors.redAccent : ink)),
        textDirection: TextDirection.rtl,
      )..layout();
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 32);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.ink != ink || old.line != line;
}
