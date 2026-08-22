import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// Equatable so BlocBuilder can tell a genuinely changed poll from an
/// identical one. The 30s auto-poll emits a fresh DashboardStats object every
/// time; without value equality every widget bound to this state rebuilt twice
/// a minute whether or not a single number had moved.
class DashboardStats extends Equatable {
  final String agentName;
  final int activeUserCount;
  final int totalUserCount;
  final int expiringSoonCount;
  final int businessUserCount;
  final int onlineUserCount;
  final int subAgentCount;
  final int creditBalance;
  final int creditsSpent;
  final List<String> recentRequests;

  /// Bottom-nav badge counts. Deliberately separate from recentRequests.length:
  /// that list is capped at 5 and falls back to recently-decided rows when
  /// there is nothing pending, so its length is not a pending count.
  final int pendingRequestCount;
  final int unreadChatCount;

  /// Unread notifications addressed to this agent, for the bell badge.
  final int unreadNotificationCount;

  const DashboardStats({
    required this.agentName,
    required this.activeUserCount,
    required this.totalUserCount,
    required this.expiringSoonCount,
    required this.businessUserCount,
    required this.onlineUserCount,
    required this.subAgentCount,
    required this.creditBalance,
    required this.creditsSpent,
    required this.recentRequests,
    this.pendingRequestCount = 0,
    this.unreadChatCount = 0,
    this.unreadNotificationCount = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      agentName: json['agent_name'] ?? 'Agent',
      activeUserCount: json['active_user_count'] ?? 0,
      totalUserCount: json['total_user_count'] ?? 0,
      expiringSoonCount: json['expiring_soon_count'] ?? 0,
      businessUserCount: json['business_user_count'] ?? 0,
      onlineUserCount: json['online_user_count'] ?? 0,
      subAgentCount: json['sub_agent_count'] ?? 0,
      creditBalance: json['credit_balance'] ?? 0,
      creditsSpent: json['credits_spent_this_month'] != null
          ? int.parse(json['credits_spent_this_month'].toString())
          : 0,
      recentRequests: json['recent_requests'] != null
          ? List<String>.from(json['recent_requests'])
          : [],
      pendingRequestCount: json['pending_request_count'] ?? 0,
      unreadChatCount: json['unread_chat_count'] ?? 0,
      unreadNotificationCount: json['unread_notification_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent_name': agentName,
      'active_user_count': activeUserCount,
      'total_user_count': totalUserCount,
      'expiring_soon_count': expiringSoonCount,
      'business_user_count': businessUserCount,
      'online_user_count': onlineUserCount,
      'sub_agent_count': subAgentCount,
      'credit_balance': creditBalance,
      'credits_spent_this_month': creditsSpent,
      'recent_requests': recentRequests,
      'pending_request_count': pendingRequestCount,
      'unread_chat_count': unreadChatCount,
    };
  }

  String get formattedCreditBalance {
    final formatter = NumberFormat('#,##0');
    return formatter.format(creditBalance);
  }

  String get formattedCreditsSpent {
    final formatter = NumberFormat('#,##0');
    return formatter.format(creditsSpent);
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get firstName {
    return agentName.split(' ').first;
  }

  @override
  List<Object?> get props => [
    agentName,
    activeUserCount,
    totalUserCount,
    expiringSoonCount,
    businessUserCount,
    onlineUserCount,
    subAgentCount,
    creditBalance,
    creditsSpent,
    recentRequests,
    pendingRequestCount,
    unreadChatCount,
    unreadNotificationCount,
  ];
}
