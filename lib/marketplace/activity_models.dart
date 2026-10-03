/// Wire model of `GET /inventory/collections/{id}/activity`
/// (MULTI-USER-V2 §2.11). Pure Dart, no Flutter imports: shared by the API
/// client, the per-collection cache (`lib/cloud/collection_activity.dart`)
/// and the copy formatters.
library;

/// `created | updated | deleted` (§2.11). Unknown strings map to [updated].
enum ActivityKind {
  created,
  updated,
  deleted;

  static ActivityKind parse(String? s) => switch (s) {
        'created' => ActivityKind.created,
        'deleted' => ActivityKind.deleted,
        _ => ActivityKind.updated,
      };

  String get wire => name;
}

/// Who did it. `username` may be empty when the server could not resolve
/// the account (deleted user).
class ActivityUser {
  const ActivityUser({required this.id, required this.username});
  final String id;
  final String username;

  factory ActivityUser.fromJson(Object? m) {
    if (m is! Map<String, dynamic>) return const ActivityUser(id: '', username: '');
    return ActivityUser(
      id: (m['id'] as String? ?? '').trim(),
      username: (m['username'] as String? ?? '').trim(),
    );
  }

  /// Blank/whitespace usernames count as unknown (the UI shows a neutral label).
  bool get isUnknown => username.trim().isEmpty;

  Map<String, dynamic> toJson() => {'id': id, 'username': username};

  @override
  bool operator ==(Object other) => other is ActivityUser && other.id == id && other.username == username;

  @override
  int get hashCode => Object.hash(id, username);
}

/// One grouped event of the server feed: consecutive ops by the same
/// `(user, device, entity, entity_id)` within 2 s (§0 "Activity").
class ActivityEvent {
  const ActivityEvent({
    required this.seq,
    this.at,
    required this.user,
    required this.entity,
    required this.entityId,
    required this.kind,
    this.deviceId,
    this.fields = const [],
    this.summaryName,
  });

  /// Server op sequence of the group (its highest op); the paging cursor.
  final int seq;
  /// Null when the server sent no parsable timestamp; the UI then omits it.
  final DateTime? at;
  final ActivityUser user;
  final String? deviceId;

  /// Codec entity name: `plants`, `locations`, `care_schedules`,
  /// `care_events`, `photos`, … (anything else renders generically).
  final String entity;
  final String entityId;
  final ActivityKind kind;

  /// Field names touched by the group (informational).
  final List<String> fields;

  /// `summary.name` — best-effort display name of the entity (plant
  /// nickname, space name, the plant a reminder belongs to…); null when
  /// the server could not derive one.
  final String? summaryName;

  /// Tolerant parse: a row without a numeric `seq` is dropped by callers
  /// ([tryParse] returns null) — everything else defaults.
  static ActivityEvent? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final seq = raw['seq'];
    if (seq is! num) return null;
    final summary = raw['summary'];
    final fields = raw['fields'];
    return ActivityEvent(
      seq: seq.toInt(),
      at: raw['at'] is String ? DateTime.tryParse(raw['at'] as String)?.toUtc() : null,
      user: ActivityUser.fromJson(raw['user']),
      deviceId: raw['device_id'] as String?,
      entity: raw['entity'] as String? ?? '',
      entityId: raw['entity_id'] as String? ?? '',
      kind: ActivityKind.parse(raw['kind'] as String?),
      fields: [
        if (fields is List)
          for (final f in fields)
            if (f is String) f,
      ],
      summaryName: summary is Map<String, dynamic> ? (summary['name'] as String?) : null,
    );
  }

  /// Round-trips through the prefs cache (same shape as the wire).
  Map<String, dynamic> toJson() => {
        'seq': seq,
        if (at != null) 'at': at!.toUtc().toIso8601String(),
        'user': user.toJson(),
        if (deviceId != null) 'device_id': deviceId,
        'entity': entity,
        'entity_id': entityId,
        'kind': kind.wire,
        'fields': fields,
        if (summaryName != null) 'summary': {'name': summaryName},
      };

  @override
  bool operator ==(Object other) => other is ActivityEvent && other.seq == seq && other.entityId == entityId;

  @override
  int get hashCode => Object.hash(seq, entityId);

  @override
  String toString() => 'ActivityEvent(#$seq ${user.username} ${kind.wire} $entity/$entityId @ $at)';
}

/// One page of the feed, newest first. [nextBefore] is null when the
/// server reports no older events.
class ActivityPage {
  const ActivityPage({required this.events, this.nextBefore});
  final List<ActivityEvent> events;
  final int? nextBefore;

  bool get hasMore => nextBefore != null;

  factory ActivityPage.fromJson(Object? body) {
    if (body is! Map<String, dynamic>) return const ActivityPage(events: []);
    final raw = body['events'];
    final events = raw is List ? raw.map(ActivityEvent.tryParse).nonNulls.toList() : <ActivityEvent>[];
    events.sort((a, b) => b.seq.compareTo(a.seq));
    final nb = body['next_before'];
    return ActivityPage(events: events, nextBefore: nb is num && nb > 0 ? nb.toInt() : null);
  }
}
