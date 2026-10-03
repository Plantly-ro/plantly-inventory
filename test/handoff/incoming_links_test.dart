import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';

void main() {
  const d = 'eyJzY2hlbWFWZXJzaW9uIjoxfQ';

  group('extractImportParam — the three §4a link forms', () {
    test('1. custom scheme plantlyinventory://import#d=', () {
      expect(extractImportParam(Uri.parse('plantlyinventory://import#d=$d')), d);
    });

    test('2. universal page https://plantly.ro/app/inventory/import#d=', () {
      expect(extractImportParam(Uri.parse('https://plantly.ro/app/inventory/import#d=$d')), d);
      expect(extractImportParam(Uri.parse('https://plantly.ro/ro/app/inventory/import#d=$d')), d);
      expect(extractImportParam(Uri.parse('https://development.agent-khepri.urundead.win/app/inventory/import#d=$d')), d);
    });

    test('3. inventory web hash route /#/import?d=', () {
      expect(extractImportParam(Uri.parse('http://127.0.0.1:8099/#/import?d=$d')), d);
      expect(extractImportParam(Uri.parse('https://inventory.plantly.ro/#/import?d=$d&x=1')), d);
      expect(extractImportParamFromHash('#/import?d=$d'), d);
      expect(extractImportParamFromHash('/import?d=$d'), d);
    });

    test('4. canonical path route /import?d= (path-URL web build)', () {
      expect(extractImportParam(Uri.parse('https://inventory.plantly.ro/import?d=$d')), d);
      expect(extractImportParam(Uri.parse('http://127.0.0.1:8099/import?d=$d&x=1')), d);
      expect(extractImportParam(Uri.parse('https://host/inventory/import/?d=$d')), d);
      expect(extractImportParam(Uri.parse('https://inventory.plantly.ro/import')), isNull);
      expect(isImportPath('/import'), isTrue);
      expect(isImportPath('/import/'), isTrue);
      expect(isImportPath('/plants/import-notes'), isFalse);
      expect(isImportPath('/'), isFalse);
    });

    test('non-import links → null', () {
      expect(extractImportParam(Uri.parse('https://plantly.ro/posts/abc')), isNull);
      expect(extractImportParam(Uri.parse('http://127.0.0.1:8099/#/plants/1')), isNull);
      expect(extractImportParam(Uri.parse('plantlyinventory://other#d=$d')), isNull);
      expect(extractImportParam(Uri.parse('plantlyinventory://import')), isNull);
      expect(extractImportParam(Uri.parse('https://plantly.ro/app/inventory/import')), isNull);
      expect(extractImportParamFromHash(''), isNull);
    });

    test('query-string form is tolerated as a fallback', () {
      expect(extractImportParam(Uri.parse('plantlyinventory://import?d=$d')), d);
    });
  });
}
