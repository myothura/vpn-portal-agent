import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/history/models/credit_history_model.dart';
import 'package:vpn_agent_app/features/history/services/credit_history_service.dart';

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  final _service = CreditHistoryService();
  final _scrollController = ScrollController();

  List<CreditTransaction> _rows = [];
  Map<String, int> _totals = {};
  Map<String, int> _counts = {};

  /// null means everything. Sent to the server: the screen holds one page of
  /// twenty out of thousands, so filtering here searched only the most recent
  /// twenty and could show nothing while hundreds matched.
  String? _filter;

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;

  // The column is enum('add','spend'); there is no 'topup' or 'refund'.
  static const _tabs = <(String?, String)>[
    (null, 'All'),
    ('spend', 'Spent'),
    ('add', 'Received'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
        _rows = [];
      });
    }

    final response = await _service.getCreditHistory(
      page: _page,
      type: _filter,
    );
    if (!mounted) return;

    setState(() {
      if (response != null) {
        _rows = refresh
            ? response.transactions
            : [..._rows, ...response.transactions];
        _lastPage = response.lastPage;
        if (response.totals.isNotEmpty) _totals = response.totals;
        if (response.counts.isNotEmpty) _counts = response.counts;
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);

    // PAGE_ROLLBACK_V1 — _page was advanced before the fetch and never put
    // back. One timed-out page meant the next scroll asked for the page
    // after it, so a whole page was skipped for the life of the screen
    // while the footer still read as if the list were complete.
    final before = _rows.length;
    _page++;
    await _load();
    if (mounted && _rows.length == before) _page--;
  }

  void _onFilterChanged(String? type) {
    if (_filter == type) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = type);
    _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Credit history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: _SummaryCard(
              received: _totals['add'] ?? 0,
              spent: _totals['spend'] ?? 0,
              balance: _rows.isEmpty ? null : _rows.first.runningBalance,
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (type, label) = _tabs[i];
                return _FilterChip(
                  label: label,
                  count: _counts[type ?? 'all'] ?? 0,
                  selected: _filter == type,
                  onTap: () => _onFilterChanged(type),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const _ListSkeleton()
                : _rows.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.surface,
                    child: Material(
                      color: AppColors.surface,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _rows.length + 1,
                        itemBuilder: (context, i) {
                          if (i == _rows.length) return _buildFooter();
                          return _TransactionRow(
                            key: ValueKey(_rows[i].id),
                            tx: _rows[i],
                            showDivider: i < _rows.length - 1,
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: AppLoader(compact: true),
      );
    }
    if (_page < _lastPage) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          '${_rows.length} shown',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildEmpty() => switch (_filter) {
    'add' => const AppEmptyState(
      icon: Iconsax.wallet_add,
      title: 'No credit received',
      subtitle: 'Top-ups from your administrator will appear here.',
    ),
    'spend' => const AppEmptyState(
      icon: Iconsax.wallet_minus,
      title: 'Nothing spent yet',
    ),
    _ => const AppEmptyState(
      icon: Iconsax.receipt_item,
      title: 'No transactions',
      subtitle: 'Renewals and top-ups will be listed here.',
    ),
  };
}

// ── Summary ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int received;
  final int spent;

  /// Where the account stands now. Taken from the newest row's
  /// running_balance — it comes free with the page already loaded, and a
  /// ledger showing what went in and out but not the result is half an answer.
  final int? balance;

  const _SummaryCard({
    required this.received,
    required this.spent,
    this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (balance != null) ...[
            Text(
              'Balance',
              style: t.bodySmall?.copyWith(
                color: AppColors.textOnInk.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              money.format(balance),
              style: t.displaySmall?.copyWith(
                color: AppColors.textOnInk,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: AppColors.textOnInk.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _Figure(
                  icon: Iconsax.arrow_down,
                  iconColor: AppColors.accent,
                  label: 'Received',
                  value: money.format(received),
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: AppColors.textOnInk.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Figure(
                  icon: Iconsax.arrow_up_3,
                  iconColor: AppColors.warning,
                  label: 'Spent',
                  value: money.format(spent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _Figure({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: t.bodySmall?.copyWith(
                color: AppColors.textOnInk.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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

// ── Row ───────────────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  final CreditTransaction tx;
  final bool showDivider;

  const _TransactionRow({
    super.key,
    required this.tx,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');
    final isCredit = tx.type == 'add';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              AppIconBadge(
                icon: isCredit ? Iconsax.wallet_add : Iconsax.wallet_minus,
                color: isCredit ? AppColors.accentInk : AppColors.warning,
                background: isCredit
                    ? AppColors.accentWash
                    : AppColors.warningWash,
                size: 17,
                padding: 9,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(_formatDate(tx.createdAt), style: t.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // Signed, because the type is otherwise only carried by
                    // an icon at the far side of the row.
                    '${isCredit ? '+' : '−'}${money.format(tx.amount)}',
                    style: t.titleMedium?.copyWith(
                      fontSize: 14,
                      color: isCredit
                          ? AppColors.accentInk
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (tx.runningBalance > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      money.format(tx.runningBalance),
                      style: t.bodySmall?.copyWith(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 62),
            child: Divider(height: 1),
          ),
      ],
    );
  }

  static String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    final diff = DateTime.now().difference(local);

    // Relative while it is still recent enough to place from memory, absolute
    // once it is not.
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, h:mm a').format(local);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? AppColors.accentInk : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: t.bodySmall?.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Text(
                  count > 999 ? '999+' : '$count',
                  style: t.bodySmall?.copyWith(
                    color: selected
                        ? AppColors.textOnAccent.withValues(alpha: 0.75)
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            AppSkeleton(width: 35, height: 35, radius: AppTheme.radiusSm),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 180, height: 12),
                  SizedBox(height: 7),
                  AppSkeleton(width: 90, height: 10),
                ],
              ),
            ),
            SizedBox(width: 10),
            AppSkeleton(width: 60, height: 13),
          ],
        ),
      ),
    );
  }
}
