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
    return RenewalRequest(
      id: json['id'],
      vpnUserName: json['vpn_user']['username'] ?? 'N/A',
      // If plan is null (device purchase), show fallback text
      planName: json['plan'] != null
          ? json['plan']['plan_name']
          : 'Device Slot',
      durationMonths: json['duration_months'],
      status: json['status'],
      screenshotUrl: ApiConfig.resolveMediaUrl(json['payment_screenshot_url']) ?? '',
      createdAt: json['created_at'],

      // ✅ Bind Data from Backend API
      type: json['type'] ?? 'plan_renewal',
      title: json['request_title'] ?? 'Request',
      subtitle: json['request_subtitle'] ?? 'Details',
      estimatedCost: (json['estimated_cost'] as num?)?.toInt() ?? 0,
      rejectReason: (json['reject_reason'] as String?)?.trim().isEmpty ?? true
          ? null
          : json['reject_reason'] as String,
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
    var list = json['data'] as List;
    List<RenewalRequest> requests = list
        .map((i) => RenewalRequest.fromJson(i))
        .toList();
    final rawCounts = json['counts'];
    return RenewalRequestResponse(
      requests: requests,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? requests.length,
      counts: rawCounts is Map
          ? rawCounts.map((k, v) => MapEntry(k.toString(), (v as num).toInt()))
          : const {},
    );
  }
}
