import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vpn_agent_app/core/services/agent_realtime_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/utils/formatters.dart';
import 'package:vpn_agent_app/core/widgets/confirm_dialog.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:vpn_agent_app/features/history/models/renewal_request_model.dart';
import 'package:vpn_agent_app/features/history/services/renewal_service.dart';

/// How a request type is presented. The backend already labels each request;
/// this only supplies the colour and icon that distinguish a device-slot
/// purchase from a plan renewal at a glance down a list.
class _RequestKind {
  final IconData icon;
  final Color color;
  final Color wash;
  final String label;

  const _RequestKind(this.icon, this.color, this.wash, this.label);

  static _RequestKind of(String type) => switch (type) {
    'device_slot' => const _RequestKind(
      Iconsax.mobile,
      AppColors.info,
      AppColors.infoWash,
      'Device slot',
    ),
    'business_plan' => const _RequestKind(
      Iconsax.briefcase,
      AppColors.orange,
      AppColors.orangeWash,
      'Business plan',
    ),
    _ => const _RequestKind(
      Iconsax.refresh_circle,
      AppColors.accentInk,
      AppColors.accentWash,
      'Renewal',
    ),
  };
}

class _StatusStyle {
  final Color color;
  final Color wash;
  final String label;

  const _StatusStyle(this.color, this.wash, this.label);

  static _StatusStyle of(String status) => switch (status) {
    'approved' => const _StatusStyle(
      AppColors.success,
      AppColors.successWash,
      'Approved',
    ),
    'rejected' => const _StatusStyle(
      AppColors.danger,
      AppColors.dangerWash,
      'Rejected',
    ),
    _ => const _StatusStyle(
      AppColors.warning,
      AppColors.warningWash,
      'Pending',
    ),
  };
}

class RenewalRequestsScreen extends StatefulWidget {
  const RenewalRequestsScreen({super.key});

  @override
  State<RenewalRequestsScreen> createState() => _RenewalRequestsScreenState();
}

class _RenewalRequestsScreenState extends State<RenewalRequestsScreen> {
  final _service = RenewalRequestService();
  final _scrollController = ScrollController();

  List<RenewalRequest> _requests = [];
  Map<String, int> _counts = {};

  /// null means "all". Sent to the server rather than applied here: the screen
  /// holds one page of twenty out of thousands, so filtering locally searched
  /// only the most recent twenty and could show nothing while hundreds
  /// matched.
  String? _filter = 'pending';

  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _lastPage = 1;

  /// LIST_FAILURE_STATE_V1 — set when a fetch came back with nothing AND
  /// there is nothing already on screen. An empty list and a list that failed
  /// to load are different facts and the agent can only act on one of them.
  bool _failed = false;

  /// Ids currently being approved or rejected, so a row can show its own
  /// progress instead of an overlay blocking the whole list.
  final Set<int> _busyIds = {};

