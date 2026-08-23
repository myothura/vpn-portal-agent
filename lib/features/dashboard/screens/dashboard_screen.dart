import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';
import 'package:vpn_agent_app/shared_widgets/theme_helpers.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_tiles.dart';

import 'package:vpn_agent_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';

import 'package:vpn_agent_app/features/agent_management/screens/agent_list_screen.dart';
import 'package:vpn_agent_app/features/history/screens/credit_history_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/notification_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/screens/manage_payment_screen.dart';
import 'package:vpn_agent_app/features/profile/screens/profile_screen.dart';
import 'package:vpn_agent_app/features/profit_loss/screens/profit_loss_screen.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';
import 'package:vpn_agent_app/features/users/screens/add_user_screen.dart';
import 'package:vpn_agent_app/features/users/screens/device_slot_management_screen.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
import 'package:vpn_agent_app/core/navigation/app_transitions.dart';

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

  /// Profit & loss is the whole business's figures, so it is the one tile
  /// gated on being account 16 rather than on a permission flag — there is no
  /// column that would grant it to anyone else.
  bool _isSuperAdmin = false;
  bool _canAccessChat = false;

  /// Which action tile is mid-flight, so the spinner sits in the tile that was
  /// tapped instead of an overlay covering the whole screen.
  String? _busyAction;

  /// Identity of the current entrance run. The stagger plays once when the
  /// screen first has data; it must not replay on every 30s poll.
  final int _entranceKey = DateTime.now().microsecondsSinceEpoch;

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
        _isSuperAdmin = isSuperAdmin;
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
    // Slide, not fade-through: these are details opened from the dashboard,
    // so the motion should read as stepping into a hierarchy and back out.
    await Navigator.push(context, AppTransitions.slide(screen));
    // The 30s poll picks up changes on its own; this just avoids a stale
    // number sitting on screen for up to half a minute after an edit.
    if (mounted) _refresh();
  }

  /// Moves the shell to another tab instead of pushing a screen.
  ///
  /// The user and renewal screens are tabs in their own right. Pushing them
  /// from here left the nav bar highlighting Dashboard while a user list was
  /// on screen, and created a second copy of a screen the Users tab already
  /// held.
  void _switchTab(String label, {String? userFilter}) {
    MainShell.of(context)?.goToTab(label, userFilter: userFilter);
  }

  Future<void> _openPaymentMethods() async {
    setState(() => _busyAction = 'payment');
    try {
      final profile = await _profileService.getProfile();
      if (!mounted) return;

      final methods =
          (profile?['payment_details'] as List?)
              ?.map((e) => PaymentMethod.fromJson(e))
              .toList() ??
          <PaymentMethod>[];

      setState(() => _busyAction = null);
      await _open(ManagePaymentScreen(initialMethods: methods));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAction = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load payment methods: $e')),
      );
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

            // Anything not freshly fetched is flagged: cache on cold start, a
            // failed background poll, or an error we are riding out on cache.
            final isStale = switch (state) {
              DashboardLoaded s => s.isStale,
              DashboardError _ => true,
              _ => false,
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
              return const _DashboardSkeleton();
            }

            return Stack(
              children: [
                const _DashboardBackdrop(),
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      if (isStale) ...[
                        const _StaleStrip(),
                        const SizedBox(height: 12),
                      ],
                      // Sections fade up in sequence on first paint. Keyed to
                      // _entranceKey, not rebuilt per poll: re-running the
                      // entrance every 30 seconds would make the page flicker.
                      _Enter(
                        key: ValueKey('h$_entranceKey'),
                        step: 0,
                        child: _Header(
                          stats: stats,
                          onNotifications: () =>
                              _open(const NotificationScreen()),
                          onProfile: () => _open(const ProfileScreen()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Enter(
                        key: ValueKey('t$_entranceKey'),
                        step: 1,
                        child: _RequestTicker(
                          requests: stats.recentRequests,
                          pendingCount: stats.pendingRequestCount,
                          onTap: () => _switchTab('Requests'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Enter(
                        key: ValueKey('b$_entranceKey'),
                        step: 2,
                        child: _BalanceCard(
                          stats: stats,
                          onHistory: () => _open(const CreditHistoryScreen()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const AppSectionHeader(title: 'Your users'),
                      const SizedBox(height: 12),
                      _Enter(
                        key: ValueKey('s$_entranceKey'),
                        step: 3,
                        child: _StatsGrid(stats: stats, onSwitch: _switchTab),
                      ),
                      const SizedBox(height: 24),
                      const AppSectionHeader(title: 'Quick actions'),
                      const SizedBox(height: 12),
                      _Enter(
                        key: ValueKey('a$_entranceKey'),
                        step: 4,
                        child: _ActionsGrid(
                          stats: stats,
                          busyAction: _busyAction,
                          canAccessChat: _canAccessChat,
                          canManageAgents: _canManageAgents,
                          canSendNoti: _canSendNoti,
                          isSuperAdmin: _isSuperAdmin,
                          onOpen: _open,
                          onPayment: _openPaymentMethods,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Illustration behind the header, above the balance card.
///
/// It occupies the band the greeting and the ticker sit in and stops where the
/// balance panel begins — that panel is solid ink, so artwork running under it
/// would simply be invisible. Faded upward so it thins out behind the greeting
/// rather than crowding it.
class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    // Starts under the status bar rather than under SafeArea, so the artwork
    // reaches up level with the notification and profile buttons instead of
    // beginning below them.
    final topInset = MediaQuery.of(context).padding.top;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: topInset),
        child: Align(
          alignment: Alignment.topCenter,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // A long, even ramp to nothing. A short one ended in a visible
              // horizontal edge partway down the artwork, which read as the
              // image being cut off rather than fading out.
              stops: [0.0, 0.35, 1.0],
              colors: [Colors.black, Colors.black87, Colors.transparent],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: Opacity(
              opacity: 0.55,
              child: Image.asset(
                'assets/images/dashboard_hero.png',
                width: double.infinity,
                // contain: the whole artwork, scaled to the width. cover
                // cropped it to a fixed band and cut through the cards.
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Staggered fade-up. Thin wrapper over FadeInUp, which already existed in
/// theme_helpers.dart and was never used by any screen.
class _Enter extends StatelessWidget {
  final Widget child;
  final int step;

  const _Enter({super.key, required this.child, required this.step});

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      // 70ms apart: enough to read as a sequence, short enough that the last
      // section is up in under half a second.
      delay: Duration(milliseconds: 70 * step),
      duration: const Duration(milliseconds: 420),
      slideOffset: 0.06,
      child: child,
    );
  }
}

/// Cold-start placeholder. Mirrors the real layout — header, banner, balance,
/// two rows of tiles — so the page does not reflow when the data lands.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile() => const AppCard(
      padding: EdgeInsets.all(14),
      radius: AppTheme.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSkeleton(width: 30, height: 30, radius: 9),
          SizedBox(height: 12),
          AppSkeleton(width: 64, height: 26),
          SizedBox(height: 6),
          AppSkeleton(width: 88, height: 11),
        ],
      ),
    );

    Widget row() => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tile()),
          const SizedBox(width: 12),
          Expanded(child: tile()),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 110, height: 12),
                  SizedBox(height: 8),
                  AppSkeleton(width: 150, height: 28),
                ],
              ),
            ),
            const AppSkeleton(width: 40, height: 40, radius: AppTheme.radiusSm),
            const SizedBox(width: 8),
            const AppSkeleton(width: 40, height: 40, radius: AppTheme.radiusSm),
          ],
        ),
        const SizedBox(height: 16),
        const AppSkeleton(height: 54, radius: AppTheme.radiusMd),
        const SizedBox(height: 16),
        const AppSkeleton(height: 168, radius: AppTheme.radiusXl),
        const SizedBox(height: 24),
        const AppSkeleton(width: 96, height: 16),
        const SizedBox(height: 12),
        row(),
        const SizedBox(height: 12),
        row(),
      ],
    );
  }
}

