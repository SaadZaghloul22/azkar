import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'auto_azkar_screen.dart';
import 'reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final cs = Theme.of(context).colorScheme;
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SectionTitle('المظهر'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('فاتح')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('داكن')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('تلقائي')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
            ),
          ),
          const SectionTitle('خط الأذكار'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Amiri', label: Text('أميري (نسخ)')),
                      ButtonSegment(value: 'Cairo', label: Text('القاهرة')),
                    ],
                    selected: {s.azkarFont},
                    onSelectionChanged: (v) => s.setAzkarFont(v.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('الحجم'),
                      Expanded(
                        child: Slider(
                          value: s.fontSize,
                          min: 18,
                          max: 38,
                          divisions: 10,
                          label: arNum(s.fontSize.round()),
                          onChanged: s.setFontSize,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، سُبْحَانَ اللَّهِ الْعَظِيمِ',
                        textAlign: TextAlign.center, style: azkarTextStyle(context)),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('القراءة والمسبحة'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('الانتقال التلقائي للذكر التالي'),
                  subtitle: const Text('عند إكمال عدد التكرار'),
                  value: s.autoAdvance,
                  onChanged: s.setAutoAdvance,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('إظهار فضل الذكر'),
                  value: s.showVirtue,
                  onChanged: s.setShowVirtue,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('الاهتزاز'),
                  value: s.vibration,
                  onChanged: s.setVibration,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('صوت النقر'),
                  subtitle: const Text('يعتمد على تفعيل أصوات اللمس في الهاتف'),
                  value: s.sound,
                  onChanged: s.setSound,
                ),
              ],
            ),
          ),
          const SectionTitle('التنبيهات'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: const Text('التذكيرات'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => go(const RemindersScreen()),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.picture_in_picture_alt_rounded),
                  title: const Text('الأذكار التلقائية'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => go(const AutoAzkarScreen()),
                ),
              ],
            ),
          ),
          const SectionTitle('عام'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.language_rounded),
                  title: Text('اللغة'),
                  subtitle: Text('العربية — لغات أخرى في التحديثات القادمة'),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text('سياسة الخصوصية'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => go(const PrivacyScreen()),
                ),
                const Divider(indent: 56),
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title: const Text('عن التطبيق'),
                  subtitle: Text('الإصدار ${arNum(appVersion)}'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => go(const AboutScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