  // Each tab wears the colour of the status it selects, so the chip row and
  // the badges on the cards below it agree.
  static const _tabs = <(String?, String, Color)>[
    ('pending', 'Pending', AppColors.warning),
    ('approved', 'Approved', AppColors.success),
    ('rejected', 'Rejected', AppColors.danger),
    (null, 'All', AppColors.accentInk),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // A request arriving while this screen is open now appears without a pull
    // to refresh. The push notification only helps an agent who is elsewhere.
    AgentRealtimeService.instance.start();
    AgentRealtimeService.instance.addRenewalListener(_onNewRequest);

    // The tabs are kept alive, so switching back here does not re-run this
    // method and nothing refetched. A request that arrived while the agent was
    // on another tab was missing from the pending list until a filter chip was
    // tapped — the chip reloads, the tab switch did not.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _visibleTab = MainShell.of(context)?.visibleTab;
      _visibleTab?.addListener(_onTabChanged);
    });

    _load(refresh: true);
  }

  /// The shell's visible-tab notifier, held so it can be detached in dispose.
  ValueNotifier<String>? _visibleTab;

  void _onTabChanged() {
    if (!mounted || _visibleTab?.value != 'Requests') return;
    _load(refresh: true);
    _refreshBadge();
  }

  @override
  void dispose() {
    _visibleTab?.removeListener(_onTabChanged);
    AgentRealtimeService.instance.removeRenewalListener(_onNewRequest);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 600) _loadMore();
  }

  /// Pulls the nav badge back in step with this screen.
  ///
  /// The badge reads DashboardBloc, which polls every 30 seconds, so approving
  /// a request cleared it from the list while the count above kept the old
  /// number for up to half a minute.
  void _refreshBadge() {
    if (!mounted) return;
    context.read<DashboardBloc>().add(DashboardRefreshed());
  }

  void _onNewRequest(Map<String, dynamic> _) {
    if (!mounted) return;
    _refreshBadge();
    // Refetched rather than inserted: the counts and the estimated cost are
    // computed server-side, and a locally-built row would be missing both.
    _load(refresh: true);
  }

  /// REFRESH_IN_PLACE_V1 — a reload keeps the rows it already has.
  ///
  /// This used to clear _requests and raise the skeleton before every fetch,
  /// so an arriving request, a tab return or a pull to refresh replaced the
  /// list being read with five grey cards for the length of a round trip. The
  /// skeleton belongs to a screen that has never loaded anything; a reload
  /// swaps the rows when the response lands and shows nothing in between.
  ///
  /// [clearFirst] is for a filter change, which is a different query — there
  /// the old rows are the wrong status and holding them on screen would be a
  /// lie rather than a courtesy.
  Future<void> _load({bool refresh = false, bool clearFirst = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        if (clearFirst) _requests = [];
        _loading = _requests.isEmpty;
      });
    }

    final response = await _service.getRenewalRequests(
      page: _page,
      status: _filter,
    );
    if (!mounted) return;

    setState(() {
      if (response != null) {
        _requests = refresh
            ? response.requests
            : [..._requests, ...response.requests];
        _lastPage = response.lastPage;
        if (response.counts.isNotEmpty) _counts = response.counts;
        _failed = false;
      } else {
        // Only a failure worth showing when it leaves the screen blank.
        _failed = _requests.isEmpty;
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
    final before = _requests.length;
    _page++;
    await _load();
    if (mounted && _requests.length == before) _page--;
  }

  void _onFilterChanged(String? status) {
    if (_filter == status) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = status);
    // Cleared: a different status is a different query, and the rows on
    // screen belong to the tab being left.
    _load(refresh: true, clearFirst: true);
  }

  // ── Decisions ──

  /// APPROVE_SHOWS_COST_V1 — the dialog names the amount.
  ///
  /// The figure is already on the card the agent tapped; it was simply not
  /// carried into the confirmation, which said only that credit would be
  /// deducted. That is the one thing the agent already knew.
  Future<void> _approve(RenewalRequest request) async {
    final confirmed = await confirmAction(
      context,
      title: 'တောင်းဆိုမှုကို အတည်ပြုမလား',
      message: 'အတည်ပြုပါက အောက်ပါပမာဏကို သင့် Credit မှ ချက်ချင်း နုတ်ယူပါမည်။',
      details: [
        ConfirmDetail('အသုံးပြုသူ', request.vpnUserName),
        ConfirmDetail('အစီအစဉ်', request.subtitle),
        ConfirmDetail(
          'ကုန်ကျမည့် Credit',
          '${Fmt.money.format(request.estimatedCost)} MMK',
          emphasise: true,
        ),
      ],
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(request.id));
    final ok = await _service.approveRequest(request.id);
    if (!mounted) return;
    setState(() => _busyIds.remove(request.id));

    _toast(ok ? 'Request approved.' : 'Could not approve. Check your balance.');
    if (ok) {
      _load(refresh: true);
      _refreshBadge();
    }
  }

  Future<void> _reject(RenewalRequest request) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.close_circle,
          color: AppColors.danger,
          background: AppColors.dangerWash,
          size: 22,
          padding: 12,
        ),
        title: const Text('Reject this request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.vpnUserName} — ${request.subtitle}',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Reason (shown to the user)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            // A reason is required: the user sees this, and "rejected" with no
            // explanation just becomes a support message the agent answers by
            // hand anyway.
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    // REJECT_CONTROLLER_DISPOSE_V1 — the dialog has closed and its field went
    // with it, but a TextEditingController is a ChangeNotifier and stays
    // registered until it is disposed. One was leaked per rejection.
    controller.dispose();

    if (reason == null || reason.isEmpty || !mounted) {
      if (reason != null && reason.isEmpty) _toast('Add a reason to reject.');
      return;
    }

    setState(() => _busyIds.add(request.id));
    final ok = await _service.rejectRequest(request.id, reason);
    if (!mounted) return;
    setState(() => _busyIds.remove(request.id));

    _toast(ok ? 'Request rejected.' : 'Could not reject the request.');
    if (ok) {
      _load(refresh: true);
      _refreshBadge();
    }
  }

  // LOCAL_CONFIRM_REMOVED_V1 — the screen's own _confirm lived here. Its one
  // caller now uses confirmAction from core/widgets, which shows the amount
  // being spent rather than only naming the action.

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _viewScreenshot(RenewalRequest request) {
    if (request.screenshotUrl.isEmpty) {
      _toast('No payment screenshot was attached.');
      return;
    }
    Navigator.of(context).push(
      // opaque: false so the list stays rendered underneath the scrim; a
      // normal route would cut it away entirely.
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => _ScreenshotViewer(
          url: request.screenshotUrl,
          title: request.vpnUserName,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _RequestsBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Plain gap, not SafeArea.minimum: that only applies when the
                // value exceeds the system inset, and the status bar is already
                // taller than any sensible padding here — so it did nothing.
                const SizedBox(height: 14),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tabs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final (status, label, color) = _tabs[i];
                      return _FilterChip(
                        label: label,
                        color: color,
                        count: _counts[status ?? 'all'] ?? 0,
                        selected: _filter == status,
                        onTap: () => _onFilterChanged(status),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const _ListSkeleton()
                      : _requests.isEmpty
                      ? (_failed ? _buildFailed() : _buildEmpty())
                      : RefreshIndicator(
                          onRefresh: () => _load(refresh: true),
                          color: AppColors.accentInk,
                          backgroundColor: AppColors.surface,
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: _requests.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              if (i == _requests.length) {
                                return _buildFooter();
                              }
                              final request = _requests[i];
                              return _RequestCard(
                                request: request,
                                busy: _busyIds.contains(request.id),
                                onApprove: () => _approve(request),
                                onReject: () => _reject(request),
                                onViewScreenshot: () =>
                                    _viewScreenshot(request),
                              );
                            },
                          ),
                        ),
                ),
              ],
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
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: Text(
          '${_requests.length} shown',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildEmpty() => switch (_filter) {
    'pending' => const AppEmptyState(
      icon: Iconsax.tick_circle,
      title: 'Nothing waiting',
      subtitle: 'Every request has been dealt with.',
    ),
    'rejected' => const AppEmptyState(
      icon: Iconsax.close_circle,
      title: 'No rejected requests',
    ),
    'approved' => const AppEmptyState(
      icon: Iconsax.tick_circle,
      title: 'No approved requests yet',
    ),
    _ => const AppEmptyState(
      icon: Iconsax.receipt_item,
      title: 'No requests',
      subtitle: 'Renewals your users submit will appear here.',
    ),
  };

  /// Shown instead of the empty state when the fetch itself failed.
  ///
  /// The pending tab's empty state reads "Nothing waiting — every request has
  /// been dealt with", which is the opposite of true after a timeout.
  Widget _buildFailed() => AppEmptyState(
    icon: Iconsax.cloud_cross,
    title: 'စာရင်း ဆွဲယူ၍ မရပါ',
    subtitle: 'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
    actionLabel: 'ထပ်မံကြိုးစားမည်',
    onAction: () => _load(refresh: true, clearFirst: true),
  );
}

