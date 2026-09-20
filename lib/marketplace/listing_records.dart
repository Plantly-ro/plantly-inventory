import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';

/// The local memory of "this plant is listed on plantly.ro" (CONTRACT §5):
/// `shared_preferences` key `plantly_ro_export/<plantId>` =
/// `{post_id, url, posted_at, status}`.
class ListingRecord {
  const ListingRecord({
    required this.plantId,
    required this.postId,
    required this.url,
    required this.postedAt,
    required this.status,
  });

  final String plantId;
  final String postId;
  final String url;
  final DateTime postedAt;

  /// Mirrors the marketplace status we last knew: `active` | `sold`.
  final String status;

  bool get isSold => status == 'sold';

  ListingRecord copyWith({String? status}) => ListingRecord(
        plantId: plantId,
        postId: postId,
        url: url,
        postedAt: postedAt,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'post_id': postId,
        'url': url,
        'posted_at': postedAt.toUtc().toIso8601String(),
        'status': status,
      };

  static ListingRecord? fromJson(String plantId, Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final postId = raw['post_id'];
    if (postId is! String || postId.isEmpty) return null;
    return ListingRecord(
      plantId: plantId,
      postId: postId,
      url: raw['url'] as String? ?? '',
      postedAt: DateTime.tryParse(raw['posted_at'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: raw['status'] as String? ?? 'active',
    );
  }
}

/// All listing records keyed by plant id, loaded once from prefs and kept in
/// memory so plant detail rows rebuild synchronously.
class ListingRecords extends StateNotifier<Map<String, ListingRecord>> {
  ListingRecords(this._prefs) : super(const {}) {
    _load();
  }

  static const prefix = 'plantly_ro_export/';
  static String keyFor(String plantId) => '$prefix$plantId';

  final Future<SharedPreferences> _prefs;

  Future<void> _load() async {
    final p = await _prefs;
    final out = <String, ListingRecord>{};
    for (final key in p.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final plantId = key.substring(prefix.length);
      try {
        final rec = ListingRecord.fromJson(plantId, json.decode(p.getString(key) ?? ''));
        if (rec != null) out[plantId] = rec;
      } catch (_) {
        // Corrupt entry — ignore rather than crash the detail screen.
      }
    }
    state = out;
  }

  ListingRecord? forPlant(String plantId) => state[plantId];

  /// Read-only snapshot for non-widget callers (the plugin).
  Map<String, ListingRecord> get all => state;

  Future<void> put(ListingRecord record) async {
    state = {...state, record.plantId: record};
    final p = await _prefs;
    await p.setString(keyFor(record.plantId), json.encode(record.toJson()));
  }

  Future<void> setStatus(String plantId, String status) async {
    final current = state[plantId];
    if (current == null) return;
    await put(current.copyWith(status: status));
  }

  Future<void> remove(String plantId) async {
    state = {...state}..remove(plantId);
    final p = await _prefs;
    await p.remove(keyFor(plantId));
  }
}

final listingRecordsProvider = StateNotifierProvider<ListingRecords, Map<String, ListingRecord>>((ref) {
  return ListingRecords(ref.watch(sharedPreferencesProvider.future));
});
