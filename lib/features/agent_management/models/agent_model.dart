class AgentModel {
  final int id;
  final String name;
  final String email;
  final int creditBalance;
  final String status;
  final bool canSendNotifications;
  final bool canAccessChat;

  /// Authority to create and edit sub-agents. The column and the update
  /// endpoint have always carried it; the list endpoint never returned it, so
  /// the app could neither show nor set it.
  final bool canManageAgents;

  /// Bonus credited on top of a cash top-up, as a percentage. Priced into
  /// every top-up and central to the P&L, but the list endpoint never returned
  /// it — agents on 20% and 50% looked identical in the app.
  final double topupBonusPercent;
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
    this.canManageAgents = false,
    this.topupBonusPercent = 0,
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
      canManageAgents:
          json['can_manage_agents'] == 1 || json['can_manage_agents'] == true,
      topupBonusPercent:
          double.tryParse(json['topup_bonus_percent']?.toString() ?? '0') ?? 0,
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
      'can_manage_agents': canManageAgents,
      'topup_bonus_percent': topupBonusPercent,
      'plans': planIds,
    };
  }
}
