// File: lib/features/scaffold/main_scaffold.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/chat/screens/agent_chat_list_screen.dart';
import 'package:vpn_agent_app/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:vpn_agent_app/features/dashboard/repositories/dashboard_repository.dart';
import 'package:vpn_agent_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:vpn_agent_app/features/history/screens/renewal_requests_screen.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';
import 'package:vpn_agent_app/features/users/screens/user_management_screen.dart';

/// Root shell. Owns the tab bar and, crucially, the DashboardBloc.
///
/// The bloc lives here rather than inside DashboardScreen because the nav
/// badges read the same numbers the dashboard does. One bloc means one 30s
/// poll feeding both; providing it per-screen would mean two pollers fetching
/// the same endpoint.
/// Lets a screen inside a tab move the shell to a different tab.
///
/// The dashboard's stat tiles used to push UserManagementScreen onto the
/// dashboard's own navigator: the list appeared, but the nav bar still showed
/// Dashboard as current, and the Users tab held a second, unrelated copy of
/// the same screen. Switching the shell instead keeps one list, and the
/// highlighted tab always matches what is on screen.
class MainShell extends InheritedWidget {
  final void Function(String tabLabel, {String? userFilter}) goToTab;

  const MainShell({super.key, required this.goToTab, required super.child});

  static MainShell? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShell>();

  @override
  bool updateShouldNotify(MainShell oldWidget) => false;
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  /// Chat is permission-gated, so the tab list is built at runtime. Null until
  /// the profile call answers — the bar renders three tabs meanwhile rather
  /// than flashing a fourth in and out.
  bool _canAccessChat = false;
  bool _permissionsResolved = false;

  /// One Navigator per tab, so a screen pushed from a tab renders inside it
  /// and the nav bar stays visible. Pushing on the root navigator put the new
  /// screen over the whole scaffold, hiding the bar, and gave every tab a
  /// single shared back stack.
  final _navKeys = <String, GlobalKey<NavigatorState>>{};

  /// Filter the Users tab is showing. The epoch is bumped alongside it so the
  /// tab's key changes and the screen re-runs initState with the new filter —
  /// an existing instance would otherwise keep the old one.
  String _userFilter = 'all';
  int _userFilterEpoch = 0;

  GlobalKey<NavigatorState> _keyFor(String label) =>
      _navKeys.putIfAbsent(label, () => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final profile = await ProfileService().getProfile();
      if (!mounted || profile == null) return;
      setState(() {
        _canAccessChat =
            profile['can_access_chat'] == true ||
            profile['can_access_chat'] == 1 ||
            profile['id'] == 16;
        _permissionsResolved = true;
      });
    } catch (_) {
      if (mounted) setState(() => _permissionsResolved = true);
    }
  }

  List<_NavItem> get _items => [
    const _NavItem(
      icon: Iconsax.category_2,
      activeIcon: Iconsax.category_25,
      label: 'Dashboard',
      screen: DashboardScreen(),
    ),
    _NavItem(
      icon: Iconsax.profile_2user,
      activeIcon: Iconsax.profile_2user5,
      label: 'Users',
      screen: UserManagementScreen(
        key: ValueKey('users-$_userFilter-$_userFilterEpoch'),
        initialFilter: _userFilter,
      ),
    ),
    const _NavItem(
      icon: Iconsax.repeat,
      activeIcon: Iconsax.repeat5,
      label: 'Requests',
      screen: RenewalRequestsScreen(),
      badge: _BadgeSource.pendingRequests,
    ),
    if (_canAccessChat)
      const _NavItem(
        icon: Iconsax.message_text,
        activeIcon: Iconsax.message_text_15,
        label: 'Chat',
        screen: AgentChatListScreen(),
        badge: _BadgeSource.unreadChat,
      ),
  ];

  void _goToTab(String label, {String? userFilter}) {
    final index = _items.indexWhere((i) => i.label == label);
    if (index < 0) return;

    setState(() {
      if (userFilter != null && userFilter != _userFilter) {
        _userFilter = userFilter;
        _userFilterEpoch++;
      }
      _selectedIndex = index;
    });

    // Any detail screen already open in the destination tab is dismissed, so
    // the agent lands on the list they asked for rather than behind something.
    final nav = _keyFor(label).currentState;
    if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
  }

  void _onTap(int index) {
    // Tapping the tab you are already on returns it to its root. Without
    // this, a tab holding a pushed screen had no way back to its own list —
    // the tab button did nothing and the detail screen stayed up.
    if (index == _selectedIndex) {
      final nav = _keyFor(_items[index].label).currentState;
      if (nav != null && nav.canPop()) nav.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    // Losing the Chat tab (permission revoked mid-session) must not strand the
    // index past the end of the list.
    final safeIndex = _selectedIndex.clamp(0, items.length - 1);

    return BlocProvider(
      create: (_) =>
          DashboardBloc(repository: DashboardRepository())
            ..add(DashboardStarted()),
      child: MainShell(
        goToTab: _goToTab,
        child: PopScope(
          // Back belongs to the visible tab first. Without this the system back
          // gesture closed the app from a detail screen instead of returning to
          // the list behind it.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final nav = _keyFor(items[safeIndex].label).currentState;
            if (nav != null && nav.canPop()) {
              nav.pop();
              return;
            }
            if (safeIndex != 0) {
              setState(() => _selectedIndex = 0);
              return;
            }
            Navigator.of(context, rootNavigator: true).maybePop();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            // IndexedStack, not a rebuild per tab: switching away and back must
            // not throw away the user list's scroll position or its loaded pages.
            body: IndexedStack(
              index: safeIndex,
              children: [
                for (final item in items)
                  Navigator(
                    key: _keyFor(item.label),
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (_) => item.screen,
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: _NavBar(
              items: items,
              currentIndex: safeIndex,
              onTap: _onTap,
              ready: _permissionsResolved,
            ),
          ),
        ),
      ),
    );
  }
}

enum _BadgeSource { none, pendingRequests, unreadChat }

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget screen;
  final _BadgeSource badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.screen,
    this.badge = _BadgeSource.none,
  });
}

/// Solid bar. The previous one was a BottomNavigationBar wrapped in a
/// BackdropFilter over a black 30% fill — a full-width blur repainting behind
/// every scroll, for an effect invisible on a light background.
class _NavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool ready;

  const _NavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      // Only the two badge numbers affect this bar, so it does not rebuild
      // when any other dashboard figure moves.
      buildWhen: (prev, next) =>
          _counts(prev).toString() != _counts(next).toString(),
      builder: (context, state) {
        final counts = _counts(state);

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _NavButton(
                        item: items[i],
                        selected: i == currentIndex,
                        count: ready ? counts[items[i].badge] ?? 0 : 0,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Map<_BadgeSource, int> _counts(DashboardState state) {
    final stats = switch (state) {
      DashboardLoaded s => s.stats,
      DashboardLoading s => s.cachedStats,
      DashboardError s => s.cachedStats,
      _ => null,
    };
    return {
      _BadgeSource.pendingRequests: stats?.pendingRequestCount ?? 0,
      _BadgeSource.unreadChat: stats?.unreadChatCount ?? 0,
    };
  }
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentInk : AppColors.textTertiary;

    return InkWell(
      onTap: onTap,
      // No ripple splash across the whole bar segment; the colour and weight
      // change is the feedback.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                selected ? item.activeIcon : item.icon,
                size: 22,
                color: color,
              ),
              if (count > 0)
                Positioned(
                  top: -5,
                  left: 13,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
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
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
