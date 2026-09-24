import 'package:vpn_agent_app/core/services/remote_config_service.dart';

class ApiConfig {
  static String get baseUrl => RemoteConfigService().activeApiUrl;
  static String get backupUrl => RemoteConfigService().backupApiUrl;
  static String get backupUrl2 => RemoteConfigService().backupApiUrl2;
  static String get backupUrl3 => RemoteConfigService().backupApiUrl3;

  /// Hosts that belong to our own backend. Laravel builds media URLs with
  /// asset()/url() off APP_URL, which is still the DPI-blocked
  /// control.vpnportal.org, so those URLs are rewritten onto the active host.
  static Set<String> get _ownHosts {
    final hosts = <String>{'control.vpnportal.org'};
    for (final u in [baseUrl, backupUrl, backupUrl2, backupUrl3]) {
      if (u.isEmpty) continue;
      final h = Uri.tryParse(u)?.host;
      if (h != null && h.isNotEmpty) hosts.add(h);
    }
    return hosts;
  }

  /// Active origin, e.g. https://static-asset-delivery.com (no /api suffix).
  static String get _activeOrigin {
    final u = Uri.tryParse(baseUrl);
    if (u == null || u.host.isEmpty) return '';
    return '${u.scheme}://${u.host}';
  }

  /// Rewrites a backend media URL onto the active domain.
  /// External URLs are returned untouched.
  static String? resolveMediaUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return url;
    if (!_ownHosts.contains(uri.host)) return url;
    final origin = _activeOrigin;
    if (origin.isEmpty) return url;
    final active = Uri.parse(origin);
    return uri
        .replace(scheme: active.scheme, host: active.host, port: null)
        .toString();
  }

  static const String agentLogin = "/agent/login";
  static const String agentLogout = "/agent/logout";
  static const String agentDashboard = "/agent/dashboard";
  static const String agentVpnUsers = "/agent/vpn-users";
  static const String agentPlans = "/agent/plans";
  static const String agentCreditHistory = "/agent/credit-history";
  static const String agentRenewalRequests = "/agent/renewal-requests";
  static const String agentUpdateFcmToken = "/agent/update-fcm-token";
  static const String agentBusinessPlans = "/agent/business-plans";
  static const String agentProfile = "/agent/profile";

  static String agentAssignBusiness(int userId) =>
      "/agent/vpn-users/$userId/assign-business";

  static String agentRemoveBusiness(int userId) =>
      "/agent/vpn-users/$userId/remove-business";

  static const String chatUsers = "/agent/chat/users";
  static String chatHistory(int userId) => "/agent/chat/history/$userId";
  static String chatReply(int userId) => "/agent/chat/reply/$userId";
  static String chatPlanCard(int userId) => "/agent/chat/plan-card/$userId";
  static const String chatSelfRenewalStatus = "/agent/chat/self-renewal-status";
  static const String chatToggleSelfRenewal = "/agent/chat/toggle-self-renewal";
  static String chatExtend(int userId) => "/agent/chat/extend/$userId";
  static const String chatBroadcast = "/agent/chat/broadcast";

  // CONNECT_MONITOR_V1 — super-admin only. These sit under auth:sanctum in
  // routes/api.php; the admin web page reaches the same two services through
  // its own session-authenticated routes.
  static const String agentMonitorSnapshot = "/agent/monitor/snapshot";
  static const String agentMonitorOverall = "/agent/monitor/overall";
  static const String agentMonitorAsk = "/agent/monitor/ask";
}
