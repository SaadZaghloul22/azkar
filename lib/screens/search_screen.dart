import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/zekr_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  int? _category;
  List<Zekr> _results = [];
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _run);
  }

  Future<void> _run() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty && _category == null) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final r = await context.read<AppState>().db.search(q, categoryId: _category);
    if (mounted) {
      setState(() {
        _results = r;
        _searched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<AppState>().categories;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'اكتب كلمة من الذكر…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _ctrl.clear();
                _run();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: const Text('الكل'),
                    selected: _category == null,
                    onSelected: (_) {
                      setState(() => _category = null);
                      _run();
                    },
                  ),
                ),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.name),
                      selected: _category == c.id,
                      onSelected: (_) {
                        setState(() => _category = c.id);
                        _run();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: !_searched
                ? const EmptyState(
                    icon: Icons.search_rounded,
                    text: 'ابحث بكلمة من الذكر أو اختر قسمًا.\nالبحث يتجاهل التشكيل.')
                : _results.isEmpty
                    ? const EmptyState(icon: Icons.search_off_rounded, text: 'لا توجد نتائج')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => ZekrTile(zekr: _results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}
