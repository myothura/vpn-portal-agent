class VpnUser {
  final int id;
  final String username;
  final String? planName;
  final String status;
  final String? expiryDate;
  final bool isOnline;
  final int extraDeviceSlots;
  final int? businessPlanId;
  final String? businessPlanName;
  final int? businessPlanPrice;
  final bool hasBusinessPlan;

  VpnUser({
    required this.id,
    required this.username,
    this.planName,
    required this.status,
    this.expiryDate,
    this.isOnline = false,
    this.extraDeviceSlots = 0,
    this.businessPlanId,
    this.businessPlanName,
    this.businessPlanPrice,
    this.hasBusinessPlan = false,
  });

  factory VpnUser.fromJson(Map<String, dynamic> json) {
    return VpnUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? 'N/A',
      planName: json['plan']?['plan_name'],
      status: json['status'] ?? 'inactive',
      expiryDate: json['subscription_expiry_date'],
      isOnline: json['is_online'] ?? false,
      extraDeviceSlots: json['extra_device_slots'] ?? 0,
      businessPlanId: json['business_plan_id'],
      businessPlanName: json['business_plan']?['plan_name'],
      businessPlanPrice: json['business_plan']?['price_per_month_credits'],
      hasBusinessPlan:
          json['has_business_plan'] ?? json['business_plan_id'] != null,
    );
  }
}

class VpnUserResponse {
  final List<VpnUser> users;
  final int currentPage;
  final int lastPage;

  /// Rows matching the query across every page, not just the ones returned.
  /// `users.length` is a page — showing it as a count told the agent there
  /// were 10 accounts expiring when there were 359.
  final int total;

  VpnUserResponse({
    required this.users,
    required this.currentPage,
    required this.lastPage,
    this.total = 0,
  });

  factory VpnUserResponse.fromJson(Map<String, dynamic> json) {
    var userList = json['data'] as List;
    List<VpnUser> users = userList.map((i) => VpnUser.fromJson(i)).toList();
    return VpnUserResponse(
      users: users,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      total: json['total'] ?? users.length,
    );
  }
}
