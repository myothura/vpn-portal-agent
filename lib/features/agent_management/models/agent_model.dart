class AgentModel {
  final int id;
  final String name;
  final String email;
  final int creditBalance;
  final String status;
  final bool canSendNotifications;
  final bool canAccessChat;
  final String createdAt;
  final List<int> planIds;
  final String? parentName;
  final int? parentId;
  final int userCount;

  AgentModel({
    required this.id,
    required this.name,
    required this.email,
    required this.creditBalance,
    required this.status,
    required this.canSendNotifications,
    required this.canAccessChat,
    required this.createdAt,
    this.planIds = const [],
    this.parentName,
    this.parentId,
    this.userCount = 0,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    List<int> parsedPlanIds = [];
    if (json['plans'] != null) {
      parsedPlanIds = (json['plans'] as List)
          .map((p) => p['id'] as int)
          .toList();
    }

    return AgentModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      creditBalance: json['credit_balance'] ?? 0,
      status: json['status'] ?? 'inactive',
      canSendNotifications:
          json['can_send_notifications'] == 1 ||
          json['can_send_notifications'] == true,
      canAccessChat:
          json['can_access_chat'] == 1 || json['can_access_chat'] == true,
      createdAt: json['created_at'] ?? '',
      planIds: parsedPlanIds,
      parentName: json['parent_name'],
      parentId: json['parent_id'],
      userCount: json['user_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'credit_balance': creditBalance,
      'status': status,
      'can_send_notifications': canSendNotifications,
      'can_access_chat': canAccessChat,
      'plans': planIds,
    };
  }
}
