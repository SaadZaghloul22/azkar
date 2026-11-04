import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/zekr_tile.dart';
import 'reader_screen.dart';

/// The user's own azkar. Always labelled as user-added, separate from verified content.
class CustomAzkarScreen extends StatelessWidget {
  const CustomAzkarScreen({super.key});

  Future<void> _edit(BuildContext context, [Zekr? z]) async {
    final title = TextEditingController(text: z?.title ?? '');
    final content = TextEditingController(text: z?.content ?? '');
    final repeat = TextEditingController(text: '${z?.repeatCount ?? 1}');
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(z == null ? 'إضافة ذكر خاص' : 'تعديل الذكر'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'العنوان'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب عنوانًا' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: content,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: 'نص الذكر أو الدعاء'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب نص الذكر' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: repeat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد مرات التكرار'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n < 1 || n > 10000) ? 'من ١ إلى ١٠٠٠٠' : null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final state = context.read<AppState>();
    final n = int.parse(repeat.text.trim());
    if (z == null) {
      await state.db.addCustomZekr(title.text.trim(), content.text.trim(), n);
    } else {
      await state.db.updateCustomZekr(z.id, title.text.trim(), content.text.trim(), n);
    }
    await state.reloadCustom();
  }

  Future<void> _delete(BuildContext context, Zekr z) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الذكر؟'),
        content: Text('سيُحذف «${z.title}» من أذكارك.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final state = context.read<AppState>();
    await state.db.deleteCustomZekr(z.id);
    await state.reloadCustom();
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<AppState>().customAzkar;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أذكاري'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'قراءة الكل',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReaderScreen.list(title: 'أذكاري', azkar: items, counterKey: 'custom'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة ذكر'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'الأذكار التي تضيفها هنا خاصة بك وتظهر بعلامة «ذكر خاص بك»، وهي منفصلة عن الأذكار الموثّقة.',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.edit_note_rounded,
                    text: 'أضف أدعيتك وأذكارك الخاصة لتقرأها وتظهر في الأذكار التلقائية')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => ZekrTile(
                      zekr: items[i],
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) =>
                            v == 'edit' ? _edit(context, items[i]) : _delete(context, items[i]),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
