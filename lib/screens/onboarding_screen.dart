import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/arabic.dart';
import '../core/theme.dart';
import '../services/location_service.dart';
import '../services/native_bridge.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

/// First-run setup: asks for each permission only with a clear reason,
/// and turns on the reminders the user picks. Every step can be skipped.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _page = PageController();
  int _step = 0;
  bool _busy = false;

  // Reminder choices on the reminders step (key -> enabled); times come from settings.
  final Map<String, bool> _picked = {'morning': true, 'evening': true, 'sleep': true};
  bool _notifGranted = false;
  bool _locationDone = false;
  bool _overlayRequested = false;
  bool _overlayGranted = false;

  static const _steps = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && _overlayRequested) _checkOverlay();
  }

  Future<void> _checkOverlay() async {
    final ok = await NativeBridge.canDrawOverlays();
    if (mounted) setState(() => _overlayGranted = ok);
  }

  void _next() {
    if (_step < _steps - 1) {
      setState(() => _step++);
      _page.animateToPage(_step,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    final s = context.read<SettingsController>();
    await s.setOnboarded();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeShell()));
  }

  Future<void> _enableReminders() async {
    setState(() => _busy = true);
    final s = context.read<SettingsController>();
    final state = context.read<AppState>();
    final granted = await NotificationService.instance.requestPermission();
    // Exact alarms make reminders arrive on time on phones that delay background work.
    if (granted && !await NotificationService.instance.canExact()) {
      await NotificationService.instance.requestExact();
    }
    for (final r in s.reminders) {
      if (_picked.containsKey(r.key)) {
        await s.setReminder(r.copyWith(enabled: _picked[r.key]!));
      }
    }
    await state.syncReminders();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notifGranted = granted;
    });
    if (!granted) {
      showSnack(context, 'لم يُمنح إذن الإشعارات، يمكنك تفعيله لاحقًا من الإعدادات');
    }
    _next();
  }

  Future<void> _enableLocation() async {
    setState(() => _busy = true);
    final s = context.read<SettingsController>();
    final state = context.read<AppState>();
    final fix = await LocationService.current();
    if (!mounted) return;
    if (fix.result != LocationResult.ok) {
      setState(() => _busy = false);
      showSnack(context, LocationService.message(fix.result));
      return;
    }
    await s.setPrayer(s.prayer.copyWith(lat: fix.lat, lng: fix.lng));
    // Prayer alerts are on by default; ask for exact timing so they arrive on time.
    if (!await NotificationService.instance.canExact()) {
      await NotificationService.instance.requestExact();
    }
    await state.syncPrayerAlerts();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _locationDone = true;
    });
    _next();
  }

  Future<void> _enableOverlay() async {
    final s = context.read<SettingsController>();
    final state = context.read<AppState>();
    await s.setOverlay(s.overlay.copyWith(enabled: true));
    await state.syncOverlay();
    if (!await NativeBridge.canDrawOverlays()) {
      _overlayRequested = true;
      await NativeBridge.openOverlaySettings();
    } else {
      setState(() => _overlayGranted = true);
      _next();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  for (var i = 0; i < _steps; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i <= _step ? cs.secondary : cs.outlineVariant,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _welcome(cs),
                  _reminders(cs),
                  _location(cs),
                  _overlay(cs),
                  _done(cs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepLayout({
    required IconData icon,
    required String title,
    required String body,
    Widget? content,
    required String primary,
    required VoidCallback? onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: cs.primary),
          ),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, height: 1.7, color: cs.onSurface.withValues(alpha: 0.75))),
        if (content != null) ...[const SizedBox(height: 18), content],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : onPrimary,
          child: _busy
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(primary),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 6),
          TextButton(onPressed: _busy ? null : onSecondary, child: Text(secondary)),
        ],
      ],
    );
  }

  Widget _welcome(ColorScheme cs) {
    Widget feature(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(i, color: cs.secondary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(t, style: const TextStyle(fontSize: 15))),
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset('assets/images/logo.png', width: 108, height: 108),
          ),
        ),
        const SizedBox(height: 18),
        const Text('أهلًا بك في أذكار المسلم',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('خطوات قليلة لتجهيز التطبيق لك',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              children: [
                feature(Icons.menu_book_rounded, 'أذكار موثّقة بالتشكيل مع مصادرها'),
                feature(Icons.notifications_active_rounded, 'تذكير بأذكار الصباح والمساء والنوم'),
                feature(Icons.access_time_filled_rounded, 'مواقيت الصلاة واتجاه القبلة'),
                feature(Icons.picture_in_picture_alt_rounded, 'ذكر يظهر تلقائيًا أثناء استخدام الهاتف'),
                feature(Icons.wifi_off_rounded, 'يعمل بدون إنترنت، بلا إعلانات'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _next, child: const Text('ابدأ')),
      ],
    );
  }

  Widget _reminders(ColorScheme cs) {
    final s = context.watch<SettingsController>();
    String fmt(ReminderConfig r) {
      final h = r.hour % 12 == 0 ? 12 : r.hour % 12;
      return arNum('$h:${r.minute.toString().padLeft(2, '0')} ${r.hour < 12 ? 'ص' : 'م'}');
    }

    return _stepLayout(
      icon: Icons.notifications_active_rounded,
      title: 'التذكيرات',
      body: 'اختر الأذكار التي تريد أن نذكّرك بها. يمكنك تغيير الأوقات بالضغط عليها.',
      content: Card(
        child: Column(
          children: [
            for (final r in s.reminders.where((r) => _picked.containsKey(r.key)))
              SwitchListTile(
                value: _picked[r.key]!,
                onChanged: (v) => setState(() => _picked[r.key] = v),
                title: Text(r.label),
                subtitle: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
                    if (t != null) {
                      await s.setReminder(r.copyWith(hour: t.hour, minute: t.minute));
                      setState(() => _picked[r.key] = true);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(fmt(r),
                          style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      primary: 'تفعيل التذكيرات',
      onPrimary: _picked.values.any((v) => v) ? _enableReminders : null,
      secondary: 'لاحقًا',
      onSecondary: _next,
    );
  }

  Widget _location(ColorScheme cs) => _stepLayout(
        icon: Icons.location_on_rounded,
        title: 'مواقيت الصلاة والقبلة',
        body:
            'نحتاج موقعك لحساب مواقيت الصلاة واتجاه القبلة وتنبيهك عند دخول وقت كل صلاة.\nيُحفظ الموقع على جهازك فقط ولا يُرسل لأي جهة.',
        content: _locationDone
            ? Center(
                child: Chip(
                  avatar: Icon(Icons.check_circle_rounded, color: cs.primary),
                  label: const Text('تم تحديد الموقع'),
                ),
              )
            : null,
        primary: 'تحديد موقعي',
        onPrimary: _enableLocation,
        secondary: 'لاحقًا',
        onSecondary: _next,
      );

  Widget _overlay(ColorScheme cs) => _stepLayout(
        icon: Icons.picture_in_picture_alt_rounded,
        title: 'الأذكار التلقائية',
        body:
            'ذكر قصير يظهر فوق التطبيقات كل ١٥ دقيقة ليذكّرك بالله. لا يظهر أثناء المكالمات أو في وضع عدم الإزعاج، ويمكنك إيقافه في أي وقت.\n\nيتطلب إذن «الظهور فوق التطبيقات».',
        content: _overlayGranted
            ? Column(
                children: [
                  Chip(
                    avatar: Icon(Icons.check_circle_rounded, color: cs.primary),
                    label: const Text('تم التفعيل'),
                  ),
                  const SizedBox(height: 8),
                  Text('في هواتف ريلمي وأوبو وشاومي وفيفو: فعّل «التشغيل التلقائي» حتى لا يوقف الهاتف الأذكار.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
                  TextButton.icon(
                    onPressed: NativeBridge.openAutostartSettings,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: const Text('فتح التشغيل التلقائي'),
                  ),
                ],
              )
            : (_overlayRequested
                ? Text('فعّل الإذن لتطبيق «أذكار المسلم» ثم ارجع هنا.',
                    textAlign: TextAlign.center, style: TextStyle(color: cs.secondary))
                : null),
        primary: _overlayGranted ? 'التالي' : 'تفعيل الأذكار التلقائية',
        onPrimary: _overlayGranted ? _next : _enableOverlay,
        secondary: _overlayGranted ? null : 'لاحقًا',
        onSecondary: _next,
      );

  Widget _done(ColorScheme cs) {
    Widget row(bool ok, String text) => ListTile(
          dense: true,
          leading: Icon(ok ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
              color: ok ? cs.primary : cs.outline),
          title: Text(text),
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const Icon(Icons.verified_rounded, size: 84, color: AppColors.gold),
        const SizedBox(height: 14),
        const Text('كل شيء جاهز',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('يمكنك تعديل كل هذه الإعدادات لاحقًا من «المزيد».',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              row(_notifGranted, 'التذكيرات'),
              row(_locationDone, 'مواقيت الصلاة والقبلة'),
              row(_overlayGranted, 'الأذكار التلقائية'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _finish, child: const Text('ابدأ الآن')),
      ],
    );
  }
}
