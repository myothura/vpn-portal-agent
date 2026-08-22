class CreditTransaction {
  final int id;
  final String type;
  final int amount;
  final String description;
  final String createdAt;
  final int runningBalance;

  CreditTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.runningBalance = 0,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      amount: json['amount'] is int
          ? json['amount']
          : int.tryParse(json['amount'].toString()) ?? 0,
      description: json['description'] ?? 'No description',
      createdAt: json['created_at'] ?? '',
      runningBalance: json['running_balance'] is int
          ? json['running_balance']
          : int.tryParse(json['running_balance']?.toString() ?? '0') ?? 0,
    );
  }
}

class CreditHistoryResponse {
  final List<CreditTransaction> transactions;
  final int currentPage;
  final int lastPage;

  CreditHistoryResponse({
    required this.transactions,
    required this.currentPage,
    required this.lastPage,
  });

  factory CreditHistoryResponse.fromJson(Map<String, dynamic> json) {
    var transactionList = json['data'] as List;
    List<CreditTransaction> transactions = transactionList
        .map((i) => CreditTransaction.fromJson(i))
        .toList();
    return CreditHistoryResponse(
      transactions: transactions,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }
}
