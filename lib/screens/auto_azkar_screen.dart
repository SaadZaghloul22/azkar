import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/device_tips.dart';
import '../services/native_bridge.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

/// Settings for the floating azkar shown over other apps (Android overlay).
class AutoAzkarScreen extends StatefulWidget {
  const AutoAzkarScreen({super.key});
  @override
  State<AutoAzkarScreen> createState() => _AutoAzkarScreenState();
}

class _AutoAzkarScreenState extends State<AutoAzkarScreen> with WidgetsBindingObserver {
  bool _canOverlay = false;
  Map<String, Object?> _status = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final v = await NativeBridge.canDrawOverlays();
    final st = await NativeBridge.overlayStatus();
    if (mounted) {
      setState(() {
        _canOverlay = v;
        _status = st;
      });
    }
  }

  String? _brandTip() => deviceTip(_status['manufacturer'] as String? ?? '');

  Future<void> _save(OverlayConfig c) async {
    await context.read<SettingsController>().setOverlay(c);
    if (mounted) await context.read<AppState>().syncOverlay();
  }

  Future<void> _toggle(bool on) async {
    final s = context.read<SettingsController>();
    if (on) {
      await NotificationService.instance.requestPermission();
      if (!_canOverlay && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.picture_in_picture_alt_rounded),
            title: const Text('إذن الظهور فوق التطبيقات'),
            content: const Text(
                'لعرض الذكر فوق التطبيقات الأخرى، فعّل إذن «الظهور فوق التطبيقات» لتطبيق أذكار المسلم في الصفحة التالية ثم ارجع.\n\nإن لم تمنح الإذن، ستصلك الأذكار كإشعارات بدلًا من ذلك.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('استخدام الإشعارات')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: const Text('منح الإذن')),
            ],
          ),
        );
        if (go == true) await NativeBridge.openOverlaySettings();
      }
    }
    await _save(s.overlay.copyWith(enabled: on));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final state = context.watch<AppState>();
    final o = s.overlay;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار التلقائية')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          HeroCard(
            child: Row(
              children: [
                const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ذكر يظهر تلقائيًا',
                          style: TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('نافذة صغيرة فوق التطبيقات تذكّرك بالله كل فترة',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                Switch(
                  value: o.enabled,
                  onChanged: _toggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: cs.secondary,
                ),
              ],
            ),
          ),
          if (o.enabled && !_canOverlay)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: Colors.orange.withValues(alpha: 0.12),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: const Text('تعمل الآن كإشعارات'),
                  subtitle: const Text('امنح إذن الظهور فوق التطبيقات لعرض النافذة العائمة'),
                  trailing: TextButton(
                      onPressed: NativeBridge.openOverlaySettings, child: const Text('منح')),
                ),
              ),
            ),
          if (o.enabled && _brandTip() != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: cs.secondary.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phone_android_rounded),
                          SizedBox(width: 8),
                          Text('مهم لهاتفك حتى لا تتوقف الأذكار',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_brandTip()!, style: const TextStyle(fontSize: 13, height: 1.7)),
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
                  ),
                ),
              ),
            ),
          if ((_status['status'] as String?)?.startsWith('error') ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                color: Colors.red.withValues(alpha: 0.08),
                child: ListTile(
                  leading: const Icon(Icons.error_outline_rounded, color: Colors.red),
                  title: const Text('تعذّر عرض النافذة العائمة آخر مرة'),
                  subtitle: Text(
                      'أُرسل الذكر كإشعار بدلًا منها.\nالسبب: ${(_status['status'] as String).substring(6)}'),
                ),
              ),
            ),
          const SectionTitle('كل كم دقيقة؟'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in [5, 10, 15, 30, 60])
                ChoiceChip(
                  label: Text(m == 60 ? 'كل ساعة' : '${arNum(m)} دقائق'),
                  selected: o.intervalMinutes == m,
                  onSelected: (_) => _save(o.copyWith(intervalMinutes: m)),
                ),
            ],
          ),
          const SectionTitle('ساعات التشغيل'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _HourRow(
                      label: 'من الساعة',
                      value: o.startHour,
                      onChanged: (v) => _save(o.copyWith(startHour: v))),
                  _HourRow(
                      label: 'إلى الساعة',
                      value: o.endHour,
                      onChanged: (v) => _save(o.copyWith(endHour: v))),
                  Text('لن يظهر أي ذكر خارج هذه الساعات، ولا أثناء المكالمات، ولا في وضع عدم الإزعاج.',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ),
          const SectionTitle('طريقة العرض'),
          Card(
            child: Column(
              children: [
                RadioGroup<bool>(
                  groupValue: o.random,
                  onChanged: (v) => _save(o.copyWith(random: v ?? true)),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(value: true, title: Text('ذكر عشوائي')),
                      RadioListTile<bool>(value: false, title: Text('بالتسلسل')),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('مدة ظهور الذكر'),
                  trailing: DropdownButton<int>(
                    value: o.displaySeconds,
                    underline: const SizedBox(),
                    items: [
                      for (final sec in [5, 8, 10, 15, 20, 30])
                        DropdownMenuItem(value: sec, child: Text('${arNum(sec)} ثانية')),
                    ],
                    onChanged: (v) => v == null ? null : _save(o.copyWith(displaySeconds: v)),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('الأذكار التي تظهر'),
          Card(
            child: Column(
              children: [
                for (final c in state.categories)
                  CheckboxListTile(
                    title: Text(c.name),
                    value: o.categories.contains(c.key),
                    onChanged: (v) {
                      final list = [...o.categories];
                      v == true ? list.add(c.key) : list.remove(c.key);
                      if (list.isEmpty && !o.includeCustom) {
                        showSnack(context, 'اختر قسمًا واحدًا على الأقل');
                        return;
                      }
                      _save(o.copyWith(categories: list));
                    },
                  ),
                CheckboxListTile(
                  title: const Text('أذكاري الخاصة'),
                  subtitle: Text('${arNum(state.customAzkar.length)} ذكر'),
                  value: o.includeCustom,
                  onChanged: (v) => _save(o.copyWith(includeCustom: v ?? false)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await NativeBridge.previewOverlay(
                  o, state.customAzkar.map((e) => e.content).toList());
              if (!_canOverlay && context.mounted) {
                showSnack(context, 'أُرسل كإشعار لأن إذن الظهور فوق التطبيقات غير ممنوح');
              }
            },
            icon: const Icon(Icons.visibility_rounded),
            label: const Text('معاينة الآن'),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.battery_saver_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('لماذا يتوقف أحيانًا؟',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'يشترط أندرويد إشعارًا ثابتًا لأي خدمة تعمل في الخلفية، وهو صامت. يمكنك إخفاؤه بالضغط عليه مطولًا ← إيقاف «تشغيل الأذكار التلقائية» دون أن تتوقف الأذكار.\n\nبعض الشركات (ريلمي، أوبو، شاومي، فيفو، هواوي) تغلق التطبيقات في الخلفية. التطبيق يعيد تشغيل الأذكار تلقائيًا، لكن لأفضل نتيجة فعّل التشغيل التلقائي واجعل البطارية «غير مقيّدة».',
                  style: TextStyle(fontSize: 13, height: 1.7),
                ),
                TextButton(
                  onPressed: NativeBridge.openBatterySettings,
                  child: const Text('فتح إعدادات البطارية'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  String _fmt(int h) {
    final hh = h % 12 == 0 ? 12 : h % 12;
    return arNum('$hh ${h < 12 ? 'ص' : 'م'}');
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<int>(
          value: value,
          underline: const SizedBox(),
          items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(_fmt(h)))],
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ],
    );
  }
}
