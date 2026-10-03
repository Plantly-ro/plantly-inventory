import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../cloud/collections.dart';
import '../features/home/add_plant_sheet.dart';
import '../features/home/home_providers.dart';
import '../features/search/search_screen.dart';
import 'breakpoints.dart';
import 'navigation.dart';
import 'side_sheet.dart';

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class NewPlantIntent extends Intent {
  const NewPlantIntent();
}

/// Desktop/tablet keyboard shortcuts: `/` focuses the dashboard's inline
/// search on desktop `/`, elsewhere opens the search screen (its field
/// autofocuses); `n` opens Add plant. `Esc` closes side sheets through the
/// modal route's own `DismissIntent` handling, nothing to add here. Both
/// are ignored while a text field has focus so typing "n" still types "n".
class AppShortcuts extends ConsumerWidget {
  const AppShortcuts({super.key, required this.shellNavigatorKey, required this.child});

  /// Search is pushed on the shell navigator so the side nav stays visible.
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Shortcuts(
      shortcuts: const {
        CharacterActivator('/'): FocusSearchIntent(),
        CharacterActivator('n'): NewPlantIntent(),
      },
      child: Actions(
        actions: {
          FocusSearchIntent: _GuardedAction<FocusSearchIntent>(() {
            if (context.isDesktop && _currentPath(context) == AppRoutes.home) {
              ref.read(homeSearchFocusProvider).requestFocus();
              return;
            }
            shellNavigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            );
          }),
          NewPlantIntent: _GuardedAction<NewPlantIntent>(() {
            // Read-only collection: the add action is hidden, so the key is a no-op.
            if (!ref.read(canEditActiveCollectionProvider)) return;
            showAdaptiveSheet<void>(
              context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddPlantSheet(),
            );
          }),
        },
        // Something must own focus for key events to reach [Shortcuts];
        // without this the first keypress after load goes nowhere.
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      ),
    );
  }
}

String? _currentPath(BuildContext context) =>
    GoRouter.maybeOf(context)?.routerDelegate.currentConfiguration.uri.path;

class _GuardedAction<T extends Intent> extends Action<T> {
  _GuardedAction(this.callback);
  final VoidCallback callback;

  @override
  bool isEnabled(T intent) => !isTypingInTextField();

  @override
  Object? invoke(T intent) {
    callback();
    return null;
  }
}

/// True when the primary focus sits inside an [EditableText] — the key
/// should then be left to the field (returning "not handled" also keeps
/// the browser from `preventDefault`-ing the character on web).
bool isTypingInTextField() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
}
