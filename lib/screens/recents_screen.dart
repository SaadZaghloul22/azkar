import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/zekr_tile.dart';

class RecentsScreen extends StatelessWidget {
  const RecentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آخر ما قرأت')),
      body: FutureBuilder<List<Zekr>>(
        future: context.read<AppState>().db.recents(limit: 30),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(
                icon: Icons.history_rounded, text: 'ستظهر هنا الأذكار التي قرأتها مؤخرًا');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => ZekrTile(zekr: items[i]),
          );
        },
      ),
    );
  }
}
