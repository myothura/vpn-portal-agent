import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_tiles.dart';

import 'package:vpn_agent_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';

import 'package:vpn_agent_app/features/agent_management/screens/agent_list_screen.dart';
import 'package:vpn_agent_app/features/history/screens/credit_history_screen.dart';
import 'package:vpn_agent_app/features/history/screens/renewal_requests_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/notification_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/screens/manage_payment_screen.dart';
import 'package:vpn_agent_app/features/profile/screens/profile_screen.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';
import 'package:vpn_agent_app/features/users/screens/add_user_screen.dart';
import 'package:vpn_agent_app/features/users/screens/device_slot_management_screen.dart';
import 'package:vpn_agent_app/features/users/screens/user_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The bloc is provided by MainScaffold — the nav badges read the same
    // state, and a second provider here would run a second 30s poll against
    // /agent/dashboard.
    return const _DashboardView();
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final ProfileService _profileService = ProfileService();

  bool _canManageAgents = false;
  bool _canSendNoti = false;
  bool _canAccessChat = false;

  /// Which action tile is mid-flight, so the spinner sits in the tile that was
  /// tapped instead of an overlay covering the whole screen.
  String? _busyAction;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  /// Called once. Permissions are set by an administrator, not by anything the
  /// agent does in the app, so re-fetching them every time a pushed screen pops
  /// — as the previous version did, fifteen call sites over — was a request per
  /// navigation for data that had not changed.
  Future<void> _loadPermissions() async {
    try {
      final profile = await _profileService.getProfile();
      if (!mounted || profile == null) return;
      final isSuperAdmin = profile['id'] == 16;
      setState(() {
        _canManageAgents = isSuperAdmin || _flag(profile['can_manage_agents']);
        _canSendNoti = isSuperAdmin || _flag(profile['can_send_notifications']);
        _canAccessChat = isSuperAdmin || _flag(profile['can_access_chat']);
      });
    } catch (_) {
      // Permissions stay false; the agent sees the core tiles and nothing is
      // blocked that they could otherwise reach.
    }
  }

  static bool _flag(dynamic v) => v == true || v == 1;

  Future<void> _refresh() async {
    context.read<DashboardBloc>().add(DashboardRefreshed());
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    // The 30s poll picks up changes on its own; this just avoids a stale
    // number sitting on screen for up to half a minute after an edit.
    if (mounted) _refresh();
  }

  Future<void> _openPaymentMethods() async {
    setState(() => _busyAction = 'payment');
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;

      final methods = (profile?['payment_details'] as List?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          <PaymentMethod>[];

      setState(() => _busyAction = null);
      await _open(ManagePaymentScreen(initialMethods: methods));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not load payment methods: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            final stats = switch (state) {
              DashboardLoaded s => s.stats,
              DashboardLoading s => s.cachedStats,
              DashboardError s => s.cachedStats,
              _ => null,
            };

            // Only a cold start with nothing cached is a blocking state.
            if (stats == null) {
              if (state is DashboardError) {
                return AppEmptyState(
                  icon: Iconsax.wifi_square,
                  title: 'Could not load your dashboard',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      context.read<DashboardBloc>().add(DashboardStarted()),
                );
              }
              return const AppLoader();
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              color: AppColors.accent,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  _Header(
                    stats: stats,
                    onNotifications: () => _open(const NotificationScreen()),
                    onProfile: () => _open(const ProfileScreen()),
                  ),
                  const SizedBox(height: 16),
                  _RequestTicker(
                    requests: stats.recentRequests,
                    pendingCount: stats.pendingRequestCount,
                    onTap: () => _open(const RenewalRequestsScreen()),
                  ),
                  const SizedBox(height: 16),
                  _BalanceCard(
                    stats: stats,
                    onHistory: () => _open(const CreditHistoryScreen()),
                  ),
                  const SizedBox(height: 24),
                  const AppSectionHeader(title: 'Your users'),
                  const SizedBox(height: 12),
                  _StatsGrid(stats: stats, onOpen: _open),
                  const SizedBox(height: 24),
                  const AppSectionHeader(title: 'Quick actions'),
                  const SizedBox(height: 12),
                  _ActionsGrid(
                    stats: stats,
                    busyAction: _busyAction,
                    canAccessChat: _canAccessChat,
                    canManageAgents: _canManageAgents,
                    canSendNoti: _canSendNoti,
                    onOpen: _open,
                    onPayment: _openPaymentMethods,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _Header({
    required this.stats,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stats.greeting, style: t.bodyMedium),
              const SizedBox(height: 2),
              Text(
                stats.firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.displaySmall,
              ),
            ],
          ),
        ),
        // Fleet-wide online count; only the super admin's payload carries it.
        if (stats.onlineUserCount > 0) ...[
          AppPill(
            label: '${stats.onlineUserCount} online',
            color: AppColors.accentInk,
            background: AppColors.accentWash,
            dot: true,
          ),
          const SizedBox(width: 8),
        ],
        _HeaderButton(icon: Iconsax.notification, onTap: onNotifications),
        const SizedBox(width: 8),
        _HeaderButton(icon: Iconsax.user, onTap: onProfile),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      radius: AppTheme.radiusSm,
      showShadow: false,
      child: Icon(icon, size: 20, color: AppColors.textSecondary),
    );
  }
}

