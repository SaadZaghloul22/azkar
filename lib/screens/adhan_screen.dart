import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/native_bridge.dart';
import '../services/notifications.dart';
import '../services/prayer_service.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';

/// Choose the adhan voice (and a separate one for Fajr), listen to each one,
/// and pick per prayer whether to play the full adhan or a short notification.
class AdhanScreen extends StatefulWidget {
  const AdhanScreen({super.key});
  @override
  State<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends State<AdhanScreen> {
  String? _playing;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    NativeBridge.stopAdhan();
    super.dispose();
  }

  Future<void> _togglePreview(String voice) async {
    _poll?.cancel();
    if (_playing == voice) {
      await NativeBridge.stopAdhan();
      if (mounted) setState(() => _playing = null);
      return;
    }
    final ok = await NativeBridge.playAdhan(voice);
    if (!mounted) return;
    if (!ok) {
      showSnack(context, 'تعذّر تشغيل الصوت');
      return;
    }
    setState(() => _playing = voice);
    // Clear the "playing" state when the recording ends by itself.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!await NativeBridge.isAdhanPlaying() && mounted) {
        _poll?.cancel();
        setState(() => _playing = null);
      }
    });
  }

  Future<void> _save(PrayerConfig c) async {
    final s = context.read<SettingsController>();
    final state = context.read<AppState>();
    await s.setPrayer(c);
    await state.syncPrayerAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SettingsController>().prayer;
    final cs = Theme.of(context).colorScheme;

    Widget voiceTile(String key, AdhanVoice v, String selected, ValueChanged<String> onPick) {
      final isSel = key == selected;
      final isPlaying = _playing == key;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isSel ? cs.primary : cs.outlineVariant, width: isSel ? 2 : 1),
        ),
        child: ListTile(
          onTap: () => onPick(key),
          leading: Icon(isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSel ? cs.primary : cs.outline),
          title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(v.hint),
          trailing: IconButton.filledTonal(
            tooltip: isPlaying ? 'إيقاف' : 'استماع',
            onPressed: () => _togglePreview(key),
            icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الأذان')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (!c.hasLocation)
            Card(
              color: cs.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('حدّد موقعك من شاشة المواقيت أولًا حتى يُرفع الأذان في أوقات الصلاة.'),
              ),
            ),
          const SectionTitle('صوت الأذان'),
          for (final e in adhanVoices.entries)
            voiceTile(e.key, e.value, c.muezzin, (k) => _save(c.copyWith(muezzin: k))),
          const SizedBox(height: 12),
          const SectionTitle('صوت أذان الفجر'),
          for (final e in adhanVoices.entries)
            voiceTile(e.key, e.value, c.fajrMuezzin, (k) => _save(c.copyWith(fajrMuezzin: k))),
          const SizedBox(height: 12),
          const SectionTitle('طريقة التنبيه لكل صلاة'),
          Card(
            child: Column(
              children: [
                for (final key in const ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
                  _PrayerModeRow(
                    name: prayerNames[key]!,
                    enabled: c.alerts[key] ?? false,
                    adhan: c.adhanFor(key),
                    onChanged: (mode) => _save(c.copyWith(
                      alerts: {...c.alerts, key: mode != 'off'},
                      adhan: mode == 'off' ? c.adhan : {...c.adhan, key: mode == 'adhan'},
                    )),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await NativeBridge.stopAdhan();
              if (mounted) setState(() => _playing = null);
              await NotificationService.instance.requestPermission();
              await NotificationService.instance.testAdhan(c.muezzin);
              if (context.mounted) {
                showSnack(context, 'تم إرسال أذان تجريبي، اسحب الإشعار لإيقافه');
              }
            },
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('تجربة الأذان كإشعار'),
          ),
          const SizedBox(height: 8),
          Text(
            'يُرفع الأذان من خلال إشعار بصوت المنبّه، ويمكنك إيقافه في أي وقت بزر «إيقاف الأذان» أو بسحب الإشعار. '
            'إذا لم تسمع الأذان فتأكد أن صوت المنبّه في هاتفك غير صامت.',
            style: TextStyle(fontSize: 12.5, color: cs.onSurface.withValues(alpha: 0.65), height: 1.6),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('مصادر الأصوات',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
            children: [
              for (final line in adhanCredits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(line,
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65), height: 1.5)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerModeRow extends StatelessWidget {
  const _PrayerModeRow({
    required this.name,
    required this.enabled,
    required this.adhan,
    required this.onChanged,
  });
  final String name;
  final bool enabled;
  final bool adhan;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final mode = !enabled ? 'off' : (adhan ? 'adhan' : 'notify');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          SegmentedButton<String>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 'adhan', label: Text('أذان')),
              ButtonSegment(value: 'notify', label: Text('إشعار')),
              ButtonSegment(value: 'off', label: Text('إيقاف')),
            ],
            selected: {mode},
            onSelectionChanged: (sel) => onChanged(sel.first),
          ),
        ],
      ),
    );
  }
}
