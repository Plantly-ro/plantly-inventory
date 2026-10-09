import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/navigation.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlantRow> _results = const [];
  bool _loading = false;
  String? _lastQuery;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () => _runSearch(value));
  }

  /// [quiet]: a refresh of the current query (data changed) — keep the
  /// list on screen instead of flashing the spinner.
  Future<void> _runSearch(String query, {bool quiet = false}) async {
    final repo = ref.read(searchRepositoryProvider);
    setState(() {
      if (!quiet) _loading = true;
      _lastQuery = query;
    });
    try {
      final rows = await repo.search(query);
      if (!mounted || _lastQuery != query) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    // The query is one-shot: re-run it whenever the plants change (a plant
    // opened from here and deleted / renamed must not linger in the list).
    ref.listen(plantsStreamProvider, (_, next) {
      final q = _lastQuery;
      if (next.hasValue && q != null && q.trim().isNotEmpty) _runSearch(q, quiet: true);
    });

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 16, color: surface.text),
          decoration: InputDecoration(
            hintText: t.search,
            hintStyle: TextStyle(color: surface.muted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: surface.muted),
              onPressed: () {
                _controller.clear();
                _runSearch('');
              },
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: surface.green))
          : _results.isEmpty
              ? _Empty(query: _controller.text, surface: surface)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final row = _results[i];
                    final mock = MockPlants.byId(row.id);
                    return _ResultRow(
                      plantId: row.id,
                      plant: mock,
                      label: row.nickname,
                      notes: row.notes,
                      surface: surface,
                      onTap: () => openPlant(context, row.id),
                    );
                  },
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query, required this.surface});
  final String query;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          query.trim().isEmpty ? t.searchEmptyStart : t.searchNoMatch(query),
          textAlign: TextAlign.center,
          style: TextStyle(color: surface.muted, fontSize: 14),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.plantId,
    required this.plant,
    required this.label,
    required this.notes,
    required this.surface,
    required this.onTap,
  });

  final String plantId;
  final MockPlant plant;
  final String label;
  final String? notes;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          child: Row(
            children: [
              PlantPhotoThumb(
                plantId: plantId,
                fallback: plant,
                size: 44,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                    ),
                    if (notes != null && notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notes!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: surface.muted),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}
