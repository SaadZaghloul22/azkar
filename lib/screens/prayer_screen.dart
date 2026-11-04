import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../services/location_service.dart';
import '../services/notifications.dart';
import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'qibla_screen.dart';

const _prayerIcons = {
  'fajr': Icons.wb_twilight_rounded,
  'sunrise': Icons.wb_sunny_outlined,
  'dhuhr': Icons.wb_sunny_rounded,
  'asr': Icons.light_mode_rounded,
  'maghrib': Icons.wb_twilight_rounded,
  'isha': Icons.nights_stay_rounded,
};

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});
  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_rounded),
        title: const Text('استخدام موقعك'),
        content: const Text(
            'نحتاج موقعك التقريبي لحساب مواقيت الصلاة واتجاه القبلة بدقة.\n\nيُحفظ الموقع على جهازك فقط ولا يُرسل إلى أي جهة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ليس الآن')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('موافق')),
        ],
      ),
    );
    if (agreed != true || !mounted) return;
    setState(() => _locating = true);
    final fix = await LocationService.current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix.result != LocationResult.ok) {
      showSnack(context, LocationService.message(fix.result));
      if (fix.result == LocationResult.deniedForever) LocationService.openSettings();
      if (fix.result == LocationResult.serviceOff) LocationService.openLocationSettings();
      return;
    }
    final s = context.read<SettingsController>();
    await s.setPrayer(s.prayer.copyWith(lat: fix.lat, lng: fix.lng));
    if (mounted) await context.read<AppState>().syncPrayerAlerts();
    if (mounted) showSnack(context, 'تم تحديث الموقع');
  }

  Future<void> _toggleAlert(String key, bool v) async {
    final s = context.read<SettingsController>();
    if (v) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted && mounted) {
        showSnack(context, 'اسمح بالإشعارات من إعدادات الهاتف لتصلك التنبيهات');
      }
      final exact = await NotificationService.instance.canExact();
      if (!exact && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تنبيه في الوقت بالضبط'),
            content: const Text(
                'لكي يصلك التنبيه عند دخول الوقت تمامًا، اسمح للتطبيق بـ«المنبّهات والتذكيرات» من الإعدادات. بدون ذلك قد يتأخر التنبيه بضع دقائق.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقًا')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: const Text('فتح الإعدادات')),
            ],
          ),
        );
        if (go == true) await NotificationService.instance.requestExact();
      }
    }
    await s.setPrayer(s.prayer.copyWith(alerts: {...s.prayer.alerts, key: v}));
    if (mounted) await context.read<AppState>().syncPrayerAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final cs = Theme.of(context).colorScheme;
    final c = s.prayer;
    final slots = PrayerService.timesFor(c, _now);
    final next = PrayerService.next(c, _now);
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: [
          IconButton(
            tooltip: 'اتجاه القبلة',
            icon: const Icon(Icons.explore_rounded),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const QiblaScreen())),
          ),
          if (c.hasLocation)
            IconButton(
              tooltip: 'إعدادات المواقيت',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _PrayerSettingsSheet(),
              ),
            ),
        ],
      ),
      body: slots == null
          ? EmptyState(
              icon: Icons.location_searching_rounded,
              text: 'حدّد موقعك لحساب مواقيت الصلاة حسب مدينتك',
              action: FilledButton.icon(
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: const Text('تحديد موقعي'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (next != null)
                  HeroCard(
                    child: Column(
                      children: [
                        Text('الصلاة القادمة',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                        Text(next.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                        Text(timeText(next.time),
                            style: const TextStyle(
                                color: AppColors.goldSoft,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(durationText(next.time.difference(_now)),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                        Text('${hijriDateText(_now)} • ${gregorianDateText(_now)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      for (final slot in slots)
                        _PrayerRow(
                          slot: slot,
                          isNext: next != null &&
                              next.key == slot.key &&
                              next.time.day == slot.time.day,
                          passed: slot.time.isBefore(_now),
                          alert: c.alerts[slot.key] ?? false,
                          onAlert: (v) => _toggleAlert(slot.key, v),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'طريقة الحساب: ${calcMethods[c.method] ?? c.method}${c.hanafi ? ' • العصر: حنفي' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                Text(
                  'الموقع: ${arNum(c.lat!.toStringAsFixed(3))}، ${arNum(c.lng!.toStringAsFixed(3))}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                ),
                TextButton.icon(
                  onPressed: _locating ? null : _locate,
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('تحديث الموقع'),
                ),
              ],
            ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.slot,
    required this.isNext,
    required this.passed,
    required this.alert,
    required this.onAlert,
  });
  final PrayerSlot slot;
  final bool isNext;
  final bool passed;
  final bool alert;
  final ValueChanged<bool> onAlert;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: isNext ? cs.primary.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: Icon(_prayerIcons[slot.key],
            color: isNext ? cs.secondary : cs.primary.withValues(alpha: passed ? 0.5 : 1)),
        title: Text(slot.name,
            style: TextStyle(
                fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                color: passed && !isNext ? cs.onSurface.withValues(alpha: 0.5) : null)),
        subtitle: isNext ? const Text('القادمة') : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(timeText(slot.time),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: passed && !isNext ? cs.onSurface.withValues(alpha: 0.5) : null)),
            IconButton(
              tooltip: alert ? 'إيقاف التنبيه' : 'تفعيل التنبيه',
              onPressed: () => onAlert(!alert),
              icon: Icon(
                alert ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                color: alert ? cs.primary : cs.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerSettingsSheet extends StatelessWidget {
  const _PrayerSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final c = s.prayer;
    Future<void> save(PrayerConfig n) async {
      await s.setPrayer(n);
      if (context.mounted) await context.read<AppState>().syncPrayerAlerts();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('إعدادات المواقيت',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: c.method,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'طريقة الحساب', border: OutlineInputBorder()),
            items: [
              for (final e in calcMethods.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => v == null ? null : save(c.copyWith(method: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('حساب العصر على المذهب الحنفي'),
            subtitle: const Text('الافتراضي: الجمهور (الشافعي والمالكي والحنبلي)'),
            value: c.hanafi,
            onChanged: (v) => save(c.copyWith(hanafi: v)),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('تعديل يدوي بالدقائق',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          for (final key in PrayerConfig.prayers)
            Row(
              children: [
                Expanded(child: Text(prayerNames[key]!)),
                IconButton(
                  onPressed: () => save(c.copyWith(
                      offsets: {...c.offsets, key: (c.offsets[key] ?? 0) - 1})),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                      arNum('${(c.offsets[key] ?? 0) > 0 ? '+' : ''}${c.offsets[key] ?? 0}'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                IconButton(
                  onPressed: () => save(c.copyWith(
                      offsets: {...c.offsets, key: (c.offsets[key] ?? 0) + 1})),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
          TextButton(
            onPressed: () => save(c.copyWith(offsets: {})),
            child: const Text('إعادة الضبط'),
          ),
        ],
      ),
    );
  }
}
