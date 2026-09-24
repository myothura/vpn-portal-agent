import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

// C_LISTS_DS_IMPORTS — intl is gone: both NumberFormats this file built now
// point at Fmt, which builds one and keeps it. One of them sat in the price
// bar's build().
//
// M_DS_CONFIRM_IMPORT — and the two AlertDialogs this file wrote by hand are
// gone as well: both slot confirmations ask through the shared confirmAction,
// the same one the renewal and transfer confirmations use.
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/confirm_dialog.dart';

import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/dashboard/services/dashboard_service.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class DeviceSlotManagementScreen extends StatefulWidget {
  const DeviceSlotManagementScreen({super.key});

  @override
  State<DeviceSlotManagementScreen> createState() =>
      _DeviceSlotManagementScreenState();
}

class _DeviceSlotManagementScreenState
    extends State<DeviceSlotManagementScreen> {
  final _userService = UserManagementService();
  final _dashboardService = DashboardService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchFocus = FocusNode();

  List<VpnUser> _users = [];

  /// Ids mid-request, so a row shows its own progress instead of an overlay
  /// over the whole list.
  final Set<int> _busyIds = {};

  int _slotPrice = 1000;
  int _maxSlots = 5;
  int? _balance;

  bool _loading = true;
  bool _loadingMore = false;
  bool _searchOpen = false;
  int _page = 1;
  int _lastPage = 1;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchSettings();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _userService.getSlotSettings();
      final stats = await _dashboardService.getDashboardStats();
      if (!mounted) return;

      setState(() {
        if (settings != null) {
          _slotPrice = settings.price;
          _maxSlots = settings.maxSlots;
        }
        if (stats is DashboardStats) _balance = stats.creditBalance;
      });
    } catch (_) {
      // Falls back to the default price; the server is the authority on the
      // charge either way and will refuse if the balance is short.
    }
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
        _users = [];
      });
    }

    final response = await _userService.getVpnUsers(
      page: _page,
      search: _searchController.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      if (response != null) {
        _users = refresh ? response.users : [..._users, ...response.users];
        _lastPage = response.lastPage;
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
    final before = _users.length;
    _page++;
    await _load();
    if (mounted && _users.length == before) _page--;
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(refresh: true),
    );
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = !_searchOpen);

    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
      return;
    }

    _searchFocus.unfocus();
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _load(refresh: true);
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _addSlot(VpnUser user) async {
    // M_DS_ADD_CONFIRM — this was a hand-rolled AlertDialog. Nothing it said
    // is lost: the account, the before and after device count and the exact
    // charge are all still in front of the agent before the tap, now as the
    // same labelled rows every other credit-spending confirmation uses.
    //
    // The old dialog opened with its confirm button disabled and "Over your
    // balance" under the price when the charge was out of reach. confirmAction
    // has no disabled state, so a charge the balance cannot cover is refused
    // before the dialog opens instead of inside it, with that same sentence.
    // The tap ends in the same place, one step earlier.
    final balance = _balance;
    if (balance != null && _slotPrice > balance) {
      _toast('Over your balance');
      return;
    }

    final ok = await confirmAction(
      context,
      title: 'Add a device slot?',
      message:
          'ဤနေရာအတွက် Credit ကို ယခု နုတ်ယူပါမည်။ '
          'နောက်ထပ် သက်တမ်းတိုးတိုင်း ထပ်မံ ကောက်ခံပါမည်။',
      confirmLabel: 'Add slot',
      details: [
        ConfirmDetail('အသုံးပြုသူ', user.username),
        ConfirmDetail(
          'စက်ပစ္စည်း',
          '${user.extraDeviceSlots + 1} → ${user.extraDeviceSlots + 2}',
        ),
        // C_LISTS_DS_DIALOGFMT — the shared instance, not a new one per tap.
        ConfirmDetail('Cost', Fmt.money.format(_slotPrice), emphasise: true),
        if (balance != null)
          ConfirmDetail('Balance', Fmt.money.format(balance)),
      ],
    );
    if (!ok) return;

    setState(() => _busyIds.add(user.id));
    final success = await _userService.addDeviceSlots(user.id, 1);
    if (!mounted) return;
    setState(() => _busyIds.remove(user.id));

    _toast(
      success
          ? 'Slot added for ${user.username}.'
          : 'Could not add the slot. Check your balance.',
    );
    if (success) {
      _load(refresh: true);
      _fetchSettings();
    }
  }

  Future<void> _removeSlot(VpnUser user) async {
    // M_DS_REMOVE_CONFIRM — the same move as the add dialog. The sentence
    // about the refund is the whole point of this confirmation, so it stays
    // word for word as the message; the account and the device count the tap
    // changes are the labelled rows under it.
    //
    // destructive: true — no credit changes hands, but the slot cannot be got
    // back without paying for it a second time, and that is what the red
    // treatment means everywhere else in this app.
    final ok = await confirmAction(
      context,
      title: 'Remove a device slot?',
      // Stated outright: the server issues no refund, and an agent who
      // assumed otherwise would only find out by checking their balance.
      message: 'No credit is refunded for removing a slot.',
      confirmLabel: 'Remove',
      destructive: true,
      details: [
        ConfirmDetail('အသုံးပြုသူ', user.username),
        ConfirmDetail(
          'စက်ပစ္စည်း',
          '${user.extraDeviceSlots + 1} → ${user.extraDeviceSlots}',
          emphasise: true,
        ),
      ],
    );
    if (!ok) return;

    setState(() => _busyIds.add(user.id));
    final success = await _userService.removeDeviceSlots(user.id, 1);
    if (!mounted) return;
    setState(() => _busyIds.remove(user.id));

    _toast(success ? 'Slot removed.' : 'Could not remove the slot.');
    if (success) _load(refresh: true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Device slots')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _PriceBar(price: _slotPrice, balance: _balance),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_searchOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search by username',
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
                        suffixIcon: IconButton(
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
          Expanded(
            child: _loading
                ? const _ListSkeleton()
                : _users.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.surface,
                    child: Material(
                      color: AppColors.surface,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 96),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _users.length + 1,
                        itemBuilder: (context, i) {
                          if (i == _users.length) return _buildFooter();
                          final user = _users[i];
                          return _SlotRow(
                            key: ValueKey(user.id),
                            user: user,
                            busy: _busyIds.contains(user.id),
                            maxSlots: _maxSlots,
                            onAdd: () => _addSlot(user),
                            onRemove: () => _removeSlot(user),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'slot-search',
        onPressed: _toggleSearch,
        backgroundColor: AppColors.surface,
        foregroundColor: _searchOpen
            ? AppColors.accentInk
            : AppColors.textSecondary,
        elevation: 2,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: Icon(
          _searchOpen ? Iconsax.close_circle : Iconsax.search_normal_1,
          size: 20,
        ),
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
    return const SizedBox(height: 20);
  }

  Widget _buildEmpty() {
    if (_searchController.text.isNotEmpty) {
      return AppEmptyState(
        icon: Iconsax.search_status,
        title: 'No match for "${_searchController.text}"',
      );
    }
    return const AppEmptyState(
      icon: Iconsax.profile_2user,
      title: 'No users yet',
      subtitle: 'Device slots are added per user.',
    );
  }
}

// ── Price bar ─────────────────────────────────────────────────────────────

class _PriceBar extends StatelessWidget {
  final int price;
  final int? balance;

  const _PriceBar({required this.price, required this.balance});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // C_LISTS_DS_PRICEFMT — was NumberFormat('#,##0') here, constructed on
    // every frame this bar painted.
    final money = Fmt.money;

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Iconsax.mobile,
            color: AppColors.accentInk,
            background: AppColors.surface,
            size: 16,
            padding: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${money.format(price)} per slot',
                  style: t.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnInk,
                  ),
                ),
                Text(
                  // Charged per month, not once — worth saying next to the
                  // price, since a slot recurs at every renewal.
                  'Charged monthly at renewal',
                  style: t.bodySmall?.copyWith(
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (balance != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Balance',
                  style: t.bodySmall?.copyWith(
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  money.format(balance),
                  style: t.titleMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.textOnInk,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────

class _SlotRow extends StatelessWidget {
  final VpnUser user;
  final bool busy;

  /// From app-config, not a constant: the ceiling is an admin setting, and
  /// hard-coding 5 would let the app offer a slot the server then refuses.
  final int maxSlots;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _SlotRow({
    super.key,
    required this.user,
    required this.busy,
    required this.maxSlots,
    required this.onAdd,
    required this.onRemove,
  });

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

    // One device comes with the plan; extra_device_slots is what was bought
    // on top, so the total the user actually gets is one more.
    final extra = user.extraDeviceSlots;
    final total = extra + 1;

    // AVATAR_CACHE_M_DS — 256x256 of artwork, 0.2 MB decoded, for a circle
    // drawn 42 points across; and both files reach the cache, because the
    // face comes from the username's hash. Decoded for the 42-point slot,
    // rounded up to a multiple of 32 and never above the artwork's own 256.
    //
    // No RepaintBoundary: this row is a ListView item and ListView already
    // wraps each of its children in one.
    const slot = 42;
    const assetWidth = 256;
    final wanted = (slot * MediaQuery.devicePixelRatioOf(context)).ceil();
    final rounded = wanted < 32 ? 32 : ((wanted + 31) ~/ 32) * 32;
    final cacheWidth = rounded > assetWidth ? assetWidth : rounded;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              _avatarFor(user.username),
              width: 42,
              height: 42,
              cacheWidth: cacheWidth,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$total device${total == 1 ? '' : 's'}',
                      style: t.bodySmall?.copyWith(
                        color: extra > 0
                            ? AppColors.info
                            : AppColors.textTertiary,
                        fontWeight: extra > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (extra > 0)
                      Text(' · +$extra bought', style: t.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 40,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SlotButton(
                  icon: Icons.remove_rounded,
                  // Nothing to remove when the user is on the plan default.
                  enabled: extra > 0,
                  onTap: onRemove,
                ),
                const SizedBox(width: 6),
                _SlotButton(
                  icon: Icons.add_rounded,
                  enabled: extra < maxSlots,
                  onTap: onAdd,
                  filled: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  const _SlotButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppColors.background
        : filled
        ? AppColors.accentInk
        : AppColors.surfaceAlt;

    // C_LISTS_DS_HITAREA — 44 of hit area around a box that still paints at
    // 34. These two sit 6 pixels apart at the right edge of a row, and at 34
    // they were under the 44 minimum in both directions: plus and minus, next
    // to each other, each one a charge or a downgrade if it is the one you
    // hit by mistake.
    //
    // Ink rather than a Material of its own: the decoration is painted on the
    // list's Material, and the InkWell's splash goes on over it, so the
    // ripple still fills the visible box and not the 44 around it.
    return SizedBox(
      width: 44,
      height: 44,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Ink(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? AppColors.textTertiary
                    : filled
                    ? AppColors.textOnAccent
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// C_LISTS_DS_SKELETON — one ticker for the whole placeholder list.
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
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            _SkeletonBar(_shimmer, width: 42, height: 42, radius: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(_shimmer, width: 130, height: 13),
                  const SizedBox(height: 7),
                  _SkeletonBar(_shimmer, width: 90, height: 11),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 94 by 44: the two slot buttons at their new hit size, so the
            // placeholder occupies what the real row will.
            _SkeletonBar(_shimmer, width: 94, height: 44, radius: 9),
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
