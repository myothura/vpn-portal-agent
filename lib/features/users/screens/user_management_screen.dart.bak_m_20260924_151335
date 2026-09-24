import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

// C_LISTS_UM_IMPORTS — intl is gone from this file: the one DateFormat it
// built sat in a helper called from every row. Fmt holds it now, and
// confirmAction replaces the delete dialog written out below.
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';

import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/screens/add_user_screen.dart';
import 'package:vpn_agent_app/features/users/screens/edit_user_screen.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

/// One user's derived state, computed once per card rather than as four
/// separate untyped map lookups.
class _Expiry {
  final String label;
  final String date;
  final Color color;
  final Color wash;
  final IconData icon;

  const _Expiry(this.label, this.date, this.color, this.wash, this.icon);

  static _Expiry of(String? dateStr, String status) {
    if (status == 'inactive') {
      return const _Expiry(
        'Paused',
        'Inactive',
        AppColors.neutral,
        AppColors.neutralWash,
        Iconsax.pause_circle,
      );
    }
    if (dateStr == null) {
      return const _Expiry(
        'Active',
        'No expiry',
        AppColors.success,
        AppColors.successWash,
        Iconsax.tick_circle,
      );
    }

    try {
      final expiry = DateTime.parse(dateStr);
      final now = DateTime.now();
      final e = DateTime(expiry.year, expiry.month, expiry.day);
      final n = DateTime(now.year, now.month, now.day);
      final days = e.difference(n).inDays;
      // C_LISTS_UM_EXPIRYFMT — Fmt.date is the same pattern, built once. This
      // line runs for every visible row on every frame.
      final formatted = Fmt.date.format(expiry);

      if (n.isAfter(e)) {
        return _Expiry(
          'Expired',
          formatted,
          AppColors.danger,
          AppColors.dangerWash,
          Iconsax.close_circle,
        );
      }
      if (days == 0) {
        // "0d left" reads like a bug; it means the subscription lapses today.
        return _Expiry(
          'Today',
          formatted,
          AppColors.danger,
          AppColors.dangerWash,
          Iconsax.timer_1,
        );
      }
      if (days <= 7) {
        return _Expiry(
          '${days}d left',
          formatted,
          AppColors.warning,
          AppColors.warningWash,
          Iconsax.timer_1,
        );
      }
      return _Expiry(
        'Active',
        formatted,
        AppColors.success,
        AppColors.successWash,
        Iconsax.tick_circle,
      );
    } catch (_) {
      return const _Expiry(
        'Unknown',
        'Invalid date',
        AppColors.neutral,
        AppColors.neutralWash,
        Iconsax.warning_2,
      );
    }
  }
}

class _FilterOption {
  final String key;
  final String label;
  final IconData icon;

  const _FilterOption(this.key, this.label, this.icon);
}

class UserManagementScreen extends StatefulWidget {
  final String initialFilter;

  const UserManagementScreen({super.key, this.initialFilter = 'all'});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<VpnUser> _users = [];
  Timer? _debounce;
  String _query = '';
  late String _filter;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _lastPage = 1;

  /// C_LISTS_UM_FAILSTATE — the request itself failed, as opposed to coming
  /// back with nothing in it. Both used to land on the same "no users yet"
  /// panel, so a dropped connection read as an empty account and the only way
  /// out of it was to guess that pulling down might help.
  bool _loadFailed = false;

  /// Whether the search field currently holds anything.
  ///
  /// build() needs this and cannot read the controller for it — see the
  /// listener in initState.
  bool _searchHasText = false;

  /// Accounts lapsing within seven days, fetched separately from the main
  /// list. They cannot be derived from what is on screen: the list is
  /// paginated and filtered, so an account expiring tomorrow may sit on page
  /// four — or be excluded entirely by the active filter.
  List<VpnUser> _urgent = [];

  /// How many accounts are expiring in total. The strip only carries the ten
  /// most urgent; this is what the badge reports.
  int _urgentTotal = 0;

  /// Search is opened on demand rather than always occupying a band above the
  /// list. On a screen whose job is scanning rows, a permanently-visible
  /// search field costs height every session to serve the minority of them.
  bool _searchOpen = false;
  final FocusNode _searchFocus = FocusNode();

