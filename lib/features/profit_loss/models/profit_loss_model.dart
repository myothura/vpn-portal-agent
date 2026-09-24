/// The month's figures, mirroring what ProfitLossService computes.
///
/// Everything is an int of MMK. Nothing is recomputed here: the totals are the
/// server's, so the app and the web report cannot disagree about the month.
class ProfitLossSummary {
  final int topupCash;
  final int directSale;
  final int manualRevenue;
  final int revenueTotal;
  final int expenseTotal;
  final int profit;

  /// Named revenue and expense lines, each {name, total}.
  final List<PlLine> revenueLines;
  final List<PlLine> expenseLines;

  const ProfitLossSummary({
    this.topupCash = 0,
    this.directSale = 0,
    this.manualRevenue = 0,
    this.revenueTotal = 0,
    this.expenseTotal = 0,
    this.profit = 0,
    this.revenueLines = const [],
    this.expenseLines = const [],
  });

  /// Profit as a share of revenue. Zero revenue is 0 rather than a division
  /// by zero — a month with no income has no margin, not an error.
  double get margin => revenueTotal == 0 ? 0 : (profit / revenueTotal) * 100;

  factory ProfitLossSummary.fromJson(Map<String, dynamic> json) {
    // AGENT_APP_F1 — PHP encodes an empty associative array as [], so these
    // casts threw on a month with no revenue instead of reporting zero. The
    // local asInt moved to the file-level _int, which the rest of the file
    // now shares.
    final revenue = _map(json['revenue']) ?? const <String, dynamic>{};
    final expense = _map(json['expense']) ?? const <String, dynamic>{};
    final manual = _map(revenue['manual']) ?? const <String, dynamic>{};

    final topup = _int(revenue['topup_cash']);
    final direct = _int(revenue['direct_sale']);
    final manualTotal = _int(manual['total']);

    return ProfitLossSummary(
      topupCash: topup,
      directSale: direct,
      manualRevenue: manualTotal,
      revenueTotal: _int(revenue['total']),
      expenseTotal: _int(expense['total']),
      profit: _int(json['profit']),
      // The two computed lines are listed alongside the manual ones so the
      // breakdown adds up to the total shown above it.
      revenueLines: [
        if (topup > 0) PlLine(name: 'Agent top-up cash', total: topup),
        if (direct > 0)
          PlLine(name: 'Direct sale (Super Admin)', total: direct),
        ...PlLine.listFrom(manual['by_category']),
      ],
      expenseLines: PlLine.listFrom(expense['by_category']),
    );
  }
}

class PlLine {
  final String name;
  final int total;

  const PlLine({required this.name, required this.total});

  /// The service returns by_category as a map of category to total, not a
  /// list of objects — it groups in SQL and plucks the pair.
  static List<PlLine> listFrom(dynamic raw) {
    if (raw is! Map) return const [];
    final lines = raw.entries
        .map((e) => PlLine(name: e.key.toString(), total: _int(e.value)))
        .toList();
    // Largest first: a breakdown is read to find where the money went.
    lines.sort((a, b) => b.total.compareTo(a.total));
    return lines;
  }
}

/// A super-admin sale — one approved renewal, slot purchase or extension.
class DirectSale {
  final int id;
  final int amount;
  final String description;
  final String? username;
  final String action;
  final String createdAt;
  final bool excluded;

  const DirectSale({
    required this.id,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.username,
    this.action = '',
    this.excluded = false,
  });

  /// The user this sale was for, pulled out of the description.
  ///
  /// The server writes seven sentence shapes and stores no user id on the
  /// transaction, so the name has to be read back out of the text. Falls back
  /// to null, and the row then shows the raw description — better than a wrong
  /// name.
  static final _patterns = <RegExp>[
    RegExp(r'Approved renewal for (.+?) to '),
    RegExp(r'Renewed .+? for (.+?) \('),
    RegExp(r'assigned to (.+?)$'),
    RegExp(r'user: (.+?)(?: \(|$)'),
  ];

