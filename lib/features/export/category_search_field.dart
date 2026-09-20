import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../theme/tokens.dart';

/// Marketplace category picker (CONTRACT §5): a search box backed by
/// `GET /categories/search`, debounced 300 ms, listing the localized `path`
/// of each hit. Emits the chosen [CategoryHit]; the draft stores its UUID.
class CategorySearchField extends StatefulWidget {
  const CategorySearchField({
    super.key,
    required this.search,
    required this.lang,
    required this.surface,
    required this.selected,
    required this.onSelected,
    this.debounce = const Duration(milliseconds: 300),
  });

  /// `(q, lang) → hits` — the API call, injectable for tests.
  final Future<List<CategoryHit>> Function(String q, String lang) search;
  final String lang;
  final PlantlySurface surface;

  /// Currently chosen category label (the path), or null.
  final String? selected;
  final ValueChanged<CategoryHit?> onSelected;
  final Duration debounce;

  @override
  State<CategorySearchField> createState() => _CategorySearchFieldState();
}

class _CategorySearchFieldState extends State<CategorySearchField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  int _requestSeq = 0;
  List<CategoryHit> _hits = const [];
  bool _loading = false;
  bool _failed = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _loading = false;
        _searched = false;
      });
      return;
    }
    _debounce = Timer(widget.debounce, () => _run(q));
  }

  Future<void> _run(String q) async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final hits = await widget.search(q, widget.lang);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hits = hits;
        _loading = false;
        _searched = true;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _hits = const [];
        _loading = false;
        _failed = true;
        _searched = true;
      });
    }
  }

  void _pick(CategoryHit hit) {
    _debounce?.cancel();
    _requestSeq++;
    _controller.clear();
    _focus.unfocus();
    setState(() {
      _hits = const [];
      _searched = false;
    });
    widget.onSelected(hit);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surface;
    final t = AppLocalizations.of(context);
    final selected = widget.selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected != null)
          Container(
            key: const Key('category-selected'),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: s.surfaceAlt,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              border: Border.all(color: s.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: s.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(selected, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: s.text)),
                ),
                InkWell(
                  onTap: () => widget.onSelected(null),
                  child: Icon(Icons.close, size: 14, color: s.muted),
                ),
              ],
            ),
          ),
        TextField(
          key: const Key('category-search'),
          controller: _controller,
          focusNode: _focus,
          onChanged: _onChanged,
          style: TextStyle(fontSize: 13, color: s.text),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: s.surface,
            hintText: selected == null ? t.exportCategorySearchHint : t.exportCategoryChangeHint,
            hintStyle: TextStyle(fontSize: 13, color: s.muted),
            prefixIcon: Icon(Icons.search, size: 16, color: s.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            suffixIcon: _loading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: s.green)),
                  )
                : null,
            contentPadding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              borderSide: BorderSide(color: s.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              borderSide: BorderSide(color: s.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              borderSide: BorderSide(color: s.green, width: 1.5),
            ),
          ),
        ),
        if (_hits.isNotEmpty)
          Container(
            key: const Key('category-results'),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: s.surface,
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              border: Border.all(color: s.border),
            ),
            child: Column(
              children: [
                for (final hit in _hits)
                  InkWell(
                    key: Key('category-hit-${hit.id}'),
                    onTap: () => _pick(hit),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(hit.path, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: s.text)),
                          ),
                          Icon(Icons.north_west, size: 12, color: s.muted),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          )
        else if (_searched && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _failed ? t.exportCategorySearchFailed : t.exportCategoryNoResults,
              style: TextStyle(fontSize: 11.5, color: _failed ? s.terra : s.muted),
            ),
          ),
      ],
    );
  }
}
