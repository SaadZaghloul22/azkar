import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/settings.dart';

IconData categoryIcon(String name) {
  switch (name) {
    case 'wb_sunny':
      return Icons.wb_sunny_rounded;
    case 'nights_stay':
      return Icons.nights_stay_rounded;
    case 'bedtime':
      return Icons.bedtime_rounded;
    case 'alarm':
      return Icons.alarm_rounded;
    case 'mosque':
      return Icons.mosque_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'volunteer_activism':
      return Icons.volunteer_activism_rounded;
    case 'auto_awesome':
      return Icons.auto_awesome_rounded;
    default:
      return Icons.bookmark_rounded;
  }
}

/// Subtle repeating eight-pointed star (Rub el Hizb) pattern used on hero cards.
class StarPatternPainter extends CustomPainter {
  StarPatternPainter({required this.color, this.cell = 46});
  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (double y = -cell / 2; y < size.height + cell; y += cell) {
      for (double x = -cell / 2; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x, y), cell * 0.32, paint);
      }
    }
  }

  void _star(Canvas c, Offset o, double r, Paint p) {
    for (final rot in [0.0, math.pi / 4]) {
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2 + math.pi / 4;
        final pt = o + Offset(math.cos(a) * r, math.sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      path.close();
      c.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant StarPatternPainter old) => old.color != color;
}

/// Emerald gradient card with the star pattern, used for the home header etc.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.emerald, AppColors.emeraldDark],
          ),
        ),
        child: CustomPaint(
          painter: StarPatternPainter(color: Colors.white.withValues(alpha: 0.07)),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
                color: cs.secondary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          ?action,
        ],
      ),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 64,
    this.stroke = 7,
    this.child,
    this.color,
    this.track,
  });
  final double value;
  final double size;
  final double stroke;
  final Widget? child;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              builder: (_, v, _) => CircularProgressIndicator(
                value: v,
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                color: color ?? cs.secondary,
                backgroundColor: track ?? cs.outlineVariant,
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Text style for azkar body text, following the user's font and size settings.
TextStyle azkarTextStyle(BuildContext context, {double? size, Color? color}) {
  final s = context.watch<SettingsController>();
  return TextStyle(
    fontFamily: s.azkarFont,
    fontSize: size ?? s.fontSize,
    height: s.azkarFont == 'Amiri' ? 2.0 : 1.8,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.primary.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: cs.onSurface.withValues(alpha: 0.7))),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
