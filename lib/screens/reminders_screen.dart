import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/device_tips.dart';
import '../services/native_bridge.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with WidgetsBindingObserver {
  static const _icons = {
    'morning': Icons.wb_sunny_rounded,
    'evening': Icons.nights_stay_rounded,
    'sleep': Icons.bedtime_rounded,
    'random': Icons.shuffle_rounded,
    'istighfar': Icons.favorite_rounded,
    'wird': Icons.task_alt_rounded,
  };

  bool _exact = true;
  String _maker = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // Back from system settings: re-check and reschedule with the new permissions.
    if (s == AppLifecycleState.resumed) {
      _refresh();
      context.read<AppState>().syncReminders();
    }
  }

  Future<void> _refresh() async {
    final exact = await NotificationService.instance.canExact();
    final st = await NativeBridge.overlayStatus();
    if (mounted) {
      setState(() {
        _exact = exact;
        _maker = st['manufacturer'] as String? ?? '';
      });
    }
  }

  Future<void> _update(ReminderConfig r) async {
    if (r.enabled) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok && mounted) {
        showSnack(context, 'اسمح بالإشعارات من إعدادات الهاتف لتصلك التذكيرات');
      }
    }
    if (!mounted) return;
    await context.read<SettingsController>().setReminder(r);
    if (mounted) await context.read<AppState>().syncReminders();
  }

  Future<void> _test() async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.scheduleTest(const Duration(minutes: 1));
    if (mounted) {
      showSnack(context, 'سيصلك تذكير تجريبي بعد دقيقة. أغلق التطبيق الآن وانتظره.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final cs = Theme.of(context).colorScheme;
    final tip = deviceTip(_maker);
    return Scaffold(
      appBar: AppBar(title: const Text('التذكيرات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('اختر التذكيرات التي تريدها ووقت كل منها. تعمل دون إنترنت.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < s.reminders.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  _ReminderTile(
                    r: s.reminders[i],
                    icon: _icons[s.reminders[i].key]!,
                    onChanged: _update,
                  ),
                ],
              ],
            ),
          ),
          const SectionTitle('حتى تصلك التذكيرات في وقتها'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_exact ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: _exact ? cs.primary : Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            _exact
                                ? 'إذن «المنبّهات والتذكيرات» مفعّل'
                                : 'إذن «المنبّهات والتذكيرات» غير مفعّل — قد تتأخر التذكيرات أو لا تصل',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  if (!_exact)
                    TextButton.icon(
                      onPressed: NotificationService.instance.requestExact,
                      icon: const Icon(Icons.alarm_on_rounded, size: 18),
                      label: const Text('تفعيل الإذن'),
                    ),
                  if (tip != null) ...[
                    const SizedBox(height: 8),
                    Text(tip, style: const TextStyle(fontSize: 13, height: 1.7)),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: NativeBridge.openAutostartSettings,
                          icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                          label: const Text('التشغيل التلقائي'),
                        ),
                        TextButton.icon(
                          onPressed: NativeBridge.openBatterySettings,
                          icon: const Icon(Icons.battery_charging_full_rounded, size: 18),
                          label: const Text('البطارية'),
                        ),
                      ],
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.science_rounded),
                    title: const Text('تجربة التذكير'),
                    subtitle: const Text('يصلك تذكير بعد دقيقة، أغلق التطبيق وانتظره'),
                    trailing: FilledButton.tonal(onPressed: _test, child: const Text('جرّب')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.r, required this.icon, required this.onChanged});
  final ReminderConfig r;
  final IconData icon;
  final ValueChanged<ReminderConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TimeOfDay(hour: r.hour, minute: r.minute);
    final label = arNum(
        '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'ص' : 'م'}');
    return ListTile(
      leading: Icon(icon),
      title: Text(r.label),
      subtitle: InkWell(
        onTap: () async {
          final picked = await showTimePicker(context: context, initialTime: t);
          if (picked != null) {
            onChanged(r.copyWith(hour: picked.hour, minute: picked.minute, enabled: true));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 4),
              const Text('(اضغط للتعديل)', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
      trailing: Switch(
        value: r.enabled,
        onChanged: (v) => onChanged(r.copyWith(enabled: v)),
      ),
    );
  }
}