// ── Card ──────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final RenewalRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewScreenshot;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onViewScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kind = _RequestKind.of(request.type);
    final status = _StatusStyle.of(request.status);
    final pending = request.status == 'pending';

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // The user, not the request type. An agent scans this list
                // for who is waiting; the type is a badge on the corner and
                // the label beneath the name.
                _RequestAvatar(username: request.vpnUserName, kind: kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request.vpnUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                AppPill(
                  label: status.label.toUpperCase(),
                  color: status.color,
                  background: status.wash,
                ),
              ],
            ),
          ),
          // Label/value rows: an agent checking a payment reads down the
          // right-hand column, so the values line up rather than sitting at
          // the end of sentences of different lengths.
          _DetailRow(
            label: 'Amount',
            // FMT_MONEY_V1 — Fmt.money, built once, instead of a NumberFormat
            // constructed in this build method: once per visible row, per
            // frame, on a list that reaches five hundred rows.
            valueWidget: Text(
              '${Fmt.money.format(request.estimatedCost)} MMK',
              style: t.titleMedium?.copyWith(
                fontSize: 15,
                color: AppColors.orange,
              ),
            ),
          ),
          _DetailRow(label: kind.label, value: request.subtitle),
          _DetailRow(label: 'Date', value: _formatDate(request.createdAt)),
          if (request.rejectReason != null)
            _DetailRow(label: 'Reason', value: request.rejectReason!),
          _DetailRow(
            label: 'Payment slip',
            last: true,
            valueWidget: InkWell(
              onTap: onViewScreenshot,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View',
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Iconsax.eye, size: 15, color: AppColors.info),
                ],
              ),
            ),
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      // TAP_TARGET_44_V1 — 42 was under the platform minimum,
                      // on a button that sits beside a destructive one.
                      height: 44,
                      child: OutlinedButton(
                        onPressed: busy ? null : onReject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        // No icon: at half width the icon pushed "Reject"
                        // onto two lines and split the word.
                        child: const Text('Reject'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      // Both halves fixed to the same 44: the minimum,
                      // and no more. The theme's 48 made a pair of buttons the
                      // tallest thing in a card whose subject is the figures
                      // above them.
                      height: 44,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onApprove,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textOnAccent,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(busy ? 'Working' : 'Approve'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return Fmt.dateTime.format(parsed.toLocal());
  }
}

/// One label/value line inside a request card.
class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool last;

  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodyMedium),
              const SizedBox(width: 16),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      valueWidget ??
                      Text(
                        value ?? '',
                        textAlign: TextAlign.right,
                        style: t.bodyLarge?.copyWith(fontSize: 13.5),
                      ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: _DashedLine(),
          ),
      ],
    );
  }
}

