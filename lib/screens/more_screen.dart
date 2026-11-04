import 'package:flutter/material.dart';

import '../services/native_bridge.dart';
import '../widgets/common.dart';
import 'about_screen.dart';
import 'auto_azkar_screen.dart';
import 'custom_azkar_screen.dart';
import 'favorites_screen.dart';
import 'qibla_screen.dart';
import 'reminders_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    Widget group(List<Widget> tiles) => Card(
          child: Column(children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const Divider(indent: 56),
              tiles[i],
            ]
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          group([
            ListTile(
              leading: const Icon(Icons.picture_in_picture_alt_rounded),
              title: const Text('الأذكار التلقائية'),
              subtitle: const Text('ذكر يظهر فوق التطبيقات كل فترة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const AutoAzkarScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_rounded),
              title: const Text('التذكيرات'),
              subtitle: const Text('الصباح والمساء والنوم والاستغفار'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const RemindersScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.explore_rounded),
              title: const Text('اتجاه القبلة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const QiblaScreen()),
            ),
          ]),
          const SizedBox(height: 12),
          group([
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('المفضلة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const FavoritesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('أذكاري الخاصة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const CustomAzkarScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.widgets_rounded),
              title: const Text('إضافة ويدجت للشاشة الرئيسية'),
              subtitle: const Text('ذكر اليوم على شاشة هاتفك'),
              onTap: () async {
                final ok = await NativeBridge.requestPinWidget();
                if (!ok && context.mounted) {
                  showSnack(context,
                      'اضغط مطولًا على الشاشة الرئيسية ← الأدوات (Widgets) ← أذكار المسلم');
                }
              },
            ),
          ]),
          const SizedBox(height: 12),
          group([
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('الإعدادات'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const SettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_rounded),
              title: const Text('سياسة الخصوصية'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const PrivacyScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text('عن التطبيق'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => go(const AboutScreen()),
            ),
          ]),
        ],
      ),
    );
  }
}
