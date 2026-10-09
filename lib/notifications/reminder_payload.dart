import 'dart:convert';

/// What a plant-care OS notification carries back to the app on tap: the
/// plant and the tenant (collection) it was scheduled for. Encoded as a
/// small JSON object so the format can grow; [decode] is lenient — any
/// payload it cannot read (older builds scheduled none) yields null and the
/// tap just opens the app.
class ReminderPayload {
  const ReminderPayload({required this.plantId, this.tenantId});

  final String plantId;

  /// Tenant the reminder was armed for; null when unknown.
  final String? tenantId;

  String encode() => jsonEncode({'v': 1, 'plant': plantId, if (tenantId != null) 'tenant': tenantId});

  static ReminderPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final plant = m['plant'];
      final tenant = m['tenant'];
      if (plant is! String || plant.isEmpty) return null;
      return ReminderPayload(plantId: plant, tenantId: tenant is String && tenant.isNotEmpty ? tenant : null);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPayload && other.plantId == plantId && other.tenantId == tenantId;

  @override
  int get hashCode => Object.hash(plantId, tenantId);

  @override
  String toString() => 'ReminderPayload($plantId @ $tenantId)';
}
