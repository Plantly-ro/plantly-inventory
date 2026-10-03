import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/features/collections/collection_switcher.dart';
import 'package:plantly_inventory/features/collections/sharing_rows.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

/// MULTI-USER-V2 UI: members sheet v2 (badges, owner menu, role change,
/// transfer), invites list + revoke, invite create form, switcher
/// rename / delete / owner subtitle / paused marker. Request bodies are
/// captured through a MockClient like the §3 tests.
const _mine = CloudCollection(id: 'col-1', name: 'My plants', role: 'owner', ownerUserId: 'u-1', memberCount: 3);
const _second = CloudCollection(id: 'col-3', name: 'Balcony', role: 'owner', ownerUserId: 'u-1', memberCount: 1);
const _shared = CloudCollection(
  id: 'col-2',
  name: 'Family greenhouse',
  role: 'editor',
  ownerUserId: 'u-2',
  ownerUsername: 'bob',
  memberCount: 3,
);
const _viewed = CloudCollection(
  id: 'col-4',
  name: 'Office jungle',
  role: 'viewer',
  ownerUserId: 'u-3',
  ownerUsername: 'carol',
  ownerEntitled: false,
  memberCount: 2,
);

const _ready = CloudState(phase: CloudPhase.ready, account: 'alice', collectionId: 'col-1', collectionName: 'My plants');

Map<String, dynamic> _member(String id, String name, String role) =>
    {'user_id': id, 'username': name, 'role': role, 'joined_at': '2026-09-01T10:00:00Z'};

/// Members as seen from [active]: alice (u-1) is always present.
List<Map<String, dynamic>> _membersFor(CloudCollection active) => switch (active.id) {
      'col-1' => [_member('u-1', 'alice', 'owner'), _member('u-2', 'bob', 'editor'), _member('u-3', 'carol', 'viewer')],
      'col-2' => [_member('u-2', 'bob', 'owner'), _member('u-1', 'alice', 'editor')],
      _ => [_member('u-3', 'carol', 'owner'), _member('u-1', 'alice', 'viewer'), _member('u-2', 'bob', 'editor')],
    };

final _invites = [
  {
    'id': 'inv-1',
    'role': 'editor',
    'label': 'Grandma',
    'max_uses': 1,
    'use_count': 0,
    'expires_at': DateTime.now().toUtc().add(const Duration(days: 6, hours: 2)).toIso8601String(),
    'created_at': '2026-10-01T10:00:00Z',
    'created_by_username': 'alice',
  },
  {
    'id': 'inv-2',
    'role': 'viewer',
    'max_uses': 10,
    'use_count': 3,
    'expires_at': DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String(),
    'created_at': '2026-10-02T10:00:00Z',
    'created_by_username': 'alice',
  },
];