// ── Pending-requests ticker ───────────────────────────────────────────────

class _RequestTicker extends StatefulWidget {
  final List<String> requests;
  final int pendingCount;
  final VoidCallback onTap;

  const _RequestTicker({
    required this.requests,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  State<_RequestTicker> createState() => _RequestTickerState();
}

class _RequestTickerState extends State<_RequestTicker> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _RequestTicker old) {
    super.didUpdateWidget(old);
    if (old.requests.length != widget.requests.length) {
      _index = 0;
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.requests.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.requests.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = widget.pendingCount > 0;

    // recent_requests falls back to recently-decided rows when nothing is
    // pending, so the pending COUNT decides the tone — not the list's length.
    if (widget.requests.isEmpty) {
      return const AppStatusBanner(
        message: 'Nothing needs your attention',
        icon: Iconsax.tick_circle,
        color: AppColors.success,
        wash: AppColors.successWash,
      );
    }

    final message = widget.requests[_index % widget.requests.length];

    return AppStatusBanner(
      message: message,
      icon: hasPending ? Iconsax.notification : Iconsax.tick_circle,
      color: hasPending ? AppColors.warning : AppColors.success,
      wash: hasPending ? AppColors.warningWash : AppColors.successWash,
      trailingLabel: hasPending ? '${widget.pendingCount}' : null,
      onTap: widget.onTap,
    );
  }
}

// ── Balance ───────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final DashboardStats stats;
  final VoidCallback onHistory;