/// Hairline of dashes. A solid rule between every field made the card read as
/// a table; dashes separate without carrying the same weight.
///
/// DASHED_LINE_PAINTER_V1 — one painter, not one widget per dash. This was a
/// LayoutBuilder wrapping a Row of roughly a hundred SizedBoxes, each with a
/// DecoratedBox inside it, for a single hairline — and there are four or five
/// of them per card, laid out again on every frame the list moves.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedLinePainter()),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  static const double _dash = 3;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;

    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      final end = x + _dash > size.width ? size.width : x + _dash;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
    }
  }

  /// Nothing here varies: same colour, same dash, same gap on every row. A
  /// size change is handled by the framework without asking the painter.
  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) => false;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Material(
      color: selected ? color : AppColors.surface,
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
              // Unselected keeps a tint of its own colour, so the row still
              // reads as three states rather than three identical outlines.
              color: selected ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: t.bodySmall?.copyWith(
                  color: selected ? AppColors.textOnAccent : color,
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
                        : color.withValues(alpha: 0.7),
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

/// Full-screen payment slip over a scrimmed copy of the list.
///
/// The list stays on the route beneath so that closing the image returns the
/// agent to the row they were reading rather than to the top of the screen.
class _ScreenshotViewer extends StatelessWidget {
  final String url;
  final String title;

  const _ScreenshotViewer({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // SCRIM_NOT_BLUR_V1 — a plain fill where a sigma-18 BackdropFilter
          // used to be. That was a saveLayer over the whole window on a
          // non-opaque route, re-rasterised through the fade-in, and it was
          // the most expensive thing on this page. A light scrim rather than a
          // dark one: the page behind it is white.
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.background.withValues(alpha: 0.9),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textPrimary,
                      ),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: ColoredBox(
                        color: AppColors.surface,
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 5,
                          child: Center(
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : const AppLoader(),
                              errorBuilder: (_, __, ___) => const AppEmptyState(
                                icon: Iconsax.gallery_slash,
                                title: 'Could not load the screenshot',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const AppCard(
        padding: EdgeInsets.all(14),
        radius: AppTheme.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSkeleton(width: 36, height: 36, radius: AppTheme.radiusSm),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 120, height: 13),
                      SizedBox(height: 7),
                      AppSkeleton(width: 170, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            AppSkeleton(height: 40, radius: AppTheme.radiusSm),
          ],
        ),
      ),
    );
  }
}

/// Illustration behind the header and the filter row.
///
/// Anchored to the top and faded out downward so the list scrolls over it. The
/// composition leaves its middle empty, which is where the title and status
/// chips sit — the artwork occupies margins the screen was not using.
class _RequestsBackdrop extends StatelessWidget {
  const _RequestsBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.6, 1.0],
              colors: [Colors.black, Colors.black26, Colors.transparent],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Opacity(
              opacity: 0.35,
              child: Image.asset(
                'assets/images/requests_hero.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The requesting user's portrait, with the request type marked on its corner.
class _RequestAvatar extends StatelessWidget {
  final String username;
  final _RequestKind kind;

  const _RequestAvatar({required this.username, required this.kind});

  static const _avatars = [
    'assets/images/avatars/a1.png',
    'assets/images/avatars/a2.png',
  ];

  /// Hashed rather than random, so the same user keeps the same face between
  /// this screen and the user list.
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
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.asset(
              _avatarFor(username),
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: kind.wash,
                shape: BoxShape.circle,
                // Ringed in the card colour so the badge reads as sitting on
                // the portrait rather than cut out of it.
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Icon(kind.icon, size: 11, color: kind.color),
            ),
          ),
        ],
      ),
    );
  }
}