/// Shown whenever the figures on screen are not known to be current.
///
/// Without it a failed poll is silent: the previous numbers stay up and read
/// as live. On a screen whose whole purpose is counts an agent acts on, that
/// is worse than showing nothing.
class _StaleStrip extends StatelessWidget {
  const _StaleStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Iconsax.cloud_cross,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing saved data — pull down to refresh',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
      // The greeting is two lines and the controls are one, so `start` pinned
      // the pill and buttons to the top of the tallest child. They belong on
      // the same optical line as each other, centred against the block.
      crossAxisAlignment: CrossAxisAlignment.center,
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
        _HeaderButton(
          icon: Iconsax.notification,
          onTap: onNotifications,
          badge: stats.unreadNotificationCount,
        ),
        const SizedBox(width: 8),
        _HeaderButton(icon: Iconsax.user, onTap: onProfile),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// Unread count, drawn as a badge. Zero hides it.
  final int badge;

  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final button = AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      radius: AppTheme.radiusSm,
      showShadow: false,
      child: Icon(icon, size: 20, color: AppColors.textSecondary),
    );

    if (badge == 0) return button;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        button,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(999),
              // Ringed in the page colour so the badge reads as separate from
              // the button rather than part of its outline.
              border: Border.all(color: AppColors.background, width: 1.5),
            ),
            child: Text(
              badge > 99 ? '99+' : '$badge',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textOnAccent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
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
      // Only on the all-clear. When something is pending the banner is an
      // alert and the count is what has to be read; artwork behind it competes
      // with that. With nothing waiting there is nothing to compete with.
      backdropAsset: hasPending ? null : 'assets/images/requests_hero.png',
      onTap: widget.onTap,
    );
  }
}

