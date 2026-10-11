import 'package:flutter/widgets.dart';

/// Owns [TextEditingController]s for a dialog / sheet body and disposes
/// them with the route's widgets — i.e. after the exit animation.
///
/// The pattern `final c = TextEditingController(); await showDialog(…);
/// c.dispose();` disposes the controller the moment the route's future
/// completes, while the closing animation still rebuilds the TextField:
/// "A TextEditingController was used after being disposed" (debug red
/// screen). Creating the controller here ties its lifetime to the dialog.
class TextControllersScope extends StatefulWidget {
  const TextControllersScope({
    super.key,
    required this.initialTexts,
    required this.builder,
    this.selectAllFirst = false,
  });

  /// One controller per entry, seeded with that text (cursor at the end).
  final List<String> initialTexts;

  /// Select the first controller's text initially (rename dialogs).
  final bool selectAllFirst;

  final Widget Function(BuildContext context, List<TextEditingController> controllers) builder;

  @override
  State<TextControllersScope> createState() => _TextControllersScopeState();
}

class _TextControllersScopeState extends State<TextControllersScope> {
  late final List<TextEditingController> _controllers = [
    for (final text in widget.initialTexts)
      TextEditingController(text: text)..selection = TextSelection.collapsed(offset: text.length),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.selectAllFirst && _controllers.isNotEmpty) {
      final c = _controllers.first;
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}