  static const _filters = [
    _FilterOption('all', 'All', Iconsax.profile_2user),
    _FilterOption('active', 'Active', Iconsax.tick_circle),
    _FilterOption('expiring', 'Expiring', Iconsax.timer_1),
    _FilterOption('business', 'Business', Iconsax.briefcase),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _searchController.addListener(_onSearchChanged);
    // C_LISTS_UM_FIELDLISTENER — build() reads the search controller to decide
    // what the field's trailing button does, and the only listener on it was
    // _onSearchChanged, which is debounced by 400ms and returns early when the
    // text has not changed since the last query. So between the first
    // keystroke and the debounce firing, build had never re-run: the cross
    // still carried the empty-field action, and tapping it closed search
    // instead of clearing what had just been typed. This keeps that one piece
    // of derived state in step, and dispose takes it off again.
    _searchController.addListener(_onSearchFieldChanged);
    // Pages load as the list reaches its end. The previous screen made the
    // agent tap a "Load More" button at the bottom of every page — with
    // thousands of users that is a tap per fifty rows.
    _scrollController.addListener(_onScroll);
    _load(refresh: true);
    _loadUrgent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchFieldChanged);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Rebuilds only when the field crosses between empty and not empty, so this
  /// costs one setState per transition rather than one per keystroke.
  void _onSearchFieldChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText == _searchHasText) return;
    setState(() => _searchHasText = hasText);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Twelve hundred pixels of runway — roughly eighteen rows. At 400 the
    // fetch started only as the end came into view, so a fast flick reached
    // the bottom before it returned and the spinner was on screen for most
    // of the scroll.
    if (position.pixels >= position.maxScrollExtent - 1200) _loadMore();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_query == _searchController.text) return;
      setState(() => _query = _searchController.text);
      _load(refresh: true);
    });
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = !_searchOpen);

    if (_searchOpen) {
      // After the frame, not during it: the field does not exist yet when
      // setState returns, so focusing here silently does nothing and the
      // keyboard never appears.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
      return;
    }

    // Closing clears the query: leaving a hidden filter applied would show a
    // truncated list with nothing on screen explaining why.
    _searchFocus.unfocus();
    if (_searchController.text.isEmpty && _query.isEmpty) return;
    _searchController.clear();
    setState(() => _query = '');
    _load(refresh: true);
  }

  void _onFilterChanged(String key) {
    if (_filter == key) return;
    HapticFeedback.selectionClick();
    setState(() => _filter = key);
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _users = [];
      });
    }

    final response = await _userService.getVpnUsers(
      page: _page,
      search: _query,
      filter: _filter,
    );
    if (!mounted) return;

    setState(() {
      // C_LISTS_UM_LOADFAIL — a null response is the service saying the
      // request did not come back. Recorded, rather than leaving the list as
      // it was and letting the empty state speak for it.
      _loadFailed = response == null;
      if (response != null) {
        // Appended in server order, never re-sorted. Sorting the accumulated
        // list on every page meant page two's rows interleaved into page one,
        // so everything already on screen shifted position mid-scroll and the
        // viewport jumped — which looked like the list resetting to the top.
        // Ordering is the server's job; it has all the rows, this has a page.
        _users = refresh ? response.users : [..._users, ...response.users];
        _lastPage = response.lastPage;
      }
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadUrgent() async {
    final response = await _userService.getVpnUsers(
      page: 1,
      filter: 'expiring',
    );
    if (!mounted || response == null) return;
    setState(() {
      _urgent = response.users.take(10).toList();
      _urgentTotal = response.total;
    });
  }

  /// Reloads the list AND the urgent strip together.
  ///
  /// They come from separate requests, so refreshing only the list left the
  /// strip asserting an account expires today after the agent had just
  /// renewed it — and its badge counting rows that no longer exist.
  Future<void> _refreshAll() async {
    await Future.wait([_load(refresh: true), _loadUrgent()]);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _page >= _lastPage) return;
    setState(() => _isLoadingMore = true);

    // PAGE_ROLLBACK_V1 — _page was advanced before the fetch and never put
    // back. One timed-out page meant the next scroll asked for the page
    // after it, so a whole page was skipped for the life of the screen
    // while the footer still read as if the list were complete.
    final before = _users.length;
    _page++;
    await _load();
    if (mounted && _users.length == before) _page--;
  }

  Future<void> _openUser(VpnUser user) async {
    final changed = await Navigator.push(
      context,
      AppTransitions.slide(EditUserScreen(user: user)),
    );
    if (changed == true) _refreshAll();
  }

  Future<void> _addUser() async {
    final created = await Navigator.push(
      context,
      AppTransitions.slide(const AddUserScreen()),
    );
    if (created == true) _refreshAll();
  }

  /// C_LISTS_UM_DELETE — no dialog here any more.
  ///
  /// The asking moved into the swipe's confirmDismiss, where confirmAction
  /// names the account and the plan before the tap. Leaving this one in place
  /// as well would have meant two dialogs for one gesture.
  Future<void> _deleteUser(VpnUser user) async {
    final ok = await _userService.deleteUser(user.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'User removed' : 'Could not remove user')),
    );
    if (ok) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // No app bar. The title only restated the tab already highlighted in
      // the nav, and the online count duplicated the dashboard's — both cost
      // a band of height above a screen whose job is scanning a long list.
      // The list is white; without this the controls above it floated on the
      // same page background as the rest of the app and the two areas ran
      // together. A tinted, textured band separates "tools" from "content".
      body: SafeArea(
        bottom: false,
        // minimum adds breathing room under the status bar: SafeArea alone
        // stops content overlapping it, it does not separate them.
        minimum: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_searchOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Search by username',
                          // Overrides the theme's form-field metrics locally. Those
                          // are sized for a login page where a field is the focus; a
                          // search bar is a control above a list and should not take
                          // a form field's height.
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 38,
                            minHeight: 38,
                          ),
                          prefixIcon: const Icon(
                            Iconsax.search_normal_1,
                            size: 17,
                            color: AppColors.textTertiary,
                          ),
                          // C_LISTS_UM_SUFFIX — reads the tracked flag, not
                          // the controller, so it is right from the first
                          // keystroke rather than from whenever the debounce
                          // last happened to rebuild this.
                          suffixIcon: _searchHasText
                              ? IconButton(
                                  tooltip: 'ရှာဖွေမှုကို ရှင်းမည်',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: const Icon(
                                    Iconsax.close_circle,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                    _load(refresh: true);
                                  },
                                )
                              : IconButton(
                                  tooltip: 'ရှာဖွေမှုကို ပိတ်မည်',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  icon: const Icon(
                                    Iconsax.close_circle,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                  onPressed: _toggleSearch,
                                ),
                        ),
                      ),
                    ),
            ),
            // Hidden only while search is open — those results are what the
            // agent is looking at. It stays under the expiring filter: the
            // list there is ordered by expiry but paginated, and the strip
            // still puts the ten most urgent one tap away without scrolling.
            if (_urgent.isNotEmpty && _query.isEmpty && !_searchOpen)
              _UrgentStrip(
                users: _urgent,
                total: _urgentTotal,
                onTap: _openUser,
                onSeeAll: () => _onFilterChanged('expiring'),
              ),
            SizedBox(
              // C_LISTS_UM_CHIPSCALE — the strip is horizontal, so it has to be
              // given a height; that height is derived from the label rather
              // than written down as 36. A 12pt line at 1.35 plus 10 of padding
              // above and below is 36 at the default text size and grows with
              // it, instead of cutting the chip labels off from about 1.2x up.
              height: MediaQuery.textScalerOf(context).scale(12) * 1.35 + 20,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                clipBehavior: Clip.none,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final selected = _filter == f.key;
                  return _FilterChip(
                    label: f.label,
                    icon: f.icon,
                    selected: selected,
                    onTap: () => _onFilterChanged(f.key),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const _ListSkeleton()
                  : _users.isEmpty
                  // C_LISTS_UM_EMPTYSPLIT — a failed request and an empty
                  // account are not the same screen. One offers a retry; the
                  // other offers the thing you would do next if the account
                  // really has no users in it.
                  ? (_loadFailed ? _buildLoadError() : _buildEmpty())
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      color: AppColors.accent,
                      backgroundColor: AppColors.surface,
                      // Rows separated by hairlines on a single surface
                      // rather than a card each: a card per user spent 10px
                      // of gap and a border on every row and fitted five to
                      // a screen. This fits nine.
                      // One Material for the whole list, and a fixed
                      // itemExtent. Row height never varies — avatar 44 plus
                      // 20 of padding plus the divider — so telling the
                      // viewport that up front lets it skip a layout pass
                      // per row while scrolling, which is where the
                      // jank came from on long lists.
                      child: Material(
                        color: AppColors.surface,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 96),
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemExtent: _UserRow.heightFor(context),
                          itemCount: _users.length + 1,
                          itemBuilder: (context, i) {
                            if (i == _users.length) return _buildFooter();
                            final user = _users[i];
                            return _UserRow(
                              key: ValueKey(user.id),
                              user: user,
                              onTap: () => _openUser(user),
                              // C_LISTS_UM_ROWDELETE — straight to the delete.
                              // The swipe has already asked.
                              onDelete: () => _deleteUser(user),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search above add, both within thumb reach. Search is a mode
          // toggle rather than a primary action, so it is the smaller,
          // surface-coloured button of the pair.
          FloatingActionButton.small(
            heroTag: 'search',
            onPressed: _toggleSearch,
            backgroundColor: AppColors.surface,
            foregroundColor: _searchOpen
                ? AppColors.accentInk
                : AppColors.textSecondary,
            elevation: 2,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border),
            ),
            child: Icon(
              _searchOpen ? Iconsax.close_circle : Iconsax.search_normal_1,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addUser,
            backgroundColor: AppColors.accentInk,
            foregroundColor: AppColors.textOnAccent,
            shape: const CircleBorder(),
            child: const Icon(Iconsax.add, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoadingMore) {
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
          '${_users.length} users',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_query.isNotEmpty) {
      return AppEmptyState(
        icon: Iconsax.search_status,
        title: 'No match for "$_query"',
        subtitle: 'Check the spelling or try part of the name.',
      );
    }
    if (_filter != 'all') {
      return AppEmptyState(
        icon: Iconsax.filter,
        title: 'No users in this filter',
        actionLabel: 'Show all users',
        onAction: () => _onFilterChanged('all'),
      );
    }
    return AppEmptyState(
      icon: Iconsax.profile_2user,
      title: 'No users yet',
      subtitle: 'Add your first user to get started.',
      actionLabel: 'Add user',
      onAction: _addUser,
    );
  }

  /// C_LISTS_UM_ERRORSTATE — shown when the list request failed, in place of
  /// the empty panel that used to stand in for both.
  Widget _buildLoadError() {
    return AppEmptyState(
      icon: Iconsax.warning_2,
      title: 'စာရင်း ဆွဲယူ၍ မရပါ',
      subtitle: 'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံကြိုးစားပါ။',
      actionLabel: 'ပြန်ကြိုးစားမည်',
      onAction: _refreshAll,
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  /// Row height, used as the list's itemExtent.
  ///
  /// Derived from the device's text scale rather than fixed. A constant 65
  /// held only at the default scale: raise the system font size and the two
  /// stacked text lines outgrew the box, which is what overflowed. The avatar
  /// sets the floor; text taller than it pushes the row instead.
  static double heightFor(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // 14pt title + 3 gap + 12pt caption, each at roughly 1.35 line height.
    final textBlock = scaler.scale(14) * 1.35 + 3 + scaler.scale(12) * 1.35;
    const avatar = 44.0;
    const verticalPadding = 19.0; // 10 top + 9 bottom
    const divider = 1.0;
    return (textBlock > avatar ? textBlock : avatar) +
        verticalPadding +
        divider;
  }

  final VpnUser user;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _UserRow({
    super.key,
    required this.user,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final expiry = _Expiry.of(user.expiryDate, user.status);
    final isBusiness = user.hasBusinessPlan;

    // No Material here — the list provides one. A Material per row means an
    // extra render layer for every visible item.
    final Widget row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 9),
        child: Row(
          children: [
            _Avatar(
              username: user.username,
              isBusiness: isBusiness,
              isOnline: user.isOnline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium?.copyWith(fontSize: 14),
                        ),
                      ),
                      if (isBusiness) ...[
                        const SizedBox(width: 6),
                        const _MiniTag(
                          label: 'BIZ',
                          color: AppColors.orange,
                          background: AppColors.orangeWash,
                        ),
                      ],
                      if (user.extraDeviceSlots > 0) ...[
                        const SizedBox(width: 5),
                        _MiniTag(
                          label: '+${user.extraDeviceSlots}',
                          color: AppColors.info,
                          background: AppColors.infoWash,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        expiry.label,
                        style: t.bodySmall?.copyWith(
                          color: expiry.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(' · ', style: t.bodySmall),
                      Flexible(
                        child: Text(
                          user.planName ?? 'No plan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Date on the right, as the reference puts the timestamp:
            // scannable as a column rather than buried mid-sentence.
            Text(
              expiry.date,
              style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );

    // Swipe to remove, in place of the long-press it replaces: a long-press
    // is invisible until someone happens to try it, whereas a swipe reveals
    // its own affordance the moment a finger moves sideways.
    //
    // C_LISTS_UM_DISMISS — right-to-left only. DismissDirection.horizontal
    // also claimed a drag begun at the left screen edge, which is where
    // Android's system back gesture starts: on a gesture-navigation phone the
    // two fought over every attempt to leave this screen, and whichever row
    // happened to be under the thumb offered to delete itself instead.
    //
    // confirmDismiss does the asking and still always returns false. The row
    // is never removed by the gesture itself — the delete call reloads the
    // list, and letting Dismissible also drop it would assert on the next
    // build, when the item count had not yet changed.
    final dismissible = Dismissible(
      key: ValueKey('dismiss-${user.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await confirmAction(
          context,
          title: 'ဤအသုံးပြုသူကို ဖယ်ရှားမလား',
          message:
              'ဖယ်ရှားလိုက်ပါက ချက်ချင်း ချိတ်ဆက်မှု ပြတ်တောက်သွားပြီး '
              'ပြန်လည် ပြင်ဆင်၍ မရနိုင်ပါ။',
          confirmLabel: 'ဖယ်ရှားမည်',
          destructive: true,
          details: [
            ConfirmDetail('အသုံးပြုသူ', user.username, emphasise: true),
            ConfirmDetail('အစီအစဉ်', user.planName ?? 'မရှိပါ'),
          ],
        );
        if (confirmed) onDelete();
        return false;
      },
      // One direction, so one panel: Dismissible shows background when no
      // secondaryBackground is given, whichever way the row is pulled. The
      // label hugs the edge the row is pulling away from, so it appears from
      // under the finger.
      background: const _SwipeAction(alignment: Alignment.centerRight),
      child: row,
    );

    // The divider belongs to the row, not to a separatorBuilder: with a fixed
    // itemExtent the list has no separate slot to put one in.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: dismissible),
        const SizedBox(height: 1),
      ],
    );
  }
}

/// Accounts lapsing within the week, pinned above the list.
///
/// These are the rows that cost the agent money if missed, and paging through
/// a filtered list to find them defeats the point. Horizontal, so it costs one
/// band of height however many there are.
class _UrgentStrip extends StatelessWidget {
  final List<VpnUser> users;
  final int total;
  final ValueChanged<VpnUser> onTap;
  final VoidCallback onSeeAll;

  const _UrgentStrip({
    required this.users,
    required this.total,
    required this.onTap,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: AppCard(
        // Plain white, no texture. The band carries an illustration with its
        // own palette; a wash behind it gives two backgrounds competing for
        // the same space.
        tone: SurfaceTone.plain,
        texture: CardTexture.none,
        showShadow: false,
        radius: AppTheme.radiusLg,
        // No horizontal padding: the avatar row runs to the card's own edges,
        // so a scrolled avatar is clipped by the card boundary rather than
        // vanishing at an inset line inside it. The header and the list each
        // re-add their own inset.
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 14),
        child: Stack(
          children: [
            const _ExpiringBackdrop(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(
                        Iconsax.timer_1,
                        size: 15,
                        color: AppColors.accentInk,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Expiring this week',
                        style: t.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Tapping through switches to the expiring filter, since the
                      // strip deliberately shows only the ten soonest.
                      InkWell(
                        onTap: onSeeAll,
                        borderRadius: BorderRadius.circular(999),
                        child: Row(
                          children: [
                            AppPill(
                              label: '$total',
                              color: AppColors.textOnAccent,
                              background: AppColors.accentInk,
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.accentInk,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // C_LISTS_UM_URGENTSCALE — 52 of avatar ring plus 5 of gap,
                // then the two 10pt caption lines, scaled. The flat 84 this
                // replaces is exactly what that works out to at the default
                // text size and at no size above it: at 1.3x the username line
                // underneath the portrait was cut in half.
                SizedBox(
                  height:
                      57 +
                      MediaQuery.textScalerOf(context).scale(10) * 1.35 * 2,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    // Clipped: Clip.none let avatars scroll on past the card's
                    // rounded edge and sit loose on the page behind it.
                    clipBehavior: Clip.hardEdge,
                    // The card no longer pads its sides, so the inset lives here:
                    // the row scrolls to the card's own edge and is clipped there.
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final user = users[i];
                      final expiry = _Expiry.of(user.expiryDate, user.status);
                      return SizedBox(
                        width: 60,
                        child: InkWell(
                          onTap: () => onTap(user),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                  border: Border.all(
                                    color: expiry.color,
                                    width: 2,
                                  ),
                                ),
                                child: _Avatar(
                                  username: user.username,
                                  isBusiness: user.hasBusinessPlan,
                                  isOnline: user.isOnline,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                expiry.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodySmall?.copyWith(
                                  color: expiry.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                user.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: t.bodySmall?.copyWith(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Artwork on the right of the expiring band.
///
/// Aligned right and faded in from the left: the label, the count and the
/// avatar row all live on the left, and the illustration fills the space they
/// leave rather than sitting behind them.
class _ExpiringBackdrop extends StatelessWidget {
  const _ExpiringBackdrop();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Align(
            alignment: Alignment.centerRight,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.5, 1.0],
                colors: [Colors.transparent, Colors.black26, Colors.black],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                // Faint. At anything stronger the hourglass and calendar read as
                // content to look at, competing with the avatar row that is
                // the actual point of the band. It is texture, not an image.
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/expiring_hero.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String username;
  final bool isBusiness;
  final bool isOnline;

  const _Avatar({
    required this.username,
    required this.isBusiness,
    required this.isOnline,
  });

  /// Illustrated portraits instead of an initial. There is no gender or photo
  /// on VpnUser, so one is picked from the username's hash: the same account
  /// always gets the same face, which makes a row recognisable on return
  /// rather than reshuffling on every rebuild.
  static const _avatars = [
    'assets/images/avatars/a1.png',
    'assets/images/avatars/a2.png',
  ];

  String get _asset {
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
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.asset(
              _asset,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
            ),
          ),
          if (isBusiness)
            Positioned(
              left: -1,
              top: -1,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: const Icon(
                  Iconsax.briefcase,
                  size: 7,
                  color: AppColors.textOnAccent,
                ),
              ),
            ),
          if (isOnline)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  // Ring in the surface colour so the dot reads as separate
                  // from whatever sits behind it.
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _MiniTag({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // One accent for the selected chip rather than a colour per filter. Four
    // hues across four chips gave every option equal visual weight and told
    // the eye nothing about which was active.
    return Material(
      // Deep green, matching the buttons. The bright accent is for fills and
      // status marks; using it on a control this size made the chip the
      // loudest thing on a screen whose subject is the list below it.
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
              Icon(
                icon,
                size: 14,
                color: selected
                    ? AppColors.textOnAccent
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// C_LISTS_UM_SKELETON — one ticker for the whole placeholder list.
///
/// AppSkeleton owns an AnimationController each, and eight rows of three bars
/// meant twenty-four controllers, twenty-four tickers and twenty-four copies
/// of the same 1200ms sweep, all running while the screen waited for its first
/// page. One controller lives here and every bar listens to it.
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
    // Same itemExtent as the real list, so nothing shifts when the rows
    // replace the placeholders.
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: _UserRow.heightFor(context),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 9),
        child: Row(
          children: [
            _SkeletonBar(_shimmer, width: 44, height: 44, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              // Two bars, matching the real row's two text lines. A third bar
              // was 21px of content the row's height never allowed for, so
              // every placeholder overflowed.
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(_shimmer, width: 130, height: 13),
                  const SizedBox(height: 6),
                  _SkeletonBar(_shimmer, width: 170, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One placeholder bar, painting from an animation it does not own.
///
/// The RepaintBoundary is what the per-bar controller was really buying: only
/// the bar repaints per frame, not the list behind it. That part is kept; the
/// ticker is not.
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

/// Red panel revealed behind a swiped row.
class _SwipeAction extends StatelessWidget {
  final Alignment alignment;

  const _SwipeAction({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.danger,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.trash, size: 18, color: AppColors.textOnAccent),
          SizedBox(width: 8),
          Text(
            'Remove',
            style: TextStyle(
              color: AppColors.textOnAccent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
