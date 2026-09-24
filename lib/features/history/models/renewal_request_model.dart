import 'package:vpn_agent_app/core/api/api_config.dart';

class RenewalRequest {
  final int id;
  final String vpnUserName;
  final String planName;
  final int durationMonths;
  final String status;
  final String screenshotUrl;
  final String createdAt;

  // 🔥 New Fields for UI Update
  final String type; // plan_renewal | device_slot | business_plan
  final String title;
  final String subtitle;

  /// What approving this will deduct, computed server-side. It depends on the
  /// slot-price setting, the user's existing extra slots, and for a business
  /// plan on days left on the subscription — none of which the app holds.
  final int estimatedCost;

  /// Present only on rejected requests.
  final String? rejectReason;

  RenewalRequest({
    required this.id,
    required this.vpnUserName,
    required this.planName,
    required this.durationMonths,
    required this.status,
    required this.screenshotUrl,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.subtitle,
    this.estimatedCost = 0,
    this.rejectReason,
  });

  factory RenewalRequest.fromJson(Map<String, dynamic> json) {
    // AGENT_APP_F1 — vpn_user and plan are joins and either can be missing;
    // duration_months and estimated_cost come back as strings from the list
    // endpoint and as ints from the detail one. A bad reject_reason type used
    // to throw here and blank the whole tab.
    final vpnUser = _map(json['vpn_user']);
    final plan = _map(json['plan']);
    final rawReason = _strOrNull(json['reject_reason']);

    return RenewalRequest(
      id: _int(json['id']),
      vpnUserName: _str(vpnUser?['username'], 'N/A'),
      // If plan is null (device purchase), show fallback text
      planName: plan == null
          ? 'Device Slot'
          : _str(plan['plan_name'], 'Device Slot'),
      durationMonths: _int(json['duration_months']),
      status: _str(json['status']),
      screenshotUrl:
          ApiConfig.resolveMediaUrl(
            _strOrNull(json['payment_screenshot_url']),
          ) ??
          '',
      createdAt: _str(json['created_at']),

      // Bound from the backend API.
      type: _str(json['type'], 'plan_renewal'),
      title: _str(json['request_title'], 'Request'),
      subtitle: _str(json['request_subtitle'], 'Details'),
      estimatedCost: _int(json['estimated_cost']),
      rejectReason: (rawReason == null || rawReason.trim().isEmpty)
          ? null
          : rawReason,
    );
  }
}

class RenewalRequestResponse {
  final List<RenewalRequest> requests;
  final int currentPage;
  final int lastPage;

  /// Rows matching the current status across every page.
  final int total;

  /// Totals per status, computed server-side over the whole table. The tab
  /// counts cannot come from the loaded page: with 3,138 requests, a page of
  /// twenty would have reported single digits while the nav badge showed the
  /// real 109 pending.
  final Map<String, int> counts;

  RenewalRequestResponse({
    required this.requests,
    required this.currentPage,
    required this.lastPage,
    this.total = 0,
    this.counts = const {},
  });

  factory RenewalRequestResponse.fromJson(Map<String, dynamic> json) {
    // AGENT_APP_F1 — the counts block is a GROUP BY, so every total in it is
    // a string; `(v as num)` threw on the first one.
    final rawList = json['data'];
    final List<dynamic> items = rawList is List ? rawList : const <dynamic>[];
    final List<RenewalRequest> requests = items
        .whereType<Map>()
        .map((i) => RenewalRequest.fromJson(Map<String, dynamic>.from(i)))
        .toList();
    final rawCounts = json['counts'];
    return RenewalRequestResponse(
      requests: requests,
      currentPage: _int(json['current_page'], 1),
      lastPage: _int(json['last_page'], 1),
      total: _int(json['total'], requests.length),
      counts: rawCounts is Map
          ? rawCounts.map((k, v) => MapEntry(k.toString(), _int(v)))
          : const {},
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

Map<String, dynamic>? _map(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}