// ── Balance ───────────────────────────────────────────────────────────────

class _BalanceCard extends StatefulWidget {
  final DashboardStats stats;
  final VoidCallback onHistory;

  const _BalanceCard({required this.stats, required this.onHistory});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  /// Persisted, not per-session: an agent who hides their balance in a shop
  /// wants it to stay hidden the next time they open the app, not to have it
  /// flash on screen at every launch.
  static const _hiddenKey = 'balance_hidden';

  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden =
        Hive.box('app_cache').get(_hiddenKey, defaultValue: false) as bool;
  }

  void _toggle() {
    setState(() => _hidden = !_hidden);
    Hive.box('app_cache').put(_hiddenKey, _hidden);
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final onHistory = widget.onHistory;
    final t = Theme.of(context).textTheme;

    // The one ink card on the page. Balance is the number an agent checks
    // first, so it gets the contrast rather than competing with four tiles.
    return AppCard(
      tone: SurfaceTone.ink,
      padding: const EdgeInsets.all(20),
      radius: AppTheme.radiusXl,
      // Arcs are anchored past the top-right corner, so they cross the empty
      // area beside the label and never sit behind the balance figure.
      texture: CardTexture.rings,
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
              //
              // Drawn as a raised pill rather than a text link: bare text on
              // the ink card was the same weight as the label beside it, so
              // nothing marked it as tappable. The lighter fill and the
              // chevron are what say "this goes somewhere".
              Material(
                color: AppColors.textOnInk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: onHistory,
                  borderRadius: BorderRadius.circular(999),
                  splashColor: AppColors.textOnInk.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 8,
                      top: 6,
                      bottom: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'History',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.textOnInk,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textOnInk.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The whole figure is the hit target — a small eye icon beside a
          // number this large is a fiddly thing to aim at one-handed.
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _hidden
                        // Not an AppAnimatedNumber while masked: counting dots
                        // up to a hidden figure would be absurd, and the mask
                        // must not leak the magnitude through its width.
                        ? Text(
                            '••••••••',
                            style: t.displaySmall?.copyWith(
                              color: AppColors.textOnInk,
                              fontSize: 34,
                              letterSpacing: 2,
                            ),
                          )
                        : AppAnimatedNumber(
                            value: stats.creditBalance,
                            format: (n) => NumberFormat('#,##0').format(n),
                            style: t.displaySmall?.copyWith(
                              color: AppColors.textOnInk,
                              fontSize: 34,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  _hidden ? Iconsax.eye_slash : Iconsax.eye,
                  size: 18,
                  color: AppColors.textOnInk.withValues(alpha: 0.5),
                ),
              ],
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
                // Follows the same toggle: leaving spend visible while the
                // balance is masked gives away the same information.
                _hidden ? '••••' : stats.formattedCreditsSpent,
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
  final void Function(String label, {String? userFilter}) onSwitch;

  const _StatsGrid({required this.stats, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      // Emphasised: this is the number that costs the agent money if it is
      // missed. Previously it sat bottom-right with the same weight as a
      // total that changes slowly and needs no action.
      AppStatTile(
        label: 'Expiring in 7 days',
        value: stats.expiringSoonCount,
        icon: Iconsax.timer_1,
        color: AppColors.warning,
        wash: AppColors.warningWash,
        emphasis: stats.expiringSoonCount > 0,
        onTap: () => onSwitch('Users', userFilter: 'expiring'),
      ),
      AppStatTile(
        label: 'Active',
        value: stats.activeUserCount,
        icon: Iconsax.tick_circle,
        color: AppColors.success,
        wash: AppColors.successWash,
        onTap: () => onSwitch('Users', userFilter: 'active'),
      ),
      AppStatTile(
        label: 'Total users',
        value: stats.totalUserCount,
        icon: Iconsax.profile_2user,
        color: AppColors.neutral,
        wash: AppColors.neutralWash,
        onTap: () => onSwitch('Users', userFilter: 'all'),
      ),
      AppStatTile(
        label: 'Business',
        value: stats.businessUserCount,
        icon: Iconsax.briefcase,
        color: AppColors.neutral,
        wash: AppColors.neutralWash,
        onTap: () => onSwitch('Users', userFilter: 'business'),
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
  final bool isSuperAdmin;
  final bool canManageAgents;
  final bool canSendNoti;
  final Future<void> Function(Widget) onOpen;
  final VoidCallback onPayment;

  const _ActionsGrid({
    required this.stats,
    required this.busyAction,
    required this.canAccessChat,
    required this.isSuperAdmin,
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
      if (isSuperAdmin)
        AppActionTile(
          label: 'Profit & loss',
          icon: Iconsax.chart_2,
          color: AppColors.orange,
          wash: AppColors.orangeWash,
          onTap: () => onOpen(const ProfitLossScreen()),
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
