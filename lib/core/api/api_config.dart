class ApiConfig {
  static const String baseUrl = "https://control.vpnportal.org/api";

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
}