  static String? _usernameFrom(String description) {
    for (final pattern in _patterns) {
      final match = pattern.firstMatch(description);
      final name = match?.group(1)?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  /// What happened, without the username — the row shows that separately.
  static String _actionFrom(String description) {
    if (description.startsWith('Approved renewal')) return 'Renewal approved';
    if (description.startsWith('Renewed/Changed')) return 'Plan changed';
    if (description.startsWith('Renewed')) return 'Renewed';
    if (description.startsWith('Activated')) return 'Activated';
    if (description.contains('device slot')) return 'Device slot added';
    if (description.startsWith('Business Plan')) return 'Business plan';
    return description;
  }

  factory DirectSale.fromJson(Map<String, dynamic> json, Set<int> excludedIds) {
    final id = _int(json['id']);
    final description = (json['description'] ?? '').toString();

    return DirectSale(
      id: id,
      amount: _int(json['amount']),
      description: description,
      username: _usernameFrom(description),
      action: _actionFrom(description),
      createdAt: (json['created_at'] ?? '').toString(),
      excluded: excludedIds.contains(id),
    );
  }
}

/// Cash an agent paid in, and the credit granted for it.
class TopupRow {
  final int id;
  final int amount;
  final int cashReceived;
  final double bonusPercent;
  final String? agentName;
  final bool countsAsRevenue;
  final String createdAt;

  const TopupRow({
    required this.id,
    required this.amount,
    required this.cashReceived,
    required this.bonusPercent,
    required this.agentName,
    required this.countsAsRevenue,
    required this.createdAt,
  });

  factory TopupRow.fromJson(Map<String, dynamic> json) {
    return TopupRow(
      id: _int(json['id']),
      amount: _int(json['amount']),
      cashReceived: _int(json['cash_received']),
      bonusPercent:
          double.tryParse(json['bonus_percent']?.toString() ?? '0') ?? 0,
      agentName: json['agent_name']?.toString(),
      countsAsRevenue: json['counts_as_revenue'] == true,
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

/// A manually entered revenue or expense line.
class FinanceEntry {
  final int id;
  final String direction;
  final String category;
  final String name;
  final int amount;
  final String? entryDate;

  const FinanceEntry({
    required this.id,
    required this.direction,
    required this.category,
    required this.name,
    required this.amount,
    this.entryDate,
  });

  bool get isExpense => direction == 'expense';

  factory FinanceEntry.fromJson(Map<String, dynamic> json) {
    return FinanceEntry(
      id: _int(json['id']),
      direction: (json['direction'] ?? 'expense').toString(),
      category: (json['category'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      amount: _int(json['amount_mmk']),
      entryDate: json['entry_date']?.toString(),
    );
  }
}

/// Everything the screen needs for one month, in one response.
class ProfitLossReport {
  final String month;
  final List<String> months;
  final ProfitLossSummary summary;
  final List<DirectSale> directSales;
  final int directSalesTotal;
  final int directSalesPage;
  final int directSalesLastPage;
  final List<TopupRow> topups;
  final List<FinanceEntry> entries;

  const ProfitLossReport({
    required this.month,
    required this.months,
    required this.summary,
    required this.directSales,
    required this.directSalesTotal,
    required this.directSalesPage,
    required this.directSalesLastPage,
    required this.topups,
    required this.entries,
  });

  factory ProfitLossReport.fromJson(Map<String, dynamic> json) {
    final direct = _map(json['direct_sales']) ?? const <String, dynamic>{};
    final rawExcluded = direct['excluded_ids'];
    final List<dynamic> excludedList = rawExcluded is List
        ? rawExcluded
        : const <dynamic>[];
    final excluded = excludedList.map((e) => _int(e)).toSet();

    final rawMonths = json['months'];
    final List<dynamic> months = rawMonths is List
        ? rawMonths
        : const <dynamic>[];
    final rawSales = direct['data'];
    final List<dynamic> sales = rawSales is List ? rawSales : const <dynamic>[];
    final rawTopups = json['topups'];
    final List<dynamic> topups = rawTopups is List
        ? rawTopups
        : const <dynamic>[];
    final rawEntries = json['entries'];
    final List<dynamic> entries = rawEntries is List
        ? rawEntries
        : const <dynamic>[];

    return ProfitLossReport(
      month: (json['month'] ?? '').toString(),
      months: months.map((e) => e.toString()).toList(),
      summary: ProfitLossSummary.fromJson(
        _map(json['summary']) ?? const <String, dynamic>{},
      ),
      directSales: sales
          .whereType<Map>()
          .map(
            (e) => DirectSale.fromJson(Map<String, dynamic>.from(e), excluded),
          )
          .toList(),
      // AGENT_APP_F1 — the paging block is built by the paginator and its
      // counters arrive as strings from this endpoint.
      directSalesTotal: _int(direct['total']),
      directSalesPage: _int(direct['current_page'], 1),
      directSalesLastPage: _int(direct['last_page'], 1),
      topups: topups
          .whereType<Map>()
          .map((e) => TopupRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      entries: entries
          .whereType<Map>()
          .map((e) => FinanceEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
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

Map<String, dynamic>? _map(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}
