import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/zekr_tile.dart';
import 'reader_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Zekr>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await context.read<AppState>().db.favorites();
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = _items?.where((z) => state.isFavorite(z.id)).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('المفضلة'),
        actions: [
          if (items != null && items.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderScreen.list(
                      title: 'المفضلة', azkar: items, counterKey: 'favorites'),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('قراءة الكل'),
            ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const EmptyState(
                  icon: Icons.favorite_border_rounded,
                  text: 'لم تُضف أي ذكر للمفضلة بعد.\nاضغط على ♡ أثناء القراءة لإضافته هنا.')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => ZekrTile(
                    zekr: items[i],
                    trailing: IconButton(
                      tooltip: 'حذف من المفضلة',
                      icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                      onPressed: () =>
                          context.read<AppState>().toggleFavorite(items[i].id),
                    ),
                  ),
                ),
    );
  }
}
