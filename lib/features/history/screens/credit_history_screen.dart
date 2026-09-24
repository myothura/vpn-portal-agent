import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

// C_LISTS_CH_IMPORTS — intl is gone: two NumberFormats and a DateFormat, all
// three built inside a build() or a row builder, now point at Fmt.
import '../../../core/utils/formatters.dart';

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

  /// FAIL_L_FIELD — the last fetch came back with nothing and there is nothing
  /// already on screen.
  ///
  /// CreditHistoryService.getCreditHistory returns null for every failure it
  /// can have — a timeout, a 500, a token the server has stopped accepting —
  /// and this screen drew the same "No transactions" state for all of them as
  /// it does for a ledger that is genuinely empty. An agent checking whether
  /// an administrator's top-up had landed was being told that it had not.
  ///
  /// Only true when the screen is blank. A page that fails while rows are
  /// already up keeps the rows and says nothing, which is how the requests
  /// screen and the conversation list both behave.
  bool _failed = false;

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
        _failed = false;
      } else {
        // FAIL_L_LOAD — a refresh has already emptied _rows above, so a failed
        // refresh always lands here with a blank screen and reports it. A page
        // that fails behind rows already on screen leaves them alone and says
        // nothing: the agent is reading them, and a full-screen error over a
        // working list would be worse than a page that quietly did not arrive.
        _failed = _rows.isEmpty;
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
            // C_LISTS_CH_CHIPSCALE — the strip is horizontal, so it has to be
            // given a height; that height is derived from the label rather
            // than written down as 36. A 12pt line at 1.35 plus 10 of padding
            // above and below is 36 at the default text size and grows with
            // it, instead of cutting the chip labels off from about 1.2x up.
            height: MediaQuery.textScalerOf(context).scale(12) * 1.35 + 20,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                // FAIL_L_BRANCH — an empty ledger and a ledger that would not
                // load are different facts, and only one of them is something
                // the agent can act on.
                ? (_failed ? _buildFailed() : _buildEmpty())
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

  /// FAIL_L_STATE — shown instead of the empty state when the fetch failed.
  ///
  /// The same shape as the requests screen's: an icon that says network rather
  /// than ledger, the reason in Burmese, and the retry on the state itself, so
  /// the agent is not left to guess that pulling down is the way back.
  Widget _buildFailed() => AppEmptyState(
    icon: Iconsax.cloud_cross,
    title: 'မှတ်တမ်း ဆွဲယူ၍ မရပါ',
    subtitle: 'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
    actionLabel: 'ထပ်မံကြိုးစားမည်',
    onAction: () => _load(refresh: true),
  );

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
    // C_LISTS_CH_SUMMARYFMT — the shared instance. This build() runs on every
    // frame the card is on screen and constructed a new one each time.
    final money = Fmt.money;

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
    // C_LISTS_CH_ROWFMT — this is a row builder: one NumberFormat was being
    // constructed per visible row per frame, on a ledger that reaches
    // thousands of rows.
    final money = Fmt.money;
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
    // C_LISTS_CH_DATEFMT — Fmt.dateTime is the same pattern, built once.
    return Fmt.dateTime.format(local);
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

/// C_LISTS_CH_SKELETON — one ticker for the whole placeholder list.
///
/// AppSkeleton owns an AnimationController each; eight rows of four bars meant
/// thirty-two of them running the same 1200ms sweep while the screen waited
/// for its first page. One controller lives here and every bar listens to it.
class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();

  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            _SkeletonBar(
              _shimmer,
              width: 35,
              height: 35,
              radius: AppTheme.radiusSm,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(_shimmer, width: 180, height: 12),
                  const SizedBox(height: 7),
                  _SkeletonBar(_shimmer, width: 90, height: 10),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _SkeletonBar(_shimmer, width: 60, height: 13),
          ],
        ),
      ),
    );
  }
}

/// One placeholder bar, painting from an animation it does not own.
class _SkeletonBar extends StatelessWidget {
  final Animation<double> shimmer;
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBar(
    this.shimmer, {
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (context, _) {
          // The gradient slides across a fixed box rather than the box moving,
          // so nothing is laid out again per frame.
          final t = shimmer.value * 2 - 1;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + t, 0),
                end: Alignment(1 + t, 0),
                colors: const [
                  AppColors.surfaceAlt,
                  AppColors.border,
                  AppColors.surfaceAlt,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
