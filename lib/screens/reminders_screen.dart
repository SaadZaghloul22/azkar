import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  static const _icons = {
    'morning': Icons.wb_sunny_rounded,
    'evening': Icons.nights_stay_rounded,
    'sleep': Icons.bedtime_rounded,
    'random': Icons.shuffle_rounded,
    'istighfar': Icons.favorite_rounded,
    'wird': Icons.task_alt_rounded,
  };

  Future<void> _update(BuildContext context, ReminderConfig r) async {
    if (r.enabled) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok && context.mounted) {
        showSnack(context, 'اسمح بالإشعارات من إعدادات الهاتف لتصلك التذكيرات');
      }
    }
    if (!context.mounted) return;
    await context.read<SettingsController>().setReminder(r);
    if (context.mounted) await context.read<AppState>().syncReminders();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final cs = Theme.of(context).colorScheme;
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
                    onChanged: (r) => _update(context, r),
                  ),
                ],
              ],
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
