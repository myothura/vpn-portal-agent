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
    // AGENT_APP_F1 — credit_balance is an int on the update response and a
    // string on the list (it is a SUM), and `p['id'] as int` threw whenever
    // plans came back as bare ids rather than objects, which is the shape
    // toJson itself sends.
    final List<int> parsedPlanIds = [];
    final rawPlans = json['plans'];
    if (rawPlans is List) {
      for (final p in rawPlans) {
        final planId = p is Map ? _int(p['id']) : _int(p);
        if (planId > 0) parsedPlanIds.add(planId);
      }
    }

    return AgentModel(
      id: _int(json['id']),
      name: _str(json['name']),
      email: _str(json['email']),
      creditBalance: _int(json['credit_balance']),
      status: _str(json['status'], 'inactive'),
      canSendNotifications: _bool(json['can_send_notifications']),
      canAccessChat: _bool(json['can_access_chat']),
      canManageAgents: _bool(json['can_manage_agents']),
      topupBonusPercent: _double(json['topup_bonus_percent']),
      createdAt: _str(json['created_at']),
      planIds: parsedPlanIds,
      parentName: _strOrNull(json['parent_name']),
      parentId: _intOrNull(json['parent_id']),
      userCount: _int(json['user_count']),
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

double _double(Object? v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
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

bool _bool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }
  return false;
}
