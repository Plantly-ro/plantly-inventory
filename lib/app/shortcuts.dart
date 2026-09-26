import 'package:flutter/material.dart';

import '../features/home/add_plant_sheet.dart';
import '../features/search/search_screen.dart';
import 'side_sheet.dart';

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

class NewPlantIntent extends Intent {
  const NewPlantIntent();
}

/// Desktop/tablet keyboard shortcuts: `/` opens search (its field
/// autofocuses), `n` opens Add plant. `Esc` closes side sheets through the
/// modal route's own `DismissIntent` handling, nothing to add here. Both
/// are ignored while a text field has focus so typing "n" still types "n".
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.shellNavigatorKey, required this.child});

  /// Search is pushed on the shell navigator so the side nav stays visible.
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        CharacterActivator('/'): FocusSearchIntent(),
        CharacterActivator('n'): NewPlantIntent(),
      },
      child: Actions(
        actions: {
          FocusSearchIntent: _GuardedAction<FocusSearchIntent>(() {
            shellNavigatorKey.currentState?.push(
              MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
            );
          }),
          NewPlantIntent: _GuardedAction<NewPlantIntent>(() {
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
