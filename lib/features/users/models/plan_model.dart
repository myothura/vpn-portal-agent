class Plan {
  final int id;
  final String planName;
  final int price;

  Plan({required this.id, required this.planName, required this.price});

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      id: json['id'],
      planName: json['plan_name'] ?? 'Unknown Plan',
      price: json['price_per_month_credits'] ?? 0,
    );
  }
}

class BusinessPlan {
  final int id;
  final String planName;
  final int price;
  final int serverCount;

  BusinessPlan({
    required this.id,
    required this.planName,
    required this.price,
    this.serverCount = 0,
  });

  factory BusinessPlan.fromJson(Map<String, dynamic> json) {
    return BusinessPlan(
      id: json['id'],
      planName: json['plan_name'] ?? 'Unknown',
      price: json['price_per_month_credits'] ?? json['price'] ?? 0,
      serverCount: json['server_count'] ?? 0,
    );
  }
}
