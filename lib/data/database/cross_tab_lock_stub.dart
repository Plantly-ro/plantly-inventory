import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor openAppDatabase({required String name, required DriftWebOptions web}) =>
    driftDatabase(name: name, web: web);
