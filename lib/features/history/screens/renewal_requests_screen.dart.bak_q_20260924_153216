import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:vpn_agent_app/core/services/agent_realtime_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/utils/app_log.dart';
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

  /// FAST_APPROVE_STATE_V1 — the decisions this agent has already made, held
  /// beside the list rather than inside it.
  ///
  /// RenewalRequest has final fields and no copyWith, and the model file is
  /// not part of this change, so a row cannot be rewritten in place. The id
  /// and the decision live here instead, and every reader of a row's status
  /// goes through _statusOf.
  ///
  /// This map is also what keeps a reload from undoing the tap. The realtime
  /// listener, the tab return and pull-to-refresh all replace _requests with
  /// whatever the server says, and for a second or two after the tap the
  /// server still says 'pending'. The local decision outranks it.
  ///
  /// An entry is removed in one place only — a POST that did not succeed —
  /// because that is the one case where 'pending' is true and the row has to
  /// come back.
  final Map<int, String> _localDecisions = {};

  /// The status a row should be drawn with: the local decision if there is
  /// one, otherwise what the server sent.
  String _statusOf(RenewalRequest request) =>
      _localDecisions[request.id] ?? request.status;

  /// The rows the current tab should show.
  ///
  /// A request just approved no longer belongs on the pending tab and leaves
  /// it without waiting for a refetch. Before the first decision — which is
  /// every build until the agent taps — this is the list itself, so there is
  /// no copy per build.
  List<RenewalRequest> get _visibleRequests {
    if (_localDecisions.isEmpty || _filter == null) return _requests;
    return _requests
        .where((request) => _statusOf(request) == _filter)
        .toList(growable: false);
  }

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
    //
    // REALTIME_KEEPS_LOCAL_DECISION_V1 — this replaces _requests wholesale,
    // including rows the agent has just decided and whose POST may still be
    // in flight, which the server is still reporting as pending. It cannot
    // resurrect them: _localDecisions is untouched by a reload and _statusOf
    // is read after it.
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
    // FAST_APPROVE_REENTRY_V1 — this is what _busyIds used to cover. A second
    // tap cannot reach here through the UI (the row loses its buttons in the
    // same frame as the first), but the retry action on the failure snackbar
    // calls straight back in, and so would a double tap landing either side
    // of the confirmation.
    if (_localDecisions.containsKey(request.id)) return;

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

    // FAST_APPROVE_OPTIMISTIC_V1 — the row changes here, before the POST.
    //
    // It used to be: add to _busyIds, await approveRequest, then
    // _load(refresh: true) and wait for a page of twenty rows to come back
    // before the approved one left the tab. Two round trips with the agent
    // watching a spinner inside the button they had just pressed. The
    // decision is recorded and drawn now; the call runs behind it.
    setState(() => _localDecisions[request.id] = 'approved');
    _toast('${request.vpnUserName} ၏ တောင်းဆိုမှုကို အတည်ပြုလိုက်ပါပြီ။');

    await _settleDecision(
      request,
      'approved',
      () => _service.approveRequest(request.id),
      '${request.vpnUserName} ၏ တောင်းဆိုမှုကို အတည်မပြုနိုင်ပါ။ '
          'တောင်းဆိုမှုကို စာရင်းထဲသို့ ပြန်ထည့်လိုက်ပါပြီ။ '
          'Credit လက်ကျန်နှင့် အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး '
          'ထပ်မံ ကြိုးစားပါ။',
      () => _approve(request),
    );
  }

  Future<void> _reject(RenewalRequest request) async {
    // FAST_REJECT_REENTRY_V1 — see _approve. The failure snackbar's retry
    // calls back in here, and a rejection already recorded must not open a
    // second reason dialog.
    if (_localDecisions.containsKey(request.id)) return;

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
        // REJECT_DIALOG_MY_V1 — Burmese, like every other dialog on this
        // path, and both buttons raised to the 44dp minimum. The Material
        // default is 40 high, which is under it, on a dialog whose confirm
        // button is destructive. Only minimumSize changes: same padding,
        // same type, same colours.
        title: const Text('တောင်းဆိုမှုကို ငြင်းပယ်မလား'),
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
                hintText: 'အကြောင်းပြချက် (အသုံးပြုသူ မြင်ရပါမည်)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('မလုပ်တော့ပါ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(64, 44),
            ),
            // A reason is required: the user sees this, and "rejected" with no
            // explanation just becomes a support message the agent answers by
            // hand anyway.
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('ငြင်းပယ်မည်'),
          ),
        ],
      ),
    );
    // REJECT_CONTROLLER_DISPOSE_V1 — the dialog has closed and its field went
    // with it, but a TextEditingController is a ChangeNotifier and stays
    // registered until it is disposed. One was leaked per rejection.
    controller.dispose();

    if (reason == null || reason.isEmpty || !mounted) {
      if (reason != null && reason.isEmpty) {
        _toast('ငြင်းပယ်ရန် အကြောင်းပြချက် ထည့်ပါ။');
      }
      return;
    }

    // FAST_REJECT_OPTIMISTIC_V1 — the same shape as approve. A rejection is
    // not a purchase, but it took the identical two round trips to leave the
    // pending tab, and the agent clearing a batch of them felt every one.
    setState(() => _localDecisions[request.id] = 'rejected');
    _toast('${request.vpnUserName} ၏ တောင်းဆိုမှုကို ငြင်းပယ်လိုက်ပါပြီ။');

    await _settleDecision(
      request,
      'rejected',
      () => _service.rejectRequest(request.id, reason),
      '${request.vpnUserName} ၏ တောင်းဆိုမှုကို ငြင်းပယ်၍ မရပါ။ '
          'တောင်းဆိုမှုကို စာရင်းထဲသို့ ပြန်ထည့်လိုက်ပါပြီ။ '
          'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
      () => _reject(request),
    );
  }

  // LOCAL_CONFIRM_REMOVED_V1 — the screen's own _confirm lived here. Its one
  // caller now uses confirmAction from core/widgets, which shows the amount
  // being spent rather than only naming the action.

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// DECISION_FAILED_LOUD_V1 — a decision that never reached the server.
  ///
  /// The caller has already put the row back. A row that reappears with
  /// nothing said would be worse than the wait this replaced: the agent
  /// watched the request leave the list and would find it there again with no
  /// idea why. So this one is red rather than the default surface, holds for
  /// eight seconds rather than four, names the user in the message, and
  /// carries the retry.
  void _decisionFailed(String message, VoidCallback onRetry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 8),
          content: Text(
            message,
            style: const TextStyle(color: AppColors.textOnAccent),
          ),
          action: SnackBarAction(
            label: 'ထပ်မံကြိုးစားမည်',
            textColor: AppColors.textOnAccent,
            onPressed: onRetry,
          ),
        ),
      );
  }

  /// Runs the POST behind a decision that is already drawn.
  ///
  /// Nothing in the UI waits on this — the tap returned as soon as the row
  /// changed — so it has to swallow everything. The service already maps a
  /// DioException to false, but an error escaping here would land in the zone
  /// handler with no one to report it. Every path ends either in a badge
  /// refresh or in a visible error; none of them ends in silence.
  Future<void> _settleDecision(
    RenewalRequest request,
    String decision,
    Future<bool> Function() send,
    String failureMessage,
    VoidCallback onRetry,
  ) async {
    var ok = false;
    try {
      ok = await send();
    } catch (error) {
      AppLog.e('renewalDecision/$decision', error);
      ok = false;
    }
    if (!mounted) return;

    if (ok) {
      // No refetch. The row is already where it belongs; the only stale thing
      // left on screen is the count in the nav badge, and that is one cheap
      // call rather than a page of twenty rows the agent has already read.
      _refreshBadge();
      return;
    }

    AppLog.e(
      'renewalDecision/$decision',
      'request ${request.id} was not applied',
    );
    setState(() => _localDecisions.remove(request.id));
    _decisionFailed(failureMessage, onRetry);
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
        pageBuilder: (_, _, _) => _ScreenshotViewer(
          url: request.screenshotUrl,
          title: request.vpnUserName,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    // FAST_APPROVE_VISIBLE_V1 — resolved once per build, not per row. Every
    // use below is this list: the empty check, the item count, the index and
    // the footer's total all have to agree, and _requests alone no longer
    // answers any of them once a decision has been made locally.
    final visible = _visibleRequests;

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
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                  // FAST_APPROVE_LIST_V1 — driven by the visible list, so a
                  // row decided a moment ago is gone from the pending tab now
                  // rather than after the refetch that used to follow the
                  // POST. Pull-to-refresh is unchanged and still refetches.
                  child: _loading
                      ? const _ListSkeleton()
                      : visible.isEmpty
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
                            itemCount: visible.length + 1,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              if (i == visible.length) {
                                return _buildFooter(visible.length);
                              }
                              final request = visible[i];
                              return _RequestCard(
                                request: request,
                                status: _statusOf(request),
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

  /// FOOTER_COUNT_VISIBLE_V1 — counts what is on screen, not what was
  /// fetched. After a few approvals those differ: the decided rows are still
  /// in _requests until the next reload, and the footer used to count them.
  Widget _buildFooter(int shown) {
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
          '$shown shown',
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

  /// CARD_EFFECTIVE_STATUS_V1 — passed in rather than read off the model.
  ///
  /// A request the agent has decided on this device is approved or rejected
  /// before the server has been told, and RenewalRequest.status still says
  /// pending. The screen resolves that; the card only draws what it is given.
  ///
  /// This replaces the `busy` flag, which disabled the buttons and put a
  /// spinner on the approve one while the POST was in flight. There is no
  /// such window any more — a decided card has no button row at all.
  final String status;

  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewScreenshot;

  const _RequestCard({
    required this.request,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onViewScreenshot,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final kind = _RequestKind.of(request.type);
    // CARD_STATUS_STYLE_V1 — both read the effective status now. The badge and
    // the button row have to agree: a card showing APPROVED with an Approve
    // button under it would be the worst of both.
    final statusStyle = _StatusStyle.of(status);
    final pending = status == 'pending';

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
                  // CARD_STATUS_PILL_V1 — the resolved style, not the model's.
                  label: statusStyle.label.toUpperCase(),
                  color: statusStyle.color,
                  background: statusStyle.wash,
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
            // TAP_L_VIEW_LINK — the only tappable thing in a card whose other
            // rows are text, and it was the height of its own label: about 18
            // points, inside a row 40 points tall. It is 44 now, with a little
            // horizontal padding so the ink splash reads as a control rather
            // than as the words lighting up.
            tallValue: true,
            valueWidget: InkWell(
              onTap: onViewScreenshot,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
            ),
          ),
          if (pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Row(
                children: [
                  // CARD_NO_BUSY_V1 — no disabled state and no spinner.
                  // The decision is recorded in the same frame as the tap, so
                  // this row is already gone by the time the POST starts; a
                  // "Working" label had nowhere left to appear. Heights,
                  // padding and type are exactly as before.
                  Expanded(
                    child: SizedBox(
                      // TAP_TARGET_44_V1 — 42 was under the platform minimum,
                      // on a button that sits beside a destructive one.
                      height: 44,
                      child: OutlinedButton(
                        onPressed: onReject,
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
                        onPressed: onApprove,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
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

  /// TAP_L_VIEW_ROW — set on a row whose value is itself tappable.
  ///
  /// That value carries its own 44-point height, so this row gives 7 of its 11
  /// points of padding back and lands at 52 rather than 66: grown enough to
  /// hold a real tap target, not enough to read as stretched beside the four
  /// rows above it. The label is centred against it at the same time — against
  /// a 44-tall value a top-aligned label sits well above the text it names.
  final bool tallValue;

  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.last = false,
    this.tallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: tallValue ? 4 : 11,
          ),
          child: Row(
            crossAxisAlignment: tallValue
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
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

  /// IMG_L_SLIPVIEW_FN — twice the device's pixel width, rounded up to a
  /// multiple of 64.
  ///
  /// This is the screen an agent opens to read a transfer reference and an
  /// amount off a payment slip before spending credit on it, and the
  /// InteractiveViewer below zooms to 5x for exactly that. Decoding at the
  /// unzoomed screen width would blur the only thing the screen is for, so the
  /// cap is twice the screen: a 3000x4000 photograph of a bank receipt drops
  /// from roughly 48 MB to 30 MB, and the number no longer depends on which
  /// phone took the picture.
  static int _zoomCachePx(BuildContext context) {
    final media = MediaQuery.of(context);
    final px = (media.size.width * media.devicePixelRatio * 2).ceil();
    return px < 64 ? 64 : ((px + 63) ~/ 64) * 64;
  }

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
                              // IMG_L_SLIPVIEW_USE — sized for the zoom this
                              // viewer allows rather than for whatever file is
                              // behind the URL.
                              cacheWidth: _zoomCachePx(context),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : const AppLoader(),
                              // A dead link left a blank panel over the list
                              // and an exception in the console. The agent is
                              // about to decide on this request, so the state
                              // has to say plainly that the slip cannot be
                              // seen.
                              errorBuilder: (_, _, _) => const AppEmptyState(
                                icon: Iconsax.gallery_slash,
                                title: 'ပုံကို ဖွင့်၍ မရပါ',
                                subtitle:
                                    'လင့်ခ် ပျက်နေခြင်း သို့မဟုတ် အင်တာနက် '
                                    'ချိတ်ဆက်မှု ပြတ်တောက်နေခြင်း ဖြစ်နိုင်ပါသည်။',
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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => const AppCard(
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
    final media = MediaQuery.of(context);

    // IMG_L_REQHERO — requests_hero.png is 1200x514, 2.4 MB decoded, painted
    // at the screen's width. On a 720p Android that width is 720 pixels, so
    // the cache was holding two and a half times the artwork the screen can
    // show. Rounded up to a multiple of 64 so a rotation or a split-screen
    // resize reuses the same cache key rather than decoding a second copy.
    final heroPixelWidth = (media.size.width * media.devicePixelRatio).ceil();
    final heroCacheWidth = heroPixelWidth < 64
        ? 64
        : ((heroPixelWidth + 63) ~/ 64) * 64;

    // RepaintBoundary: the ShaderMask is a saveLayer and the request list
    // scrolls over this in a Stack, so the masked image was being
    // re-composited on every scroll frame.
    return RepaintBoundary(
      child: IgnorePointer(
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
                  cacheWidth: heroCacheWidth,
                  fit: BoxFit.contain,
                ),
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

  /// IMG_L_REQAVATAR_FN — the 42-point circle, in device pixels.
  ///
  /// a1.png and a2.png are 256x256, 0.26 MB each decoded, and a page of twenty
  /// requests puts both of them in the cache. Rounded up to a multiple of 64,
  /// which is 128 on a 2x screen and 192 on a 3x one.
  static int _avatarCachePx(BuildContext context) {
    final px = (42 * MediaQuery.of(context).devicePixelRatio).ceil();
    return px < 64 ? 64 : ((px + 63) ~/ 64) * 64;
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
              // IMG_L_REQAVATAR_USE — decoded at the size of the circle. No
              // RepaintBoundary: the card is built by a ListView.separated,
              // which already wraps each child in one.
              cacheWidth: _avatarCachePx(context),
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
