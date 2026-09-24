class VpnUser {
  final int id;
  final String username;
  final String? planName;
  final String status;
  final String? expiryDate;
  final bool isOnline;
  final int extraDeviceSlots;
  final int? businessPlanId;
  final String? businessPlanName;
  final int? businessPlanPrice;
  final bool hasBusinessPlan;

  VpnUser({
    required this.id,
    required this.username,
    this.planName,
    required this.status,
    this.expiryDate,
    this.isOnline = false,
    this.extraDeviceSlots = 0,
    this.businessPlanId,
    this.businessPlanName,
    this.businessPlanPrice,
    this.hasBusinessPlan = false,
  });

  factory VpnUser.fromJson(Map<String, dynamic> json) {
    // AGENT_APP_F1 — the list endpoint sends business_plan_id as an int and
    // the detail endpoint as a string, and neither sends the join at all once
    // the plan has been removed. Same fields, same types, tolerant reads.
    final businessPlan = _map(json['business_plan']);
    final businessPlanId = _intOrNull(json['business_plan_id']);
    final rawHasBusinessPlan = json['has_business_plan'];

    return VpnUser(
      id: _int(json['id']),
      username: _str(json['username'], 'N/A'),
      planName: _strOrNull(_map(json['plan'])?['plan_name']),
      status: _str(json['status'], 'inactive'),
      expiryDate: _strOrNull(json['subscription_expiry_date']),
      isOnline: _bool(json['is_online']),
      extraDeviceSlots: _int(json['extra_device_slots']),
      businessPlanId: businessPlanId,
      businessPlanName: _strOrNull(businessPlan?['plan_name']),
      businessPlanPrice: _intOrNull(businessPlan?['price_per_month_credits']),
      // Unchanged rule: trust the flag when the endpoint sends one, otherwise
      // infer it from the id.
      hasBusinessPlan: rawHasBusinessPlan == null
          ? businessPlanId != null
          : _bool(rawHasBusinessPlan),
    );
  }
}

class VpnUserResponse {
  final List<VpnUser> users;
  final int currentPage;
  final int lastPage;

  /// Rows matching the query across every page, not just the ones returned.
  /// `users.length` is a page — showing it as a count told the agent there
  /// were 10 accounts expiring when there were 359.
  final int total;

  VpnUserResponse({
    required this.users,
    required this.currentPage,
    required this.lastPage,
    this.total = 0,
  });

  factory VpnUserResponse.fromJson(Map<String, dynamic> json) {
    // AGENT_APP_F1 — `json['data'] as List` threw on the error envelope the
    // API returns when the page is out of range, losing the page and the
    // paging state with it.
    final rawList = json['data'];
    final List<dynamic> items = rawList is List ? rawList : const <dynamic>[];
    final List<VpnUser> users = items
        .whereType<Map>()
        .map((i) => VpnUser.fromJson(Map<String, dynamic>.from(i)))
        .toList();
    return VpnUserResponse(
      users: users,
      currentPage: _int(json['current_page'], 1),
      lastPage: _int(json['last_page'], 1),
      total: _int(json['total'], users.length),
    );
  }
}

// ── Tolerant JSON readers ─────────────────────────────────────────────────
//
// The backend is PHP: a numeric column arrives as 5000 from one endpoint and
// as "5000" from another, and as null where a join missed. A direct cast or a
// bare int.parse throws inside fromJson, and one bad row then fails the whole
// page of otherwise good rows. These take whatever arrived and fall back to
// the value the previous code produced for well-formed input.

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;
  if (v is String) {
    final s = v.trim();
    return int.tryParse(s) ?? double.tryParse(s)?.toInt() ?? fallback;
  }
  return fallback;
}

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}

String _str(Object? v, [String fallback = '']) {
  if (v is String) return v;
  if (v == null) return fallback;
  return v.toString();
}

String? _strOrNull(Object? v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

bool _bool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}

Map<String, dynamic>? _map(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}
