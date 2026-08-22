import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';

class ProfileUser {
  final String name;
  final String email;
  final String telegramUsername;
  final int creditBalance;
  final int activeUserCount;
  final bool canSendNoti;
  final bool canManageAgents;
  final List<PaymentMethod> paymentMethods;

  ProfileUser({
    required this.name,
    required this.email,
    required this.telegramUsername,
    required this.creditBalance,
    required this.activeUserCount,
    required this.canSendNoti,
    required this.canManageAgents,
    required this.paymentMethods,
  });

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      name: json['name'] ?? "Unknown",
      email: json['email'] ?? "No Email",
      telegramUsername: json['telegram_username'] ?? "",
      creditBalance: json['credit_balance'] ?? 0,
      activeUserCount: json['active_user_count'] ?? 0,
      canSendNoti: json['can_send_notifications'] ?? false,
      canManageAgents: json['can_manage_agents'] ?? false,
      paymentMethods:
          (json['payment_details'] as List?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'telegram_username': telegramUsername,
      'credit_balance': creditBalance,
      'active_user_count': activeUserCount,
      'can_send_notifications': canSendNoti,
      'can_manage_agents': canManageAgents,
      'payment_details': paymentMethods.map((e) => e.toJson()).toList(),
    };
  }
}
