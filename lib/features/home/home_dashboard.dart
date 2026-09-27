import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart';
import '../../app/side_sheet.dart';
import '../../data/providers.dart';
import '../../data/user_prefs.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import 'bulk_action_bar.dart';
import 'filter.dart';
import 'filter_chips.dart';
import 'home_providers.dart';
import 'home_screen.dart';
import 'selection.dart';
import 'sort.dart';
import 'widget_registry.dart';

/// Desktop home (DESKTOP-POLISH §1). Same [homeLayoutProvider] widgets as
/// the phone [HomeScreen], laid out in a 12-column grid under a toolbar
/// (inline search · filter chips · sort · Customise). Phone chrome (tab
/// bar, FAB, long-press edit, search icon) stays on [HomeScreen].
class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> with FirstRunOnboardingGate {
  /// True while the Customise side sheet is open: widgets show their
  /// move/remove controls, mirroring phone edit mode.
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final layout = ref.watch(homeLayoutProvider);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final bootstrap = ref.watch(appContextProvider);
    maybePushOnboarding(ref.watch(userPrefsProvider));
    final hasSelection = ref.watch(plantSelectionProvider).isNotEmpty;

    return Scaffold(
      backgroundColor: surface.bg,
      bottomNavigationBar: bootstrap.hasValue && hasSelection ? BulkActionBar(surface: surface) : null,
      body: SafeArea(
        child: bootstrap.when(
          loading: () => BootstrapLoading(surface: surface),
          error: (e, _) => BootstrapError(surface: surface, error: e),
          data: (_) {
            final hasPlants = ref.watch(hasPlantsProvider);
            final permDenied = ref.watch(notificationBannerVisibleProvider);
            return Column(
              children: [
                if (permDenied) NotificationPermissionBanner(surface: surface),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: PlantlyTokens.space6, bottom: 96),
                    children: [
                      _Toolbar(surface: surface, onCustomise: _openCustomise),
                      const SizedBox(height: PlantlyTokens.space6),
                      if (!hasPlants)
                        FirstRunCallout(
                          surface: surface,
                          body: t.homeNoPlantsBodyDesktop,
                          padding: const EdgeInsets.only(bottom: PlantlyTokens.space6),
                        ),
                      ..._rows(layout, surface),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Greedy 12-column packing: walk the layout in order, start a new row
  /// when the next span no longer fits. A short final row keeps its
  /// widths (a lone 6-span widget takes half, not the whole line).
  List<Widget> _rows(List<String> layout, PlantlySurface surface) {
    final entries = <(int, WidgetEntry)>[
      for (var i = 0; i < layout.length; i++)
        if (WidgetRegistry.entries[layout[i]] case final e?) (i, e),
    ];
    final rows = <List<(int, WidgetEntry)>>[];
    var used = 0;
    for (final item in entries) {
      final span = item.$2.desktopSpan;
      if (rows.isEmpty || used + span > 12) {
        rows.add([item]);
        used = span;
      } else {
        rows.last.add(item);
        used += span;
      }
    }
    final out = <Widget>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final filled = row.fold(0, (sum, it) => sum + it.$2.desktopSpan);
      out.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < row.length; i++) ...[
            if (i > 0) const SizedBox(width: PlantlyTokens.space4),
            Expanded(
              flex: row[i].$2.desktopSpan,
              child: _renderWidget(row[i].$2, row[i].$1, layout.length, surface),
            ),
          ],
          if (filled < 12) ...[
            const SizedBox(width: PlantlyTokens.space4),
            Spacer(flex: 12 - filled),
          ],
        ],
      ));
      if (r < rows.length - 1) out.add(const SizedBox(height: PlantlyTokens.space6));
    }
    return out;
  }

  Widget _renderWidget(WidgetEntry entry, int index, int total, PlantlySurface surface) {
    return entry.render(
      WidgetRenderParams(
        surface: surface,
        editing: _editing,
        padInner: false,
        onMoveUp: () => ref.read(homeLayoutProvider.notifier).move(index, -1),
        onMoveDown: () => ref.read(homeLayoutProvider.notifier).move(index, 1),
        onRemove: () => ref.read(homeLayoutProvider.notifier).remove(index),
        onPlantTap: (id) => openPlant(context, id),
        onToast: (msg) => showHomeToast(context, msg),
      ),
    );
  }

  Future<void> _openCustomise() async {
    final t = AppLocalizations.of(context);
    final mode = ref.read(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    setState(() => _editing = true);
    await showSideSheet<void>(
      context,
      builder: (_) => SheetChrome(
        surface: surface,
        title: t.homeCustomise,
        children: [
          HomeEditPanel(surface: surface, padding: EdgeInsets.zero, showCurrent: true),
        ],
      ),
    );
    if (mounted) setState(() => _editing = false);
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({required this.surface, required this.onCustomise});
  final PlantlySurface surface;
  final VoidCallback onCustomise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final sort = ref.watch(plantSortProvider);
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // The field yields width to the right-hand group below ~1230 px
          // of content instead of overflowing; it keeps 320 when there is room.
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: DashboardSearchField(surface: surface),
            ),
          ),
          const SizedBox(width: PlantlyTokens.space3),
          SizedBox(height: 32, child: FilterChipsRow(surface: surface)),
          const SizedBox(width: PlantlyTokens.space2),
          _SortDropdown(
            surface: surface,
            value: sort,
            onChanged: (s) => ref.read(plantSortProvider.notifier).set(s),
          ),
          const SizedBox(width: PlantlyTokens.space3),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: surface.text,
                side: BorderSide(color: surface.border),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                // ButtonStyle.textStyle replaces the theme's labelLarge, so
                // the family has to be restated or the label loses Inter.
                textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: onCustomise,
              icon: Icon(Icons.tune, size: 18, color: surface.muted),
              label: Text(t.homeCustomise),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.surface, required this.value, required this.onChanged});
  final PlantlySurface surface;
  final PlantSort value;
  final ValueChanged<PlantSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      borderSide: BorderSide(color: surface.border),
    );
    return SizedBox(
      height: 36,
      // Keyed on the value: `initialSelection` is only read once, and the
      // persisted sort arrives asynchronously after the first build.
      child: DropdownMenu<PlantSort>(
        key: ValueKey(value),
        width: 180,
        initialSelection: value,
        requestFocusOnTap: false,
        onSelected: (s) => s == null ? null : onChanged(s),
        textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text),
        trailingIcon: Icon(Icons.expand_more, size: 18, color: surface.muted),
        selectedTrailingIcon: Icon(Icons.expand_less, size: 18, color: surface.muted),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: surface.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          constraints: const BoxConstraints.tightFor(height: 36),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(borderSide: BorderSide(color: surface.green)),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        dropdownMenuEntries: [
          for (final s in PlantSort.values)
            DropdownMenuEntry(
              value: s,
              label: s.label(context),
              style: MenuItemButton.styleFrom(
                foregroundColor: surface.text,
                textStyle: const TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline plant search (desktop). Writes [plantQueryProvider] after a
/// 150 ms debounce; `Enter` opens the first plant of the current sorted
/// list, `Esc` clears and drops focus. `/` from anywhere on `/` focuses it
/// via [homeSearchFocusProvider].
class DashboardSearchField extends ConsumerStatefulWidget {
  const DashboardSearchField({super.key, required this.surface, this.width = 320});
  final PlantlySurface surface;
  final double width;

  @override
  ConsumerState<DashboardSearchField> createState() => _DashboardSearchFieldState();
}

class _DashboardSearchFieldState extends ConsumerState<DashboardSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(plantQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () => _commit(value));
  }

  void _commit(String value) {
    if (!mounted) return;
    ref.read(plantQueryProvider.notifier).state = value;
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _commit('');
    ref.read(homeSearchFocusProvider).unfocus();
  }

  void _openFirst(String value) {
    _debounce?.cancel();
    _commit(value);
    final first = ref.read(sortedPlantsProvider).maybeWhen(
          data: (rows) => rows.isEmpty ? null : rows.first,
          orElse: () => null,
        );
    if (first != null) openPlant(context, first.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surface;
    return SizedBox(
      width: widget.width,
      height: 36,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
        child: TextField(
          controller: _controller,
          focusNode: ref.watch(homeSearchFocusProvider),
          onChanged: _onChanged,
          onSubmitted: _openFirst,
          textInputAction: TextInputAction.search,
          style: TextStyle(fontFamily: PlantlyFonts.inter, fontSize: 13, color: s.text),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: s.surface,
            hintText: AppLocalizations.of(context).homeSearchHint,
            hintStyle: TextStyle(fontSize: 13, color: s.muted),
            prefixIcon: Icon(Icons.search, size: 18, color: s.muted),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
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
              borderSide: BorderSide(color: s.green),
            ),
          ),
        ),
      ),
    );
  }
}
