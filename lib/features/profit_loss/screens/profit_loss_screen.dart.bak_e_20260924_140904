import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/profit_loss/models/profit_loss_model.dart';
import 'package:vpn_agent_app/features/profit_loss/services/profit_loss_service.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  final _service = ProfitLossService();

  final _scrollController = ScrollController();

  ProfitLossReport? _report;
  String? _month;
  bool _loading = true;
  bool _busy = false;

  /// Direct sales accumulate across pages; the rest of the report is replaced
  /// each load. 510 rows in a month is normal and the list is the only part
  /// of this screen that pages.
  List<DirectSale> _sales = [];
  bool _loadingMore = false;
  int _salesPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 600) _loadMoreSales();
  }

  Future<void> _loadMoreSales() async {
    final report = _report;
    if (_loadingMore || _loading || report == null) return;
    if (_salesPage >= report.directSalesLastPage) return;

    setState(() => _loadingMore = true);
    final next = await _service.getReport(month: _month, page: _salesPage + 1);
    if (!mounted) return;

    setState(() {
      if (next != null) {
        _sales = [..._sales, ...next.directSales];
        _salesPage = next.directSalesPage;
      }
      _loadingMore = false;
    });
  }

  Future<void> _load({String? month}) async {
    setState(() => _loading = true);
    final report = await _service.getReport(month: month ?? _month);
    if (!mounted) return;
    setState(() {
      _report = report;
      _sales = report?.directSales ?? [];
      _salesPage = report?.directSalesPage ?? 1;
      _month = report?.month ?? month ?? _month;
      _loading = false;
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _addEntry(String direction) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EntrySheet(direction: direction),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    final ok = await _service.addEntry(
      direction: direction,
      category: result['category'] as String,
      name: result['name'] as String,
      amount: result['amount'] as int,
      periodMonth: _month ?? '',
      notes: result['notes'] as String?,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    _toast(ok ? 'Entry added.' : 'Could not add the entry.');
    if (ok) _load();
  }

  Future<void> _deleteEntry(FinanceEntry entry) async {
    final ok = await _confirm(
      title: 'Remove ${entry.name}?',
      body:
          '${NumberFormat('#,##0').format(entry.amount)} Ks will come out of '
          "this month's ${entry.isExpense ? 'expenses' : 'revenue'}.",
      action: 'Remove',
      color: AppColors.danger,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final done = await _service.deleteEntry(entry.id);
    if (!mounted) return;
    setState(() => _busy = false);

    _toast(done ? 'Entry removed.' : 'Could not remove it.');
    if (done) _load();
  }

  Future<void> _copyExpenses() async {
    final ok = await _confirm(
      title: "Copy last month's expenses?",
      body:
          'Recurring costs are brought forward. Anything already entered '
          'this month under the same name is skipped.',
      action: 'Copy',
      color: AppColors.accentInk,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final copied = await _service.copyExpenses(_month ?? '');
    if (!mounted) return;
    setState(() => _busy = false);

    if (copied == null) {
      _toast('Could not copy.');
      return;
    }
    _toast(
      copied == 0
          ? 'Nothing to copy — this month already has them.'
          : 'Copied $copied ${copied == 1 ? 'entry' : 'entries'}.',
    );
    if (copied > 0) _load();
  }

  Future<void> _toggleExclude(DirectSale sale) async {
    final money = NumberFormat('#,##0');

    final ok = await _confirm(
      title: sale.excluded ? 'Count this again?' : 'Exclude from revenue?',
      body: sale.excluded
          ? '${money.format(sale.amount)} Ks goes back into this '
                "month's revenue."
          : '${money.format(sale.amount)} Ks comes out of this month\'s '
                'revenue. This is reversible.',
      action: sale.excluded ? 'Count it' : 'Exclude',
      color: sale.excluded ? AppColors.accentInk : AppColors.warning,
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final result = await _service.toggleExclude(sale.id);
    if (!mounted) return;

    if (result == null) {
      setState(() => _busy = false);
      _toast('Could not change it.');
      return;
    }

    // The row flips locally and only the totals are refetched. A full reload
    // reset the list to page one, so excluding the fortieth sale threw away
    // everything scrolled past to reach it.
    final index = _sales.indexWhere((s) => s.id == sale.id);
    if (index != -1) {
      setState(() {
        _sales[index] = DirectSale(
          id: sale.id,
          amount: sale.amount,
          description: sale.description,
          username: sale.username,
          action: sale.action,
          createdAt: sale.createdAt,
          excluded: result,
        );
      });
    }

    await _refreshTotals();
  }

  /// Re-reads the month's figures without disturbing the loaded sales.
  ///
  /// Excluding a row changes revenue and profit, which are computed server
  /// side; page one is the cheapest way to get them back.
  Future<void> _refreshTotals() async {
    final fresh = await _service.getReport(month: _month);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _report = fresh;
      _busy = false;
    });
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String action,
    required Color color,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profit & loss'),
        actions: [
          if (report != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              position: PopupMenuPosition.under,
              onSelected: (v) {
                if (v == 'copy') _copyExpenses();
                if (v == 'revenue') _addEntry('revenue');
                if (v == 'expense') _addEntry('expense');
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'expense', child: Text('Add expense')),
                PopupMenuItem(value: 'revenue', child: Text('Add revenue')),
                PopupMenuItem(
                  value: 'copy',
                  child: Text("Copy last month's expenses"),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : report == null
          ? _buildError()
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(),
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.surface,
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        _MonthPicker(
                          month: report.month,
                          months: report.months,
                          onChanged: (m) => _load(month: m),
                        ),
                        const SizedBox(height: 14),
                        _HeadlineCard(summary: report.summary),
                        const SizedBox(height: 20),
                        _Breakdown(
                          title: 'Revenue',
                          lines: report.summary.revenueLines,
                          total: report.summary.revenueTotal,
                          color: AppColors.accentInk,
                        ),
                        const SizedBox(height: 16),
                        _Breakdown(
                          title: 'Expenses',
                          lines: report.summary.expenseLines,
                          total: report.summary.expenseTotal,
                          color: AppColors.danger,
                        ),
                        if (report.entries.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionHead(
                            icon: Iconsax.edit_2,
                            color: AppColors.violet,
                            title: 'Manual entries',
                            subtitle: 'Costs and income entered by hand',
                            count: report.entries.length,
                          ),
                          const SizedBox(height: 10),
                          for (final entry in report.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _EntryRow(
                                entry: entry,
                                onDelete: () => _deleteEntry(entry),
                              ),
                            ),
                        ],
                        if (report.topups.isNotEmpty) ...[
                          const SizedBox(height: 22),
                          _SectionHead(
                            icon: Iconsax.wallet_add,
                            color: AppColors.accentInk,
                            title: 'Agent top-ups',
                            // Says which of the two numbers on each row is the
                            // revenue: the cash, not the credit granted.
                            subtitle: 'Cash paid in by agents',
                            count: report.topups.length,
                          ),
                          const SizedBox(height: 10),
                          for (final row in report.topups)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TopupRowCard(row: row),
                            ),
                        ],
                        const SizedBox(height: 22),
                        _SectionHead(
                          icon: Iconsax.shopping_cart,
                          color: AppColors.info,
                          title: 'Direct sales',
                          // Says what tapping does before the agent taps: it
                          // changes the month's revenue.
                          subtitle: 'Tap a row to exclude it from revenue',
                          count: report.directSalesTotal,
                        ),
                        const SizedBox(height: 10),
                        for (final sale in _sales)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SaleRow(
                              sale: sale,
                              onTap: () => _toggleExclude(sale),
                            ),
                          ),
                        if (_loadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: AppLoader(compact: true),
                          )
                        else if (_salesPage < report.directSalesLastPage)
                          const SizedBox(height: 20)
                        else if (report.directSalesTotal > 0) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              '${report.directSalesTotal} sales this month',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppEmptyState(
            icon: Iconsax.chart_2,
            title: 'Could not load the report',
            subtitle: 'This is only available to the main account.',
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => _load(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Month ─────────────────────────────────────────────────────────────────

class _MonthPicker extends StatelessWidget {
  final String month;
  final List<String> months;
  final ValueChanged<String> onChanged;

  const _MonthPicker({
    required this.month,
    required this.months,
    required this.onChanged,
  });

  static String _label(String raw) {
    final parsed = DateTime.tryParse('$raw-01');
    return parsed == null ? raw : DateFormat('MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      // Horizontal, newest first: the current month is what is usually wanted,
      // and a dropdown of thirteen would hide it behind a tap.
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = months[i];
          final selected = m == month;
          return Material(
            color: selected ? AppColors.accentInk : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: selected ? null : () => onChanged(m),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? AppColors.accentInk : AppColors.border,
                  ),
                ),
                child: Text(
                  _label(m),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.textOnAccent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Headline ──────────────────────────────────────────────────────────────

class _HeadlineCard extends StatelessWidget {
  final ProfitLossSummary summary;

  const _HeadlineCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');
    final profitable = summary.profit >= 0;

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Profit',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textOnInk.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              AppPill(
                label: '${summary.margin.toStringAsFixed(0)}% margin',
                color: AppColors.ink,
                background: profitable ? AppColors.accent : AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            money.format(summary.profit),
            style: t.displaySmall?.copyWith(
              fontSize: 32,
              color: profitable ? AppColors.textOnInk : AppColors.danger,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.textOnInk.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InkFigure(
                  label: 'Revenue',
                  value: money.format(summary.revenueTotal),
                  color: AppColors.accent,
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.textOnInk.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InkFigure(
                  label: 'Expenses',
                  value: money.format(summary.expenseTotal),
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InkFigure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InkFigure({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: t.bodySmall?.copyWith(
                color: AppColors.textOnInk.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleLarge?.copyWith(color: AppColors.textOnInk),
        ),
      ],
    );
  }
}

// ── Breakdown ─────────────────────────────────────────────────────────────

class _Breakdown extends StatelessWidget {
  final String title;
  final List<PlLine> lines;
  final int total;
  final Color color;

  const _Breakdown({
    required this.title,
    required this.lines,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: t.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                money.format(total),
                style: t.titleMedium?.copyWith(fontSize: 15, color: color),
              ),
            ],
          ),
          if (lines.isEmpty) ...[
            const SizedBox(height: 10),
            Text('Nothing recorded', style: t.bodySmall),
          ] else
            for (final line in lines) ...[
              const SizedBox(height: 12),
              _BreakdownLine(line: line, total: total, color: color),
            ],
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  final PlLine line;
  final int total;
  final Color color;

  const _BreakdownLine({
    required this.line,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');
    final share = total == 0 ? 0.0 : line.total / total;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money.format(line.total),
              style: t.bodyLarge?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // A bar per line, scaled to the section total: which line dominates is
        // the question a breakdown is read to answer, and eight numbers in a
        // column do not answer it at a glance.
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 4,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── Rows ──────────────────────────────────────────────────────────────────

class _EntryRow extends StatelessWidget {
  final FinanceEntry entry;
  final VoidCallback onDelete;

  const _EntryRow({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      child: Row(
        children: [
          AppPill(
            label: entry.isExpense ? 'expense' : 'revenue',
            color: entry.isExpense ? AppColors.danger : AppColors.accentInk,
            background: entry.isExpense
                ? AppColors.dangerWash
                : AppColors.accentWash,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(entry.category, style: t.bodySmall),
              ],
            ),
          ),
          Text(
            money.format(entry.amount),
            style: t.bodyLarge?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: entry.isExpense ? AppColors.danger : AppColors.accentInk,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Iconsax.trash, size: 16),
            color: AppColors.textTertiary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TopupRowCard extends StatelessWidget {
  final TopupRow row;

  const _TopupRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.agentName ?? 'Unknown agent',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyLarge?.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (row.bonusPercent > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentWash,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '+${row.bonusPercent.toStringAsFixed(0)}%',
                          style: t.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentInk,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  // Cash is the revenue; credit is what they got for it. Both
                  // matter and they are not the same number.
                  '${money.format(row.cashReceived)} cash '
                  '→ ${money.format(row.amount)} credit',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          if (!row.countsAsRevenue)
            const AppPill(
              label: 'not revenue',
              color: AppColors.neutral,
              background: AppColors.neutralWash,
            ),
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final DirectSale sale;
  final VoidCallback onTap;

  const _SaleRow({required this.sale, required this.onTap});

  static const _avatars = [
    'assets/images/avatars/a1.png',
    'assets/images/avatars/a2.png',
  ];

  static String _avatarFor(String username) {
    if (username.isEmpty) return _avatars.first;
    var hash = 0;
    for (final code in username.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _avatars[hash % _avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');
    final username = sale.username;

    return AppCard(
      onTap: onTap,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      tone: sale.excluded ? SurfaceTone.wash : SurfaceTone.plain,
      washColor: AppColors.surfaceAlt,
      child: Row(
        children: [
          // The same portraits as the user list, so a name recognised there is
          // recognisable here. Greyed when the row is excluded.
          Opacity(
            opacity: sale.excluded ? 0.4 : 1,
            child: username == null
                ? Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Iconsax.receipt_item,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  )
                : ClipOval(
                    child: Image.asset(
                      _avatarFor(username),
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The username leads, because that is what an agent scans
                  // for. The full sentence was 60 characters of boilerplate
                  // with the name buried in the middle.
                  username ?? sale.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: sale.excluded
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                    decoration: sale.excluded
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (username != null) ...[
                      Flexible(
                        child: Text(
                          sale.action,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ),
                      Text(' · ', style: t.bodySmall),
                    ],
                    Text(_date(sale.createdAt), style: t.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money.format(sale.amount),
                style: t.bodyLarge?.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: sale.excluded
                      ? AppColors.textTertiary
                      : AppColors.accentInk,
                ),
              ),
              if (sale.excluded) ...[
                const SizedBox(height: 2),
                Text(
                  'excluded',
                  style: t.bodySmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _date(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM, h:mm a').format(parsed.toLocal());
  }
}

// ── Entry sheet ───────────────────────────────────────────────────────────

class _EntrySheet extends StatefulWidget {
  final String direction;

  const _EntrySheet({required this.direction});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  late String _category = widget.direction == 'expense' ? 'vps' : 'wholesale';

  // The categories already in the data, each with an icon. Free text would
  // fragment the breakdown into one line per spelling of "VPS".
  static const _expense = <({String key, String label, IconData icon})>[
    (key: 'vps', label: 'VPS', icon: Iconsax.cloud),
    (key: 'domain', label: 'Domain', icon: Iconsax.global),
    (key: 'tools', label: 'Tools', icon: Iconsax.setting_4),
    (key: 'other', label: 'Other', icon: Iconsax.category),
  ];

  static const _revenue = <({String key, String label, IconData icon})>[
    (key: 'wholesale', label: 'Wholesale', icon: Iconsax.shop),
    (key: 'other', label: 'Other', icon: Iconsax.category),
  ];

  bool get _isExpense => widget.direction == 'expense';
  Color get _accent => _isExpense ? AppColors.danger : AppColors.accentInk;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, {
      'category': _category,
      'name': _name.text.trim(),
      'amount': int.parse(_amount.text.trim()),
      'notes': _notes.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final categories = _isExpense ? _expense : _revenue;
    final amount = int.tryParse(_amount.text.trim()) ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 6,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: _isExpense ? Iconsax.arrow_up_3 : Iconsax.arrow_down,
                    color: _accent,
                    background: _accent.withValues(alpha: 0.12),
                    size: 17,
                    padding: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isExpense ? 'Add expense' : 'Add revenue',
                          style: t.titleLarge,
                        ),
                        Text(
                          _isExpense
                              ? "Comes off this month's profit"
                              : "Adds to this month's revenue",
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Amount first and large: it is the number being recorded, and
              // typing it into a standard field below two others buried it.
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.center,
                style: t.displaySmall?.copyWith(
                  fontSize: 30,
                  color: amount > 0 ? _accent : AppColors.textTertiary,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: t.displaySmall?.copyWith(
                    fontSize: 30,
                    color: AppColors.borderStrong,
                  ),
                  suffixText: 'Ks',
                  filled: true,
                  fillColor: AppColors.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    borderSide: BorderSide(color: _accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                validator: (v) {
                  final value = int.tryParse((v ?? '').trim());
                  return (value == null || value < 1)
                      ? 'Enter an amount'
                      : null;
                },
              ),
              const SizedBox(height: 18),
              Text('Category', style: t.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < categories.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _CategoryTile(
                        label: categories[i].label,
                        icon: categories[i].icon,
                        color: _accent,
                        selected: _category == categories[i].key,
                        onTap: () =>
                            setState(() => _category = categories[i].key),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: _isExpense ? 'ReadyIDC, Cloudflare…' : 'Who paid',
                  prefixIcon: const Icon(Iconsax.tag, size: 18),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                child: Text(
                  amount > 0
                      ? 'Add ${NumberFormat('#,##0').format(amount)} Ks'
                      : 'Add',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One category, as a tile rather than a Material ChoiceChip — the chip's
/// default styling ignores the app's palette and shape entirely.
class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section heading with its own icon, a one-line explanation and a count.
///
/// The three lists below the summary are different kinds of thing — money
/// entered by hand, cash from agents, sales to users — and a plain bold word
/// above each of them did not say which was which.
class _SectionHead extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int count;

  const _SectionHead({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      children: [
        AppIconBadge(
          icon: icon,
          color: color,
          background: color.withValues(alpha: 0.12),
          size: 15,
          padding: 8,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.bodyLarge?.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(subtitle, style: t.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
        AppPill(
          label: '$count',
          color: color,
          background: color.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}
