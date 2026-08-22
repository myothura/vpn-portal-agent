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
  final String type; // 'plan_renewal' or 'device_slot'
  final String title;
  final String subtitle;

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
    );
  }
}

class RenewalRequestResponse {
  final List<RenewalRequest> requests;
  final int currentPage;
  final int lastPage;

  RenewalRequestResponse({
    required this.requests,
    required this.currentPage,
    required this.lastPage,
  });

  factory RenewalRequestResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List;
    List<RenewalRequest> requests = list
        .map((i) => RenewalRequest.fromJson(i))
        .toList();
    return RenewalRequestResponse(
      requests: requests,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }
}
