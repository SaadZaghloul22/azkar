import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import '../widgets/common.dart';
import 'custom_azkar_screen.dart';
import 'favorites_screen.dart';
import 'reader_screen.dart';
import 'recents_screen.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final cs = Theme.of(context).colorScheme;
    final counters = settings.countersFor(dayKey(DateTime.now()));
    return Scaffold(
      appBar: AppBar(title: const Text('الأذكار')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('ابحث في الأذكار والأدعية',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  icon: Icons.favorite_rounded,
                  label: 'المفضلة',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FavoritesScreen())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  icon: Icons.history_rounded,
                  label: 'آخر ما قرأت',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RecentsScreen())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  icon: Icons.edit_note_rounded,
                  label: 'أذكاري',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CustomAzkarScreen())),
                ),
              ),
            ],
          ),
          const SectionTitle('الأقسام'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (_, i) {
              final c = state.categories[i];
              final saved = counters[c.key];
              final started = saved != null && saved.any((e) => e > 0);
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ReaderScreen(category: c))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(categoryIcon(c.icon), color: cs.primary),
                            ),
                            const Spacer(),
                            if (started)
                              Icon(Icons.timelapse_rounded, size: 18, color: cs.secondary),
                          ],
                        ),
                        const Spacer(),
                        Text(c.name,
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800)),
                        Text('${arNum(c.count)} ذكر',
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: cs.primary, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