void main() {
  final token = fakeJwt(iat: 1, exp: 4102444800);

  /// Routes every §3 call; [override] answers first when it returns non-null.
  List<Override> overrides(
    List<CloudCollection> items,
    CloudCollection active,
    List<http.Request> log, {
    http.Response? Function(http.Request req)? override,
    List<Map<String, dynamic>>? invites,
  }) {
    // The server's view, patched by transfer / rename / delete so the
    // notifier's follow-up `refresh()` confirms rather than reverts.
    final server = [...items];
    return [
        cloudEnabledProvider.overrideWithValue(true),
        collectionsProvider.overrideWith((ref) => CollectionsNotifier(ref, autoStart: false, initial: items)),
        activeCollectionProvider.overrideWithValue(active),
        activeCollectionIdProvider.overrideWithValue(active.id),
        syncRunnerProvider.overrideWithValue(const NoopSyncRunner()),
        cloudStateProvider.overrideWithValue(_ready),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              log.add(req);
              final o = override?.call(req);
              if (o != null) return o;
              final p = req.url.path;
              final colId = RegExp(r'/inventory/collections/([^/]+)').firstMatch(p)?.group(1);
              if (req.method == 'DELETE') {
                if (p.endsWith('/inventory/collections/$colId')) server.removeWhere((c) => c.id == colId);
                return http.Response('', 204);
              }
              if (req.method == 'PATCH' && p.endsWith('/inventory/collections/$colId')) {
                final name = json.decode(req.body)['name'] as String;
                for (var i = 0; i < server.length; i++) {
                  if (server[i].id == colId) server[i] = server[i].copyWith(name: name);
                }
                return http.Response(json.encode({'id': colId, 'name': name}), 200);
              }
              if (req.method == 'PATCH') return http.Response('', 204);
              if (req.method == 'POST' && p.endsWith('/transfer')) {
                final uid = json.decode(req.body)['user_id'] as String;
                for (var i = 0; i < server.length; i++) {
                  if (server[i].id == colId) server[i] = server[i].copyWith(role: 'editor', ownerUserId: uid);
                }
                return http.Response(json.encode({'owner_user_id': uid}), 200);
              }
              if (req.method == 'POST' && p.endsWith('/invites')) {
                return http.Response(
                  json.encode({
                    'invite': {
                      'id': 'inv-new',
                      'code': 'BCDFGHJK',
                      'url': 'https://plantly.ro/app/inventory/join#c=BCDFGHJK',
                      'expires_at': '2026-10-10T10:00:00Z',
                      ...json.decode(req.body) as Map<String, dynamic>,
                    }
                  }),
                  201,
                );
              }
              if (p.endsWith('/inventory/collections')) {
                return http.Response(json.encode({'collections': [for (final c in server) c.toJson()]}), 200);
              }
              if (p.endsWith('/invites')) return http.Response(json.encode({'invites': invites ?? _invites}), 200);
              if (p.endsWith('/members')) return http.Response(json.encode({'members': _membersFor(active)}), 200);
              return http.Response('{"error":"unexpected"}', 500);
            })),
      ];
  }

  Future<void> pump(WidgetTester tester, Widget child, List<Override> ov) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(KeyedSubtree(
      key: UniqueKey(),
      child: buildTestApp(
        overrides: ov,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openMembers(WidgetTester tester, List<Override> ov) async {
    await pump(tester, SharingRows(surface: PlantlySurface.light), ov);
    await tester.tap(find.byKey(const Key('share-members')));
    await tester.pumpAndSettle();
  }

  http.Request only(List<http.Request> log, String method, String suffix) =>
      log.singleWhere((r) => r.method == method && r.url.path.endsWith(suffix));

  group('members sheet v2 — owner', () {
    testWidgets('badges on every row, "(you)" on mine, menus only on others; Make viewer → PATCH {"role":"viewer"}',
        (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine, _shared], _mine, log));
      expect(find.text('alice (you)'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-role-u-1')), matching: find.text('Owner')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-role-u-2')), matching: find.text('Editor')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-role-u-3')), matching: find.text('Viewer')), findsOneWidget);
      expect(find.byKey(const Key('member-menu-u-1')), findsNothing);
      expect(find.byKey(const Key('member-menu-u-2')), findsOneWidget);
      expect(find.byKey(const Key('member-menu-u-3')), findsOneWidget);
      expect(find.byKey(const Key('member-leave')), findsNothing);

      await tester.tap(find.byKey(const Key('member-menu-u-2')));
      await tester.pumpAndSettle();
      expect(find.text('Make viewer'), findsOneWidget);
      expect(find.text('Make editor'), findsNothing);
      expect(find.text('Transfer ownership'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      await tester.tap(find.byKey(const Key('member-make-viewer-u-2')));
      await tester.pumpAndSettle();
      final patch = only(log, 'PATCH', '/inventory/collections/col-1/members/u-2');
      expect(json.decode(patch.body), {'role': 'viewer'});
      expect(find.text('bob is now Viewer'), findsOneWidget);
      // The list was invalidated and refetched.
      expect(log.where((r) => r.method == 'GET' && r.url.path.endsWith('/members')).length, greaterThanOrEqualTo(2));
    });

    testWidgets('Make editor on a viewer → PATCH {"role":"editor"}; Remove goes through the confirm', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine], _mine, log));
      await tester.tap(find.byKey(const Key('member-menu-u-3')));
      await tester.pumpAndSettle();
      expect(find.text('Make editor'), findsOneWidget);
      await tester.tap(find.byKey(const Key('member-make-editor-u-3')));
      await tester.pumpAndSettle();
      expect(json.decode(only(log, 'PATCH', '/members/u-3').body), {'role': 'editor'});

      await tester.tap(find.byKey(const Key('member-menu-u-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-remove-u-3')));
      await tester.pumpAndSettle();
      expect(find.text('Remove carol?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('member-remove-confirm')));
      await tester.pumpAndSettle();
      expect(only(log, 'DELETE', '/inventory/collections/col-1/members/u-3'), isNotNull);
      expect(find.text('carol removed'), findsOneWidget);
    });

    testWidgets('Transfer ownership: confirm explains plan/quota + editor, POST /transfer {"user_id"}', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine, _shared], _mine, log));
      await tester.tap(find.byKey(const Key('member-menu-u-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-transfer-u-2')));
      await tester.pumpAndSettle();
      expect(find.text('Transfer My plants to bob?'), findsOneWidget);
      expect(find.textContaining('Their Plantly Cloud plan and storage quota apply from now on'), findsOneWidget);
      expect(find.textContaining('You stay in it as an editor'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.byKey(const Key('transfer-confirm')));
      await tester.pumpAndSettle();
      final post = only(log, 'POST', '/inventory/collections/col-1/transfer');
      expect(json.decode(post.body), {'user_id': 'u-2'});
      expect(find.byKey(const Key('transfer-confirm')), findsNothing, reason: 'dialog closes on success');
      expect(find.text('bob now owns My plants'), findsOneWidget);
      // Local role flipped to editor right away → the owner tools are gone.
      expect(find.byKey(const Key('member-menu-u-2')), findsNothing);
      expect(find.byKey(const Key('invites-section')), findsNothing);
    });

    testWidgets('Transfer 402 cloud_required_new_owner → inline copy, dialog stays open; 404 member_not_found',
        (tester) async {
      final log = <http.Request>[];
      var status = 402;
      var code = 'cloud_required_new_owner';
      await openMembers(
        tester,
        overrides([_mine], _mine, log, override: (req) {
          if (req.method == 'POST' && req.url.path.endsWith('/transfer')) {
            return http.Response(json.encode({'error': code}), status);
          }
          return null;
        }),
      );
      await tester.tap(find.byKey(const Key('member-menu-u-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('member-transfer-u-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('transfer-confirm')));
      await tester.pumpAndSettle();
      final en = lookupAppLocalizations(const Locale('en'));
      expect(find.byKey(const Key('transfer-error')), findsOneWidget);
      expect(find.text(en.shareErrCloudRequiredNewOwner), findsOneWidget);
      expect(find.byKey(const Key('transfer-confirm')), findsOneWidget, reason: 'stays open to read the reason');
      expect(find.byKey(const Key('member-menu-u-2')), findsOneWidget, reason: 'still owner');

      status = 404;
      code = 'member_not_found';
      await tester.tap(find.byKey(const Key('transfer-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(en.shareErrMemberNotFound), findsOneWidget);
      expect(log.where((r) => r.method == 'POST' && r.url.path.endsWith('/transfer')).length, 2);
    });
  });

  group('members sheet v2 — editor / viewer', () {
    testWidgets('editor: badges, no menus, Leave on own row, no invites section', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine, _shared], _shared, log));
      expect(find.text('alice (you)'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-role-u-2')), matching: find.text('Owner')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('member-role-u-1')), matching: find.text('Editor')), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byKey(const Key('member-leave')), findsOneWidget);
      expect(find.byKey(const Key('invites-section')), findsNothing);
      expect(log.any((r) => r.url.path.endsWith('/invites')), isFalse, reason: 'invites are never fetched for non-owners');
    });

    testWidgets('viewer: badges show "Viewer", no menus, Leave present', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine, _viewed], _viewed, log));
      expect(find.descendant(of: find.byKey(const Key('member-role-u-1')), matching: find.text('Viewer')), findsOneWidget);
      expect(find.text('alice (you)'), findsOneWidget);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byKey(const Key('member-leave')), findsOneWidget);
      expect(find.byKey(const Key('invites-section')), findsNothing);
    });
  });

  group('invites section (owner)', () {
    testWidgets('lists label / role / uses / expiry; revoke → confirm → DELETE …/invites/<id> + refetch', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine], _mine, log));
      expect(find.byKey(const Key('invites-section')), findsOneWidget);
      expect(find.text('INVITES'), findsOneWidget);
      expect(find.byKey(const Key('invites-new')), findsOneWidget);
      expect(find.byKey(const Key('invite-inv-1')), findsOneWidget);
      expect(find.byKey(const Key('invite-inv-2')), findsOneWidget);
      expect(find.text('Grandma'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget, reason: 'unlabelled invite falls back to "Invite"');
      expect(find.descendant(of: find.byKey(const Key('invite-inv-2')), matching: find.text('Viewer')), findsOneWidget);
      expect(find.textContaining('0/1 used'), findsOneWidget);
      expect(find.textContaining('3/10 used'), findsOneWidget);
      expect(find.textContaining('expires in 7 days'), findsOneWidget);
      expect(find.textContaining('expires in 5 hours'), findsOneWidget);
      expect(find.text('alice (you)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-revoke-inv-1')));
      await tester.pumpAndSettle();
      expect(find.text('Revoke this invite?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-revoke-confirm')));
      await tester.pumpAndSettle();
      expect(only(log, 'DELETE', '/inventory/collections/col-1/invites/inv-1'), isNotNull);
      expect(find.text('Invite revoked'), findsOneWidget);
      expect(log.where((r) => r.method == 'GET' && r.url.path.endsWith('/invites')).length, 2);
    });

    testWidgets('empty state; "New invite" opens the create sheet and refetches after it closes', (tester) async {
      final log = <http.Request>[];
      await openMembers(tester, overrides([_mine], _mine, log, invites: const []));
      expect(find.byKey(const Key('invites-empty')), findsOneWidget);
      await tester.tap(find.byKey(const Key('invites-new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-create')), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(find.text('BCDF-GHJK'), findsOneWidget);
      // Close the invite sheet → the list refetches.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(log.where((r) => r.method == 'GET' && r.url.path.endsWith('/invites')).length, 2);
    });
  });

  group('invite create sheet v2', () {
    Future<void> openInvite(WidgetTester tester, List<Override> ov) async {
      await pump(tester, SharingRows(surface: PlantlySurface.light), ov);
      await tester.tap(find.byKey(const Key('share-invite')));
      await tester.pumpAndSettle();
    }

    testWidgets('defaults: Editor + single use · 7 days → body {"role":"editor","max_uses":1,"ttl_days":7}; summary line',
        (tester) async {
      final log = <http.Request>[];
      await openInvite(tester, overrides([_mine], _mine, log));
      expect(find.byKey(const Key('invite-role-editor')), findsOneWidget);
      expect(find.byKey(const Key('invite-role-viewer')), findsOneWidget);
      expect(find.byKey(const Key('invite-preset-single')), findsOneWidget);
      expect(find.byKey(const Key('invite-preset-family')), findsOneWidget);
      expect(find.byKey(const Key('invite-preset-custom')), findsOneWidget);
      expect(find.byKey(const Key('invite-max-uses')), findsNothing, reason: 'steppers only under Custom');
      expect(find.text('Editor · single use · 7 days'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      final post = only(log, 'POST', '/inventory/collections/col-1/invites');
      expect(json.decode(post.body), {'role': 'editor', 'max_uses': 1, 'ttl_days': 7});
      expect(find.byKey(const Key('invite-code')), findsOneWidget);
      expect(find.byKey(const Key('invite-url')), findsOneWidget);
      expect(find.byKey(const Key('invite-copy')), findsOneWidget);
      expect(find.byKey(const Key('invite-share')), findsOneWidget);
      expect(find.byKey(const Key('invite-summary')), findsOneWidget);
      // The result line drops the TTL — the expiry date right under it
      // already says when the code stops working.
      expect(find.text('Editor · single use'), findsOneWidget);
      expect(find.text('Editor · single use · 7 days'), findsNothing);
    });

    testWidgets('Family preset → max_uses 10 / ttl_days 30', (tester) async {
      final log = <http.Request>[];
      await openInvite(tester, overrides([_mine], _mine, log));
      await tester.tap(find.byKey(const Key('invite-preset-family')));
      await tester.pumpAndSettle();
      expect(find.text('Editor · 10 uses · 30 days'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(json.decode(only(log, 'POST', '/invites').body), {'role': 'editor', 'max_uses': 10, 'ttl_days': 30});
    });

    testWidgets('Viewer + Custom steppers + label → all sent; label capped at 40', (tester) async {
      final log = <http.Request>[];
      await openInvite(tester, overrides([_mine], _mine, log));
      await tester.tap(find.byKey(const Key('invite-role-viewer')));
      await tester.tap(find.byKey(const Key('invite-preset-custom')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-max-uses')), findsOneWidget);
      expect(find.byKey(const Key('invite-ttl-days')), findsOneWidget);
      expect(find.byTooltip('Increase Max uses'), findsOneWidget);
      expect(find.byTooltip('Decrease Valid for (days)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-max-uses-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('invite-max-uses-plus')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('invite-ttl-days-minus')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('invite-max-uses')), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('invite-ttl-days')), matching: find.text('6')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('invite-label')), '  Plant-sitter ');
      await tester.pumpAndSettle();
      expect(find.text('Viewer · 3 uses · 6 days'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(json.decode(only(log, 'POST', '/invites').body),
          {'role': 'viewer', 'max_uses': 3, 'ttl_days': 6, 'label': 'Plant-sitter'});
      expect(find.textContaining('Plant-sitter'), findsWidgets);
      expect(find.byKey(const Key('invite-label')), findsNothing, reason: 'result view replaces the form');
    });

    testWidgets('stepper floors: uses never below 1, days never above 30', (tester) async {
      final log = <http.Request>[];
      await openInvite(tester, overrides([_mine], _mine, log));
      await tester.tap(find.byKey(const Key('invite-preset-custom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-max-uses-minus')), warnIfMissed: false);
      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byKey(const Key('invite-ttl-days-plus')), warnIfMissed: false);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Editor · single use · 30 days'), findsOneWidget);
    });

    testWidgets('409 too_many_invites → inline error, form stays', (tester) async {
      final log = <http.Request>[];
      await openInvite(
        tester,
        overrides([_mine], _mine, log, override: (req) {
          if (req.method == 'POST' && req.url.path.endsWith('/invites')) {
            return http.Response(json.encode({'error': 'too_many_invites', 'max_active': 10}), 409);
          }
          return null;
        }),
      );
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-error')), findsOneWidget);
      expect(find.textContaining('10 active invites'), findsOneWidget);
      expect(find.byKey(const Key('invite-create')), findsOneWidget);
    });
  });

  group('collection switcher v2', () {
    Future<void> openSwitcher(WidgetTester tester, List<Override> ov) async {
      await pump(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            key: const Key('open-switcher'),
            onPressed: () => showCollectionSwitcherSheet(ctx),
            child: const Text('open'),
          ),
        ),
        ov,
      );
      await tester.tap(find.byKey(const Key('open-switcher')));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionSwitcherSheet), findsOneWidget);
    }

    testWidgets('owner menu on mine (delete hidden on the linked default), "by <owner>" + paused on shared',
        (tester) async {
      final log = <http.Request>[];
      await openSwitcher(tester, overrides([_mine, _second, _shared, _viewed], _mine, log));
      expect(find.byKey(const Key('collection-menu-col-1')), findsOneWidget);
      expect(find.byKey(const Key('collection-menu-col-3')), findsOneWidget);
      expect(find.byKey(const Key('collection-menu-col-2')), findsNothing);
      expect(find.byKey(const Key('collection-menu-col-4')), findsNothing);
      expect(find.text('3 members · by bob'), findsOneWidget);
      expect(find.text('2 members · by carol'), findsOneWidget);
      expect(find.byKey(const Key('collection-paused-col-4')), findsOneWidget);
      expect(find.byKey(const Key('collection-paused-col-2')), findsNothing);
      expect(find.text('Viewer'), findsOneWidget);

      await tester.tap(find.byKey(const Key('collection-menu-col-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-rename-col-1')), findsOneWidget);
      expect(find.byKey(const Key('collection-delete-col-1')), findsNothing, reason: 'home collection is never deletable');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-menu-col-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-rename-col-3')), findsOneWidget);
      expect(find.byKey(const Key('collection-delete-col-3')), findsOneWidget);
    });

    testWidgets('Rename: prefilled, 1..60 validation, PATCH {"name":…}', (tester) async {
      final log = <http.Request>[];
      await openSwitcher(tester, overrides([_mine, _second], _mine, log));
      await tester.tap(find.byKey(const Key('collection-menu-col-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-rename-col-1')));
      await tester.pumpAndSettle();
      final field = find.byKey(const Key('collection-rename-field'));
      expect(tester.widget<TextField>(field).controller!.text, 'My plants');
      FilledButton save() => tester.widget<FilledButton>(find.byKey(const Key('collection-rename-save')));
      expect(save().onPressed, isNull, reason: 'unchanged');
      await tester.enterText(field, '   ');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull);
      expect(find.text('Use 1 to 60 characters.'), findsOneWidget);
      await tester.enterText(field, ' Living room ');
      await tester.pumpAndSettle();
      expect(save().onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('collection-rename-save')));
      await tester.pumpAndSettle();
      final patch = only(log, 'PATCH', '/inventory/collections/col-1');
      expect(json.decode(patch.body), {'name': 'Living room'});
      expect(find.text('Renamed to Living room'), findsOneWidget);
      expect(find.text('Living room'), findsWidgets, reason: 'local list patched');
      expect(find.byType(CollectionSwitcherSheet), findsOneWidget, reason: 'rename keeps the sheet open');
    });

    testWidgets('Delete: destructive confirm → DELETE /collections/{id}, sheet closes, collection gone', (tester) async {
      final log = <http.Request>[];
      await openSwitcher(tester, overrides([_mine, _second], _mine, log));
      await tester.tap(find.byKey(const Key('collection-menu-col-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collection-delete-col-3')));
      await tester.pumpAndSettle();
      expect(find.text('Delete Balcony?'), findsOneWidget);
      expect(find.textContaining('Members lose access'), findsOneWidget);
      expect(find.textContaining('The copy on this device stays'), findsOneWidget);
      await tester.tap(find.byKey(const Key('collection-delete-confirm')));
      await tester.pumpAndSettle();
      expect(only(log, 'DELETE', '/inventory/collections/col-3'), isNotNull);
      expect(log.any((r) => r.method == 'DELETE' && r.url.path.contains('/members/')), isFalse);
      expect(find.text('Balcony deleted'), findsOneWidget);
      expect(find.byType(CollectionSwitcherSheet), findsNothing, reason: 'sheet closes after a successful delete');
      final state = ProviderScope.containerOf(tester.element(find.byKey(const Key('open-switcher')))).read(collectionsProvider);
      expect(state.byId('col-3'), isNull);
      expect(state.byId('col-1'), isNotNull);
    });
  });
}
