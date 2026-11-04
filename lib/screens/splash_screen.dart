import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'onboarding_screen.dart';

/// Opening screen: logo, app name and a short zekr for two seconds.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.duration = const Duration(seconds: 2)});
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final String _zekr;

  static const _fallback = [
    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
    'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
    'سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَٰهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ',
  ];

  @override
  void initState() {
    super.initState();
    final pool = context
        .read<AppState>()
        .allAzkar
        .where((z) => z.content.length <= 70 && !z.content.contains('\n'))
        .map((z) => z.content)
        .toList();
    final list = pool.isEmpty ? _fallback : pool;
    _zekr = list[Random().nextInt(list.length)];
    Future.delayed(widget.duration, _go);
  }

  void _go() {
    if (!mounted) return;
    final onboarded = context.read<SettingsController>().onboarded;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, _, _) => onboarded ? const HomeShell() : const OnboardingScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: AppColors.emerald,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.emerald, AppColors.emeraldDark],
          ),
        ),
        child: CustomPaint(
          painter: StarPatternPainter(color: Colors.white.withValues(alpha: 0.06), cell: 54),
          child: SafeArea(
            child: FadeTransition(
              opacity: fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(fade),
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('أذكار المسلم',
                      style: TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  const Text('حصّن يومك بذكر الله',
                      style: TextStyle(color: AppColors.goldSoft, fontSize: 15)),
                  const Spacer(flex: 2),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _zekr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 22, height: 1.9, color: Colors.white),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
