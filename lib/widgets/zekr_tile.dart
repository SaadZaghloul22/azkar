import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../data/models.dart';
import '../screens/reader_screen.dart';
import '../state/app_state.dart';

/// Compact list item for a zekr, used in favorites, search and recents.
class ZekrTile extends StatelessWidget {
  const ZekrTile({super.key, required this.zekr, this.trailing, this.highlight});
  final Zekr zekr;
  final Widget? trailing;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = context.read<AppState>().categoryById(zekr.categoryId);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ReaderScreen.single(zekr: zekr))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zekr.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: cs.primary, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Text(zekr.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Amiri', fontSize: 17, height: 1.8)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (cat != null) cat.name,
                        if (zekr.isCustom) 'ذكر خاص بك',
                        timesText(zekr.repeatCount),
                      ].join(' • '),
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