  const _BalanceCard({required this.stats, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // The one ink card on the page. Balance is the number an agent checks
    // first, so it gets the contrast rather than competing with four tiles.
    return AppCard(
      tone: SurfaceTone.ink,
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Available balance',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textOnInk.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              // Was a decorative pill with no action; now it is the entry
              // point to credit history, which is what people tapped it for.
              TextButton(
                onPressed: onHistory,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('History'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stats.formattedCreditBalance,
              style: t.displaySmall?.copyWith(
                color: AppColors.textOnInk,
                fontSize: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.textOnInk.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Iconsax.arrow_down,
                size: 14,
                color: AppColors.textOnInk.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Spent this month',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textOnInk.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                stats.formattedCreditsSpent,
                style: t.bodyLarge?.copyWith(
                  color: AppColors.textOnInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  final Future<void> Function(Widget) onOpen;

  const _StatsGrid({required this.stats, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      // Emphasised: this is the number that costs the agent money if it is
      // missed. Previously it sat bottom-right with the same weight as a
      // total that changes slowly and needs no action.
      AppStatTile(
        label: 'Expiring in 7 days',
        value: '${stats.expiringSoonCount}',
        icon: Iconsax.timer_1,
        color: AppColors.warning,
        wash: AppColors.warningWash,
        emphasis: stats.expiringSoonCount > 0,
        onTap: () =>
            onOpen(const UserManagementScreen(initialFilter: 'expiring')),
      ),
      AppStatTile(
        label: 'Active',
        value: '${stats.activeUserCount}',
        icon: Iconsax.tick_circle,
        color: AppColors.success,
        wash: AppColors.successWash,
        onTap: () => onOpen(const UserManagementScreen(initialFilter: 'active')),
      ),
      AppStatTile(
        label: 'Total users',
        value: '${stats.totalUserCount}',
        icon: Iconsax.profile_2user,
        color: AppColors.info,
        wash: AppColors.infoWash,
        onTap: () => onOpen(const UserManagementScreen(initialFilter: 'all')),
      ),
      AppStatTile(
        label: 'Business',
        value: '${stats.businessUserCount}',
        icon: Iconsax.briefcase,
        color: AppColors.orange,
        wash: AppColors.orangeWash,
        onTap: () =>
            onOpen(const UserManagementScreen(initialFilter: 'business')),
      ),
    ];

    return _Grid(children: tiles);
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────

class _ActionsGrid extends StatelessWidget {
  final DashboardStats stats;
  final String? busyAction;
  final bool canAccessChat;
  final bool canManageAgents;
  final bool canSendNoti;
  final Future<void> Function(Widget) onOpen;
  final VoidCallback onPayment;

  const _ActionsGrid({
    required this.stats,
    required this.busyAction,
    required this.canAccessChat,
    required this.canManageAgents,
    required this.canSendNoti,
    required this.onOpen,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    // Built as a list and laid out by the grid. The previous version wrote out
    // four separate permission branches of hand-paired Rows, repeated the
    // Device Slots and Users tiles in two of them, and padded odd counts with
    // an empty Expanded. Adding a tile meant editing every branch.
    final tiles = <Widget>[
      AppActionTile(
        label: 'Add user',
        icon: Iconsax.user_add,
        color: AppColors.accentInk,
        wash: AppColors.accentWash,
        onTap: () => onOpen(const AddUserScreen()),
      ),
      AppActionTile(
        label: 'Device slots',
        icon: Iconsax.mobile,
        color: AppColors.info,
        wash: AppColors.infoWash,
        onTap: () => onOpen(const DeviceSlotManagementScreen()),
      ),
      AppActionTile(
        label: 'Payment methods',
        icon: Iconsax.card,
        color: AppColors.violet,
        wash: AppColors.violetWash,
        busy: busyAction == 'payment',
        onTap: onPayment,
      ),
      if (canManageAgents)
        AppActionTile(
          label: 'My agents',
          icon: Iconsax.people,
          color: AppColors.violet,
          wash: AppColors.violetWash,
          badgeCount: stats.subAgentCount,
          onTap: () => onOpen(const AgentListScreen()),
        ),
      if (canSendNoti)
        AppActionTile(
          label: 'Broadcast',
          icon: Iconsax.send_2,
          color: AppColors.orange,
          wash: AppColors.orangeWash,
          onTap: () => onOpen(const SendNotificationScreen()),
        ),
    ];

    return _Grid(children: tiles);
  }
}

// ── Layout ────────────────────────────────────────────────────────────────

/// Two-column layout that takes however many children it is given.
///
/// Rows of IntrinsicHeight rather than GridView.count: a childAspectRatio
/// fixes tile height from tile WIDTH, so the content has to fit a number the
/// layout guessed. It did not — the tiles overflowed by 9px — and any device
/// with a larger system font would break a hand-tuned ratio again. Here the
/// content decides the height and IntrinsicHeight keeps both tiles in a row
/// matched, which a Wrap would not do.
class _Grid extends StatelessWidget {
  final List<Widget> children;

  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = i + 1 < children.length ? children[i + 1] : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              // Odd count: the last tile keeps its column width instead of
              // stretching across the full row.
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );

      if (i + 2 < children.length) rows.add(const SizedBox(height: 12));
    }

    return Column(children: rows);
  }
}
