import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wall clock used by date-sensitive screens (calendar "today" highlight,
/// week anchor). Production reads the real clock; golden tests override it
/// so the rendered dates don't drift day to day.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
